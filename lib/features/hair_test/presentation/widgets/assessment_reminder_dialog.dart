import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../care/presentation/viewmodels/care_cubit.dart';

/// Modal dialog allowing patients to customize and schedule product usage reminders
/// directly from the Hair Assessment Report.
class AssessmentReminderDialog extends StatefulWidget {
  final String productName;
  final String treatmentType;
  final String defaultDosage;
  final String defaultTiming;
  final TimeOfDay initialTime;

  const AssessmentReminderDialog({
    super.key,
    required this.productName,
    this.treatmentType = 'Topical Serum',
    this.defaultDosage = '1ml dropper',
    this.defaultTiming = 'Night (before sleep)',
    this.initialTime = const TimeOfDay(hour: 21, minute: 30),
  });

  static Future<bool?> show(
    BuildContext context, {
    required String productName,
    String treatmentType = 'Topical Serum',
    String defaultDosage = '1ml dropper',
    String defaultTiming = 'Night (before sleep)',
    TimeOfDay initialTime = const TimeOfDay(hour: 21, minute: 30),
  }) {
    final careCubit = context.read<CareCubit?>();
    if (careCubit == null) return Future.value(false);

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => BlocProvider<CareCubit>.value(
        value: careCubit,
        child: AssessmentReminderDialog(
          productName: productName,
          treatmentType: treatmentType,
          defaultDosage: defaultDosage,
          defaultTiming: defaultTiming,
          initialTime: initialTime,
        ),
      ),
    );
  }

  @override
  State<AssessmentReminderDialog> createState() =>
      _AssessmentReminderDialogState();
}

class _AssessmentReminderDialogState extends State<AssessmentReminderDialog> {
  late TimeOfDay _selectedTime;
  late List<int> _selectedDays;
  late String _frequency;
  bool _isSaving = false;

  static const Map<int, String> _dayLabels = {
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun',
  };

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime;
    _selectedDays = [1, 2, 3, 4, 5, 6, 7];
    _frequency = 'Daily';
  }

  void _onFrequencyChanged(String freq) {
    HapticFeedback.selectionClick();
    setState(() {
      _frequency = freq;
      if (freq == 'Daily') {
        _selectedDays = [1, 2, 3, 4, 5, 6, 7];
      } else if (freq == 'Weekdays') {
        _selectedDays = [1, 2, 3, 4, 5];
      } else if (freq == 'Weekends') {
        _selectedDays = [6, 7];
      }
    });
  }

  void _toggleDay(int day) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedDays.contains(day)) {
        if (_selectedDays.length > 1) {
          _selectedDays.remove(day);
        }
      } else {
        _selectedDays.add(day);
        _selectedDays.sort();
      }

      if (_selectedDays.length == 7) {
        _frequency = 'Daily';
      } else if (_selectedDays.length == 5 &&
          _selectedDays.every((d) => d <= 5)) {
        _frequency = 'Weekdays';
      } else if (_selectedDays.length == 2 &&
          _selectedDays.every((d) => d >= 6)) {
        _frequency = 'Weekends';
      } else {
        _frequency = 'Custom';
      }
    });
  }

  Future<void> _pickTime() async {
    HapticFeedback.lightImpact();
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.primaryDark,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _saveReminder() async {
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final careCubit = context.read<CareCubit>();
      final notes = '${widget.defaultDosage} · ${widget.defaultTiming}';

      await careCubit.addReminder(
        title: widget.productName,
        subtitle: '${widget.treatmentType} · $_frequency',
        time: _selectedTime,
        frequency: _frequency,
        treatmentType: widget.treatmentType,
        repeatDays: _selectedDays,
        notes: notes,
      );

      if (mounted) {
        AppToast.show(
          context,
          SnackBar(
            content: Text(
              'Reminder set for ${widget.productName} at ${_formatTime(_selectedTime)} ($_frequency)',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          const SnackBar(
            content: Text('Could not save reminder. Please try again.'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.bellRing,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Set Product Reminder',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.x, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Timing selector card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'REMINDER TIME',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _pickTime,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.clock,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _formatTime(_selectedTime),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Change',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.info,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Recommended: ${widget.defaultTiming} (${widget.defaultDosage})',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Frequency selection
          const Text(
            'FREQUENCY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: ['Daily', 'Weekdays', 'Weekends'].map((freq) {
              final isSelected = _frequency == freq;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () => _onFrequencyChanged(freq),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        freq,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Day pills
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [1, 2, 3, 4, 5, 6, 7].map((day) {
              final isSelected = _selectedDays.contains(day);
              return InkWell(
                onTap: () => _toggleDay(day),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 42,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryDark
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryDark
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Text(
                    _dayLabels[day] ?? '',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Save button
          AppButton(
            height: 48,
            text: _isSaving ? 'Scheduling...' : 'Set Reminder',
            variant: AppButtonVariant.filled,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(LucideIcons.check, size: 18, color: Colors.white),
            onPressed: _isSaving ? null : _saveReminder,
          ),
        ],
      ),
    );
  }
}
