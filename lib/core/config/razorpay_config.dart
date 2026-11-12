import 'package:flutter_dotenv/flutter_dotenv.dart';

class RazorpayConfig {
  RazorpayConfig._();

  static const String _buildKeyId = String.fromEnvironment('RAZORPAY_KEY_ID');

  static String get keyId {
    if (_buildKeyId.trim().isNotEmpty) return _buildKeyId.trim();
    if (!dotenv.isInitialized) return '';
    return (dotenv.env['RAZORPAY_KEY_ID'] ?? '').trim();
  }
}
