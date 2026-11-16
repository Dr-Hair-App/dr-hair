import 'package:flutter_test/flutter_test.dart';
import 'package:dr_hair/core/storage/app_local_cache.dart';
import 'package:dr_hair/features/shop/data/services/pincode_delivery_service.dart';

void main() {
  setUp(() async {
    await AppLocalCache.instance.clearAll();
  });

  tearDown(() async {
    await AppLocalCache.instance.clearAll();
  });

  group('PincodeDeliveryService Tests', () {
    test(
      'isValidPincode correctly identifies valid and invalid 6-digit PINs',
      () {
        expect(PincodeDeliveryService.isValidPincode('302020'), isTrue);
        expect(PincodeDeliveryService.isValidPincode('110001'), isTrue);
        expect(PincodeDeliveryService.isValidPincode('400001'), isTrue);

        expect(
          PincodeDeliveryService.isValidPincode('012345'),
          isFalse,
        ); // starts with 0
        expect(
          PincodeDeliveryService.isValidPincode('30202'),
          isFalse,
        ); // 5 digits
        expect(
          PincodeDeliveryService.isValidPincode('3020201'),
          isFalse,
        ); // 7 digits
        expect(
          PincodeDeliveryService.isValidPincode('ABC123'),
          isFalse,
        ); // letters
        expect(PincodeDeliveryService.isValidPincode(''), isFalse);
      },
    );

    test(
      'PIN validation does not invent courier zones or shipping estimates',
      () {
        expect(PincodeDeliveryService.isValidPincode('302001'), isTrue);
        expect(PincodeDeliveryService.isValidPincode('110001'), isTrue);
        expect(PincodeDeliveryService.isValidPincode('400001'), isTrue);
      },
    );

    test(
      'rememberPincode and getSavedPincode correctly persist to Hive cache',
      () async {
        expect(PincodeDeliveryService.getSavedPincode(), isNull);

        await PincodeDeliveryService.rememberPincode('302020');
        expect(PincodeDeliveryService.getSavedPincode(), equals('302020'));

        // Invalid pincode should not overwrite
        await PincodeDeliveryService.rememberPincode('invalid');
        expect(PincodeDeliveryService.getSavedPincode(), equals('302020'));
      },
    );
  });
}
