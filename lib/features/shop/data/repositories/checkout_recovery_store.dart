import 'dart:convert';

import '../../../../core/storage/secure_session_store.dart';

/// Secure, account-scoped recovery for an order whose Razorpay result has not
/// yet been confirmed by the backend.
class CheckoutRecoveryStore {
  static const String storageKey = 'dr_hair_pending_checkout_v1';

  final SecureSessionStore _sessionStore;

  CheckoutRecoveryStore({SecureSessionStore? sessionStore})
    : _sessionStore = sessionStore ?? SecureSessionStore();

  Future<void> save({
    required String ownerLogin,
    String? idempotencyKey,
    String? fingerprint,
    Map<String, dynamic>? checkout,
    String? paymentId,
    String? paymentSignature,
  }) async {
    final login = ownerLogin.trim().toLowerCase();
    if (login.isEmpty) return;
    await _sessionStore.writeSecret(
      key: storageKey,
      value: jsonEncode({
        'owner_login': login,
        'idempotency_key': idempotencyKey,
        'fingerprint': fingerprint,
        'checkout': checkout,
        'payment_id': paymentId,
        'payment_signature': paymentSignature,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  Future<Map<String, dynamic>?> loadForLogin(String login) async {
    final cleanLogin = login.trim().toLowerCase();
    if (cleanLogin.isEmpty) return null;
    final raw = await _sessionStore.readSecret(key: storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['owner_login']?.toString().trim().toLowerCase() !=
              cleanLogin) {
        return null;
      }
      return decoded;
    } on FormatException {
      return null;
    }
  }

  Future<void> clear() => _sessionStore.deleteSecret(key: storageKey);
}
