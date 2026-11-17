import 'package:equatable/equatable.dart';

class AppointmentBillingConfig extends Equatable {
  final bool configured;
  final bool paymentRequired;
  final int? consultationFee;
  final String currency;
  final bool firstAppointmentFree;
  final bool isFirstAppointment;
  final int? effectiveFee;
  final bool? effectivePaymentRequired;

  const AppointmentBillingConfig({
    this.configured = false,
    this.paymentRequired = false,
    this.consultationFee,
    this.currency = 'INR',
    this.firstAppointmentFree = false,
    this.isFirstAppointment = false,
    this.effectiveFee,
    this.effectivePaymentRequired,
  });

  factory AppointmentBillingConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AppointmentBillingConfig();
    return AppointmentBillingConfig(
      configured: json['configured'] == true,
      paymentRequired: json['payment_required'] == true,
      consultationFee: (json['consultation_fee'] as num?)?.toInt(),
      currency: (json['currency'] as String?) ?? 'INR',
      firstAppointmentFree: json['first_appointment_free'] == true,
      isFirstAppointment: json['is_first_appointment'] == true,
      effectiveFee: (json['effective_fee'] as num?)?.toInt(),
      effectivePaymentRequired: json['effective_payment_required'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
    'configured': configured,
    'payment_required': paymentRequired,
    'consultation_fee': consultationFee,
    'currency': currency,
    'first_appointment_free': firstAppointmentFree,
    'is_first_appointment': isFirstAppointment,
    if (effectiveFee != null) 'effective_fee': effectiveFee,
    if (effectivePaymentRequired != null)
      'effective_payment_required': effectivePaymentRequired,
  };

  @override
  List<Object?> get props => [
    configured,
    paymentRequired,
    consultationFee,
    currency,
    firstAppointmentFree,
    isFirstAppointment,
    effectiveFee,
    effectivePaymentRequired,
  ];
}

class AppVersionCheck extends Equatable {
  final bool updateRequired;
  final bool updateAvailable;
  final bool maintenanceMode;
  final String? maintenanceMessage;
  final String? latestVersion;
  final String? minVersion;
  final String? downloadUrl;
  final String? releaseNotes;
  final String? updateMessage;

  const AppVersionCheck({
    this.updateRequired = false,
    this.updateAvailable = false,
    this.maintenanceMode = false,
    this.maintenanceMessage,
    this.latestVersion,
    this.minVersion,
    this.downloadUrl,
    this.releaseNotes,
    this.updateMessage,
  });

  factory AppVersionCheck.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AppVersionCheck();
    return AppVersionCheck(
      updateRequired: json['updateRequired'] == true,
      updateAvailable: json['updateAvailable'] == true,
      maintenanceMode: json['maintenanceMode'] == true,
      maintenanceMessage: json['maintenanceMessage']?.toString(),
      latestVersion: json['latestVersion']?.toString(),
      minVersion: json['minVersion']?.toString(),
      downloadUrl: json['downloadUrl']?.toString(),
      releaseNotes: json['releaseNotes']?.toString(),
      updateMessage: json['updateMessage']?.toString(),
    );
  }

  @override
  List<Object?> get props => [updateRequired, updateAvailable, maintenanceMode, maintenanceMessage, latestVersion, minVersion, downloadUrl, releaseNotes, updateMessage];
}

/// State containing live feature flag availability for the Dr. Hair app.
class AppConfigState extends Equatable {
  final Map<String, bool> features;
  final AppointmentBillingConfig appointmentBilling;
  final AppVersionCheck versionCheck;
  final bool isLoading;
  final String? error;

  const AppConfigState({
    this.features = const <String, bool>{
      'shop': true,
      'clinic_appointment': true,
      'assessment': true,
      'videos': true,
      'reviews': true,
      'routine': true,
      'reminders': true,
      'reports': true,
    },
    this.appointmentBilling = const AppointmentBillingConfig(),
    this.versionCheck = const AppVersionCheck(),
    this.isLoading = false,
    this.error,
  });

  /// Check whether a specific feature flag is currently active.
  /// Falls back to [defaultValue] (defaults to true) if the flag is missing.
  bool isFeatureEnabled(String key, {bool defaultValue = true}) {
    return features[key] ?? defaultValue;
  }

  AppConfigState copyWith({
    Map<String, bool>? features,
    AppointmentBillingConfig? appointmentBilling,
    AppVersionCheck? versionCheck,
    bool? isLoading,
    String? error,
  }) {
    return AppConfigState(
      features: features ?? this.features,
      appointmentBilling: appointmentBilling ?? this.appointmentBilling,
      versionCheck: versionCheck ?? this.versionCheck,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [features, appointmentBilling, versionCheck, isLoading, error];
}
