class AppUrls {
  AppUrls._();

  /// STRICTLY restricted for internal doctor/admin dashboard access.
  /// NEVER share or expose this URL in patient-facing WhatsApp messages, UI widgets, or templates.
  static const String adminBaseUrl = String.fromEnvironment(
    'ADMIN_PANEL_URL',
    defaultValue: 'https://admin.drhairindia.com',
  );

  static const String websiteUrl = String.fromEnvironment(
    'WEBSITE_URL',
    defaultValue: 'https://drhairindia.com',
  );

  /// App deep linking custom scheme.
  static const String appScheme = 'drhair';

  /// Generates the custom scheme app deep-linking URL for an assessment:
  /// e.g. drhair://hair-test/assessment/:refNo
  static String assessmentAppDeepLink(String referenceNo) {
    final cleanRef = referenceNo.trim();
    if (cleanRef.isEmpty) return '$appScheme://hair-test/assessment';
    return '$appScheme://hair-test/assessment/${Uri.encodeComponent(cleanRef)}';
  }

  /// Generates the universal link URL for an assessment:
  /// e.g. https://drhairindia.com/assessment/:refNo
  static String assessmentUniversalLink(String referenceNo) {
    final cleanRef = referenceNo.trim();
    if (cleanRef.isEmpty) return '$websiteUrl/assessment';
    return '$websiteUrl/assessment/${Uri.encodeComponent(cleanRef)}';
  }

  /// Patient-facing assessment URL for WhatsApp sharing and deep linking.
  /// Always returns a patient-safe universal link that directly opens the assessment screen within the Flutter app.
  static String patientAssessmentUrl(String referenceNo) =>
      assessmentUniversalLink(referenceNo);

  /// Staff-only patient route. It is only included in a patient-initiated
  /// review request to the clinic's configured WhatsApp number; admin sign-in
  /// is still required to open the record.
  static String adminPatientDetailUrl(
    dynamic patientId, [
    String? assessmentRef,
  ]) {
    final cleanId = patientId?.toString().trim() ?? '';
    final cleanRef = assessmentRef?.trim() ?? '';
    if (cleanId.isNotEmpty &&
        cleanRef.isNotEmpty &&
        !cleanId.startsWith('HT-')) {
      return '$adminBaseUrl/patients/${Uri.encodeComponent(cleanId)}/assessments/${Uri.encodeComponent(cleanRef)}';
    }
    if (cleanId.isNotEmpty) {
      return '$adminBaseUrl/patients/${Uri.encodeComponent(cleanId)}';
    }
    return adminBaseUrl;
  }

  static const String privacyPolicy = 'https://admin.drhairindia.com/privacy';

  static const String termsOfService = 'https://admin.drhairindia.com/terms';
}
