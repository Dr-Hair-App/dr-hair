import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dr_hair/core/storage/app_local_cache.dart';
import 'package:dr_hair/core/media/data/smart_image_upload_service.dart';
import 'package:dr_hair/features/hair_test/data/hair_image_detector.dart';
import 'package:dr_hair/features/hair_test/domain/models/hair_photo_analysis.dart';
import 'package:dr_hair/features/hair_test/presentation/viewmodels/hair_test_cubit.dart';
import 'package:dr_hair/features/treatment/data/patient_clinical_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

class _FakeImagePicker extends Fake implements ImagePicker {
  final XFile? fileToReturn;

  _FakeImagePicker({this.fileToReturn});

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    if (fileToReturn != null) {
      final source = File(fileToReturn!.path);
      await source.parent.create(recursive: true);
      if (!await source.exists()) {
        await source.writeAsBytes([0xff, 0xd8, 0xff, 0xd9], flush: true);
      }
    }
    return fileToReturn;
  }
}

SmartImageUploadService _testImageUploadService() => SmartImageUploadService(
  supportDirectoryProvider: () async {
    final directory = Directory(
      '${Directory.systemTemp.path}/drhair_cubit_upload_test',
    );
    await directory.create(recursive: true);
    return directory;
  },
);

void main() {
  group('HairTestCubit', () {
    test(
      'clears dependent allergy and medication answers when changed to no',
      () {
        final cubit = HairTestCubit(cache: AppLocalCache.inMemory());
        cubit
          ..setAllergyStatus('Yes, I have allergies')
          ..setAllergyDetails('A known medicine allergy')
          ..setAllergyStatus('No known allergies')
          ..setCurrentMedicationsStatus('Yes')
          ..setCurrentMedications('A current supplement')
          ..setCurrentMedicationsStatus('No');

        expect(cubit.state.allergyDetails, isEmpty);
        expect(cubit.state.currentMedications, isEmpty);
        cubit.close();
      },
    );

    test(
      'does not submit stale allergy or medication details when status is no',
      () async {
        final submittedForm = Completer<FormData>();
        final dio = Dio(BaseOptions(baseUrl: 'https://test.drhair.local'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/api/v1/hair-tests/submit_form') {
                submittedForm.complete(options.data as FormData);
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'data': {
                        'reference_no': 'HT-SAFETY-001',
                        'ai_assessment_status': 'ready',
                        'ai_assessment': {
                          'ai_status': 'available',
                          'summary': 'Assessment received.',
                        },
                      },
                    },
                  ),
                );
                return;
              }
              handler.reject(DioException(requestOptions: options));
            },
          ),
        );
        final cubit = HairTestCubit(dio: dio, cache: AppLocalCache.inMemory());
        cubit.emit(
          cubit.state.copyWith(
            primaryConcern: 'Reported thinning',
            duration: 'Less than 6 months',
            dandruff: 'No noticeable flakes or itching',
            stressLevel: 'Low / Manageable',
            gutHealth: 'No',
            hairFallTrend: 'No, it has been gradual or stable',
            scalpSymptoms: 'No',
            allergyStatus: 'No known allergies',
            allergyDetails: 'Old allergy detail',
            currentMedicationsStatus: 'No',
            currentMedications: 'Old medicine detail',
          ),
        );

        await cubit.submitTest(
          sessionToken: 'test-token',
          patientName: 'Test Patient',
        );
        final fields = (await submittedForm.future).fields
            .map((field) => field.key)
            .toSet();

        expect(fields, contains('allergy_status'));
        expect(fields, contains('current_medications_status'));
        expect(fields, isNot(contains('allergy_details')));
        expect(fields, isNot(contains('current_medications')));
        await cubit.close();
      },
    );

    test(
      'status refresh reads pending state without posting an AI retry',
      () async {
        var retryRequests = 0;
        var statusReads = 0;
        final dio = Dio(BaseOptions(baseUrl: 'https://test.drhair.local'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/api/v1/patient/clinical-record') {
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'data': {
                        'assessments': [],
                        'reports': [],
                        'care_plans': [],
                      },
                    },
                  ),
                );
                return;
              }
              if (options.path.endsWith('/ai_assessment/retry')) {
                retryRequests++;
              }
              if (options.path.endsWith('/ai_assessment/status')) {
                statusReads++;
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'data': {'status': 'processing'},
                    },
                  ),
                );
                return;
              }
              handler.reject(DioException(requestOptions: options));
            },
          ),
        );
        final cubit = HairTestCubit(dio: dio, cache: AppLocalCache.inMemory());
        await cubit.bindPatient('patient-1', sessionToken: 'test-token');
        cubit.emit(
          cubit.state.copyWith(
            referenceNo: 'HT-PENDING-001',
            isCompleted: true,
            isSubmitted: true,
            aiAssessmentStatus: 'queued',
          ),
        );

        await cubit.refreshAiAssessmentStatus();

        expect(statusReads, 1);
        expect(retryRequests, 0);
        expect(cubit.state.aiAssessment, isNull);
        expect(cubit.state.aiAssessmentStatus, 'processing');
        expect(cubit.state.isSubmitting, isFalse);
        expect(cubit.state.isSubmitted, isTrue);
        await cubit.close();
      },
    );

    test('keeps assessment pending until the AI response is ready', () async {
      final aiRequestStarted = Completer<void>();
      final aiResponse = Completer<Map<String, dynamic>>();
      final dio = Dio(BaseOptions(baseUrl: 'https://test.drhair.local'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (options.path == '/api/v1/hair-tests/submit_form') {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'reference_no': 'HT-TEST-001'},
                ),
              );
              return;
            }
            if (options.path ==
                '/api/v1/hair-tests/HT-TEST-001/ai_assessment/status') {
              if (!aiRequestStarted.isCompleted) aiRequestStarted.complete();
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'status': 'success', 'data': await aiResponse.future},
                ),
              );
              return;
            }
            handler.reject(DioException(requestOptions: options));
          },
        ),
      );
      final cubit = HairTestCubit(dio: dio, cache: AppLocalCache.inMemory());
      cubit
        ..selectPrimaryConcern('Early thinning')
        ..selectDuration('Less than 6 months')
        ..selectDandruff('Occasional flakes')
        ..selectStressLevel('Moderate')
        ..selectGutHealth('Normal')
        ..selectFamilyHistory('No known family history')
        ..selectHairFallTrend('No, it has been gradual or stable')
        ..selectScalpSymptoms('No')
        ..setAllergyStatus('No known allergies')
        ..setCurrentMedicationsStatus('No');

      final submission = cubit.submitTest(
        sessionToken: 'test-session-token',
        patientName: 'Test Patient',
        patientAge: 30,
      );
      await aiRequestStarted.future;

      expect(cubit.state.isSubmitting, isTrue);
      expect(cubit.state.isSubmitted, isFalse);
      expect(cubit.state.aiAssessment, isNull);

      aiResponse.complete({
        'status': 'ready',
        'ai_assessment': {
          'ai_status': 'available',
          'scalp_health_score': 72,
          'stage_classification': 'Reported pattern',
          'summary': 'Screening summary based on reported answers.',
          'recommended_regimen': {'daily_steps': []},
          'next_step_recommendation': {
            'type': 'products',
            'reason': 'Daily care guidance is a reasonable next step.',
          },
        },
      });
      await submission;
      for (
        var attempt = 0;
        attempt < 100 && cubit.state.isSubmitting;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(cubit.state.isSubmitting, isFalse);
      expect(cubit.state.isSubmitted, isTrue);
      expect(cubit.state.aiAssessment?.isAvailable, isTrue);
      await cubit.close();
    });

    test(
      'makes at most two status reads and keeps loading between them',
      () async {
        final firstStatusRead = Completer<void>();
        final resultReady = Completer<void>();
        var statusReads = 0;
        var submitRequests = 0;
        final dio = Dio(BaseOptions(baseUrl: 'https://test.drhair.local'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/api/v1/hair-tests/submit_form') {
                submitRequests++;
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'data': {
                        'reference_no': 'HT-LIMIT-001',
                        'ai_assessment_status': 'queued',
                      },
                    },
                  ),
                );
                return;
              }
              statusReads++;
              if (statusReads == 1) firstStatusRead.complete();
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': statusReads == 1
                        ? {'status': 'processing'}
                        : {
                            'status': 'ready',
                            'ai_assessment': {
                              'ai_status': 'available',
                              'scalp_health_score': 72,
                              'stage_classification': 'Reported pattern',
                              'summary': 'Result is ready.',
                            },
                          },
                  },
                ),
              );
            },
          ),
        );
        final cubit = HairTestCubit(dio: dio, cache: AppLocalCache.inMemory());
        final subscription = cubit.stream.listen((state) {
          if (state.aiAssessment?.isAvailable == true &&
              !resultReady.isCompleted) {
            resultReady.complete();
          }
        });
        cubit
          ..selectPrimaryConcern('Early thinning')
          ..selectDuration('Less than 6 months')
          ..selectDandruff('Occasional flakes')
          ..selectStressLevel('Moderate')
          ..selectGutHealth('Normal')
          ..selectFamilyHistory('No known family history')
          ..selectHairFallTrend('No, it has been gradual or stable')
          ..selectScalpSymptoms('No')
          ..setAllergyStatus('No known allergies')
          ..setCurrentMedicationsStatus('No');

        await cubit.submitTest(
          sessionToken: 'test-session-token',
          patientName: 'Test Patient',
          patientAge: 30,
        );
        await firstStatusRead.future;
        expect(cubit.state.isSubmitting, isTrue);
        expect(cubit.state.isSubmitted, isFalse);

        await resultReady.future.timeout(const Duration(seconds: 10));
        expect(submitRequests, 1);
        expect(statusReads, 2);
        expect(cubit.state.isSubmitting, isFalse);
        expect(cubit.state.isSubmitted, isTrue);
        await subscription.cancel();
        await cubit.close();
      },
    );

    test(
      'keeps a slow AI job pending after the bounded automatic checks',
      () async {
        final completed = Completer<void>();
        var statusReads = 0;
        final dio = Dio(BaseOptions(baseUrl: 'https://test.drhair.local'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/api/v1/hair-tests/submit_form') {
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'data': {
                        'reference_no': 'HT-STILL-PROCESSING',
                        'ai_assessment_status': 'queued',
                      },
                    },
                  ),
                );
                return;
              }
              if (options.path.endsWith('/ai_assessment/status')) {
                statusReads++;
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'data': {'status': 'processing'},
                    },
                  ),
                );
                return;
              }
              handler.reject(DioException(requestOptions: options));
            },
          ),
        );
        final cubit = HairTestCubit(dio: dio, cache: AppLocalCache.inMemory());
        final subscription = cubit.stream.listen((state) {
          if (state.isSubmitted &&
              !state.isSubmitting &&
              state.aiAssessmentStatus == 'processing' &&
              !completed.isCompleted) {
            completed.complete();
          }
        });
        cubit
          ..selectPrimaryConcern('Reported thinning')
          ..selectDuration('Less than 6 months')
          ..selectDandruff('No noticeable flakes or itching')
          ..selectStressLevel('Low / Manageable')
          ..selectGutHealth('No')
          ..selectHairFallTrend('No, it has been gradual or stable')
          ..selectScalpSymptoms('No')
          ..setAllergyStatus('No known allergies')
          ..setCurrentMedicationsStatus('No');

        await cubit.submitTest(
          sessionToken: 'test-token',
          patientName: 'Test Patient',
        );
        await completed.future.timeout(const Duration(seconds: 10));

        expect(statusReads, 2);
        expect(cubit.state.aiAssessment, isNull);
        expect(cubit.state.aiAssessmentStatus, 'processing');
        expect(cubit.state.isSubmitting, isFalse);
        expect(cubit.state.isSubmitted, isTrue);
        await subscription.cancel();
        await cubit.close();
      },
    );

    test('restarts pending polling for the newly bound patient after account switch', () async {
      final secondPatientStatusRead = Completer<void>();
      final dio = Dio(BaseOptions(baseUrl: 'https://test.drhair.local'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/api/v1/patient/clinical-record') {
              final isSecondPatient =
                  options.headers['Authorization'] == 'Bearer token-B';
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': {
                      'assessments': [
                        {
                          'reference_no': isSecondPatient
                              ? 'HT-PATIENT-B'
                              : 'HT-PATIENT-A',
                          'status': 'submitted',
                          'full_name': isSecondPatient
                              ? 'Patient B'
                              : 'Patient A',
                          'hair_loss_stage': 'Reported thinning',
                          'ai_assessment_status': 'queued',
                        },
                      ],
                      'reports': [],
                      'care_plans': [],
                    },
                  },
                ),
              );
              return;
            }
            if (options.path ==
                '/api/v1/hair-tests/HT-PATIENT-B/ai_assessment/status') {
              if (!secondPatientStatusRead.isCompleted) {
                secondPatientStatusRead.complete();
              }
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': {
                      'status': 'ready',
                      'ai_assessment': {
                        'ai_status': 'available',
                        'scalp_health_score': 78,
                        'stage_classification': 'Reported pattern',
                        'summary': 'Patient B result.',
                      },
                    },
                  },
                ),
              );
              return;
            }
            handler.reject(DioException(requestOptions: options));
          },
        ),
      );
      final cubit = HairTestCubit(dio: dio, cache: AppLocalCache.inMemory());
      final secondPatientResult = Completer<void>();
      final subscription = cubit.stream.listen((state) {
        if (state.aiAssessment?.summary == 'Patient B result.' &&
            !secondPatientResult.isCompleted) {
          secondPatientResult.complete();
        }
      });

      await cubit.bindPatient('patient-A', sessionToken: 'token-A');
      await cubit.bindPatient('patient-B', sessionToken: 'token-B');

      await secondPatientStatusRead.future.timeout(const Duration(seconds: 5));
      await secondPatientResult.future.timeout(const Duration(seconds: 5));
      expect(cubit.state.referenceNo, 'HT-PATIENT-B');
      expect(cubit.state.aiAssessment?.summary, 'Patient B result.');
      expect(cubit.state.isSubmitting, isFalse);

      await subscription.cancel();
      await cubit.close();
    });

    test(
      'submits answers and one source image in one multipart request',
      () async {
        final temp = await Directory.systemTemp.createTemp('hair_submit_test_');
        final source = File('${temp.path}/scalp.jpg');
        final bytes = List<int>.filled(2 * 1024 * 1024, 0x7f);
        bytes.setRange(0, 4, [0xff, 0xd8, 0xff, 0xd9]);
        await source.writeAsBytes(bytes, flush: true);

        var submitRequests = 0;
        var sawUploadProgress = false;
        final cache = AppLocalCache.inMemory();
        final dio = Dio(BaseOptions(baseUrl: 'https://test.drhair.local'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              expect(options.path, '/api/v1/hair-tests/submit_form');
              submitRequests++;
              final form = options.data as FormData;
              expect(
                form.fields.any((entry) => entry.key == 'full_name'),
                isTrue,
              );
              final fileFields = form.files.map((entry) => entry.key).toSet();
              expect(fileFields, containsAll(['photo_front']));
              expect(fileFields, isNot(contains('photo_front_optimized')));
              options.onSendProgress?.call(25, 100);
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': {
                      'reference_no': 'HT-MULTIPART-001',
                      'ai_assessment_status': 'ready',
                      'ai_assessment': {
                        'ai_status': 'available',
                        'scalp_health_score': 72,
                        'stage_classification': 'Reported pattern',
                        'summary':
                            'Assessment returned with the submit response.',
                        'scalp_photo_verification': [
                          {
                            'angle': 'front',
                            'file_name':
                                'drhair/images/user-42/assessment/front.webp',
                            'status': 'hairDetected',
                            'is_hair': true,
                            'confidence': 0.92,
                            'message': 'Scalp and hair are visually present.',
                            'details': 'Visual check only.',
                          },
                        ],
                      },
                    },
                  },
                ),
              );
            },
          ),
        );
        final cubit = HairTestCubit(
          dio: dio,
          cache: cache,
          imagePicker: _FakeImagePicker(fileToReturn: XFile(source.path)),
          imageUploadService: _testImageUploadService(),
        );
        final progressSubscription = cubit.stream.listen((state) {
          if (state.uploadProgress == 0.25) sawUploadProgress = true;
        });
        cubit
          ..selectPrimaryConcern('Temple thinning')
          ..selectDuration('Less than 6 months')
          ..selectDandruff('Occasional flakes')
          ..selectStressLevel('Moderate')
          ..selectGutHealth('Normal')
          ..selectFamilyHistory('No known family history')
          ..selectHairFallTrend('No, it has been gradual or stable')
          ..selectScalpSymptoms('No')
          ..setAllergyStatus('No known allergies')
          ..setCurrentMedicationsStatus('No');

        await cubit.pickPhoto(
          label: 'Front Hairline',
          source: ImageSource.gallery,
        );
        await cubit.submitTest(
          sessionToken: 'test-session-token',
          patientName: 'Test Patient',
          patientAge: 30,
        );

        expect(submitRequests, 1);
        expect(sawUploadProgress, isTrue);
        expect(cubit.state.isSubmitted, isTrue);
        expect(cubit.state.isSubmitting, isFalse);
        expect(cubit.state.uploadProgress, isNull);
        expect(cubit.state.referenceNo, 'HT-MULTIPART-001');
        expect(cubit.state.aiAssessment?.isAvailable, isTrue);
        expect(
          cubit.state.getAnalysis('Front Hairline')?.status,
          HairDetectionStatus.hairDetected,
        );
        final cachedResult = jsonDecode(
          cache.getString('hair_test_submission_result')!,
        ) as Map<String, dynamic>;
        expect(
          (cachedResult['ai_assessment'] as Map)['scalp_photo_verification'],
          isA<List>(),
        );
        expect(
          (cachedResult['local_photo_paths'] as Map)['Front Hairline'],
          cubit.state.photos['Front Hairline'],
        );
        expect(
          (cachedResult['local_optimized_photo_paths']
              as Map)['Front Hairline'],
          cubit.state.optimizedPhotos['Front Hairline'],
        );
        await progressSubscription.cancel();
        await cubit.close();
        await temp.delete(recursive: true);
      },
    );

    test(
      'rejects an image above the upload limit without calling the API',
      () async {
        final temp = await Directory.systemTemp.createTemp(
          'hair_large_submit_test_',
        );
        final source = File('${temp.path}/large-scalp.jpg');
        final bytes = List<int>.filled(26 * 1024 * 1024, 0x7f);
        bytes.setRange(0, 4, [0xff, 0xd8, 0xff, 0xd9]);
        await source.writeAsBytes(bytes, flush: true);
        var submitRequests = 0;
        final dio = Dio(BaseOptions(baseUrl: 'https://test.drhair.local'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              submitRequests++;
              handler.reject(DioException(requestOptions: options));
            },
          ),
        );
        final cubit = HairTestCubit(
          dio: dio,
          cache: AppLocalCache.inMemory(),
          imagePicker: _FakeImagePicker(fileToReturn: XFile(source.path)),
          imageUploadService: _testImageUploadService(),
        );
        await cubit.pickPhoto(
          label: 'Front Hairline',
          source: ImageSource.gallery,
        );
        expect(cubit.state.photos['Front Hairline'], isNull);
        expect(cubit.state.errorMessage, contains('25 MiB upload limit'));
        expect(submitRequests, 0);
        await cubit.close();
        await temp.delete(recursive: true);
      },
    );

    test('initial state requires the user to provide answers', () {
      final cubit = HairTestCubit();
      expect(cubit.state.currentStep, 0);
      expect(cubit.state.totalSteps, 10);
      expect(cubit.state.primaryConcern, isNull);
      expect(cubit.state.duration, isNull);
      expect(cubit.state.stressLevel, isNull);
      expect(cubit.state.photos, isEmpty);
      expect(cubit.state.isSubmitted, false);
      cubit.close();
    });

    test(
      'restores the submitted result from the patient-scoped Hive cache',
      () async {
        final cache = AppLocalCache.inMemory({
          'hair_test_submission_result_patient-77': jsonEncode({
            'reference_no': 'HT-CACHED-0077',
            'ai_assessment_status': 'ready',
            'ai_assessment': {
              'ai_status': 'available',
              'scalp_health_score': 81,
              'stage_classification': 'Reported pattern',
              'summary': 'Cached assessment summary.',
            },
          }),
        });
        final cubit = HairTestCubit(cache: cache);

        await cubit.bindPatient('patient-77');

        expect(cubit.state.isSubmitted, isTrue);
        expect(cubit.state.referenceNo, 'HT-CACHED-0077');
        expect(cubit.state.aiAssessment?.summary, 'Cached assessment summary.');
        await cubit.close();
      },
    );

    test(
      'restores cached local result photos and deletes them on sign-out',
      () async {
        final temp = await Directory.systemTemp.createTemp(
          'hair_cached_result_photos_',
        );
        final uploads = Directory('${temp.path}/drhair_uploads')..createSync();
        final original = File('${uploads.path}/front.original.jpg')
          ..writeAsBytesSync([0xff, 0xd8, 0xff, 0xd9]);
        final optimized = File('${uploads.path}/front.upload.webp')
          ..writeAsBytesSync([0x52, 0x49, 0x46, 0x46]);
        final cache = AppLocalCache.inMemory({
          'hair_test_submission_result_patient-photos': jsonEncode({
            'reference_no': 'HT-CACHED-PHOTO-001',
            'ai_assessment_status': 'ready',
            'local_photo_paths': {'Front Hairline': original.path},
            'local_optimized_photo_paths': {'Front Hairline': optimized.path},
            'test': {'scalp_photos': []},
          }),
        });
        final cubit = HairTestCubit(
          cache: cache,
          imageUploadService: _testImageUploadService(),
        );

        await cubit.bindPatient('patient-photos');
        expect(cubit.state.photos['Front Hairline'], original.path);
        expect(cubit.state.optimizedPhotos['Front Hairline'], optimized.path);
        expect(File(original.path).existsSync(), isTrue);
        expect(File(optimized.path).existsSync(), isTrue);

        await cubit.bindPatient(null);
        expect(File(original.path).existsSync(), isFalse);
        expect(File(optimized.path).existsSync(), isFalse);
        expect(
          cache.containsKey('hair_test_submission_result_patient-photos'),
          isFalse,
        );

        await cubit.close();
        await temp.delete(recursive: true);
      },
    );

    test('restores interrupted photo checks as retryable failures', () async {
      final interrupted = HairPhotoAnalysis(
        label: 'Front Hairline',
        photoPath: '/tmp/front.jpg',
        status: HairDetectionStatus.analyzing,
        confidence: 0,
        message: 'Checking…',
        details: '',
      );
      final cache = AppLocalCache.inMemory({
        'hair_test_draft_v2': jsonEncode({
          'photos': {'Front Hairline': '/tmp/front.jpg'},
          'photoAnalysis': {'Front Hairline': interrupted.toJson()},
        }),
      });
      final cubit = HairTestCubit(cache: cache);

      await cubit.loadSavedState();

      final restored = cubit.state.getAnalysis('Front Hairline');
      expect(restored?.status, HairDetectionStatus.awaitingAssessment);
      expect(restored?.message, contains('reviewed with the assessment'));
      await cubit.close();
    });

    test(
      'clears prior patient photos and cache on account switch and sign-out',
      () async {
        final temp = await Directory.systemTemp.createTemp(
          'hair_patient_switch_',
        );
        final uploads = Directory('${temp.path}/drhair_uploads')..createSync();
        final photoA = File('${uploads.path}/patient_a.jpg')..createSync();
        final optimizedA = File('${uploads.path}/patient_a.webp')..createSync();
        final photoB = File('${uploads.path}/patient_b.jpg')..createSync();
        final optimizedB = File('${uploads.path}/patient_b.webp')..createSync();
        final cache = AppLocalCache.inMemory({
          'hair_test_draft_patient-A_v2': jsonEncode({
            'name': 'Patient A',
            'photos': {'Front Hairline': photoA.path},
            'optimizedPhotos': {'Front Hairline': optimizedA.path},
          }),
          'hair_test_ai_assessment_patient-A': '{"summary":"A result"}',
          'hair_test_name_patient-A': 'Patient A',
          'hair_test_draft_patient-B_v2': jsonEncode({
            'name': 'Patient B',
            'photos': {'Front Hairline': photoB.path},
            'optimizedPhotos': {'Front Hairline': optimizedB.path},
          }),
          'hair_test_name_patient-B': 'Patient B',
        });
        final cubit = HairTestCubit(
          cache: cache,
          imageUploadService: _testImageUploadService(),
        );

        await cubit.bindPatient('patient-A');
        expect(cubit.state.name, 'Patient A');
        expect(File(photoA.path).existsSync(), isTrue);

        await cubit.bindPatient('patient-B');
        expect(cubit.state.name, 'Patient B');
        expect(cubit.state.photos['Front Hairline'], photoB.path);
        expect(File(photoA.path).existsSync(), isFalse);
        expect(File(optimizedA.path).existsSync(), isFalse);
        expect(cache.containsKey('hair_test_draft_patient-A_v2'), isFalse);
        expect(cache.containsKey('hair_test_ai_assessment_patient-A'), isFalse);
        expect(cache.containsKey('hair_test_name_patient-A'), isFalse);
        expect(cache.containsKey('hair_test_draft_patient-B_v2'), isTrue);
        expect(File(photoB.path).existsSync(), isTrue);

        await cubit.bindPatient(null);
        expect(cubit.state.name, isEmpty);
        expect(File(photoB.path).existsSync(), isFalse);
        expect(File(optimizedB.path).existsSync(), isFalse);
        expect(cache.containsKey('hair_test_draft_patient-B_v2'), isFalse);
        expect(cache.containsKey('hair_test_name_patient-B'), isFalse);
        await cubit.close();
        await temp.delete(recursive: true);
      },
    );

    test(
      'explicit photo retry runs the verifier once and updates its verdict',
      () async {
        var attempt = 0;
        HairImageDetector.analyzerOverride = (
          path, {
          label = 'Scalp',
          referencePhotoPath,
        }) async {
          attempt++;
          return HairPhotoAnalysis(
            label: label,
            photoPath: path,
            status: HairDetectionStatus.hairDetected,
            confidence: 0.95,
            message: 'Verified.',
            details: '',
          );
        };
        addTearDown(() => HairImageDetector.analyzerOverride = null);
        final cubit = HairTestCubit(
          cache: AppLocalCache.inMemory(),
          imageUploadService: _testImageUploadService(),
        );

        await cubit.setPhoto('Front Hairline', '/tmp/front.jpg');
        expect(
          cubit.state.getAnalysis('Front Hairline')?.status,
          HairDetectionStatus.awaitingAssessment,
        );
        expect(attempt, 0);

        await cubit.retryPhotoAnalysis('Front Hairline');

        expect(attempt, 1);
        expect(
          cubit.state.getAnalysis('Front Hairline')?.status,
          HairDetectionStatus.hairDetected,
        );
        await cubit.close();
      },
    );

    test('step progression validates answers and required photos', () async {
      var returnMismatch = true;
      var referencePhotoWasCompared = false;
      HairImageDetector.analyzerOverride = (
        path, {
        label = 'Scalp',
        referencePhotoPath,
      }) async {
        if (referencePhotoPath != null) referencePhotoWasCompared = true;
        final mismatch = label == 'Crown / Top' && returnMismatch;
        return HairPhotoAnalysis(
          label: label,
          photoPath: path,
          status: mismatch
              ? HairDetectionStatus.personMismatch
              : HairDetectionStatus.hairDetected,
          confidence: 0.95,
          message: mismatch ? 'Different people.' : 'Verified.',
          details: '',
        );
      };
      addTearDown(() => HairImageDetector.analyzerOverride = null);
      final cubit = HairTestCubit(
        imagePicker: _FakeImagePicker(fileToReturn: XFile('/tmp/scalp.jpg')),
        imageUploadService: _testImageUploadService(),
      );

      cubit.nextStep();
      expect(cubit.state.currentStep, 0);
      expect(cubit.state.errorMessage, isNotNull);

      cubit.selectPrimaryConcern('Crown Thinning');
      cubit.nextStep();
      expect(cubit.state.currentStep, 1);

      cubit.prevStep();
      expect(cubit.state.currentStep, 0);

      // Does not go below 0
      cubit.prevStep();
      expect(cubit.state.currentStep, 0);

      // Each question must be answered before advancing.
      cubit.nextStep(); // advances to 1 since concern was selected
      expect(cubit.state.currentStep, 1);
      cubit.selectDuration('1 - 3 years');
      cubit.nextStep(); // 2
      cubit.selectDandruff('Occasional flakes or itching');
      cubit.nextStep(); // 3
      cubit.selectStressLevel('Moderate');
      cubit.nextStep(); // 4
      cubit.selectGutHealth('Normal');
      cubit.nextStep(); // 5
      cubit.selectFamilyHistory("Mother's side");
      await cubit.nextStep(); // 6
      cubit.selectHairFallTrend('No, it has been gradual or stable');
      await cubit.nextStep(); // 7
      cubit.selectScalpSymptoms('No');
      await cubit.nextStep(); // 8
      cubit.setAllergyStatus('No known allergies');
      cubit.setCurrentMedicationsStatus('No');
      await cubit.nextStep(); // 9
      expect(cubit.state.currentStep, 9);
      expect(cubit.state.isSubmitted, false);

      for (final label in [
        'Front Hairline',
        'Crown / Top',
        'Side Profile / Temples',
      ]) {
        await cubit.pickPhoto(label: label, source: ImageSource.gallery);
      }
      await cubit.nextStep();
      expect(cubit.state.isSubmitted, false);
      expect(cubit.state.hasPersonMismatchPhoto, true);
      expect(cubit.state.errorMessage, contains('different people'));
      expect(referencePhotoWasCompared, true);

      returnMismatch = false;
      await cubit.retryPhotoAnalysis('Crown / Top');
      await cubit.nextStep();
      expect(cubit.state.isSubmitted, true);

      cubit.close();
    });

    test('updates assessment answers', () {
      final cubit = HairTestCubit();

      cubit.selectGender('Female');
      expect(cubit.state.selectedGender, 'Female');

      cubit.selectPrimaryConcern('Receding Hairline (Temples)');
      expect(cubit.state.primaryConcern, 'Receding Hairline (Temples)');

      cubit.selectDuration('Less than 6 months');
      expect(cubit.state.duration, 'Less than 6 months');

      cubit.selectStressLevel('High Stress');
      expect(cubit.state.stressLevel, 'High Stress');

      cubit.close();
    });

    test('pickPhoto adds photo path to state for specified label', () async {
      final fakePicker = _FakeImagePicker(
        fileToReturn: XFile('/tmp/front.jpg'),
      );
      final cubit = HairTestCubit(
        imagePicker: fakePicker,
        imageUploadService: _testImageUploadService(),
      );

      await cubit.pickPhoto(
        label: 'Front Hairline',
        source: ImageSource.camera,
      );

      expect(cubit.state.hasPhoto('Front Hairline'), isTrue);
      expect(
        cubit.state.getPhoto('Front Hairline'),
        contains('/drhair_uploads/'),
      );
      expect(cubit.state.isPickingImage, false);

      cubit.removePhoto('Front Hairline');
      expect(cubit.state.hasPhoto('Front Hairline'), isFalse);
      expect(cubit.state.getAnalysis('Front Hairline'), isNull);

      cubit.close();
    });

    test(
      'pickPhoto verifies photo immediately with AI on upload screen',
      () async {
        var individualAiCalls = 0;
        HairImageDetector.analyzerOverride = (
          path, {
          label = 'Scalp',
          referencePhotoPath,
        }) async {
          individualAiCalls++;
          return HairPhotoAnalysis(
            label: label,
            photoPath: path,
            status: HairDetectionStatus.hairDetected,
            confidence: 0.95,
            message: 'Scalp photo verified.',
            details: '',
          );
        };
        addTearDown(() => HairImageDetector.analyzerOverride = null);

        final picker = _FakeImagePicker(
          fileToReturn: XFile('/tmp/scalp_crown.jpg'),
        );
        final cubit = HairTestCubit(
          imagePicker: picker,
          imageUploadService: _testImageUploadService(),
        );

        await cubit.pickPhoto(label: 'Crown / Top', source: ImageSource.camera);

        final analysis = cubit.state.getAnalysis('Crown / Top');
        expect(analysis, isNotNull);
        expect(analysis!.status, HairDetectionStatus.hairDetected);
        expect(analysis.message, contains('verified'));
        expect(individualAiCalls, 1);
        await cubit.close();
      },
    );

    test(
      'pickPhoto uses existing confirmed photo as reference and flags person mismatch',
      () async {
        String? capturedReference;
        HairImageDetector.analyzerOverride = (
          path, {
          label = 'Scalp',
          referencePhotoPath,
        }) async {
          capturedReference = referencePhotoPath;
          if (label == 'Crown / Top') {
            return HairPhotoAnalysis(
              label: label,
              photoPath: path,
              status: HairDetectionStatus.personMismatch,
              confidence: 0.96,
              message:
                  'Photos appear to be of different people. Please ensure all 3 photos are of the same person.',
              details: '',
            );
          }
          return HairPhotoAnalysis(
            label: label,
            photoPath: path,
            status: HairDetectionStatus.hairDetected,
            confidence: 0.95,
            message: 'Scalp photo verified.',
            details: '',
          );
        };
        addTearDown(() => HairImageDetector.analyzerOverride = null);

        final picker = _FakeImagePicker(
          fileToReturn: XFile('/tmp/scalp_second.jpg'),
        );
        final cubit = HairTestCubit(
          imagePicker: picker,
          imageUploadService: _testImageUploadService(),
        );

        // First set Front Hairline as confirmed
        await cubit.setPhoto(
          'Front Hairline',
          '/tmp/scalp_front.jpg',
          const HairPhotoAnalysis(
            label: 'Front Hairline',
            photoPath: '/tmp/scalp_front.jpg',
            status: HairDetectionStatus.hairDetected,
            confidence: 0.95,
            message: 'Verified',
            details: '',
          ),
        );

        // Pick second photo
        await cubit.pickPhoto(label: 'Crown / Top', source: ImageSource.gallery);

        expect(capturedReference, isNotNull);
        final analysis = cubit.state.getAnalysis('Crown / Top');
        expect(analysis?.status, HairDetectionStatus.personMismatch);
        expect(analysis?.isPersonMismatch, isTrue);
        expect(cubit.state.hasPersonMismatchPhoto, isTrue);
        await cubit.close();
      },
    );

    test(
      'markAssessmentSkipped sets cache flag and submit clears it',
      () async {
        await AppLocalCache.instance.clearAll();

        final cubit = HairTestCubit();
        await cubit.markAssessmentSkipped();
        expect(AppLocalCache.instance.getBool('has_skipped_hair_test'), isTrue);

        // Submitting assessment completes it and clears skipped flag
        cubit.selectGender('Male');
        cubit.selectPrimaryConcern('Stage 1 - Receding hairline at temples');
        await cubit.skipPhotosAndSubmit();

        expect(
          AppLocalCache.instance.getBool('has_completed_hair_test'),
          isTrue,
        );
        expect(
          AppLocalCache.instance.getBool('has_skipped_hair_test'),
          isFalse,
        );
        cubit.close();
      },
    );

    test('reset clears state to initial defaults', () {
      final cubit = HairTestCubit();
      cubit.selectGender('Female');
      cubit.nextStep();

      cubit.reset();
      expect(cubit.state.currentStep, 0);
      expect(cubit.state.selectedGender, isNull);
      expect(cubit.state.isSubmitted, false);

      cubit.close();
    });

    test('bindPatient with server assessment restores submitted state and reference number', () async {
      await AppLocalCache.instance.clearAll();

      final fakeClinical = _FakeClinicalApi({
        'care_plans': [],
        'assessments': [
          {
            'id': 105,
            'reference_no': 'HT-2026-0099',
            'status': 'submitted',
            'full_name': 'Patient Sunil',
            'age': '28',
            'hair_loss_stage': 'Stage 2 - Receding hairline',
            'dandruff': 'Mild',
          },
        ],
        'reports': [],
        'appointments': [],
      });

      final cubit = HairTestCubit(clinicalApi: fakeClinical);
      await cubit.bindPatient('patient_sunil', sessionToken: 'mock_jwt_token');

      expect(cubit.state.isCompleted, isTrue);
      expect(cubit.state.isSubmitted, isTrue);
      expect(cubit.state.referenceNo, equals('HT-2026-0099'));
      expect(cubit.state.stage, equals('Stage 2 - Receding hairline'));
      expect(cubit.state.name, equals('Patient Sunil'));

      // Sign out / unbind clears state
      await cubit.bindPatient(null);
      expect(cubit.state.isCompleted, isFalse);
      expect(cubit.state.isSubmitted, isFalse);
      expect(cubit.state.referenceNo, isNull);

      cubit.close();
    });
  });
}

class _FakeClinicalApi extends PatientClinicalApi {
  final Map<String, dynamic> record;
  _FakeClinicalApi(this.record);

  @override
  Future<Map<String, dynamic>> getClinicalRecord(String accessToken) async {
    return record;
  }
}
