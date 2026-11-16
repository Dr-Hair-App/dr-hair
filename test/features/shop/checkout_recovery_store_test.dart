import 'package:dr_hair/core/storage/app_local_cache.dart';
import 'package:dr_hair/core/storage/secure_session_store.dart';
import 'package:dr_hair/features/shop/data/repositories/checkout_recovery_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySecretStorage implements SessionSecretStorage {
  final values = <String, String>{};

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}

void main() {
  test('pending checkout and payment verification data round trip under its account', () async {
    final storage = _MemorySecretStorage();
    final sessionStore = SecureSessionStore(
      storage: storage,
      cache: AppLocalCache.inMemory(),
    );
    final recovery = CheckoutRecoveryStore(sessionStore: sessionStore);
    await recovery.save(
      ownerLogin: ' Patient@Example.test ',
      idempotencyKey: 'checkout-1',
      fingerprint: 'address|product|razorpay',
      checkout: {
        'order': {'order_id': 'ORD-1'},
        'paymentIntent': {'intentId': 'order_1', 'amount': 50000},
      },
      paymentId: 'pay_1',
      paymentSignature: 'signature_1',
    );

    final restored = await recovery.loadForLogin('patient@example.test');
    expect(restored?['idempotency_key'], 'checkout-1');
    expect(restored?['payment_id'], 'pay_1');
    expect(restored?['payment_signature'], 'signature_1');
    expect((restored?['checkout'] as Map)['order']['order_id'], 'ORD-1');
  });

  test('checkout recovery is hidden from other accounts and can be cleared after confirmation', () async {
    final storage = _MemorySecretStorage();
    final recovery = CheckoutRecoveryStore(
      sessionStore: SecureSessionStore(
        storage: storage,
        cache: AppLocalCache.inMemory(),
      ),
    );
    await recovery.save(ownerLogin: 'patient-1', idempotencyKey: 'checkout-1');

    expect(await recovery.loadForLogin('patient-2'), isNull);
    expect(await recovery.loadForLogin('patient-1'), isNotNull);
    await recovery.clear();
    expect(await recovery.loadForLogin('patient-1'), isNull);
  });
}
