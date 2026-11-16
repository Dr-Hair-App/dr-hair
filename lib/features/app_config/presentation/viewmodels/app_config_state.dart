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

/// State containing live feature flag availability for the Dr. Hair app.
class AppConfigState extends Equatable {
  final Map<String, bool> features;
  final AppointmentBillingConfig appointmentBilling;
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
    bool? isLoading,
    String? error,
  }) {
    return AppConfigState(
      features: features ?? this.features,
      appointmentBilling: appointmentBilling ?? this.appointmentBilling,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [features, appointmentBilling, isLoading, error];
}
