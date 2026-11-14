import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/patient_appointment_api.dart';

class AppointmentDatePickerBottomSheet extends StatefulWidget {
  final DateTime? initialDate;
  final String? initialSlot;
  final PatientAppointmentApi? api;

  const AppointmentDatePickerBottomSheet({
    super.key,
    this.initialDate,
    this.initialSlot,
    this.api,
  });

  /// Static helper to open the reusable bottom sheet
  static Future<DateTime?> show(
    BuildContext context, {
    DateTime? initialDate,
    String? initialSlot,
    PatientAppointmentApi? api,
  }) {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AppointmentDatePickerBottomSheet(
        initialDate: initialDate,
        initialSlot: initialSlot,
        api: api,
      ),
    );
  }

  @override
  State<AppointmentDatePickerBottomSheet> createState() =>
      _AppointmentDatePickerBottomSheetState();
}

class _AppointmentDatePickerBottomSheetState
    extends State<AppointmentDatePickerBottomSheet> {
  late DateTime _focusedMonth;
  DateTime? _selectedDate;
  String? _selectedSlot;
  late final PatientAppointmentApi _api;
  bool _isLoadingAvailability = true;
  String? _availabilityError;
  int _bookingWindowDays = 90;
  String _timezone = 'Asia/Kolkata';
  Set<int> _closedWeekdays = {DateTime.sunday};
  Set<String> _closedDates = {};
  Set<String> _bookedSlots = {};
  List<Map<String, dynamic>> _sessions = const [];

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? PatientAppointmentApi();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);

    if (widget.initialDate != null) {
      _selectedDate = DateTime(
        widget.initialDate!.year,
        widget.initialDate!.month,
        widget.initialDate!.day,
      );
      _selectedSlot = widget.initialSlot;
    }
    _loadAvailability();
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _loadAvailability({bool showLoading = true}) async {
    final month = _focusedMonth;
    if (showLoading && mounted) {
      setState(() {
        _isLoadingAvailability = true;
        _availabilityError = null;
      });
    }
    try {
      final response = await _api.getAvailability(
        from: DateTime(month.year, month.month, 1),
        to: DateTime(month.year, month.month + 1, 0),
      );
      if (!mounted ||
          month.year != _focusedMonth.year ||
          month.month != _focusedMonth.month) {
        return;
      }
      final rawSessions = response['sessions'];
      final rawClosedDates = response['closed_dates'];
      final rawBookedSlots = response['booked_slots'];
      if (rawSessions is! List ||
          rawSessions.isEmpty ||
          response['timezone'] is! String ||
          response['booking_window_days'] is! num ||
          response['weekly_closed_weekdays'] is! List ||
          rawClosedDates is! List ||
          rawBookedSlots is! List) {
        throw const FormatException(
          'Clinic availability response is incomplete.',
        );
      }
      final rawWeekdays = response['weekly_closed_weekdays'] as List;
      final sessions = rawSessions
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (sessions.isEmpty) {
        throw const FormatException(
          'Clinic availability has no valid sessions.',
        );
      }
      setState(() {
        _bookingWindowDays =
            (response['booking_window_days'] as num?)?.toInt() ?? 90;
        _timezone = response['timezone']?.toString() ?? 'Asia/Kolkata';
        _closedWeekdays = rawWeekdays
            .whereType<num>()
            .map((day) => day.toInt())
            .toSet();
        _sessions = sessions;
        _closedDates = rawClosedDates
            .whereType<Map>()
            .map((item) => item['date']?.toString() ?? '')
            .where((date) => date.isNotEmpty)
            .toSet();
        _bookedSlots = rawBookedSlots.map((item) => item.toString()).toSet();
        _isLoadingAvailability = false;
        _availabilityError = null;
        if (_selectedDate == null || !_isDateSelectable(_selectedDate!)) {
          _selectedDate = _firstSelectableDateInMonth(month);
          _selectedSlot = null;
        } else if (_selectedSlot != null &&
            _isSlotUnavailable(_selectedDate!, _selectedSlot!)) {
          _selectedSlot = null;
        }
      });
    } catch (_) {
      if (!mounted ||
          month.year != _focusedMonth.year ||
          month.month != _focusedMonth.month) {
        return;
      }
      setState(() {
        _isLoadingAvailability = false;
        _availabilityError = 'Appointment availability could not be loaded.';
        _selectedSlot = null;
      });
    }
  }

  DateTime? _firstSelectableDateInMonth(DateTime month) {
    final today = DateTime.now();
    final startDay = month.year == today.year && month.month == today.month
        ? today.day
        : 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    for (var day = startDay; day <= days; day++) {
      final date = DateTime(month.year, month.month, day);
      if (_isDateSelectable(date)) return date;
    }
    return null;
  }

  bool _isWeeklyClosed(DateTime date) => _closedWeekdays.contains(date.weekday);

  bool _isHoliday(DateTime date) => _closedDates.contains(_dateKey(date));

  bool _isPastDay(DateTime date) {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    return date.isBefore(startOfToday);
  }

  bool _isDateSelectable(DateTime date) {
    final lastBookableDate = DateTime.now().add(
      Duration(days: _bookingWindowDays),
    );
    return !_isLoadingAvailability &&
        _availabilityError == null &&
        !_isPastDay(date) &&
        !date.isAfter(
          DateTime(
            lastBookableDate.year,
            lastBookableDate.month,
            lastBookableDate.day,
          ),
        ) &&
        !_closedWeekdays.contains(date.weekday) &&
        !_closedDates.contains(_dateKey(date)) &&
        _slotsForDate(date).any((slot) => !_isSlotUnavailable(date, slot));
  }

  bool _isSlotUnavailable(DateTime date, String slot) =>
      _bookedSlots.contains('${_dateKey(date)}T${_slot24Hour(slot)}') ||
      _isSlotPast(date, slot);

  String _slot24Hour(String slot) {
    final parts = slot.split(' ');
    final time = parts.first.split(':');
    var hour = int.parse(time[0]);
    if (parts.length > 1 && parts[1] == 'PM' && hour != 12) hour += 12;
    if (parts.length > 1 && parts[1] == 'AM' && hour == 12) hour = 0;
    return '${hour.toString().padLeft(2, '0')}:${time[1]}';
  }

  List<String> _slotsForSession(Map<String, dynamic> session) {
    final opens = _minutesFromClock(session['opens_at']?.toString());
    final closes = _minutesFromClock(session['closes_at']?.toString());
    if (opens == null || closes == null || closes < opens) return const [];
    return [
      for (var minutes = opens; minutes <= closes; minutes += 30)
        _formatSlot(minutes),
    ];
  }

  List<String> _slotsForDate(DateTime date) => _sessions
      .expand(_slotsForSession)
      .where((slot) => !_isSlotUnavailable(date, slot))
      .toList();

  int? _minutesFromClock(String? value) {
    if (value == null || !RegExp(r'^\d{2}:\d{2}$').hasMatch(value)) return null;
    final parts = value.split(':').map(int.parse).toList();
    if (parts[0] > 23 || parts[1] > 59) return null;
    return parts[0] * 60 + parts[1];
  }

  String _formatSlot(int minutes) {
    final hour24 = minutes ~/ 60;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour12:$minute ${hour24 < 12 ? 'AM' : 'PM'}';
  }

  DateTime _combineDateAndTime(DateTime date, String slotStr) {
    final parts = slotStr.split(' ');
    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    if (parts[1] == 'PM' && hour != 12) hour += 12;
    if (parts[1] == 'AM' && hour == 12) hour = 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  bool _isSlotPast(DateTime date, String slotStr) {
    final slotTime = _combineDateAndTime(date, slotStr);
    return slotTime.isBefore(DateTime.now());
  }

  void _nextMonth() {
    final today = DateTime.now();
    final lastBookableDate = today.add(Duration(days: _bookingWindowDays));
    final nextMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    if (nextMonth.isAfter(
      DateTime(lastBookableDate.year, lastBookableDate.month),
    )) {
      return;
    }
    setState(() {
      _focusedMonth = nextMonth;
      _selectedDate = null;
      _selectedSlot = null;
    });
    _loadAvailability();
  }

  void _prevMonth() {
    final now = DateTime.now();
    if (_focusedMonth.year == now.year && _focusedMonth.month <= now.month) {
      return; // Cannot go prior to current month
    }
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
      _selectedDate = null;
      _selectedSlot = null;
    });
    _loadAvailability();
  }

  Future<void> _confirmSlot() async {
    final selectedDate = _selectedDate;
    final selectedSlot = _selectedSlot;
    if (selectedDate == null || selectedSlot == null) return;
    await _loadAvailability();
    if (!mounted) return;
    if (_availabilityError != null ||
        !_isDateSelectable(selectedDate) ||
        _isSlotUnavailable(selectedDate, selectedSlot)) {
      setState(() => _selectedSlot = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'That slot is no longer available. Choose another time.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pop(_combineDateAndTime(selectedDate, selectedSlot));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final canGoPrev =
        _focusedMonth.year > now.year || _focusedMonth.month > now.month;
    final lastBookableDate = now.add(Duration(days: _bookingWindowDays));
    final nextMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    final canGoNext = !nextMonth.isAfter(
      DateTime(lastBookableDate.year, lastBookableDate.month),
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Clinic Visit Slot',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Dr. Jai Bansal · Dr. Hair & Cosmodent Clinic · Jaipur',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.secondaryDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    LucideIcons.x,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: AppColors.border),

          // Scrollable Calendar & Slots Body
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
              children: [
                // Month Header Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _monthName(_focusedMonth),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: canGoPrev ? _prevMonth : null,
                          icon: Icon(
                            LucideIcons.chevronLeft,
                            size: 18,
                            color: canGoPrev
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                        ),
                        IconButton(
                          onPressed: canGoNext ? _nextMonth : null,
                          icon: const Icon(
                            LucideIcons.chevronRight,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Weekday Header
                _buildWeekdayHeader(),

                const SizedBox(height: 6),

                // Calendar Days Grid
                _buildDaysGrid(),

                const SizedBox(height: 12),

                // Legend / Notifications
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _availabilityError != null
                        ? const Color(0xFFFFF7ED)
                        : AppColors.primary5,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      if (_isLoadingAvailability)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          _availabilityError != null
                              ? LucideIcons.circleAlert
                              : LucideIcons.info,
                          color: _availabilityError != null
                              ? const Color(0xFFB45309)
                              : AppColors.primary,
                          size: 14,
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _availabilityError ??
                              (_isLoadingAvailability
                                  ? 'Loading clinic availability…'
                                  : 'Availability shown in $_timezone time · up to $_bookingWindowDays days ahead'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _availabilityError != null
                                ? const Color(0xFF92400E)
                                : AppColors.primary,
                          ),
                        ),
                      ),
                      if (_availabilityError != null)
                        TextButton(
                          onPressed: _loadAvailability,
                          child: const Text('Retry'),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Slots Section (Visible when date is picked)
                if (_selectedDate != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Dr. Jai Bansal Sitting Slots',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      Text(
                        _selectedDateFormatted(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (_isLoadingAvailability)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 22),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_availabilityError != null)
                    const Text('Refresh availability to see appointment times.')
                  else if (_slotsForDate(_selectedDate!).isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No times are available on this date. Choose another day.',
                      ),
                    )
                  else ...[
                    for (var index = 0; index < _sessions.length; index++) ...[
                      _buildSlotCategory(
                        '${_sessions[index]['label'] ?? 'Clinic Session'} (${_sessions[index]['opens_at']} – ${_sessions[index]['closes_at']})',
                        _slotsForSession(_sessions[index]),
                      ),
                      if (index < _sessions.length - 1)
                        const SizedBox(height: 14),
                    ],
                  ],
                ],
              ],
            ),
          ),

          // Bottom Confirmation Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 8,
                  offset: Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Selected Appointment Slot',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedSlotSummary(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed:
                      (_selectedDate != null &&
                          _selectedSlot != null &&
                          !_isLoadingAvailability &&
                          _availabilityError == null)
                      ? _confirmSlot
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Confirm Slot',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _selectedSlotSummary() {
    if (_selectedDate == null) return 'Select a date';
    if (_selectedSlot == null) return 'Choose time slot';
    return '${MaterialLocalizations.of(context).formatMediumDate(_selectedDate!)} · $_selectedSlot';
  }

  String _selectedDateFormatted() {
    if (_selectedDate == null) return '';
    return MaterialLocalizations.of(context).formatMediumDate(_selectedDate!);
  }

  String _monthName(DateTime month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[month.month - 1]} ${month.year}';
  }

  Widget _buildWeekdayHeader() {
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: List.generate(weekdays.length, (index) {
        final day = weekdays[index];
        final isClosed = _closedWeekdays.contains(index + 1);
        return Expanded(
          child: Center(
            child: Text(
              isClosed ? '$day (Off)' : day,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isClosed
                    ? const Color(0xFFEF4444)
                    : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDaysGrid() {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;

    // In Dart weekday: Mon=1, Sun=7. We want Mon at index 0.
    final leadingEmpty = firstDayOfMonth.weekday - 1;

    final totalCells = leadingEmpty + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rows, (rowIndex) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: List.generate(7, (colIndex) {
              final dayIndex = rowIndex * 7 + colIndex - leadingEmpty + 1;
              if (dayIndex < 1 || dayIndex > daysInMonth) {
                return const Expanded(child: SizedBox(height: 40));
              }

              final cellDate = DateTime(year, month, dayIndex);
              final isSunday = _isWeeklyClosed(cellDate);
              final isHoliday = _isHoliday(cellDate);
              final isDisabled = !_isDateSelectable(cellDate);

              final isSelected =
                  _selectedDate != null &&
                  _selectedDate!.year == cellDate.year &&
                  _selectedDate!.month == cellDate.month &&
                  _selectedDate!.day == cellDate.day;

              return Expanded(
                child: GestureDetector(
                  onTap: isDisabled
                      ? () {
                          if (isSunday) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Dr. Jai Bansal\'s clinic is closed on Sundays (Weekly Off).',
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          } else if (isHoliday) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Selected date is an official clinic holiday.',
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      : () {
                          setState(() {
                            _selectedDate = cellDate;
                            _selectedSlot = null; // reset slot for new date
                          });
                        },
                  child: Container(
                    height: 42,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : isSunday
                          ? const Color(0xFFFEF2F2)
                          : isHoliday
                          ? const Color(0xFFFFFBEB)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: AppColors.primary, width: 1.5)
                          : isSunday
                          ? Border.all(
                              color: const Color(0xFFFCA5A5)
                                  .withValues(alpha: 0.4),
                            )
                          : isHoliday
                          ? Border.all(
                              color: const Color(0xFFFCD34D)
                                  .withValues(alpha: 0.5),
                            )
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayIndex.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : isDisabled
                                ? isSunday
                                      ? const Color(0xFFEF4444)
                                      : isHoliday
                                      ? const Color(0xFFD97706)
                                      : AppColors.textMuted
                                : AppColors.primaryDark,
                          ),
                        ),
                        if (isSunday)
                          const Text(
                            'Off',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEF4444),
                            ),
                          )
                        else if (isHoliday)
                          const Text(
                            'Holiday',
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD97706),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildSlotCategory(String title, List<String> slots) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryDark,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slots.map((slot) {
            final isUnavailable =
                _selectedDate != null &&
                _isSlotUnavailable(_selectedDate!, slot);
            final isSelected = _selectedSlot == slot;

            return ChoiceChip(
              label: Text(
                slot,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isUnavailable
                      ? AppColors.textMuted
                      : isSelected
                      ? Colors.white
                      : AppColors.primaryDark,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: const Color(0xFFF8FAFC),
              disabledColor: const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primary
                      : isUnavailable
                      ? const Color(0xFFE2E8F0)
                      : AppColors.border,
                ),
              ),
              onSelected:
                  isUnavailable ||
                      _isLoadingAvailability ||
                      _availabilityError != null
                  ? null
                  : (selected) {
                      setState(() {
                        _selectedSlot = selected ? slot : null;
                      });
                    },
            );
          }).toList(),
        ),
      ],
    );
  }
}
