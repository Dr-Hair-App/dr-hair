import 'package:dr_hair/features/app_config/presentation/viewmodels/app_config_cubit.dart';
import 'package:dr_hair/features/app_config/presentation/viewmodels/app_config_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/routes/route_names.dart';
import '../../auth/presentation/viewmodels/auth_cubit.dart';
import '../../auth/presentation/views/complete_profile_view.dart';
import '../domain/clinic_appointment.dart';
import 'clinic_appointment_cubit.dart';
import 'widgets/appointment_date_picker_bottom_sheet.dart';
import 'widgets/appointment_payment_sheet.dart';

class ClinicAppointmentView extends StatefulWidget {
  const ClinicAppointmentView({super.key});

  @override
  State<ClinicAppointmentView> createState() => _ClinicAppointmentViewState();
}

class _ClinicAppointmentViewState extends State<ClinicAppointmentView> {
  DateTime? _startsAt;
  final TextEditingController _reasonController = TextEditingController();
  String? _replacingId;
  String? _reschedulingId;
  String? _accessToken;
  bool _didLoadAppointments = false;
  bool _saving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.read<AppConfigCubit?>()?.loadConfig();
    final auth = context.read<AuthCubit>().state;
    final token = auth.sessionToken;
    if (token != null && token.isNotEmpty && auth.isGuest != true) {
      _accessToken = token;
      if (!_didLoadAppointments) {
        _didLoadAppointments = true;
        context.read<ClinicAppointmentCubit>().loadFromApi(token);
      }
    }
  }

  String _dateLabel(DateTime date) =>
      '${MaterialLocalizations.of(context).formatMediumDate(date)} · ${TimeOfDay.fromDateTime(date).format(context)}';

  Future<void> _pickDateAndSlot() async {
    final picked = await AppointmentDatePickerBottomSheet.show(
      context,
      initialDate: _startsAt,
      api: context.read<ClinicAppointmentCubit>().api,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startsAt = picked;
    });
  }

  Future<void> _save(String patientId) async {
    if (_startsAt == null) {
      _message('Please select an appointment date and sitting slot.');
      return;
    }

    final auth = context.read<AuthCubit>();
    var user = auth.state.user;
    final age = user?.age;
    final gender = user?.gender?.trim();
    if (age == null || gender == null || gender.isEmpty) {
      final completed = await CompleteProfileBottomSheet.show(
        context,
        requireAgeAndGender: true,
        title: 'Complete your profile',
        subtitle: 'Age and gender are required before booking an in-clinic consultation.',
      );
      if (completed != true || !mounted) {
        return;
      }
      user = context.read<AuthCubit>().state.user;
    }

    final activePatientId = user?.patientId ?? patientId;
    final userReason = _reasonController.text.trim();
    final finalReason = userReason.isEmpty
        ? 'General hair & scalp consultation'
        : userReason;

    final billing =
        context.read<AppConfigCubit?>()?.state.appointmentBilling ??
        const AppointmentBillingConfig();
    final existingRequests = context.read<ClinicAppointmentCubit>().forPatient(
      activePatientId,
      userId: user?.id,
    );
    final hasPriorVisit = existingRequests.any((a) => a.status != 'Cancelled');
    final isFirstAppointment = !hasPriorVisit;

    final isFirstFree = billing.firstAppointmentFree && isFirstAppointment;
    final fee = isFirstFree ? 0 : billing.consultationFee;
    final paymentRequired = billing.paymentRequired && !isFirstFree;

    AppointmentPaymentResult? payment;
    if (_replacingId == null) {
      payment = await AppointmentPaymentSheet.show(
        context,
        startsAt: _startsAt!,
        reason: finalReason,
        doctorName: 'Dr. Jai Bansal',
        fee: fee,
        paymentRequired: paymentRequired,
        patientToken: _accessToken ?? auth.state.sessionToken,
        patientPhone: user?.phone,
        patientName: user?.name,
      );
      if (payment == null || !mounted) {
        return;
      }
    }

    setState(() => _saving = true);
    String? error;
    final activeToken = _accessToken ?? auth.state.sessionToken ?? '';

    if (payment != null &&
        payment.paymentStatus == 'Paid' &&
        payment.signature != null &&
        payment.signature!.isNotEmpty) {
      error = await context
          .read<ClinicAppointmentCubit>()
          .verifyAndBookPaidAppointment(
            patientId: activePatientId,
            accessToken: activeToken,
            startsAt: _startsAt!,
            reason: finalReason,
            razorpayOrderId: payment.orderId ?? '',
            razorpayPaymentId: payment.transactionId,
            razorpaySignature: payment.signature ?? '',
          );
    } else {
      error = await context.read<ClinicAppointmentCubit>().saveRequest(
        patientId: activePatientId,
        accessToken: activeToken,
        startsAt: _startsAt!,
        reason: finalReason,
        replacingId: _replacingId,
        consultationFee: payment?.amount ?? fee,
        paymentMethod: payment?.paymentMethod ?? 'Pay at clinic',
        paymentStatus: payment?.paymentStatus ?? 'Pending',
        paymentTransactionId: payment?.transactionId,
      );
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (error == null) {
        _startsAt = null;
        _reasonController.clear();
        _replacingId = null;
      }
    });
    _message(
      error ?? 'Appointment request submitted to Dr. Jai Bansal. OPD token assigned.',
    );
  }

  Future<void> _confirmCancel(String id, String patientId) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Cancel this appointment?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'The clinic will be notified and this sitting will be released. You can request another appointment later.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.secondaryDark,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 45,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        child: const Text(
                          'Keep appointment',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.danger,
                        ),
                        onPressed: () => Navigator.pop(sheetContext, true),
                        child: const Text(
                          'Cancel visit',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      _message('Sign in again to cancel this appointment.');
      return;
    }
    final error = await context.read<ClinicAppointmentCubit>().cancel(
      id,
      patientId,
      accessToken: token,
    );
    if (!mounted) return;
    _message(error ?? 'Appointment request cancelled.');
  }

  Future<void> _rescheduleAppointment(
    ClinicAppointment request,
    String patientId,
  ) async {
    final initialDate = request.startsAt;
    final hour = initialDate.hour;
    final minute = initialDate.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final standardHour = hour % 12 == 0 ? 12 : hour % 12;
    final initialSlot =
        '${standardHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';

    final picked = await AppointmentDatePickerBottomSheet.show(
      context,
      initialDate: initialDate,
      initialSlot: initialSlot,
      api: context.read<ClinicAppointmentCubit>().api,
    );

    if (picked == null || !mounted) return;

    if (picked.isAtSameMomentAs(request.startsAt)) {
      _message('Appointment slot unchanged.');
      return;
    }

    final token = _accessToken ?? context.read<AuthCubit>().state.sessionToken;
    setState(() => _reschedulingId = request.id);

    final error = await context.read<ClinicAppointmentCubit>().reschedule(
      id: request.id,
      patientId: patientId,
      newStartsAt: picked,
      accessToken: token,
    );

    if (!mounted) return;
    setState(() {
      _reschedulingId = null;
      if (_replacingId == request.id) {
        _replacingId = null;
        _startsAt = null;
        _reasonController.clear();
      }
    });

    if (error != null) {
      _message(error);
    } else {
      _message(
        'Appointment rescheduled to ${_dateLabel(picked)}. Confirmed slot updated.',
      );
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;
    final patientId = user?.patientId ?? 'GUEST';
    final canRequest = user != null && !user.isGuest;
    final billing =
        context.watch<AppConfigCubit?>()?.state.appointmentBilling ??
        const AppointmentBillingConfig();
    final existingRequests = context.watch<ClinicAppointmentCubit>().forPatient(
      patientId,
      userId: user?.id,
    );
    final hasPriorVisit = existingRequests.any((a) => a.status != 'Cancelled');
    final isFirstAppointment = !hasPriorVisit;

    final isFirstFree = billing.firstAppointmentFree && isFirstAppointment;
    final fee = isFirstFree ? 0 : billing.consultationFee;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final motionDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
        ),
        title: const Text(
          'In-Clinic Appointment',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            context.read<AppConfigCubit?>()?.loadConfig();
            final token =
                _accessToken ?? context.read<AuthCubit>().state.sessionToken;
            if (token != null && token.isNotEmpty) {
              await context.read<ClinicAppointmentCubit>().loadFromApi(token);
            }
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // Doctor & Clinic Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x081A365D),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary5,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary100),
                          ),
                          child: const Icon(
                            LucideIcons.stethoscope,
                            color: AppColors.primary,
                            size: 25,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Dr. Jai Bansal',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'In-clinic hair and scalp consultation',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(
                      height: 24,
                      thickness: 1,
                      color: AppColors.border,
                    ),
                    // Clinic Venue Details
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          LucideIcons.mapPin,
                          color: AppColors.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Dr. Hair Restoration & Trichology Center',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Dr. Hair & Cosmodent Clinic, Jaipur, Rajasthan · 302017',
                                style: TextStyle(
                                  fontSize: 10,
                                  height: 1.35,
                                  color: AppColors.secondaryDark,
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final uri = Uri.parse(
                                    'https://www.google.com/maps/search/?api=1&query=Dr+Hair+Jaipur',
                                  );
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        LucideIcons.navigation,
                                        size: 13,
                                        color: AppColors.primary,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Get Directions on Google Maps',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary5,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            LucideIcons.clock,
                            color: AppColors.primary,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Sitting Hours: Mon – Sat (10 AM – 1 PM & 3:30 PM – 7 PM)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Dynamic Billing & Payment Policy Banner (Configured from Admin Panel)
              Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isFirstFree
                      ? const Color(0xFFF0FDF4)
                      : (!billing.paymentRequired
                            ? const Color(0xFFF0FDFA)
                            : const Color(0xFFEFF6FF)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isFirstFree
                        ? const Color(0xFF86EFAC)
                        : (!billing.paymentRequired
                              ? const Color(0xFF99F6E4)
                              : const Color(0xFFBFDBFE)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isFirstFree
                            ? const Color(0xFFDCFCE7)
                            : (!billing.paymentRequired
                                  ? const Color(0xFFCCFBF1)
                                  : const Color(0xFFDBEAFE)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFirstFree
                            ? LucideIcons.sparkles
                            : (!billing.paymentRequired
                                  ? LucideIcons.banknote
                                  : LucideIcons.creditCard),
                        size: 18,
                        color: isFirstFree
                            ? const Color(0xFF16A34A)
                            : (!billing.paymentRequired
                                  ? const Color(0xFF0D9488)
                                  : const Color(0xFF2563EB)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isFirstFree
                                    ? '1st Clinic Visit 100% FREE'
                                    : (!billing.paymentRequired
                                          ? 'No Online Payment Required'
                                          : 'Online Payment Required'),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: isFirstFree
                                      ? const Color(0xFF15803D)
                                      : (!billing.paymentRequired
                                            ? const Color(0xFF0F766E)
                                            : const Color(0xFF1D4ED8)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: isFirstFree
                                      ? const Color(0xFFBBF7D0)
                                      : (!billing.paymentRequired
                                            ? const Color(0xFF99F6E4)
                                            : const Color(0xFF93C5FD)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isFirstFree
                                      ? '₹0'
                                      : (!billing.paymentRequired
                                            ? 'Pay at Clinic'
                                            : '₹$fee'),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: isFirstFree
                                        ? const Color(0xFF14532D)
                                        : (!billing.paymentRequired
                                              ? const Color(0xFF115E59)
                                              : const Color(0xFF1E3A8A)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isFirstFree
                                ? 'Welcome offer: Your first consultation with Dr. Jai Bansal is complimentary.'
                                : (!billing.paymentRequired
                                      ? 'Online payment is OFF. Reserve your slot now; pay consultation fee ${fee > 0 ? "₹$fee " : ""}at clinic reception.'
                                      : 'Consultation fee of ₹$fee payable via Razorpay (UPI, Card, NetBanking) for instant token.'),
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.35,
                              color: isFirstFree
                                  ? const Color(0xFF166534)
                                  : (!billing.paymentRequired
                                        ? const Color(0xFF134E4A)
                                        : const Color(0xFF1E40AF)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Booking Form Section
              Text(
                _replacingId == null
                    ? 'Choose your visit time'
                    : 'Choose a new time',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 14),

              // 1. Date & Slot Picker Custom Reusable Bottom Sheet trigger
              InkWell(
                onTap: _pickDateAndSlot,
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: motionDuration,
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _startsAt != null
                          ? AppColors.primary
                          : AppColors.border,
                      width: _startsAt != null ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.calendarDays,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Appointment Date & Sitting Slot',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            AnimatedSwitcher(
                              duration: motionDuration,
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              child: Text(
                                _startsAt == null
                                    ? 'Choose a date and time'
                                    : _dateLabel(_startsAt!),
                                key: ValueKey(_startsAt?.toIso8601String()),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _startsAt == null
                                      ? AppColors.textMuted
                                      : AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        LucideIcons.chevronRight,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 2. Optional Description / Reason Input Field (Replaced Dropdown)
              TextFormField(
                controller: _reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason for visit / description (Optional)',
                  hintText: 'e.g. Hair fall at crown, scalp itchiness, post-treatment check...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(LucideIcons.fileText, size: 18),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
              ),

              const SizedBox(height: 18),

              const SizedBox(height: 12),

              // Patient's Existing Requests Section
              const Text(
                'Your Scheduled Visits',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 10),

              BlocBuilder<ClinicAppointmentCubit, List<ClinicAppointment>>(
                builder: (context, _) {
                  final requests = context
                      .read<ClinicAppointmentCubit>()
                      .forPatient(patientId, userId: user?.id);

                  if (requests.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Center(
                        child: Text(
                          'No physical clinic visits scheduled yet.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryDark,
                          ),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: requests.map((request) {
                      final isCancelled = request.status == 'Cancelled';
                      final isRequested = request.status == 'Requested';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        LucideIcons.building2,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Dr. Jai Bansal Clinic Chamber',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isCancelled
                                              ? AppColors.textSecondary
                                              : AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isCancelled
                                          ? const Color(0xFFFEE2E2)
                                          : isRequested
                                          ? const Color(0xFFFEF3C7)
                                          : const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isCancelled
                                            ? const Color(0xFFFECACA)
                                            : isRequested
                                            ? const Color(0xFFFDE68A)
                                            : const Color(0xFFDCFCE7),
                                      ),
                                    ),
                                    child: Text(
                                      isCancelled
                                          ? 'Cancelled'
                                          : isRequested
                                          ? 'Slot Requested'
                                          : 'OPD Confirmed',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isCancelled
                                            ? const Color(0xFF991B1B)
                                            : isRequested
                                            ? const Color(0xFF92400E)
                                            : const Color(0xFF166534),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 18),
                              Text(
                                _dateLabel(request.startsAt),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                request.reason,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.secondaryDark,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Venue: Dr. Hair & Cosmodent Clinic · Jaipur Clinic',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  if (request.tokenNumber.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            LucideIcons.ticket,
                                            size: 12,
                                            color: Color(0xFF475569),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Token: ${request.tokenNumber}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF334155),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: request.paymentStatus == 'Paid'
                                          ? const Color(0xFFECFDF5)
                                          : const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: request.paymentStatus == 'Paid'
                                            ? const Color(0xFFA7F3D0)
                                            : const Color(0xFFFDE68A),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          request.paymentStatus == 'Paid'
                                              ? LucideIcons.checkCheck
                                              : LucideIcons.circleDollarSign,
                                          size: 12,
                                          color: request.paymentStatus == 'Paid'
                                              ? const Color(0xFF059669)
                                              : const Color(0xFFD97706),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          request.paymentStatus == 'Paid'
                                              ? '₹${request.consultationFee} Paid (${request.paymentMethod})'
                                              : '₹${request.consultationFee} Due at Clinic',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color:
                                                request.paymentStatus == 'Paid'
                                                ? const Color(0xFF047857)
                                                : const Color(0xFFB45309),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (isCancelled &&
                                  request.cancellationReason.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFFCA5A5),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        LucideIcons.alertCircle,
                                        size: 14,
                                        color: Color(0xFFDC2626),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Cancellation Reason',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF991B1B),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              request.cancellationReason,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF7F1D1D),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (!isCancelled &&
                                  request.rescheduleReason.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFBFDBFE),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        LucideIcons.calendarClock,
                                        size: 14,
                                        color: Color(0xFF2563EB),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Rescheduled by Clinic',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1D4ED8),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              request.rescheduleReason,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF1E40AF),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (!isCancelled &&
                                  request.startsAt.isAfter(DateTime.now())) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    TextButton.icon(
                                      onPressed: _reschedulingId == request.id
                                          ? null
                                          : () => _rescheduleAppointment(
                                              request,
                                              patientId,
                                            ),
                                      icon: _reschedulingId == request.id
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.primary,
                                              ),
                                            )
                                          : const Icon(
                                              LucideIcons.calendarClock,
                                              size: 14,
                                            ),
                                      label: Text(
                                        _reschedulingId == request.id
                                            ? 'Rescheduling…'
                                            : 'Reschedule',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: () =>
                                          _confirmCancel(request.id, patientId),
                                      icon: const Icon(
                                        LucideIcons.xCircle,
                                        size: 14,
                                      ),
                                      label: const Text('Cancel Visit'),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
            boxShadow: [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 12,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    isFirstFree
                        ? LucideIcons.sparkles
                        : (!billing.paymentRequired
                              ? LucideIcons.banknote
                              : LucideIcons.receipt),
                    size: 16,
                    color: isFirstFree
                        ? const Color(0xFF16A34A)
                        : (!billing.paymentRequired
                              ? const Color(0xFF0D9488)
                              : AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isFirstFree
                          ? 'First visit · Free'
                          : 'Consultation · ₹$fee',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  if (billing.paymentRequired && !isFirstFree)
                    const Text(
                      'Secure payment',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (!billing.paymentRequired && !isFirstFree)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: const Text(
                        'Pay at clinic',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving
                      ? null
                      : canRequest
                      ? () => _save(patientId)
                      : () => context.push(RouteNames.signin),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: motionDuration,
                    child: _saving
                        ? const Row(
                            key: ValueKey('saving'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Saving…'),
                            ],
                          )
                        : Text(
                            canRequest
                                ? _replacingId == null
                                      ? isFirstFree
                                            ? 'Book free consultation'
                                            : billing.paymentRequired
                                            ? 'Continue · ₹$fee'
                                            : 'Continue · Pay at clinic'
                                      : 'Update appointment time'
                                : 'Sign in to book',
                            key: ValueKey(
                              canRequest ? _replacingId : 'sign-in',
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ),
              if (_replacingId != null)
                TextButton(
                  onPressed: () => setState(() {
                    _replacingId = null;
                    _startsAt = null;
                    _reasonController.clear();
                  }),
                  child: const Text('Cancel rescheduling'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
