import 'package:flutter_test/flutter_test.dart';
import 'package:dr_hair/core/storage/app_local_cache.dart';
import 'package:dr_hair/features/care/presentation/viewmodels/care_cubit.dart';

void main() {
  setUp(() async {
    await AppLocalCache.instance.clearAll();
  });

  tearDown(() async {
    await AppLocalCache.instance.clearAll();
  });

  group('Scalp Hydration & 1-Tap Notification Tests', () {
    test('CareCubit sets, increments, and decrements water count accurately', () async {
      final cubit = CareCubit();

      expect(cubit.state.waterCups, equals(0));

      await cubit.setWater(5);
      expect(cubit.state.waterCups, equals(5));

      await cubit.incrementWater();
      expect(cubit.state.waterCups, equals(6));

      await cubit.decrementWater();
      expect(cubit.state.waterCups, equals(5));

      // Clamps to max 12
      await cubit.setWater(15);
      expect(cubit.state.waterCups, equals(12));

      // Clamps to min 0
      await cubit.setWater(-3);
      expect(cubit.state.waterCups, equals(0));
    });

    test('onNotificationActionTaken marks routine tasks as completed', () async {
      final cubit = CareCubit();

      await cubit.addCustomRoutineTask(
        title: 'Morning Scalp Serum',
        subtitle: 'Apply 1ml to dry scalp',
        category: 'serum',
        timeOfDay: 'Morning',
      );

      await cubit.onNotificationActionTaken();

      for (final task in cubit.state.routineTasks) {
        expect(task.isCompleted, isTrue);
      }
    });

    test('onNotificationActionSnooze logs snooze care event without failing', () async {
      final cubit = CareCubit();
      await cubit.onNotificationActionSnooze();
      expect(cubit.state, isNotNull);
    });
  });
}
