import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dr_hair/features/appointments/data/patient_appointment_api.dart';
import 'package:dr_hair/features/appointments/presentation/widgets/appointment_date_picker_bottom_sheet.dart';

class _AvailabilityApi extends PatientAppointmentApi {
  final String bookedSlot;

  _AvailabilityApi(this.bookedSlot);

  @override
  Future<Map<String, dynamic>> getAvailability({
    required DateTime from,
    required DateTime to,
  }) async => {
    'timezone': 'Asia/Kolkata',
    'is_configured': true,
    'booking_window_days': 90,
    'slot_interval_minutes': 30,
    'appointment_duration_minutes': 30,
    'appointment_services': ['Consultation'],
    'weekly_closed_weekdays': [7],
    'sessions': [
      {'label': 'Morning Session', 'opens_at': '10:00', 'closes_at': '11:00'},
    ],
    'closed_dates': [],
    'booked_slots': [bookedSlot],
  };
}

void main() {
  testWidgets(
    'appointment picker disables server-booked slots and allows open slots',
    (tester) async {
      var date = DateTime.now().add(const Duration(days: 2));
      while (date.weekday == DateTime.sunday) {
        date = date.add(const Duration(days: 1));
      }
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppointmentDatePickerBottomSheet(
              initialDate: date,
              api: _AvailabilityApi('${dateKey}T10:00'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -420));
      await tester.pumpAndSettle();
      // debugDumpApp();

      expect(find.text('10:00 AM'), findsOneWidget);
      expect(find.text('10:30 AM'), findsOneWidget);

      await tester.tap(find.text('10:00 AM'));
      await tester.pumpAndSettle();
      expect(find.text('Choose time slot'), findsOneWidget);

      await tester.tap(find.text('10:30 AM'));
      await tester.pumpAndSettle();
      final openSlotChip = find.ancestor(
        of: find.text('10:30 AM'),
        matching: find.byType(ChoiceChip),
      );
      expect(tester.widget<ChoiceChip>(openSlotChip).selected, isTrue);
    },
  );
}
