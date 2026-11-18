class AiRootCause {
  final String factor;
  final String severity;
  final String explanation;

  const AiRootCause({
    required this.factor,
    required this.severity,
    required this.explanation,
  });

  factory AiRootCause.fromJson(Map<String, dynamic> json) {
    return AiRootCause(
      factor: json['factor']?.toString() ?? 'Follicle Sensitivity',
      severity: json['severity']?.toString() ?? 'Moderate',
      explanation: json['explanation']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'factor': factor,
    'severity': severity,
    'explanation': explanation,
  };
}

class AiDietPlan {
  final String summary;
  final List<String> foodsToEat;
  final List<String> foodsToAvoid;
  final String hydrationTarget;
  final List<String> keyNutrients;

  const AiDietPlan({
    this.summary = '',
    this.foodsToEat = const [],
    this.foodsToAvoid = const [],
    this.hydrationTarget = '',
    this.keyNutrients = const [],
  });

  factory AiDietPlan.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return const [];
    }

    return AiDietPlan(
      summary: json['summary']?.toString() ?? '',
      foodsToEat: parseList(json['foods_to_eat']),
      foodsToAvoid: parseList(json['foods_to_avoid']),
      hydrationTarget: json['hydration_target']?.toString() ?? '',
      keyNutrients: parseList(json['key_nutrients']),
    );
  }

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'foods_to_eat': foodsToEat,
    'foods_to_avoid': foodsToAvoid,
    'hydration_target': hydrationTarget,
    'key_nutrients': keyNutrients,
  };
}

class AiLifestyleGuidance {
  final String summary;
  final List<String> scalpCareTips;
  final List<String> oilingRules;
  final List<String> sleepAndStress;

  const AiLifestyleGuidance({
    this.summary = '',
    this.scalpCareTips = const [],
    this.oilingRules = const [],
    this.sleepAndStress = const [],
  });

  factory AiLifestyleGuidance.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return const [];
    }

    return AiLifestyleGuidance(
      summary: json['summary']?.toString() ?? '',
      scalpCareTips: parseList(json['scalp_care_tips']),
      oilingRules: parseList(json['oiling_rules']),
      sleepAndStress: parseList(json['sleep_and_stress']),
    );
  }

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'scalp_care_tips': scalpCareTips,
    'oiling_rules': oilingRules,
    'sleep_and_stress': sleepAndStress,
  };
}

class AiRegimenStep {
  final String step;
  final String instruction;

  const AiRegimenStep({required this.step, required this.instruction});

  factory AiRegimenStep.fromJson(Map<String, dynamic> json) {
    return AiRegimenStep(
      step: json['step']?.toString() ?? 'Daily',
      instruction: json['instruction']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'step': step, 'instruction': instruction};
}

class AiTargetProduct {
  final String name;
  final String category;
  final String reason;

  const AiTargetProduct({
    required this.name,
    required this.category,
    required this.reason,
  });

  factory AiTargetProduct.fromJson(Map<String, dynamic> json) {
    return AiTargetProduct(
      name: json['name']?.toString() ?? 'Dr. Hair Product',
      category: json['category']?.toString() ?? 'Hair Care',
      reason: json['reason']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'reason': reason,
  };
}

class AiRecommendedRegimen {
  final String summary;
  final List<AiRegimenStep> dailySteps;
  final List<AiTargetProduct> targetProducts;

  const AiRecommendedRegimen({
    this.summary = '',
    this.dailySteps = const [],
    this.targetProducts = const [],
  });

  factory AiRecommendedRegimen.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['daily_steps'];
    final rawProducts = json['target_products'];

    return AiRecommendedRegimen(
      summary: json['summary']?.toString() ?? '',
      dailySteps: rawSteps is List
          ? rawSteps
                .whereType<Map>()
                .map(
                  (m) => AiRegimenStep.fromJson(Map<String, dynamic>.from(m)),
                )
                .toList()
          : const [],
      targetProducts: rawProducts is List
          ? rawProducts
                .whereType<Map>()
                .map(
                  (m) => AiTargetProduct.fromJson(Map<String, dynamic>.from(m)),
                )
                .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'daily_steps': dailySteps.map((s) => s.toJson()).toList(),
    'target_products': targetProducts.map((p) => p.toJson()).toList(),
  };
}

class AiAssessmentModel {
  final int scalpHealthScore;
  final String stageClassification;
  final String summary;
  final List<AiRootCause> rootCauses;
  final AiDietPlan dietPlan;
  final AiLifestyleGuidance lifestyleGuidance;
  final AiRecommendedRegimen recommendedRegimen;
  final String nextStepType;
  final String nextStepReason;
  final bool isAvailable;
  final String generatedBy;
  final String? generatedAt;
  final List<Map<String, dynamic>> availableProducts;
  final String productAvailabilityStatus;
  final bool shopEnabled;
  final Map<String, dynamic>? customMealPlan;
  final bool requiresClinician;
  final List<Map<String, dynamic>> scalpPhotoVerification;

  const AiAssessmentModel({
    this.scalpHealthScore = 70,
    this.stageClassification = 'Stage 2 - Early Thinning',
    this.summary = '',
    this.rootCauses = const [],
    this.dietPlan = const AiDietPlan(),
    this.lifestyleGuidance = const AiLifestyleGuidance(),
    this.recommendedRegimen = const AiRecommendedRegimen(),
    this.nextStepType = '',
    this.nextStepReason = '',
    this.isAvailable = true,
    this.generatedBy = 'Dr. Hair Assistant',
    this.generatedAt,
    this.availableProducts = const [],
    this.productAvailabilityStatus = 'checked',
    this.shopEnabled = false,
    this.customMealPlan,
    this.requiresClinician = false,
    this.scalpPhotoVerification = const [],
  });

  factory AiAssessmentModel.fromJson(Map<String, dynamic> json) {
    final rawCauses = json['root_causes'];
    final nextStep = json['next_step_recommendation'];
    final generator = json['generated_by']?.toString() ?? '';
    final statusRequiresClinician =
        json['ai_status']?.toString() == 'clinician_review_required';
    final legacyStage = json['stage_classification']?.toString() ?? '';
    final nextStepType = nextStep is Map
        ? (nextStep['type']?.toString() == 'doctor_appointment'
              ? 'doctor_appointment'
              : nextStep['type']?.toString() == 'unavailable'
              ? 'unavailable'
              : 'products')
        : RegExp(
            r'stage\s*[- ]?\s*[45]|patchy',
            caseSensitive: false,
          ).hasMatch(legacyStage)
        ? 'doctor_appointment'
        : '';
    final requiresClinician =
        statusRequiresClinician || nextStepType == 'doctor_appointment';
    final isAvailable =
        json['ai_status']?.toString() != 'unavailable' &&
        !requiresClinician &&
        generator != 'unavailable' &&
        generator != 'clinical-rules-engine';
    final regimen = json['recommended_regimen'] is Map
        ? AiRecommendedRegimen.fromJson(
            Map<String, dynamic>.from(json['recommended_regimen']),
          )
        : const AiRecommendedRegimen();
    final availability = json['product_availability'] is Map
        ? Map<String, dynamic>.from(json['product_availability'])
        : const <String, dynamic>{};

    return AiAssessmentModel(
      scalpHealthScore: isAvailable
          ? int.tryParse(json['scalp_health_score']?.toString() ?? '') ?? 70
          : 0,
      stageClassification: isAvailable
          ? json['stage_classification']?.toString() ??
                'Stage 2 - Early Thinning'
          : '',
      summary: json['summary']?.toString() ?? '',
      rootCauses: rawCauses is List
          ? rawCauses
                .whereType<Map>()
                .map((m) => AiRootCause.fromJson(Map<String, dynamic>.from(m)))
                .toList()
          : const [],
      dietPlan: json['diet_plan'] is Map
          ? AiDietPlan.fromJson(Map<String, dynamic>.from(json['diet_plan']))
          : const AiDietPlan(),
      lifestyleGuidance: json['lifestyle_guidance'] is Map
          ? AiLifestyleGuidance.fromJson(
              Map<String, dynamic>.from(json['lifestyle_guidance']),
            )
          : const AiLifestyleGuidance(),
      recommendedRegimen: nextStepType == 'doctor_appointment'
          ? AiRecommendedRegimen(
              summary: regimen.summary,
              dailySteps: regimen.dailySteps,
            )
          : regimen,
      nextStepType: nextStepType,
      nextStepReason: nextStep is Map
          ? nextStep['reason']?.toString() ?? ''
          : '',
      isAvailable: isAvailable,
      generatedBy: generator.isNotEmpty ? generator : 'Dr. Hair Assistant',
      generatedAt: json['generated_at']?.toString(),
      availableProducts: json['available_products'] is List
          ? (json['available_products'] as List)
                .whereType<Map>()
                .map((product) => Map<String, dynamic>.from(product))
                .toList()
          : const [],
      productAvailabilityStatus:
          availability['status']?.toString() ?? 'checked',
      shopEnabled: availability['shop_enabled'] == true,
      customMealPlan: json['custom_meal_plan'] is Map
          ? Map<String, dynamic>.from(json['custom_meal_plan'])
          : null,
      requiresClinician: requiresClinician,
      scalpPhotoVerification: json['scalp_photo_verification'] is List
          ? (json['scalp_photo_verification'] as List)
                .whereType<Map>()
                .map((photo) => Map<String, dynamic>.from(photo))
                .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'scalp_health_score': scalpHealthScore,
    'stage_classification': stageClassification,
    'summary': summary,
    'root_causes': rootCauses.map((c) => c.toJson()).toList(),
    'diet_plan': dietPlan.toJson(),
    'lifestyle_guidance': lifestyleGuidance.toJson(),
    'recommended_regimen': recommendedRegimen.toJson(),
    'next_step_recommendation': {
      'type': nextStepType,
      'reason': nextStepReason,
    },
    'ai_status': isAvailable ? 'available' : 'unavailable',
    'generated_by': generatedBy,
    'generated_at': generatedAt,
    'available_products': availableProducts,
    'product_availability': {
      'status': productAvailabilityStatus,
      'shop_enabled': shopEnabled,
    },
    if (customMealPlan != null) 'custom_meal_plan': customMealPlan,
    'scalp_photo_verification': scalpPhotoVerification,
    if (requiresClinician) 'ai_status': 'clinician_review_required',
  };
}
