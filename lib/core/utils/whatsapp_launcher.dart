import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_urls.dart';

/// Centralized utility for launching Dr. Hair Clinic WhatsApp chat
/// with structured, well-formatted clinical or support messages and custom domain URLs.
class WhatsAppLauncher {
  static const String defaultPhoneNumber = '918058056789';

  /// Launches the clinic's official WhatsApp with an optional prefilled message.
  static Future<bool> launch({
    String? phoneNumber,
    String? message,
  }) async {
    HapticFeedback.lightImpact();
    final phone = phoneNumber ?? defaultPhoneNumber;
    final encodedMessage = message != null && message.trim().isNotEmpty
        ? '?text=${Uri.encodeComponent(message.trim())}'
        : '';
    final uri = Uri.parse('https://wa.me/$phone$encodedMessage');

    try {
      final success = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!success) {
        debugPrint(
          '[WhatsAppLauncher] Could not launch via externalApplication. Trying platformDefault...',
        );
        return await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      return true;
    } catch (e) {
      debugPrint('[WhatsAppLauncher] Error launching WhatsApp: $e');
      return false;
    }
  }

  /// Opens WhatsApp for AI assessment review with structured patient details & direct admin record link.
  static Future<bool> launchAssessmentGuidance({
    required String patientName,
    required String patientId,
    required String referenceNo,
    String? stage,
    int? scalpScore,
    String? concern,
    String? phoneNumber,
  }) {
    final adminLink = AppUrls.adminPatientDetailUrl(patientId, referenceNo);
    final message = '''Hello Dr. Hair Clinical Team,

I completed my AI Hair Assessment and would like senior doctor guidance on my diagnosis and care plan.

📋 Patient Details:
• Name: $patientName
• Patient ID: $patientId
• Assessment Ref: $referenceNo

🔬 Clinical Summary:
• Stage: ${stage ?? 'Initial'}
• Scalp Health Score: ${scalpScore ?? 70}/100
• Primary Concern: ${concern ?? 'Hair loss & scalp health'}

🔗 Direct Clinical Record:
$adminLink

Please review my record and advise on the next steps.''';

    return launch(
      phoneNumber: phoneNumber ?? defaultPhoneNumber,
      message: message,
    );
  }

  /// Opens WhatsApp for order delivery and shipment inquiries.
  static Future<bool> launchOrderInquiry({
    required String orderId,
    String? status,
    String? trackingNumber,
  }) {
    final message = '''Hello Dr. Hair Support Team,

I have an inquiry regarding my order:
• Order ID: #$orderId
• Status: ${status ?? 'In Transit'}${trackingNumber != null && trackingNumber.isNotEmpty ? '\n• Tracking Ref: $trackingNumber' : ''}
• Store Portal: ${AppUrls.websiteUrl}

Please provide an update on my shipment. Thank you!''';

    return launch(message: message);
  }

  /// Opens WhatsApp for care plan and treatment consultations.
  static Future<bool> launchCarePlanInquiry({
    required String treatmentName,
    String? referenceNo,
  }) {
    final message = '''Hello Dr. Hair Clinic,

I have a question regarding my clinical care plan:
• Plan: $treatmentName${referenceNo != null && referenceNo.isNotEmpty ? '\n• Reference No: $referenceNo' : ''}
• Clinic Portal: ${AppUrls.websiteUrl}

Please guide me on my care steps. Thank you!''';

    return launch(message: message);
  }

  /// Opens WhatsApp for general consultation inquiries.
  static Future<bool> launchGeneralConsultation() {
    final message = '''Hello Dr. Hair Clinic,

I am seeking a professional consultation for my hair & scalp health.
• Clinic Website: ${AppUrls.websiteUrl}

Could you please share details on available consultation slots?''';

    return launch(message: message);
  }
}
