import 'package:equatable/equatable.dart';

class AppointmentBillingConfig extends Equatable {
  final bool paymentRequired;
  final int consultationFee;
  final String currency;

  const AppointmentBillingConfig({
    this.paymentRequired = true,
    this.consultationFee = 500,
    this.currency = 'INR',
  });

  factory AppointmentBillingConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AppointmentBillingConfig();
    return AppointmentBillingConfig(
      paymentRequired: json['payment_required'] != false,
      consultationFee: (json['consultation_fee'] as num?)?.toInt() ?? 500,
      currency: (json['currency'] as String?) ?? 'INR',
    );
  }

  Map<String, dynamic> toJson() => {
    'payment_required': paymentRequired,
    'consultation_fee': consultationFee,
    'currency': currency,
  };

  @override
  List<Object?> get props => [paymentRequired, consultationFee, currency];
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

