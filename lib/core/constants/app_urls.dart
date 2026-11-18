class AppUrls {
  AppUrls._();

  static const String adminBaseUrl = String.fromEnvironment(
    'ADMIN_PANEL_URL',
    defaultValue: 'https://admin.drhairindia.com',
  );

  static const String websiteUrl = String.fromEnvironment(
    'WEBSITE_URL',
    defaultValue: 'https://drhairindia.com',
  );

  static String adminPatientDetailUrl(dynamic patientId, [String? assessmentRef]) {
    final cleanId = patientId?.toString().trim() ?? '';
    final cleanRef = assessmentRef?.trim() ?? '';
    if (cleanId.isNotEmpty && cleanRef.isNotEmpty && !cleanId.startsWith('HT-')) {
      return '$adminBaseUrl/patients/$cleanId/assessments/$cleanRef';
    }
    if (cleanId.isNotEmpty) {
      return '$adminBaseUrl/patients/$cleanId';
    }
    return adminBaseUrl;
  }

  static const String privacyPolicy =
      'https://admin.drhairindia.com/privacy';

  static const String termsOfService =
      'https://admin.drhairindia.com/terms';
}
