import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/media/data/smart_image_upload_service.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/app_local_cache.dart';
import '../../../treatment/data/patient_clinical_api.dart';
import '../../data/hair_image_detector.dart';
import '../../domain/models/hair_photo_analysis.dart';
import '../../domain/models/ai_assessment_model.dart';
import 'hair_test_state.dart';

const _unavailableAiAssessment = AiAssessmentModel(
  isAvailable: false,
  scalpHealthScore: 0,
  stageClassification: '',
  summary: 'Your assessment was received, but the AI summary is temporarily unavailable. Please retry or contact the clinic.',
  nextStepType: 'unavailable',
);

class HairTestCubit extends Cubit<HairTestState> {
  final ImagePicker _imagePicker;
  final AppLocalCache _cache;
  final SmartImageUploadService _imageUploadService;
  final Dio? _dio;
  final PatientClinicalApi _clinicalApi;
  String? _patientId;
  String? _sessionToken;
  final Set<String> _aiStatusPollingReferences = <String>{};
  final Map<String, int> _photoCheckGeneration = {};

  String get _draftKey => _patientId != null && _patientId!.isNotEmpty
      ? 'hair_test_draft_${_patientId}_v2'
      : 'hair_test_draft_v2';
  String get _legacyDraftKey => _patientId != null && _patientId!.isNotEmpty
      ? 'hair_test_draft_${_patientId}_v1'
      : 'hair_test_draft_v1';
  String get _completedKey => _patientId != null && _patientId!.isNotEmpty
      ? 'has_completed_hair_test_$_patientId'
      : 'has_completed_hair_test';
  String get _stageKey => _patientId != null && _patientId!.isNotEmpty
      ? 'hair_test_stage_$_patientId'
      : 'hair_test_stage';
  String get _dandruffKey => _patientId != null && _patientId!.isNotEmpty
      ? 'hair_test_dandruff_$_patientId'
      : 'hair_test_dandruff';
  String get _nameKey => _patientId != null && _patientId!.isNotEmpty
      ? 'hair_test_name_$_patientId'
      : 'hair_test_name';
  String get _ageKey => _patientId != null && _patientId!.isNotEmpty
      ? 'hair_test_age_$_patientId'
      : 'hair_test_age';
  String get _aiAssessmentKey => _patientId != null && _patientId!.isNotEmpty
      ? 'hair_test_ai_assessment_$_patientId'
      : 'hair_test_ai_assessment';
  String get _submissionResultKey =>
      _patientId != null && _patientId!.isNotEmpty
      ? 'hair_test_submission_result_$_patientId'
      : 'hair_test_submission_result';

  HairTestCubit({
    ImagePicker? imagePicker,
    AppLocalCache? cache,
    SmartImageUploadService? imageUploadService,
    Dio? dio,
    PatientClinicalApi? clinicalApi,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _cache = cache ?? AppLocalCache.instance,
       _imageUploadService =
           imageUploadService ?? const SmartImageUploadService(),
       // ignore: prefer_initializing_formals
       _dio = dio,
       _clinicalApi =
           clinicalApi ??
           PatientClinicalApi(
             client: dio != null
                 ? DioClient(
                     baseUrl: ApiEndpoints.backendBaseUrl,
                     customDio: dio,
                   )
                 : null,
           ),
       super(const HairTestState());

  Future<void> bindPatient(String? patientId, {String? sessionToken}) async {
    final previousPatientId = _patientId;
    final identityChanged = previousPatientId != patientId;
    if (identityChanged &&
        (previousPatientId != null ||
            (patientId != null && patientId.isNotEmpty))) {
      final previousState = state;
      // Clear visible patient data before any asynchronous cleanup or load for
      // the next identity, so a new account can never briefly see the old draft.
      emit(const HairTestState());
      _patientId = null;
      _sessionToken = null;
      await _clearPatientScopedData(previousPatientId, previousState);
      if (isClosed) return;
    }
    if (patientId == null || patientId.isEmpty) {
      _patientId = null;
      _sessionToken = null;
      if (!isClosed) emit(const HairTestState());
      return;
    }
    _patientId = patientId;
    _sessionToken = sessionToken;
    await loadSavedState();
    if (sessionToken != null && sessionToken.isNotEmpty) {
      await _syncWithBackend(sessionToken);
    }
  }

  Future<void> _clearPatientScopedData(
    String? patientId,
    HairTestState previousState,
  ) async {
    final photoDeletes = <Future<void>>[];
    for (final entry in previousState.photos.entries) {
      final path = entry.value;
      if (path.startsWith('http://') || path.startsWith('https://')) continue;
      photoDeletes.add(
        _imageUploadService.deletePrepared(
          path,
          previousState.optimizedPhotos[entry.key],
        ),
      );
    }
    await Future.wait(photoDeletes);
    final scopedKeys = patientId == null || patientId.isEmpty
        ? const <String>[]
        : [
            'hair_test_draft_${patientId}_v2',
            'hair_test_draft_${patientId}_v1',
            'has_completed_hair_test_$patientId',
            'hair_test_stage_$patientId',
            'hair_test_dandruff_$patientId',
            'hair_test_name_$patientId',
            'hair_test_age_$patientId',
            'hair_test_ai_assessment_$patientId',
            'hair_test_submission_result_$patientId',
          ];
    for (final key in [
      ...scopedKeys,
      'hair_test_draft_v2',
      'hair_test_draft_v1',
      'has_completed_hair_test',
      'has_skipped_hair_test',
      'hair_test_stage',
      'hair_test_dandruff',
      'hair_test_name',
      'hair_test_age',
      'hair_test_ai_assessment',
      'hair_test_submission_result',
    ]) {
      await _cache.remove(key);
    }
  }

  Future<void> _syncWithBackend(String token) async {
    try {
      final record = await _clinicalApi.getClinicalRecord(token);
      final rawReports = record['reports'] as List? ?? [];
      final reports = rawReports
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      final assessments = record['assessments'] as List? ?? [];
      final submitted = assessments
          .whereType<Map>()
          .where((a) => a['status'] != 'draft')
          .toList();
      final rawCarePlans = record['care_plans'] as List? ?? [];
      final carePlans = rawCarePlans
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      final Map<String, dynamic>? activeCarePlan = carePlans.isNotEmpty
          ? carePlans.first
          : null;

      if (submitted.isNotEmpty || reports.isNotEmpty || carePlans.isNotEmpty) {
        final latest = submitted.isNotEmpty ? submitted.first : null;
        final refNo = latest?['reference_no']?.toString();
        final stage = latest?['hair_loss_stage']?.toString();
        final serverStatus =
            latest?['status']?.toString() ??
            (carePlans.isNotEmpty ? 'reviewed' : 'submitted');

        AiAssessmentModel? aiModel = refNo == state.referenceNo
            ? state.aiAssessment
            : null;
        final rawAi = latest?['ai_assessment'];
        if (rawAi is Map) {
          try {
            aiModel = AiAssessmentModel.fromJson(
              Map<String, dynamic>.from(rawAi),
            );
            await _cache.put(_aiAssessmentKey, jsonEncode(aiModel.toJson()));
          } catch (_) {}
        }

        final aiStatus =
            latest?['ai_assessment_status']?.toString() ??
            (aiModel != null ? 'ready' : 'idle');
        final aiPending = aiStatus == 'queued' || aiStatus == 'processing';
        final photoRecords = latest?['scalp_photos'] is List
            ? List<dynamic>.from(latest!['scalp_photos'] as List)
            : const <dynamic>[];
        final serverPhotos = _photosFromScalpPhotoRecords(
          photoRecords,
          state.photos,
        );
        final photoAnalysis = _photoVerificationForAssessment(
          aiModel,
          markMissingUnavailable: !aiPending,
          sourcePhotos: serverPhotos,
          photoRecords: photoRecords,
        );

        if (!isClosed) {
          emit(
            state.copyWith(
              isCompleted: submitted.isNotEmpty ? true : state.isCompleted,
              referenceNo: refNo,
              stage: stage,
              name: latest?['full_name']?.toString() ?? state.name,
              age: latest?['age']?.toString() ?? state.age,
              dandruff: latest?['dandruff']?.toString() ?? state.dandruff,
              clinicalReports: reports,
              assessmentStatus: serverStatus,
              aiAssessmentStatus: aiStatus,
              isSubmitting: aiPending,
              isSubmitted: submitted.isNotEmpty && !aiPending,
              doctorCarePlan: activeCarePlan,
              aiAssessment: aiModel,
              clearAiAssessment: aiModel == null,
              photos: serverPhotos,
              photoAnalysis: photoAnalysis,
            ),
          );
        }
        if (aiPending && refNo != null && refNo.isNotEmpty) {
          unawaited(_pollAiAssessmentStatus(refNo, token));
        }
        if (submitted.isNotEmpty) {
          await _cache.put(_completedKey, true);
        }
        if (stage != null) await _cache.put(_stageKey, stage);
        return;
      }
    } catch (_) {}

    // In-progress answers/photos are intentionally local Hive drafts. The
    // backend is called once, with the final multipart submission.
  }

  Future<void> loadSavedState() async {
    try {
      await _cache.remove(_legacyDraftKey);
      final useLegacyCache = _patientId == null;
      final hasCompleted =
          _cache.getBool(_completedKey) ??
          (useLegacyCache ? _cache.getBool('has_completed_hair_test') : null) ??
          false;
      var restored = state;
      final rawDraft =
          _cache.getString(_draftKey) ??
          (useLegacyCache ? _cache.getString('hair_test_draft_v2') : null);
      if (rawDraft != null) {
        try {
          final draft = jsonDecode(rawDraft) as Map<String, dynamic>;
          restored = state.copyWith(
            currentStep: ((draft['currentStep'] as num?)?.toInt() ?? 0)
                .clamp(0, state.totalSteps - 1)
                .toInt(),
            isRetesting: draft['isRetesting'] as bool? ?? false,
            name: draft['name'] as String?,
            age: draft['age'] as String?,
            selectedGender: draft['selectedGender'] as String?,
            stage: draft['stage'] as String?,
            primaryConcern: draft['primaryConcern'] as String?,
            duration: draft['duration'] as String?,
            dandruff: draft['dandruff'] as String?,
            gutHealth: draft['gutHealth'] as String?,
            stressLevel: draft['stressLevel'] as String?,
            familyHistory: draft['familyHistory'] as String?,
            allergyStatus: draft['allergyStatus'] as String?,
            allergyDetails: draft['allergyDetails'] as String? ?? '',
            currentMedicationsStatus:
                draft['currentMedicationsStatus'] as String?,
            currentMedications: draft['currentMedications'] as String? ?? '',
            photos:
                (draft['photos'] as Map?)?.map(
                  (key, value) => MapEntry(key.toString(), value.toString()),
                ) ??
                const {},
            optimizedPhotos:
                (draft['optimizedPhotos'] as Map?)?.map(
                  (key, value) => MapEntry(key.toString(), value.toString()),
                ) ??
                const {},
            photoAnalysis:
                (draft['photoAnalysis'] as Map?)?.map(
                  (key, value) => MapEntry(
                    key.toString(),
                    HairPhotoAnalysis.fromJson(
                      Map<String, dynamic>.from(value as Map),
                    ),
                  ),
                ) ??
                const {},
          );
        } catch (_) {
          await _cache.remove(_draftKey);
        }
      }
      // Migrate in-progress per-photo checks from older app versions. New
      // drafts defer image review to the combined assessment submission.
      final recoveredAnalysis = Map<String, HairPhotoAnalysis>.from(
        restored.photoAnalysis,
      );
      for (final entry in recoveredAnalysis.entries.toList()) {
        if (entry.value.isAnalyzing) {
          recoveredAnalysis[entry.key] = HairPhotoAnalysis(
            label: entry.value.label,
            photoPath: entry.value.photoPath,
            status: HairDetectionStatus.awaitingAssessment,
            confidence: 0,
            message: 'Your photo will be reviewed with the assessment.',
            details: 'Image review is combined with assessment submission.',
          );
        }
      }
      restored = restored.copyWith(photoAnalysis: recoveredAnalysis);
      final savedStage =
          _cache.getString(_stageKey) ??
          (useLegacyCache ? _cache.getString('hair_test_stage') : null);
      final savedDandruff =
          _cache.getString(_dandruffKey) ??
          (useLegacyCache ? _cache.getString('hair_test_dandruff') : null);
      final savedName =
          _cache.getString(_nameKey) ??
          (useLegacyCache ? _cache.getString('hair_test_name') : null) ??
          '';
      final savedAge =
          _cache.getString(_ageKey) ??
          (useLegacyCache ? _cache.getString('hair_test_age') : null) ??
          '';

      AiAssessmentModel? savedAiModel;
      final rawAiString =
          _cache.getString(_aiAssessmentKey) ??
          (useLegacyCache ? _cache.getString('hair_test_ai_assessment') : null);
      if (rawAiString != null && rawAiString.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawAiString);
          if (decoded is Map) {
            savedAiModel = AiAssessmentModel.fromJson(
              Map<String, dynamic>.from(decoded),
            );
          }
        } catch (_) {}
      }

      Map<String, dynamic>? savedSubmission;
      final rawSubmission =
          _cache.getString(_submissionResultKey) ??
          (useLegacyCache
              ? _cache.getString('hair_test_submission_result')
              : null);
      if (rawSubmission != null && rawSubmission.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawSubmission);
          if (decoded is Map) {
            savedSubmission = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
      }

      if (savedSubmission != null) {
        final rawCachedAi = savedSubmission['ai_assessment'];
        if (rawCachedAi is Map) {
          try {
            savedAiModel = AiAssessmentModel.fromJson(
              Map<String, dynamic>.from(rawCachedAi),
            );
          } catch (_) {}
        }
        final cachedTest = savedSubmission['test'] is Map
            ? Map<String, dynamic>.from(savedSubmission['test'] as Map)
            : const <String, dynamic>{};
        final photoRecords = cachedTest['scalp_photos'] is List
            ? List<dynamic>.from(cachedTest['scalp_photos'] as List)
            : const <dynamic>[];
        final localPhotos = await _existingLocalPhotoPaths(
          savedSubmission['local_photo_paths'],
        );
        final localOptimizedPhotos = await _existingLocalPhotoPaths(
          savedSubmission['local_optimized_photo_paths'],
        );
        final restoredPhotos = _photosFromScalpPhotoRecords(photoRecords, {
          ...restored.photos,
          ...localPhotos,
        });
        emit(
          restored.copyWith(
            isCompleted: true,
            isSubmitted: true,
            referenceNo: savedSubmission['reference_no']?.toString(),
            assessmentStatus: 'submitted',
            aiAssessmentStatus:
                savedSubmission['ai_assessment_status']?.toString() ??
                (savedAiModel == null ? 'queued' : 'ready'),
            name: savedName,
            age: savedAge,
            aiAssessment: savedAiModel,
            photos: restoredPhotos,
            optimizedPhotos: {
              ...restored.optimizedPhotos,
              ...localOptimizedPhotos,
            },
            photoAnalysis: _photoVerificationForAssessment(
              savedAiModel,
              markMissingUnavailable:
                  savedSubmission['ai_assessment_status'] == 'ready' ||
                  savedSubmission['ai_assessment_status'] == 'failed',
              sourcePhotos: restoredPhotos,
              previousAnalysis: restored.photoAnalysis,
              photoRecords: photoRecords,
            ),
          ),
        );
      } else if (hasCompleted) {
        final hasObservedPattern = restored.primaryConcern != null;
        emit(
          restored.copyWith(
            isCompleted: true,
            name: savedName,
            age: savedAge,
            stage: hasObservedPattern
                ? null
                : savedStage ?? 'Stage 1 - Mild temple thinning',
            clearStage: hasObservedPattern,
            dandruff: savedDandruff ?? 'Severe Dandruff & Flakes',
            aiAssessment: savedAiModel,
          ),
        );
      } else if (rawDraft != null) {
        emit(restored.copyWith(aiAssessment: savedAiModel));
      }
    } catch (_) {}
  }

  Future<void> nextStep({
    String? sessionToken,
    String? patientName,
    int? patientAge,
    String? patientGender,
  }) async {
    final validationMessage = _validationMessageForCurrentStep();
    if (validationMessage != null) {
      emit(state.copyWith(errorMessage: validationMessage));
      return;
    }

    if (state.currentStep < state.totalSteps - 1) {
      emit(
        state.copyWith(
          currentStep: state.currentStep + 1,
          clearErrorMessage: true,
        ),
      );
      _saveDraft();
    } else {
      await submitTest(
        sessionToken: sessionToken,
        patientName: patientName,
        patientAge: patientAge,
        patientGender: patientGender,
      );
    }
  }

  String? _validationMessageForCurrentStep() {
    return _validationMessageForState(state, state.currentStep);
  }

  Future<void> skipPhotosAndSubmit({
    String? sessionToken,
    String? patientName,
    int? patientAge,
    String? patientGender,
  }) async {
    emit(state.copyWith(currentStep: state.totalSteps - 1));
    await submitTest(
      sessionToken: sessionToken,
      patientName: patientName,
      patientAge: patientAge,
      patientGender: patientGender,
    );
  }

  void prevStep() {
    if (state.currentStep > 0) {
      emit(
        state.copyWith(
          currentStep: state.currentStep - 1,
          clearErrorMessage: true,
        ),
      );
      _saveDraft();
    }
  }

  Future<void> submitTest({
    String? sessionToken,
    String? patientName,
    int? patientAge,
    String? patientGender,
  }) async {
    if (state.isSubmitting) return;
    if (sessionToken?.trim().isNotEmpty == true) {
      for (var step = 0; step < state.totalSteps - 1; step++) {
        final message = _validationMessageForStep(step);
        if (message != null) {
          emit(state.copyWith(currentStep: step, errorMessage: message));
          return;
        }
      }
    } else {
      if (state.primaryConcern == null && state.stage == null) {
        emit(
          state.copyWith(
            currentStep: 0,
            errorMessage: 'Choose an illustration, or select “Not sure.”',
          ),
        );
        return;
      }
    }
    final name = patientName?.trim().isNotEmpty == true
        ? patientName!.trim()
        : state.name.trim();
    final age = patientAge?.toString() ?? state.age.trim();
    final gender = patientGender?.trim().isNotEmpty == true
        ? patientGender!.trim()
        : state.selectedGender;
    final stage = state.stage ?? state.primaryConcern;
    final duration = state.duration ?? '1 - 3 years';
    final dandruff = state.dandruff ?? 'Mild / None';
    final gutHealth = state.gutHealth ?? 'Normal';
    final stressLevel = state.stressLevel ?? 'Moderate';
    final familyHistory = state.familyHistory ?? 'No known family history';

    if (sessionToken?.trim().isNotEmpty == true) {
      if (name.isEmpty) {
        emit(
          state.copyWith(
            errorMessage: 'Complete your profile before sending the assessment to the clinic.',
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          isSubmitting: true,
          uploadProgress: 0,
          clearErrorMessage: true,
          name: name,
          age: age,
        ),
      );

      try {
        const photoFieldPrefix = {
          'Front Hairline': 'photo_front',
          'Crown / Top': 'photo_top',
          'Side Profile / Temples': 'photo_left',
          'Side Profile': 'photo_left',
          'Back / Vertex': 'photo_back',
        };
        // Leave room for multipart boundaries and the questionnaire fields.
        const maxAssessmentBodyBytes = 89 * 1024 * 1024;
        var assessmentImageBytes = 0;
        final formFields = <String, dynamic>{
          'full_name': name,
          if (age.isNotEmpty) 'age': age,
          if (gender?.isNotEmpty == true) 'gender': gender,
          'duration': duration,
          if (state.primaryConcern?.isNotEmpty == true)
            'primary_concern': state.primaryConcern,
          if (stage?.isNotEmpty == true) 'stage': stage,
          'dandruff': dandruff,
          'gut_health': gutHealth,
          'stress_level': stressLevel,
          'family_history': familyHistory,
          if (state.allergyStatus?.isNotEmpty == true)
            'allergy_status': state.allergyStatus,
          if (state.allergyDetails.trim().isNotEmpty)
            'allergy_details': state.allergyDetails.trim(),
          if (state.currentMedicationsStatus?.isNotEmpty == true)
            'current_medications_status': state.currentMedicationsStatus,
          if (state.currentMedications.trim().isNotEmpty)
            'current_medications': state.currentMedications.trim(),
        };
        for (final entry in photoFieldPrefix.entries) {
          final originalPath = state.photos[entry.key];
          if (originalPath == null || originalPath.isEmpty) continue;
          if (originalPath.startsWith('http://') ||
              originalPath.startsWith('https://')) {
            formFields['${entry.value}_url'] = originalPath;
            continue;
          }

          final originalFile = File(originalPath);
          if (!await originalFile.exists()) {
            throw const FileSystemException(
              'A cached assessment photo is missing.',
            );
          }
          final sourceBytes = await originalFile.length();
          final optimizedPath =
              state.optimizedPhotos[entry.key] ?? originalPath;
          final sourceIsTooLarge =
              sourceBytes > SmartImageUploadService.maxFileBytes;
          if (sourceIsTooLarge && optimizedPath == originalPath) {
            throw const FileSystemException(
              'This image is larger than 25 MiB and has no compressed upload copy. Select it again to prepare it.',
            );
          }
          final primaryPath = sourceIsTooLarge ? optimizedPath : originalPath;
          final primaryFile = File(primaryPath);
          if (!await primaryFile.exists()) {
            throw const FileSystemException(
              'A prepared assessment photo is missing. Select it again.',
            );
          }
          assessmentImageBytes += await primaryFile.length();
          if (assessmentImageBytes > maxAssessmentBodyBytes) {
            throw const FileSystemException(
              'Assessment photos exceed the safe 89 MiB file budget. Remove a photo or choose smaller images.',
            );
          }
          formFields[entry.value] = await _multipartImage(primaryPath);
          // A source above the API's 25 MiB per-file limit is represented by
          // its validated derivative as the primary part; do not upload it
          // twice under the optional derivative field.
          if (!sourceIsTooLarge && optimizedPath != originalPath) {
            final optimizedFile = File(optimizedPath);
            if (!await optimizedFile.exists()) {
              throw const FileSystemException(
                'An optimized assessment photo is missing.',
              );
            }
            assessmentImageBytes += await optimizedFile.length();
            if (assessmentImageBytes > maxAssessmentBodyBytes) {
              throw const FileSystemException(
                'Assessment photos exceed the safe 89 MiB file budget. Remove a photo or choose smaller images.',
              );
            }
            formFields['${entry.value}_optimized'] = await _multipartImage(
              optimizedPath,
            );
          }
        }
        final client = _dio != null
            ? null
            : DioClient(baseUrl: ApiEndpoints.backendBaseUrl);
        final dioToUse = _dio ?? client!.dio;
        final response = await dioToUse.post<Map<String, dynamic>>(
          ApiEndpoints.hairTestSubmitForm,
          data: FormData.fromMap(formFields),
          options: Options(
            contentType: Headers.multipartFormDataContentType,
            headers: {
              'Authorization': 'Bearer $sessionToken',
              'X-Media-Purpose': 'assessment',
            },
            connectTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 120),
            receiveTimeout: const Duration(seconds: 120),
          ),
          onSendProgress: (sent, total) {
            if (total <= 0 || isClosed) return;
            emit(state.copyWith(uploadProgress: (sent / total).clamp(0, 1)));
          },
        );
        final referenceNo =
            response.data?['reference_no']?.toString() ??
            response.data?['data']?['reference_no']?.toString() ??
            response.data?['data']?['test']?['reference_no']?.toString();
        final responseData = response.data?['data'];
        final cachedSubmission = responseData is Map
            ? Map<String, dynamic>.from(responseData)
            : Map<String, dynamic>.from(response.data ?? const {});
        cachedSubmission['local_photo_paths'] = _localPhotoPaths(state.photos);
        cachedSubmission['local_optimized_photo_paths'] = _localPhotoPaths(
          state.optimizedPhotos,
        );
        await _cache.put(_submissionResultKey, jsonEncode(cachedSubmission));

        final rawAi =
            response.data?['data']?['ai_assessment'] ??
            response.data?['data']?['test']?['ai_assessment'];
        AiAssessmentModel? aiModel;
        if (rawAi is Map) {
          try {
            aiModel = AiAssessmentModel.fromJson(
              Map<String, dynamic>.from(rawAi),
            );
            await _cache.put(_aiAssessmentKey, jsonEncode(aiModel.toJson()));
          } catch (_) {}
        }
        if (aiModel == null && (referenceNo == null || referenceNo.isEmpty)) {
          aiModel = _unavailableAiAssessment;
        }
        final aiStatus =
            response.data?['data']?['ai_assessment_status']?.toString() ??
            (aiModel != null ? 'ready' : 'queued');
        final aiPending = aiStatus == 'queued' || aiStatus == 'processing';
        final photoAnalysis = _photoVerificationForAssessment(
          aiModel,
          markMissingUnavailable: !aiPending,
        );

        emit(
          state.copyWith(
            referenceNo: referenceNo,
            assessmentStatus: 'submitted',
            aiAssessmentStatus: aiStatus,
            isSubmitting: aiPending,
            clearUploadProgress: true,
            isSubmitted: !aiPending,
            isCompleted: true,
            isRetesting: false,
            clearErrorMessage: true,
            aiAssessment: aiModel,
            clearAiAssessment: aiModel == null,
            photoAnalysis: photoAnalysis,
          ),
        );

        if (aiPending && referenceNo != null && referenceNo.isNotEmpty) {
          unawaited(_pollAiAssessmentStatus(referenceNo, sessionToken!));
        }
      } on DioException catch (dioErr) {
        final serverMessage = dioErr.response?.data is Map
            ? (dioErr.response?.data['message'] ??
                      dioErr.response?.data['error']?['message'])
                  ?.toString()
            : null;
        emit(
          state.copyWith(
            isSubmitting: false,
            clearUploadProgress: true,
            errorMessage: serverMessage ?? 'Assessment could not be sent to the clinic. Check your connection and try again.',
          ),
        );
        return;
      } on FileSystemException catch (error) {
        emit(
          state.copyWith(
            isSubmitting: false,
            clearUploadProgress: true,
            errorMessage: error.message.isNotEmpty ? error.message : 'Assessment photos could not be prepared. Try selecting them again.',
          ),
        );
        return;
      } catch (_) {
        emit(
          state.copyWith(
            isSubmitting: false,
            clearUploadProgress: true,
            errorMessage: 'Assessment could not be sent to the clinic. Check your connection and try again.',
          ),
        );
        return;
      }
    } else {
      emit(
        state.copyWith(
          isSubmitted: true,
          isCompleted: true,
          assessmentStatus: 'submitted',
          isRetesting: false,
          clearErrorMessage: true,
          name: name,
          age: age,
          stage: stage,
          duration: duration,
          dandruff: dandruff,
          gutHealth: gutHealth,
          stressLevel: stressLevel,
          familyHistory: familyHistory,
        ),
      );
    }

    try {
      await _cache.put(_completedKey, true);
      await _cache.put('has_completed_hair_test', true);
      await _cache.put('has_skipped_hair_test', false);
      if (state.stage != null) {
        await _cache.put(_stageKey, state.stage!);
        await _cache.put('hair_test_stage', state.stage!);
      } else {
        await _cache.remove(_stageKey);
        await _cache.remove('hair_test_stage');
      }
      if (state.dandruff != null) {
        await _cache.put(_dandruffKey, state.dandruff!);
        await _cache.put('hair_test_dandruff', state.dandruff!);
      }
      await _cache.put(_nameKey, state.name);
      await _cache.put(_ageKey, state.age);
      await _cache.remove(_draftKey);
    } catch (_) {}
  }

  String? _validationMessageForStep(int step) {
    final answerState = state.copyWith(currentStep: step);
    // Keep the same validation rules for forward navigation and submission.
    return _validationMessageForState(answerState, step);
  }

  String? _validationMessageForState(HairTestState value, int step) {
    switch (step) {
      case 0:
        return value.primaryConcern == null && value.stage == null
            ? 'Choose an illustration, or select “Not sure.”'
            : null;
      case 1:
        return value.duration == null
            ? 'Choose how long you have noticed hair loss to continue.'
            : null;
      case 2:
        return value.dandruff == null
            ? 'Choose a scalp condition to continue.'
            : null;
      case 3:
        return value.stressLevel == null
            ? 'Choose a stress level to continue.'
            : null;
      case 4:
        return value.gutHealth == null
            ? 'Choose a digestion and gut-health option to continue.'
            : null;
      case 5:
        return null;
      case 6:
        if (value.allergyStatus == null) {
          return 'Choose an allergy option to continue.';
        }
        if (value.allergyStatus == 'Yes, I have allergies' &&
            value.allergyDetails.trim().isEmpty) {
          return 'List the known allergies, or choose “Not sure.”';
        }
        if (value.currentMedicationsStatus == null) {
          return 'Choose a medicines and supplements option to continue.';
        }
        if (value.currentMedicationsStatus == 'Yes' &&
            value.currentMedications.trim().isEmpty) {
          return 'List current medicines or supplements, or choose “Not sure.”';
        }
        return null;
      default:
        return null;
    }
  }

  void startRetest() {
    unawaited(_cache.remove(_submissionResultKey));
    unawaited(_cache.remove(_aiAssessmentKey));
    emit(
      state.copyWith(
        isRetesting: true,
        isSubmitted: false,
        currentStep: 0,
        clearReferenceNo: true,
        clearAiAssessment: true,
        clearErrorMessage: true,
      ),
    );
    _saveDraft();
  }

  Future<void> markAssessmentSkipped() async {
    await _cache.put('has_skipped_hair_test', true);
  }

  void dismissReport() {
    emit(
      state.copyWith(
        isSubmitted: false,
        isRetesting: false,
        currentStep: 0,
        clearErrorMessage: true,
      ),
    );
  }

  Future<Uri?> getReportDownloadUri(String reportId) async {
    final token = _sessionToken;
    if (token == null || token.isEmpty) return null;
    try {
      return await _clinicalApi.getReportDownloadUri(
        accessToken: token,
        reportId: reportId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> refreshClinicalReports() async {
    final token = _sessionToken;
    if (token != null && token.isNotEmpty) {
      await _syncWithBackend(token);
    }
  }

  void setPatientInfo({String? name, String? age}) {
    emit(
      state.copyWith(
        name: name ?? state.name,
        age: age ?? state.age,
        clearErrorMessage: true,
      ),
    );
    _saveDraft();
  }

  void selectGender(String gender) {
    emit(state.copyWith(selectedGender: gender, clearErrorMessage: true));
    _saveDraft();
  }

  void selectStage(String stage) {
    emit(
      state.copyWith(
        stage: stage,
        primaryConcern: stage,
        clearErrorMessage: true,
      ),
    );
    _saveDraft();
  }

  void selectPrimaryConcern(String concern) {
    emit(
      state.copyWith(
        primaryConcern: concern,
        clearStage: true,
        clearErrorMessage: true,
      ),
    );
    _saveDraft();
  }

  void selectDandruff(String condition) {
    emit(state.copyWith(dandruff: condition, clearErrorMessage: true));
    _saveDraft();
  }

  void selectGutHealth(String gut) {
    emit(state.copyWith(gutHealth: gut, clearErrorMessage: true));
    _saveDraft();
  }

  void selectStressLevel(String level) {
    emit(state.copyWith(stressLevel: level, clearErrorMessage: true));
    _saveDraft();
  }

  void selectFamilyHistory(String history) {
    emit(state.copyWith(familyHistory: history, clearErrorMessage: true));
    _saveDraft();
  }

  void setAllergyStatus(String status) {
    emit(state.copyWith(allergyStatus: status, clearErrorMessage: true));
    _saveDraft();
  }

  void setAllergyDetails(String details) {
    emit(state.copyWith(allergyDetails: details, clearErrorMessage: true));
    _saveDraft();
  }

  void setCurrentMedicationsStatus(String status) {
    emit(
      state.copyWith(currentMedicationsStatus: status, clearErrorMessage: true),
    );
    _saveDraft();
  }

  void setCurrentMedications(String medications) {
    emit(
      state.copyWith(currentMedications: medications, clearErrorMessage: true),
    );
    _saveDraft();
  }

  void selectDuration(String duration) {
    emit(state.copyWith(duration: duration, clearErrorMessage: true));
    _saveDraft();
  }

  Future<void> pickPhoto({
    required String label,
    required ImageSource source,
  }) async {
    emit(state.copyWith(isPickingImage: true, errorMessage: null));
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 100,
      );

      if (pickedFile != null) {
        final prepared = await _imageUploadService.prepare(pickedFile.path);
        final updatedPhotos = Map<String, String>.from(state.photos);
        updatedPhotos[label] = prepared.originalPath;
        final updatedOptimizedPhotos = Map<String, String>.from(
          state.optimizedPhotos,
        );
        updatedOptimizedPhotos[label] = prepared.uploadPath;

        final updatedAnalysis = Map<String, HairPhotoAnalysis>.from(
          state.photoAnalysis,
        );
        updatedAnalysis[label] = HairPhotoAnalysis(
          label: label,
          photoPath: prepared.originalPath,
          status: HairDetectionStatus.analyzing,
          confidence: 0.0,
          message: 'Analyzing scalp and hair features...',
          details: 'Scanning follicular density...',
        );

        emit(
          state.copyWith(
            photos: updatedPhotos,
            optimizedPhotos: updatedOptimizedPhotos,
            photoAnalysis: updatedAnalysis,
            isPickingImage: false,
          ),
        );
        _saveDraft();

        _markPhotoAwaitingAssessment(label);
      } else {
        emit(state.copyWith(isPickingImage: false));
      }
    } catch (e) {
      final message = e is FileSystemException && e.message.isNotEmpty
          ? e.message
          : 'Could not prepare that image. Please choose it again.';
      emit(state.copyWith(isPickingImage: false, errorMessage: message));
    }
  }

  Future<void> setPhoto(
    String label,
    String path, [
    HairPhotoAnalysis? precomputedAnalysis,
  ]) async {
    final updatedPhotos = Map<String, String>.from(state.photos);
    updatedPhotos[label] = path;
    final updatedOptimizedPhotos = Map<String, String>.from(
      state.optimizedPhotos,
    );
    updatedOptimizedPhotos[label] = path;

    final initialAnalysis =
        precomputedAnalysis ??
        HairPhotoAnalysis(
          label: label,
          photoPath: path,
          status: HairDetectionStatus.analyzing,
          confidence: 0.0,
          message: 'Analyzing scalp and hair features...',
          details: 'Scanning...',
        );

    final updatedAnalysis = Map<String, HairPhotoAnalysis>.from(
      state.photoAnalysis,
    );
    updatedAnalysis[label] = initialAnalysis;

    emit(
      state.copyWith(
        photos: updatedPhotos,
        optimizedPhotos: updatedOptimizedPhotos,
        photoAnalysis: updatedAnalysis,
        clearErrorMessage: true,
      ),
    );
    _saveDraft();

    if (precomputedAnalysis != null) return;
    _markPhotoAwaitingAssessment(label);
  }

  void _markPhotoAwaitingAssessment(String label) {
    final originalPath = state.photos[label];
    if (originalPath == null || originalPath.isEmpty || isClosed) return;

    final updatedAnalysis = Map<String, HairPhotoAnalysis>.from(
      state.photoAnalysis,
    );
    updatedAnalysis[label] = HairPhotoAnalysis(
      label: label,
      photoPath: originalPath,
      status: HairDetectionStatus.awaitingAssessment,
      confidence: 0,
      message: 'Your photo will be reviewed with the assessment.',
      details: 'AI review is combined with assessment submission to reduce API requests.',
    );
    emit(state.copyWith(photoAnalysis: updatedAnalysis));
    _saveDraft();
  }

  Future<void> retryPhotoAnalysis(String label) async {
    final originalPath = state.photos[label];
    if (originalPath == null || originalPath.isEmpty || isClosed) return;
    final checkId = (_photoCheckGeneration[label] ?? 0) + 1;
    _photoCheckGeneration[label] = checkId;
    final uploadPath = state.optimizedPhotos[label] ?? originalPath;
    final token = _sessionToken?.trim();
    final current = Map<String, HairPhotoAnalysis>.from(state.photoAnalysis);
    current[label] = HairPhotoAnalysis(
      label: label,
      photoPath: originalPath,
      status: HairDetectionStatus.analyzing,
      confidence: 0,
      message: 'Checking whether this is a clear scalp photo…',
      details: 'This retry checks the selected image with the clinic service.',
    );
    emit(state.copyWith(photoAnalysis: current));

    final result =
        (token == null || token.isEmpty) &&
            HairImageDetector.analyzerOverride == null
        ? HairPhotoAnalysis(
            label: label,
            photoPath: originalPath,
            status: HairDetectionStatus.verificationUnavailable,
            confidence: 0,
            message: 'Sign in to retry this photo check.',
            details: 'Photo verification requires an authenticated session.',
          )
        : await HairImageDetector.analyze(
            uploadPath,
            label: label,
            sessionToken: token,
            dioClient: _dio,
          );

    if (isClosed ||
        _photoCheckGeneration[label] != checkId ||
        state.photos[label] != originalPath) {
      return;
    }
    final updated = Map<String, HairPhotoAnalysis>.from(state.photoAnalysis);
    updated[label] = HairPhotoAnalysis(
      label: label,
      photoPath: originalPath,
      status: result.status,
      confidence: result.confidence,
      message: result.message,
      details: result.details,
    );
    emit(state.copyWith(photoAnalysis: updated));
    _saveDraft();
  }

  void removePhoto(String label) {
    _photoCheckGeneration[label] = (_photoCheckGeneration[label] ?? 0) + 1;
    final updatedPhotos = Map<String, String>.from(state.photos);
    final oldOriginal = updatedPhotos.remove(label);
    final updatedOptimizedPhotos = Map<String, String>.from(
      state.optimizedPhotos,
    );
    final oldOptimized = updatedOptimizedPhotos.remove(label);
    final updatedAnalysis = Map<String, HairPhotoAnalysis>.from(
      state.photoAnalysis,
    );
    updatedAnalysis.remove(label);
    emit(
      state.copyWith(
        photos: updatedPhotos,
        optimizedPhotos: updatedOptimizedPhotos,
        photoAnalysis: updatedAnalysis,
        clearErrorMessage: true,
      ),
    );
    if (oldOriginal != null) {
      unawaited(_imageUploadService.deletePrepared(oldOriginal, oldOptimized));
    }
    _saveDraft();
  }

  Map<String, dynamic> _draftJson() => {
    'currentStep': state.currentStep,
    'isRetesting': state.isRetesting,
    'name': state.name,
    'age': state.age,
    'selectedGender': state.selectedGender,
    'stage': state.stage,
    'primaryConcern': state.primaryConcern,
    'duration': state.duration,
    'dandruff': state.dandruff,
    'gutHealth': state.gutHealth,
    'stressLevel': state.stressLevel,
    'familyHistory': state.familyHistory,
    'allergyStatus': state.allergyStatus,
    'allergyDetails': state.allergyDetails,
    'currentMedicationsStatus': state.currentMedicationsStatus,
    'currentMedications': state.currentMedications,
    'photos': state.photos,
    'optimizedPhotos': state.optimizedPhotos,
    'photoAnalysis': state.photoAnalysis.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
  };

  void _saveDraft() {
    _cache.put(_draftKey, jsonEncode(_draftJson()));
  }

  void _deleteCachedPhotoFiles(HairTestState snapshot) {
    for (final entry in snapshot.photos.entries) {
      final original = entry.value;
      if (original.startsWith('http://') || original.startsWith('https://')) {
        continue;
      }
      unawaited(
        _imageUploadService.deletePrepared(
          original,
          snapshot.optimizedPhotos[entry.key],
        ),
      );
    }
  }

  void reset() {
    _deleteCachedPhotoFiles(state);
    unawaited(_cache.remove(_submissionResultKey));
    unawaited(_cache.remove(_aiAssessmentKey));
    emit(const HairTestState());
    _saveDraft();
  }

  Future<void> fetchAiAssessment({
    bool forceRefresh = false,
    String? sessionToken,
  }) async {
    final ref = state.referenceNo;
    if (ref == null || ref.isEmpty) return;
    final token = sessionToken ?? _sessionToken;
    if (token == null || token.isEmpty) return;

    if (!forceRefresh && state.aiAssessment != null) return;
    final dioToUse =
        _dio ??
        DioClient(
          baseUrl: ApiEndpoints.backendBaseUrl,
          enableDebugLogging: false,
        ).dio;
    if (forceRefresh) {
      await dioToUse.post<Map<String, dynamic>>(
        ApiEndpoints.hairTestAiAssessmentRetry(ref),
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    }
    if (!isClosed) {
      emit(state.copyWith(isSubmitting: true, isSubmitted: false));
    }
    await _pollAiAssessmentStatus(ref, token);
  }

  Map<String, HairPhotoAnalysis> _photoVerificationForAssessment(
    AiAssessmentModel? aiModel, {
    bool markMissingUnavailable = false,
    Map<String, String>? sourcePhotos,
    Map<String, HairPhotoAnalysis>? previousAnalysis,
    List<dynamic> photoRecords = const [],
  }) {
    const labelsByAngle = {
      'front': 'Front Hairline',
      'top': 'Crown / Top',
      'left': 'Side Profile / Temples',
      'right': 'Side Profile / Temples',
      'temples': 'Side Profile / Temples',
      'back': 'Back / Vertex',
    };
    final photos = sourcePhotos ?? state.photos;
    final results = <String, HairPhotoAnalysis>{
      ...(previousAnalysis ?? state.photoAnalysis),
    };
    final verifiedLabels = <String>{};
    for (final verification in aiModel?.scalpPhotoVerification ?? const []) {
      final label =
          labelsByAngle[verification['angle']?.toString().toLowerCase() ?? ''];
      if (label == null || !photos.containsKey(label)) continue;
      verifiedLabels.add(label);
      final status = switch (verification['status']?.toString()) {
        'hairDetected' => HairDetectionStatus.hairDetected,
        'notHair' => HairDetectionStatus.notHair,
        'lowClarity' => HairDetectionStatus.lowClarity,
        _ => HairDetectionStatus.verificationUnavailable,
      };
      results[label] = HairPhotoAnalysis(
        label: label,
        photoPath: photos[label]!,
        status: status,
        confidence: ((verification['confidence'] as num?)?.toDouble() ?? 0)
            .clamp(0, 1),
        message:
            verification['message']?.toString() ??
            _photoVerificationMessage(status),
        details: verification['details']?.toString() ?? '',
      );
    }
    for (final rawRecord in photoRecords.whereType<Map>()) {
      final angle = rawRecord['angle']?.toString().toLowerCase() ?? '';
      final label = labelsByAngle[angle];
      final rawStatus = rawRecord['verification_status']?.toString();
      if (label == null ||
          rawStatus == null ||
          rawStatus == 'pending' ||
          !photos.containsKey(label)) {
        continue;
      }
      final status = switch (rawStatus) {
        'hairDetected' => HairDetectionStatus.hairDetected,
        'notHair' => HairDetectionStatus.notHair,
        'lowClarity' => HairDetectionStatus.lowClarity,
        _ => HairDetectionStatus.verificationUnavailable,
      };
      verifiedLabels.add(label);
      results[label] = HairPhotoAnalysis(
        label: label,
        photoPath: photos[label]!,
        status: status,
        confidence:
            ((rawRecord['verification_confidence'] as num?)?.toDouble() ?? 0)
                .clamp(0, 1),
        message:
            rawRecord['verification_message']?.toString() ??
            _photoVerificationMessage(status),
        details: rawRecord['verification_details']?.toString() ?? '',
      );
    }
    if (markMissingUnavailable) {
      for (final entry in photos.entries) {
        if (verifiedLabels.contains(entry.key)) continue;
        results[entry.key] = HairPhotoAnalysis(
          label: entry.key,
          photoPath: entry.value,
          status: HairDetectionStatus.verificationUnavailable,
          confidence: 0,
          message: _photoVerificationMessage(
            HairDetectionStatus.verificationUnavailable,
          ),
          details: 'No usable visual verification result was returned.',
        );
      }
    }
    return results;
  }

  Map<String, String> _photosFromScalpPhotoRecords(
    List<dynamic> records,
    Map<String, String> existingPhotos,
  ) {
    const labelsByAngle = {
      'front': 'Front Hairline',
      'top': 'Crown / Top',
      'left': 'Side Profile / Temples',
      'right': 'Side Profile / Temples',
      'temples': 'Side Profile / Temples',
      'back': 'Back / Vertex',
    };
    final photos = Map<String, String>.from(existingPhotos);
    for (final rawRecord in records.whereType<Map>()) {
      final angle = rawRecord['angle']?.toString().toLowerCase() ?? '';
      final label = labelsByAngle[angle];
      if (label == null || photos.containsKey(label)) continue;
      final url = rawRecord['url']?.toString();
      if (url != null && url.isNotEmpty) photos[label] = url;
    }
    return photos;
  }

  String _photoVerificationMessage(
    HairDetectionStatus status,
  ) => switch (status) {
    HairDetectionStatus.hairDetected =>
      'Scalp and hair are visually present in this photo.',
    HairDetectionStatus.notHair => 'This photo does not appear to show a scalp. Choose a close-up scalp photo.',
    HairDetectionStatus.lowClarity =>
      'The scalp is too unclear to review. Choose a brighter, sharper photo.',
    HairDetectionStatus.verificationUnavailable =>
      'Could not visually verify this photo. Please ask the clinic for help.',
    HairDetectionStatus.analyzing => 'Checking your photo…',
    HairDetectionStatus.awaitingAssessment =>
      'Your photo will be reviewed with the assessment.',
  };

  Future<void> _pollAiAssessmentStatus(String referenceNo, String token) async {
    if (token.isEmpty ||
        referenceNo.isEmpty ||
        !_aiStatusPollingReferences.add(referenceNo)) {
      return;
    }
    try {
      final dioToUse =
          _dio ??
          DioClient(
            baseUrl: ApiEndpoints.backendBaseUrl,
            enableDebugLogging: false,
          ).dio;
      // Keep the loading state through a second, slower check only when the
      // first says work is still running. This caps the flow at three Worker
      // requests total: one multipart submit and at most two status reads.
      for (var attempt = 0; attempt < 2; attempt++) {
        await Future<void>.delayed(Duration(seconds: attempt == 0 ? 2 : 4));
        if (isClosed || state.referenceNo != referenceNo) return;

        final response = await dioToUse.get<Map<String, dynamic>>(
          ApiEndpoints.hairTestAiAssessmentStatus(referenceNo),
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        final payload = response.data?['data'];
        final status = payload is Map
            ? payload['status']?.toString() ?? 'processing'
            : 'processing';

        if (status == 'ready' &&
            payload is Map &&
            payload['ai_assessment'] is Map) {
          final aiModel = AiAssessmentModel.fromJson(
            Map<String, dynamic>.from(payload['ai_assessment'] as Map),
          );
          await _cache.put(_aiAssessmentKey, jsonEncode(aiModel.toJson()));
          await _cacheAssessmentResult(referenceNo, 'ready', aiModel);
          if (!isClosed) {
            emit(
              state.copyWith(
                aiAssessment: aiModel,
                aiAssessmentStatus: 'ready',
                isSubmitting: false,
                isSubmitted: true,
                photoAnalysis: _photoVerificationForAssessment(aiModel),
              ),
            );
          }
          return;
        }

        if (status == 'failed') {
          await _cacheAssessmentResult(
            referenceNo,
            'failed',
            _unavailableAiAssessment,
            markPhotosUnavailable: true,
          );
          if (!isClosed) {
            emit(
              state.copyWith(
                aiAssessment: _unavailableAiAssessment,
                aiAssessmentStatus: 'failed',
                assessmentStatus: 'ai_processing_failed',
                isSubmitting: false,
                isSubmitted: true,
                photoAnalysis: _photoVerificationForAssessment(
                  _unavailableAiAssessment,
                  markMissingUnavailable: true,
                ),
              ),
            );
          }
          return;
        }

        if (attempt == 1 || !['queued', 'processing'].contains(status)) {
          await _cacheAssessmentResult(
            referenceNo,
            'unavailable',
            _unavailableAiAssessment,
            markPhotosUnavailable: true,
          );
          if (!isClosed) {
            emit(
              state.copyWith(
                aiAssessment: _unavailableAiAssessment,
                aiAssessmentStatus: 'unavailable',
                isSubmitting: false,
                isSubmitted: true,
                photoAnalysis: _photoVerificationForAssessment(
                  _unavailableAiAssessment,
                  markMissingUnavailable: true,
                ),
              ),
            );
          }
          return;
        }
      }
    } catch (_) {
      if (!isClosed && state.referenceNo == referenceNo) {
        emit(
          state.copyWith(
            aiAssessment: _unavailableAiAssessment,
            aiAssessmentStatus: 'unavailable',
            isSubmitting: false,
            isSubmitted: true,
            photoAnalysis: _photoVerificationForAssessment(
              _unavailableAiAssessment,
              markMissingUnavailable: true,
            ),
          ),
        );
      }
    } finally {
      _aiStatusPollingReferences.remove(referenceNo);
    }
  }

  Map<String, String> _localPhotoPaths(Map<String, String> paths) => {
    for (final entry in paths.entries)
      if (entry.value.trim().isNotEmpty &&
          !entry.value.startsWith('http://') &&
          !entry.value.startsWith('https://'))
        entry.key: entry.value,
  };

  Future<Map<String, String>> _existingLocalPhotoPaths(dynamic value) async {
    if (value is! Map) return const {};
    final existing = <String, String>{};
    for (final entry in value.entries) {
      final label = entry.key.toString();
      final path = entry.value?.toString() ?? '';
      if (label.isEmpty ||
          path.isEmpty ||
          path.startsWith('http://') ||
          path.startsWith('https://')) {
        continue;
      }
      try {
        if (await File(path).exists()) existing[label] = path;
      } catch (_) {}
    }
    return existing;
  }

  Future<void> _cacheAssessmentResult(
    String referenceNo,
    String status,
    AiAssessmentModel aiModel, {
    bool markPhotosUnavailable = false,
  }) async {
    Map<String, dynamic> saved = {};
    final previous = _cache.getString(_submissionResultKey);
    if (previous != null && previous.isNotEmpty) {
      try {
        final decoded = jsonDecode(previous);
        if (decoded is Map) saved = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    final photoResults = aiModel.scalpPhotoVerification;
    final resultByFile = {
      for (final result in photoResults)
        result['file_name']?.toString() ?? '': result,
    };
    final rawTest = saved['test'];
    if (rawTest is Map) {
      final test = Map<String, dynamic>.from(rawTest);
      final rawPhotos = test['scalp_photos'];
      if (rawPhotos is List) {
        test['scalp_photos'] = rawPhotos.map((rawPhoto) {
          if (rawPhoto is! Map) return rawPhoto;
          final photo = Map<String, dynamic>.from(rawPhoto);
          final result = resultByFile[photo['file_name']?.toString() ?? ''];
          if (result != null) {
            photo['verification_status'] = result['status'];
            photo['verification_confidence'] = result['confidence'];
            photo['verification_message'] = result['message'];
            photo['verification_details'] = result['details'];
          } else if (markPhotosUnavailable) {
            photo['verification_status'] = 'verificationUnavailable';
            photo['verification_confidence'] = 0;
            photo['verification_message'] = _photoVerificationMessage(
              HairDetectionStatus.verificationUnavailable,
            );
          }
          return photo;
        }).toList();
      }
      test['ai_assessment'] = aiModel.toJson();
      test['ai_assessment_status'] = status;
      saved['test'] = test;
    }
    saved['reference_no'] = referenceNo;
    saved['ai_assessment_status'] = status;
    saved['ai_assessment'] = aiModel.toJson();
    await _cache.put(_submissionResultKey, jsonEncode(saved));
  }

  Future<MultipartFile> _multipartImage(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const FileSystemException('A cached assessment photo is missing.');
    }
    if (await file.length() > SmartImageUploadService.maxFileBytes) {
      throw const FileSystemException('An assessment photo exceeds 25 MiB.');
    }
    final extension = path.split('.').last.toLowerCase();
    final subtype = switch (extension) {
      'jpg' || 'jpeg' => 'jpeg',
      'png' => 'png',
      'webp' => 'webp',
      'gif' => 'gif',
      'avif' => 'avif',
      'heic' => 'heic',
      'heif' => 'heif',
      _ => throw const FileSystemException(
        'Unsupported assessment photo format.',
      ),
    };
    return MultipartFile.fromFile(
      path,
      filename: path.split('/').last,
      contentType: DioMediaType.parse('image/$subtype'),
    );
  }

  Future<bool> generatePersonalizedDietPlan() async {
    final ref = state.referenceNo;
    final token = _sessionToken;
    if (ref == null ||
        ref.isEmpty ||
        token == null ||
        token.isEmpty ||
        state.isGeneratingDietPlan) {
      return false;
    }
    emit(state.copyWith(isGeneratingDietPlan: true, clearDietPlanError: true));
    try {
      final dioToUse =
          _dio ??
          DioClient(
            baseUrl: ApiEndpoints.backendBaseUrl,
            enableDebugLogging: false,
          ).dio;
      final response = await dioToUse.post<Map<String, dynamic>>(
        ApiEndpoints.hairTestDietPlan(ref),
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final rawAi = response.data?['data']?['ai_assessment'];
      if (rawAi is! Map) throw StateError('Meal plan response is missing.');
      final aiModel = AiAssessmentModel.fromJson(
        Map<String, dynamic>.from(rawAi),
      );
      await _cache.put(_aiAssessmentKey, jsonEncode(aiModel.toJson()));
      if (!isClosed) {
        emit(
          state.copyWith(aiAssessment: aiModel, isGeneratingDietPlan: false),
        );
      }
      return true;
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isGeneratingDietPlan: false,
            dietPlanError: 'The meal plan could not be created right now. Please try again.',
          ),
        );
      }
      return false;
    }
  }

  Future<void> clearSavedAssessment() async {
    _deleteCachedPhotoFiles(state);
    for (final key in [
      _draftKey,
      _legacyDraftKey,
      _completedKey,
      _stageKey,
      _dandruffKey,
      _nameKey,
      _ageKey,
      _aiAssessmentKey,
      _submissionResultKey,
      'hair_test_draft_v2',
      'hair_test_draft_v1',
      'has_completed_hair_test',
      'has_skipped_hair_test',
      'hair_test_stage',
      'hair_test_dandruff',
      'hair_test_name',
      'hair_test_age',
      'hair_test_ai_assessment',
    ]) {
      await _cache.remove(key);
    }
    emit(const HairTestState());
  }
}
