import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Centralized utility for launching Dr. Hair Clinic WhatsApp chat
/// with optional prefilled clinical or support messages.
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
}
