class HomeActionCard {
  final String id;
  final String type;
  final int priority;
  final String title;
  final String body;
  final String actionLabel;
  final String? destinationRoute;
  final String? destinationType;
  final String? entityId;
  final String? whyShown;
  final List<Map<String, dynamic>> products;
  final DateTime? createdAt;

  const HomeActionCard({
    required this.id,
    required this.type,
    required this.priority,
    required this.title,
    required this.body,
    required this.actionLabel,
    this.destinationRoute,
    this.destinationType,
    this.entityId,
    this.whyShown,
    this.products = const [],
    this.createdAt,
  });

  factory HomeActionCard.fromJson(Map<String, dynamic> json) {
    final dest = json['destination'] is Map ? json['destination'] as Map : null;
    final rawProducts = json['products'];
    final productList = rawProducts is List
        ? rawProducts
              .whereType<Map>()
              .map((p) => Map<String, dynamic>.from(p))
              .toList()
        : const <Map<String, dynamic>>[];

    DateTime? parsedDate;
    final dateStr = json['created_at']?.toString();
    if (dateStr != null && dateStr.isNotEmpty) {
      parsedDate = DateTime.tryParse(dateStr);
    }

    return HomeActionCard(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      priority: int.tryParse(json['priority']?.toString() ?? '') ?? 99,
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      actionLabel: json['action_label']?.toString() ?? 'View',
      destinationRoute: dest?['route']?.toString(),
      destinationType: dest?['type']?.toString(),
      entityId: json['entity_id']?.toString() ?? dest?['entity_id']?.toString(),
      whyShown: json['why_shown']?.toString(),
      products: productList,
      createdAt: parsedDate,
    );
  }

  bool get isClinicianUrgent => type == 'clinician_urgent';
  bool get isPendingAssessment => type == 'pending_assessment';
  bool get isPendingAppointment => type == 'pending_appointment';
  bool get isSharedReport => type == 'shared_report';
  bool get isCarePlan => type == 'care_plan';
  bool get isProductSuggestions => type == 'product_suggestions';
  bool get isAppointmentSuggestion => type == 'appointment_suggestion';
  bool get isRoutineProgress => type == 'routine_progress';
}

class HomeSummaryData {
  final List<HomeActionCard> actionCards;
  final bool hasCompletedAssessment;
  final String assessmentStatus;
  final bool hasActiveCarePlan;
  final int sharedReportsCount;
  final int upcomingAppointmentsCount;
  final bool shopEnabled;
  final bool clinicAppointmentEnabled;
  final Map<String, dynamic>? latestReport;

  const HomeSummaryData({
    this.actionCards = const [],
    this.hasCompletedAssessment = false,
    this.assessmentStatus = 'none',
    this.hasActiveCarePlan = false,
    this.sharedReportsCount = 0,
    this.upcomingAppointmentsCount = 0,
    this.shopEnabled = true,
    this.clinicAppointmentEnabled = true,
    this.latestReport,
  });

  HomeSummaryData copyWith({
    List<HomeActionCard>? actionCards,
    Map<String, dynamic>? latestReport,
    bool clearLatestReport = false,
  }) => HomeSummaryData(
    actionCards: actionCards ?? this.actionCards,
    hasCompletedAssessment: hasCompletedAssessment,
    assessmentStatus: assessmentStatus,
    hasActiveCarePlan: hasActiveCarePlan,
    sharedReportsCount: sharedReportsCount,
    upcomingAppointmentsCount: upcomingAppointmentsCount,
    shopEnabled: shopEnabled,
    clinicAppointmentEnabled: clinicAppointmentEnabled,
    latestReport: clearLatestReport ? null : (latestReport ?? this.latestReport),
  );

  factory HomeSummaryData.fromJson(Map<String, dynamic> json) {
    final rawCards = json['action_cards'];
    final cards = rawCards is List
        ? rawCards
              .whereType<Map>()
              .map((c) => HomeActionCard.fromJson(Map<String, dynamic>.from(c)))
              .toList()
        : const <HomeActionCard>[];

    final rawReport = json['latest_report'];
    final report = rawReport is Map<String, dynamic>
        ? rawReport
        : rawReport is Map
            ? Map<String, dynamic>.from(rawReport)
            : null;

    final status = json['patient_status'] is Map
        ? json['patient_status'] as Map
        : null;
    final flags = json['feature_flags'] is Map
        ? json['feature_flags'] as Map
        : null;

    return HomeSummaryData(
      actionCards: cards,
      hasCompletedAssessment: status?['has_completed_assessment'] == true,
      assessmentStatus: status?['assessment_status']?.toString() ?? 'none',
      hasActiveCarePlan: status?['has_active_care_plan'] == true,
      sharedReportsCount:
          int.tryParse(status?['shared_reports_count']?.toString() ?? '') ?? 0,
      upcomingAppointmentsCount:
          int.tryParse(
            status?['upcoming_appointments_count']?.toString() ?? '',
          ) ??
          0,
      shopEnabled: flags?['shop_enabled'] != false,
      clinicAppointmentEnabled: flags?['clinic_appointment_enabled'] != false,
      latestReport: report,
    );
  }
}
