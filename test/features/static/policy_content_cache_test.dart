import 'package:dr_hair/features/static/data/policy_content.dart';
import 'package:dr_hair/features/static/domain/policy_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    PolicyRepository.clearCache();
  });

  tearDown(() {
    PolicyRepository.clearCache();
  });

  group('PolicyRepository Memory Cache', () {
    test('returns cached policy immediately without network call when cache populated', () async {
      // First fetch warms memory cache
      final doc1 = await PolicyRepository.fetchPolicy(PolicyType.privacyPolicy);
      expect(doc1.title, isNotEmpty);

      // Second fetch must return cached instance immediately
      final doc2 = await PolicyRepository.fetchPolicy(PolicyType.privacyPolicy);
      expect(identical(doc1, doc2), isTrue);
    });

    test('getPolicy and fetchPolicy share memory cache', () async {
      final doc = await PolicyRepository.fetchPolicy(PolicyType.termsAndConditions);
      final fromGet = PolicyRepository.getPolicy(PolicyType.termsAndConditions);
      expect(identical(doc, fromGet), isTrue);
    });
  });
}
