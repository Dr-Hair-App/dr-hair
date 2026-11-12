import 'package:dr_hair/core/services/crashlytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CrashlyticsService Tests', () {
    test('initializes and handles patient lifecycle safely without errors', () async {
      await expectLater(CrashlyticsService.initialize(), completes);
      await expectLater(CrashlyticsService.setPatientIdentifier('patient_test_123'), completes);
      await expectLater(CrashlyticsService.log('Testing diagnostic breadcrumb'), completes);
      await expectLater(
        CrashlyticsService.recordNonFatal(
          Exception('Sample non-fatal error'),
          StackTrace.current,
          reason: 'Unit test verification',
        ),
        completes,
      );
      await expectLater(CrashlyticsService.clearPatientIdentifier(), completes);
    });
  });
}

