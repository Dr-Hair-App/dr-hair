import '../../domain/models/hair_photo_analysis.dart';
import '../../domain/models/ai_assessment_model.dart';

/// Holds the user's assessment answers and completion status.
class HairTestState {
  final int currentStep;
  final int totalSteps;
  final String name;
  final String age;
  final String? selectedGender;
  final String? stage;
  final String? primaryConcern;
  final String? duration;
  final String? dandruff;
  final String? gutHealth;
  final String? stressLevel;
  final String? familyHistory;
  final String? hairFallTrend;
  final String? scalpSymptoms;
  final String? allergyStatus;
  final String allergyDetails;
  final String? currentMedicationsStatus;
  final String currentMedications;
  final String medicalConditions;
  final Map<String, String> photos;
  final Map<String, String> optimizedPhotos;
  final Map<String, HairPhotoAnalysis> photoAnalysis;
  final bool isSubmitted;
  final bool isCompleted;
  final bool isSubmitting;
  final double? uploadProgress;
  final String? referenceNo;
  final bool isRetesting;
  final bool isPickingImage;
  final String? errorMessage;
  final List<Map<String, dynamic>> clinicalReports;
  final String assessmentStatus;
  final String aiAssessmentStatus;
  final Map<String, dynamic>? doctorCarePlan;
  final String? doctorReviewNote;
  final AiAssessmentModel? aiAssessment;
  final bool isGeneratingDietPlan;
  final String? dietPlanError;
  final bool isGeneratingRoutine;
  final String? routineError;
  final String? patientId;

  const HairTestState({
    this.currentStep = 0,
    this.totalSteps = 10,
    this.name = '',
    this.age = '',
    this.selectedGender,
    this.stage,
    this.primaryConcern,
    this.duration,
    this.dandruff,
    this.gutHealth,
    this.stressLevel,
    this.familyHistory,
    this.hairFallTrend,
    this.scalpSymptoms,
    this.allergyStatus,
    this.allergyDetails = '',
    this.currentMedicationsStatus,
    this.currentMedications = '',
    this.medicalConditions = '',
    this.photos = const {},
    this.optimizedPhotos = const {},
    this.photoAnalysis = const {},
    this.isSubmitted = false,
    this.isCompleted = false,
    this.isSubmitting = false,
    this.uploadProgress,
    this.referenceNo,
    this.isRetesting = false,
    this.isPickingImage = false,
    this.errorMessage,
    this.clinicalReports = const [],
    this.assessmentStatus = 'submitted',
    this.aiAssessmentStatus = 'idle',
    this.doctorCarePlan,
    this.doctorReviewNote,
    this.aiAssessment,
    this.isGeneratingDietPlan = false,
    this.dietPlanError,
    this.isGeneratingRoutine = false,
    this.routineError,
    this.patientId,
  });

  HairTestState copyWith({
    int? currentStep,
    int? totalSteps,
    String? name,
    String? age,
    String? selectedGender,
    String? stage,
    bool clearStage = false,
    String? primaryConcern,
    String? duration,
    String? dandruff,
    String? gutHealth,
    String? stressLevel,
    String? familyHistory,
    String? hairFallTrend,
    String? scalpSymptoms,
    String? allergyStatus,
    String? allergyDetails,
    String? currentMedicationsStatus,
    String? currentMedications,
    String? medicalConditions,
    Map<String, String>? photos,
    Map<String, String>? optimizedPhotos,
    Map<String, HairPhotoAnalysis>? photoAnalysis,
    bool? isSubmitted,
    bool? isCompleted,
    bool? isSubmitting,
    double? uploadProgress,
    bool clearUploadProgress = false,
    String? referenceNo,
    bool clearReferenceNo = false,
    bool? isRetesting,
    bool? isPickingImage,
    String? errorMessage,
    bool clearErrorMessage = false,
    List<Map<String, dynamic>>? clinicalReports,
    String? assessmentStatus,
    String? aiAssessmentStatus,
    Map<String, dynamic>? doctorCarePlan,
    bool clearDoctorCarePlan = false,
    String? doctorReviewNote,
    bool clearDoctorReviewNote = false,
    AiAssessmentModel? aiAssessment,
    bool clearAiAssessment = false,
    bool? isGeneratingDietPlan,
    String? dietPlanError,
    bool clearDietPlanError = false,
    bool? isGeneratingRoutine,
    String? routineError,
    bool clearRoutineError = false,
    String? patientId,
    bool clearPatientId = false,
  }) {
    return HairTestState(
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      name: name ?? this.name,
      age: age ?? this.age,
      selectedGender: selectedGender ?? this.selectedGender,
      stage: clearStage ? null : stage ?? this.stage,
      primaryConcern: primaryConcern ?? this.primaryConcern,
      duration: duration ?? this.duration,
      dandruff: dandruff ?? this.dandruff,
      gutHealth: gutHealth ?? this.gutHealth,
      stressLevel: stressLevel ?? this.stressLevel,
      familyHistory: familyHistory ?? this.familyHistory,
      hairFallTrend: hairFallTrend ?? this.hairFallTrend,
      scalpSymptoms: scalpSymptoms ?? this.scalpSymptoms,
      allergyStatus: allergyStatus ?? this.allergyStatus,
      allergyDetails: allergyDetails ?? this.allergyDetails,
      currentMedicationsStatus:
          currentMedicationsStatus ?? this.currentMedicationsStatus,
      currentMedications: currentMedications ?? this.currentMedications,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      photos: photos ?? this.photos,
      optimizedPhotos: optimizedPhotos ?? this.optimizedPhotos,
      photoAnalysis: photoAnalysis ?? this.photoAnalysis,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      isCompleted: isCompleted ?? this.isCompleted,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      uploadProgress: clearUploadProgress
          ? null
          : uploadProgress ?? this.uploadProgress,
      referenceNo: clearReferenceNo ? null : referenceNo ?? this.referenceNo,
      isRetesting: isRetesting ?? this.isRetesting,
      isPickingImage: isPickingImage ?? this.isPickingImage,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      clinicalReports: clinicalReports ?? this.clinicalReports,
      assessmentStatus: assessmentStatus ?? this.assessmentStatus,
      aiAssessmentStatus: aiAssessmentStatus ?? this.aiAssessmentStatus,
      doctorCarePlan: clearDoctorCarePlan
          ? null
          : doctorCarePlan ?? this.doctorCarePlan,
      doctorReviewNote: clearDoctorReviewNote
          ? null
          : doctorReviewNote ?? this.doctorReviewNote,
      aiAssessment: clearAiAssessment
          ? null
          : aiAssessment ?? this.aiAssessment,
      isGeneratingDietPlan: isGeneratingDietPlan ?? this.isGeneratingDietPlan,
      dietPlanError: clearDietPlanError
          ? null
          : dietPlanError ?? this.dietPlanError,
      isGeneratingRoutine: isGeneratingRoutine ?? this.isGeneratingRoutine,
      routineError: clearRoutineError
          ? null
          : routineError ?? this.routineError,
      patientId: clearPatientId ? null : patientId ?? this.patientId,
    );
  }

  String? getPhoto(String label) => photos[label];
  bool hasPhoto(String label) =>
      photos.containsKey(label) &&
      photos[label] != null &&
      photos[label]!.isNotEmpty;

  HairPhotoAnalysis? getAnalysis(String label) => photoAnalysis[label];
  bool get hasNonHairPhoto =>
      photoAnalysis.values.any((a) => a.status == HairDetectionStatus.notHair);
  bool get hasPhotoNeedingReview => photoAnalysis.values.any(
    (a) =>
        a.status == HairDetectionStatus.notHair ||
        a.status == HairDetectionStatus.lowClarity,
  );
  bool get hasUnverifiedPhoto => photoAnalysis.values.any(
    (a) => a.status == HairDetectionStatus.verificationUnavailable,
  );

  /// Plain-language summary based on the answers selected by the user.
  String get assessmentSummary {
    final concern = primaryConcern?.trim();
    return stage ??
        (concern == null || concern.isEmpty ? 'Hair concern summary' : concern);
  }

  /// Title of the stage/concern for reports and summaries.
  String get stageTitle => assessmentSummary;

  /// Labels the patient's own selection without interpreting it as a diagnosis.
  String get stageDescription {
    return 'This is the concern you selected in your assessment. It has not been confirmed as a diagnosis.';
  }
}
