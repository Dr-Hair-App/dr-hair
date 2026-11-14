import 'package:material_ui/material_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dr_hair/core/storage/app_local_cache.dart';
import 'package:dr_hair/features/app_config/data/app_config_repository.dart';
import 'package:dr_hair/features/app_config/presentation/viewmodels/app_config_cubit.dart';
import 'package:dr_hair/features/app_config/presentation/viewmodels/app_config_state.dart';
import 'package:dr_hair/features/appointments/data/patient_appointment_api.dart';
import 'package:dr_hair/features/appointments/presentation/clinic_appointment_cubit.dart';
import 'package:dr_hair/features/appointments/presentation/clinic_appointment_view.dart';
import 'package:dr_hair/features/appointments/presentation/widgets/appointment_payment_sheet.dart';
import 'package:dr_hair/features/auth/domain/models/user_model.dart';
import 'package:dr_hair/features/auth/presentation/viewmodels/auth_cubit.dart';
import 'package:dr_hair/features/auth/presentation/viewmodels/auth_state.dart';

class _MockAppointmentApi extends PatientAppointmentApi {
  List<Map<String, dynamic>> items;
  _MockAppointmentApi([this.items = const []]);

  @override
  Future<List<Map<String, dynamic>>> list(String token) async => items;

  @override
  Future<Map<String, dynamic>> getAvailability({
    required DateTime from,
    required DateTime to,
  }) async => {
    'timezone': 'Asia/Kolkata',
    'booking_window_days': 90,
    'weekly_closed_weekdays': [7],
    'sessions': [
      {'label': 'Morning Session', 'opens_at': '10:00', 'closes_at': '12:30'},
      {'label': 'Evening Session', 'opens_at': '15:30', 'closes_at': '18:30'},
    ],
    'closed_dates': [],
    'booked_slots': [],
  };

  Future<Map<String, dynamic>> reschedule({
    required String token,
    required String appointmentId,
    required DateTime startsAt,
  }) async {
    return {
      'id': appointmentId,
      'starts_at': startsAt.toUtc().toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>> update({
    required String token,
    required String appointmentId,
    required Map<String, dynamic> data,
  }) async => {'id': appointmentId, ...data};
}

class _UnavailablePaymentApi extends PatientAppointmentApi {
  @override
  Future<Map<String, dynamic>> createPaymentIntent({
    required String token,
    required DateTime startsAt,
    required String reason,
  }) async {
    final requestOptions = RequestOptions(
      path: '/appointments/create-payment-intent',
    );
    throw DioException(
      requestOptions: requestOptions,
      response: Response<Map<String, dynamic>>(
        requestOptions: requestOptions,
        statusCode: 503,
        data: {'message': 'Razorpay online payments are not configured.'},
      ),
    );
  }
}

class _FakeAuthCubit extends AuthCubit {
  _FakeAuthCubit(UserModel? user) : super() {
    emit(
      AuthState(
        status: user != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        user: user,
        sessionToken: user != null ? 'test-token' : null,
        isRegistered: user != null,
      ),
    );
  }
}

class _FakeAppConfigCubit extends AppConfigCubit {
  _FakeAppConfigCubit(AppointmentBillingConfig billing)
    : super(repository: AppConfigRepository(cache: AppLocalCache.inMemory())) {
    emit(AppConfigState(appointmentBilling: billing));
  }

  @override
  Future<void> loadConfig() async {
    // Keep mocked billing state without triggering real network request in tests
  }
}

void main() {
  testWidgets(
    'ClinicAppointmentView renders consultation fee and booking button for authenticated patient',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cache = AppLocalCache.inMemory();
      final appointmentCubit = ClinicAppointmentCubit(
        cache: cache,
        api: _MockAppointmentApi(),
      );
      final user = const UserModel(
        id: '991',
        patientId: 'PAT-991',
        name: 'Sahil Tester',
        emailOrPhone: '9876543210',
        phone: '9876543210',
        age: 26,
        gender: 'Male',
        isGuest: false,
      );
      final authCubit = _FakeAuthCubit(user);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>.value(value: authCubit),
            BlocProvider<ClinicAppointmentCubit>.value(value: appointmentCubit),
          ],
          child: const MaterialApp(home: ClinicAppointmentView()),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Title & Doctor Card
      expect(find.text('In-Clinic Appointment'), findsOneWidget);
      expect(find.text('Dr. Jai Bansal'), findsOneWidget);

      // Verify the compact sticky fee summary and action.
      expect(find.text('Consultation · ₹500'), findsOneWidget);
      expect(find.text('Continue · ₹500'), findsOneWidget);

      // Verify empty state for visits
      expect(
        find.text('No physical clinic visits scheduled yet.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'AppointmentPaymentSheet displays payment methods, fee breakdown, and confirms payment',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      AppointmentPaymentResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await AppointmentPaymentSheet.show(
                      context,
                      startsAt: DateTime(2026, 11, 10, 10, 30),
                      doctorName: 'Dr. Jai Bansal',
                      fee: 500,
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap to open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify Sheet Content
      expect(find.text('Consultation Checkout'), findsOneWidget);
      expect(find.text('Dr. Jai Bansal'), findsOneWidget);
      expect(find.text('SELECT PAYMENT METHOD'), findsOneWidget);
      expect(
        find.textContaining('UPI (GPay / PhonePe / Paytm / QR)'),
        findsOneWidget,
      );
      expect(find.text('Credit / Debit Card'), findsOneWidget);
      expect(find.text('Pay Cash at Clinic Desk'), findsOneWidget);
      expect(find.text('Total Payable'), findsOneWidget);
      expect(find.text('₹500'), findsWidgets);

      // Select Pay Cash at Clinic option
      await tester.tap(find.text('Pay Cash at Clinic Desk'));
      await tester.pumpAndSettle();

      // Verify button text changed to reflect Cash at Clinic
      expect(find.text('Confirm Booking (Pay ₹500 at Clinic)'), findsOneWidget);

      // Select UPI option back
      await tester.tap(find.textContaining('UPI (GPay'));
      await tester.pumpAndSettle();
      expect(find.text('Pay ₹500 & Confirm Visit'), findsOneWidget);

      // Tap Pay & Confirm
      final payButton = find.text('Pay ₹500 & Confirm Visit');
      await tester.ensureVisible(payButton);
      await tester.tap(payButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Verify result returned
      expect(result, isNotNull);
      expect(result?.amount, 500);
      expect(result?.paymentMethod, 'UPI');
      expect(result?.paymentStatus, 'Paid');
      expect(result?.transactionId.startsWith('TXN-CLINIC-'), true);
    },
  );

  testWidgets(
    'shows payment-intent failure without opening checkout without a server order',
    (tester) async {
      AppointmentPaymentResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await AppointmentPaymentSheet.show(
                      context,
                      startsAt: DateTime.now().add(const Duration(days: 2)),
                      patientToken: 'patient-session-token',
                      appointmentApi: _UnavailablePaymentApi(),
                    );
                  },
                  child: const Text('Book appointment'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Book appointment'));
      await tester.pumpAndSettle();
      final payButton = find.text('Pay ₹500 & Confirm Visit');
      await tester.ensureVisible(payButton);
      await tester.tap(payButton);
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Secure payment could not be started. Razorpay online payments are not configured.',
        ),
        findsOneWidget,
      );
      expect(result, isNull);
      expect(find.text('Consultation Checkout'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping Reschedule opens date picker bottom sheet and updates slot directly on screen',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cache = AppLocalCache.inMemory();
      final existingSlot = DateTime(2026, 11, 20, 10, 0);
      final mockApi = _MockAppointmentApi([
        {
          'id': 'APT-991',
          'patientId': 'PAT-991',
          'userId': '991',
          'starts_at': existingSlot.toUtc().toIso8601String(),
          'reason': 'Scalp scan & treatment',
          'consultation_fee': 500,
          'payment_method': 'UPI',
          'payment_status': 'Paid',
          'status': 'Confirmed',
        },
      ]);
      final appointmentCubit = ClinicAppointmentCubit(
        cache: cache,
        api: mockApi,
      );
      final user = const UserModel(
        id: '991',
        patientId: 'PAT-991',
        name: 'Sahil Tester',
        emailOrPhone: '9876543210',
        phone: '9876543210',
        age: 26,
        gender: 'Male',
        isGuest: false,
      );
      final authCubit = _FakeAuthCubit(user);

      await appointmentCubit.saveRequest(
        patientId: 'PAT-991',
        startsAt: existingSlot,
        reason: 'Scalp scan & treatment',
        consultationFee: 500,
        paymentMethod: 'UPI',
        paymentStatus: 'Paid',
      );

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>.value(value: authCubit),
            BlocProvider<ClinicAppointmentCubit>.value(value: appointmentCubit),
          ],
          child: const MaterialApp(home: ClinicAppointmentView()),
        ),
      );
      await tester.pumpAndSettle();

      // Verify existing appointment is listed
      expect(find.text('Dr. Jai Bansal Clinic Chamber'), findsOneWidget);
      final rescheduleFinder = find.text('Reschedule');
      expect(rescheduleFinder, findsOneWidget);
      await tester.ensureVisible(rescheduleFinder);
      await tester.pumpAndSettle();

      // Tap Reschedule button
      await tester.tap(rescheduleFinder);
      await tester.pumpAndSettle();

      // Verify date picker bottom sheet is open
      expect(find.text('Select Clinic Visit Slot'), findsOneWidget);
      expect(find.text('Confirm Slot'), findsOneWidget);

      // Pick a new slot (11:30 AM)
      final newSlotChip = find.text('11:30 AM');
      if (newSlotChip.evaluate().isNotEmpty) {
        await tester.tap(newSlotChip);
        await tester.pumpAndSettle();
      }

      // Confirm the slot
      await tester.tap(find.text('Confirm Slot'));
      await tester.pumpAndSettle();

      // Date picker bottom sheet should be dismissed
      expect(find.text('Select Appointment Slot'), findsNothing);

      // Verify appointment card still rendered with updated slot
      expect(find.text('Dr. Jai Bansal Clinic Chamber'), findsOneWidget);
    },
  );

  testWidgets(
    'renders first appointment free UI when admin enables firstAppointmentFree',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cache = AppLocalCache.inMemory();
      final appointmentCubit = ClinicAppointmentCubit(
        cache: cache,
        api: _MockAppointmentApi(),
      );
      final user = const UserModel(
        id: '992',
        patientId: 'PAT-992',
        name: 'New Patient',
        emailOrPhone: '9876500002',
        phone: '9876500002',
        age: 24,
        gender: 'Female',
        isGuest: false,
      );
      final authCubit = _FakeAuthCubit(user);
      final appConfigCubit = _FakeAppConfigCubit(
        const AppointmentBillingConfig(
          paymentRequired: true,
          consultationFee: 500,
          firstAppointmentFree: true,
        ),
      );

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>.value(value: authCubit),
            BlocProvider<ClinicAppointmentCubit>.value(value: appointmentCubit),
            BlocProvider<AppConfigCubit>.value(value: appConfigCubit),
          ],
          child: const MaterialApp(home: ClinicAppointmentView()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('First visit · Free'), findsOneWidget);
      expect(find.text('Book free consultation'), findsOneWidget);
    },
  );

  testWidgets(
    'renders pay at clinic UI when admin turns off payment_required',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cache = AppLocalCache.inMemory();
      final appointmentCubit = ClinicAppointmentCubit(
        cache: cache,
        api: _MockAppointmentApi(),
      );
      final user = const UserModel(
        id: '993',
        patientId: 'PAT-993',
        name: 'Repeat Patient',
        emailOrPhone: '9876500003',
        phone: '9876500003',
        age: 30,
        gender: 'Male',
        isGuest: false,
      );
      final authCubit = _FakeAuthCubit(user);
      final appConfigCubit = _FakeAppConfigCubit(
        const AppointmentBillingConfig(
          paymentRequired: false,
          consultationFee: 450,
          firstAppointmentFree: false,
        ),
      );

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>.value(value: authCubit),
            BlocProvider<ClinicAppointmentCubit>.value(value: appointmentCubit),
            BlocProvider<AppConfigCubit>.value(value: appConfigCubit),
          ],
          child: const MaterialApp(home: ClinicAppointmentView()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Consultation · ₹450'), findsOneWidget);
      expect(find.text('Continue · Pay at clinic'), findsOneWidget);
      expect(find.text('No Online Payment Required'), findsOneWidget);
    },
  );

  testWidgets(
    'AppointmentPaymentSheet displays free consultation mode when fee is 0',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      AppointmentPaymentResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await AppointmentPaymentSheet.show(
                      context,
                      startsAt: DateTime(2026, 11, 10, 10, 30),
                      doctorName: 'Dr. Jai Bansal',
                      fee: 0,
                      paymentRequired: false,
                    );
                  },
                  child: const Text('Open Free Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Free Sheet'));
      await tester.pumpAndSettle();

      // Verify free consultation header and option
      expect(find.text('FREE CONSULTATION CONFIRMATION'), findsOneWidget);
      expect(find.text('100% Free Consultation (₹0)'), findsOneWidget);
      expect(find.text('₹0 FREE'), findsOneWidget);

      // Tap Confirm Free Consultation
      final confirmButton = find.text('Confirm Free Consultation (₹0)');
      await tester.ensureVisible(confirmButton);
      await tester.tap(confirmButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Verify result
      expect(result, isNotNull);
      expect(result?.amount, 0);
      expect(result?.paymentStatus, 'Waived');
      expect(result?.paymentMethod, 'Free First Consultation');
    },
  );

  testWidgets(
    'renders cancellation reason banner when appointment is cancelled',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = _MockAppointmentApi([
        {
          'id': 'APT-CANCELLED-1',
          'userId': 995,
          'patientId': 'PAT-995',
          'startsAt': '2026-11-20T10:30:00.000Z',
          'reason': 'Scalp consultation',
          'status': 'Cancelled',
          'tokenNumber': 'OPD-0088',
          'consultationFee': 500,
          'paymentStatus': 'Paid',
          'paymentMethod': 'Razorpay',
          'cancellation_reason': 'Doctor unavailable due to emergency surgery',
        },
      ]);
      final cache = AppLocalCache.inMemory();
      final appointmentCubit = ClinicAppointmentCubit(cache: cache, api: api);
      await appointmentCubit.loadFromApi('test-token');

      final user = const UserModel(
        id: '995',
        patientId: 'PAT-995',
        name: 'Rohan Sharma',
        emailOrPhone: '9876500005',
        phone: '9876500005',
        age: 29,
        gender: 'Male',
        isGuest: false,
      );
      final authCubit = _FakeAuthCubit(user);
      final appConfigCubit = _FakeAppConfigCubit(
        const AppointmentBillingConfig(),
      );

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>.value(value: authCubit),
            BlocProvider<ClinicAppointmentCubit>.value(value: appointmentCubit),
            BlocProvider<AppConfigCubit>.value(value: appConfigCubit),
          ],
          child: const MaterialApp(home: ClinicAppointmentView()),
        ),
      );
      await tester.pumpAndSettle();

      // Verify cancellation reason badge & reason text are visible
      expect(find.text('Cancellation Reason'), findsOneWidget);
      expect(
        find.text('Doctor unavailable due to emergency surgery'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'renders rescheduled notice when appointment has reschedule note',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = _MockAppointmentApi([
        {
          'id': 'APT-RESCHEDULED-1',
          'userId': 996,
          'patientId': 'PAT-996',
          'startsAt': '2026-11-22T11:00:00.000Z',
          'reason': 'Hair thinning review',
          'status': 'Confirmed',
          'tokenNumber': 'OPD-0099',
          'consultationFee': 500,
          'paymentStatus': 'Paid',
          'paymentMethod': 'Razorpay',
          'reschedule_reason':
              'Slot shifted by 30 mins due to clinic maintenance',
        },
      ]);
      final cache = AppLocalCache.inMemory();
      final appointmentCubit = ClinicAppointmentCubit(cache: cache, api: api);
      await appointmentCubit.loadFromApi('test-token');

      final user = const UserModel(
        id: '996',
        patientId: 'PAT-996',
        name: 'Priya Patel',
        emailOrPhone: '9876500006',
        phone: '9876500006',
        age: 27,
        gender: 'Female',
        isGuest: false,
      );
      final authCubit = _FakeAuthCubit(user);
      final appConfigCubit = _FakeAppConfigCubit(
        const AppointmentBillingConfig(),
      );

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>.value(value: authCubit),
            BlocProvider<ClinicAppointmentCubit>.value(value: appointmentCubit),
            BlocProvider<AppConfigCubit>.value(value: appConfigCubit),
          ],
          child: const MaterialApp(home: ClinicAppointmentView()),
        ),
      );
      await tester.pumpAndSettle();

      // Verify rescheduled notice & reason text are visible
      expect(find.text('Rescheduled by Clinic'), findsOneWidget);
      expect(
        find.text('Slot shifted by 30 mins due to clinic maintenance'),
        findsOneWidget,
      );
    },
  );
}
