import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/utils/whatsapp_launcher.dart';
import '../viewmodels/care_cubit.dart';
import '../viewmodels/care_state.dart';
import '../widgets/add_routine_task_bottom_sheet.dart';
import '../widgets/care_widgets.dart';

/// 1. Routine Tracker View
/// Allows users to view today's regimen progress, maintain daily streaks, and mark treatment steps done.
class RoutineTrackerView extends StatelessWidget {
  const RoutineTrackerView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CareCubit, CareState>(
      builder: (context, state) {
        final progress = state.routineProgress;
        final isAllCompleted = progress >= 1.0 && state.routineTasks.isNotEmpty;
        final today = DateTime.now();
        final weekStart = today.subtract(Duration(days: today.weekday - 1));

        return CarePageScaffold(
          title: 'Daily Routine',
          actions: [
            IconButton(
              tooltip: 'Reset daily steps',
              icon: const Icon(
                LucideIcons.rotateCcw,
                color: AppColors.primary,
                size: 18,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                context.read<CareCubit>().resetTodayRoutine();
              },
            ),
            IconButton(
              tooltip: 'Add new task',
              icon: const Icon(
                LucideIcons.plus,
                color: AppColors.primary,
                size: 20,
              ),
              onPressed: () => AddRoutineTaskBottomSheet.show(context),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Progress & Streak Card
              careCard(
                backgroundColor: isAllCompleted
                    ? const Color(0xFFECFDF5)
                    : Colors.white,
                border: Border.all(
                  color: isAllCompleted
                      ? const Color(0xFF10B981)
                      : AppColors.border,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAllCompleted
                                  ? '🎉 Daily Regimen Complete!'
                                  : 'Today’s Care Progress',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${state.completedRoutineCount} of ${state.routineTasks.length} steps complete',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.secondaryDark,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFEDD5)),
                          ),
                          child: Row(
                            children: [
                              const Text('🔥', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                '${state.routineStreakDays} Days',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFEA580C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 400),
                        builder: (context, value, child) =>
                            LinearProgressIndicator(
                              borderRadius: BorderRadius.circular(8),
                              value: value,
                              minHeight: 8,
                              backgroundColor: AppColors.primary5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isAllCompleted
                                    ? const Color(0xFF10B981)
                                    : AppColors.primary,
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Weekly check-in dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                          .asMap()
                          .entries
                          .map((entry) {
                            final idx = entry.key;
                            final label = entry.value;
                            final date = weekStart.add(Duration(days: idx));
                            final dayKey =
                                '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                            final isPassed = state.routineCompletionDays
                                .contains(dayKey);
                            final isToday = date.weekday == today.weekday;
                            return Column(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isToday
                                        ? AppColors.primary
                                        : (isPassed
                                              ? const Color(0xFF10B981)
                                              : AppColors.background),
                                    border: Border.all(
                                      color: isToday
                                          ? AppColors.primary
                                          : AppColors.border,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isToday
                                          ? (isAllCompleted
                                                ? LucideIcons.check
                                                : LucideIcons.clock)
                                          : (isPassed
                                                ? LucideIcons.check
                                                : LucideIcons.circle),
                                      size: 14,
                                      color: isPassed || isToday
                                          ? Colors.white
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isToday
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: isToday
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            );
                          })
                          .toList(),
                    ),
                  ],
                ),
              ),

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextButton.icon(
                      onPressed: () => context.push(RouteNames.reminders),
                      icon: const Icon(LucideIcons.bell, size: 16),
                      label: const Text(
                        'Set a reminder',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: TextButton.icon(
                      onPressed: () => context.push(RouteNames.progress),
                      icon: const Icon(LucideIcons.camera, size: 16),
                      label: const Text(
                        'View progress journal',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),

              careSectionHeader(
                title: 'TODAY’S CARE STEPS',
                subtitle: 'Mark each step complete or skip it for today',
              ),

              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _showSymptomCheckIn(context),
                  icon: const Icon(LucideIcons.heartPulse, size: 16),
                  label: const Text('Report a symptom'),
                ),
              ),

              if (state.routineTasks.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 36,
                    horizontal: 20,
                  ),
                  margin: const EdgeInsets.only(top: 10, bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: AppColors.primary5,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.calendarClock,
                          size: 36,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Care Routine in Preparation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your assigned care steps will appear here when they are added to your care plan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.push(RouteNames.clinicAppointment),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                        ),
                        icon: const Icon(LucideIcons.calendar, size: 16),
                        label: const Text(
                          'Book Doctor Consultation',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...state.routineTasks.map((task) {
                  final isDone = task.isCompleted;
                  final isSkipped = task.isSkipped;

                  Color tagBg;
                  Color tagColor;
                  if (task.category.contains('Topical')) {
                    tagBg = AppColors.primary5;
                    tagColor = AppColors.primary;
                  } else if (task.category.contains('Supplement')) {
                    tagBg = const Color(0xFFECFDF5);
                    tagColor = const Color(0xFF059669);
                  } else {
                    tagBg = const Color(0xFFFFF7ED);
                    tagColor = const Color(0xFFEA580C);
                  }

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDone ? const Color(0xFFFAFAFA) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDone
                            ? const Color(0xFF10B981).withValues(alpha: 0.3)
                            : AppColors.border,
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDone
                              ? Colors.transparent
                              : AppColors.primary.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.read<CareCubit>().toggleRoutineTask(task.id);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 20,
                              height: 20,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDone
                                    ? const Color(0xFF10B981)
                                    : Colors.white,
                                border: Border.all(
                                  color: isDone
                                      ? const Color(0xFF10B981)
                                      : AppColors.border,
                                  width: 2,
                                ),
                              ),
                              child: isDone
                                  ? const Icon(
                                      LucideIcons.check,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: tagBg,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          task.category,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: tagColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '· ${task.timeOfDay}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    task.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isDone
                                          ? AppColors.textSecondary
                                          : AppColors.primaryDark,
                                      decoration: isDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    task.subtitle,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondaryDark,
                                      height: 1.35,
                                    ),
                                  ),
                                  if (isSkipped) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      task.skipReason.isEmpty
                                          ? 'Skipped today'
                                          : 'Skipped today · ${task.skipReason}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Care step options',
                              onSelected: (action) {
                                if (action == 'skip') {
                                  _showSkipReasonDialog(context, task.id);
                                } else if (action == 'undo_skip') {
                                  context.read<CareCubit>().toggleRoutineTask(
                                    task.id,
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                if (!isSkipped)
                                  const PopupMenuItem(
                                    value: 'skip',
                                    child: Text('Skip for today'),
                                  )
                                else
                                  const PopupMenuItem(
                                    value: 'undo_skip',
                                    child: Text('Mark complete'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () => AddRoutineTaskBottomSheet.show(context),
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Add Another Care Step'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _showSkipReasonDialog(BuildContext context, String taskId) async {
  var note = '';
  final reason = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Skip this step today?'),
      content: TextField(
        maxLength: 240,
        maxLines: 2,
        onChanged: (value) => note = value,
        decoration: const InputDecoration(
          hintText: 'Why? (optional)',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, note.trim()),
          child: const Text('Skip today'),
        ),
      ],
    ),
  );
  if (reason == null || !context.mounted) return;
  await context.read<CareCubit>().skipRoutineTask(taskId, reason: reason);
}

Future<void> _showSymptomCheckIn(BuildContext context) async {
  const options = <String, String>{
    'itching': 'Itching',
    'pain': 'Pain',
    'burning': 'Burning',
    'redness': 'Redness',
    'sores': 'Sores or open areas',
    'increased_shedding': 'Increased shedding',
    'other': 'Other',
  };
  final selected = <String>{};
  var note = '';
  var severity = 'mild';
  final result =
      await showDialog<({List<String> symptoms, String severity, String note})>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Symptom check-in'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Select what you are experiencing.'),
                    ),
                    const SizedBox(height: 8),
                    ...options.entries.map(
                      (item) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.value),
                        value: selected.contains(item.key),
                        onChanged: (checked) => setDialogState(() {
                          if (checked == true) {
                            selected.add(item.key);
                          } else {
                            selected.remove(item.key);
                          }
                        }),
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: severity,
                      decoration: const InputDecoration(labelText: 'Severity'),
                      items: const [
                        DropdownMenuItem(value: 'mild', child: Text('Mild')),
                        DropdownMenuItem(
                          value: 'moderate',
                          child: Text('Moderate'),
                        ),
                        DropdownMenuItem(
                          value: 'severe',
                          child: Text('Severe'),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => severity = value ?? 'mild'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      maxLength: 1000,
                      maxLines: 3,
                      onChanged: (value) => note = value,
                      decoration: const InputDecoration(
                        labelText: 'Anything else? (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(dialogContext, (
                        symptoms: selected.toList(),
                        severity: severity,
                        note: note.trim(),
                      )),
                child: const Text('Save check-in'),
              ),
            ],
          ),
        ),
      );
  if (result == null || !context.mounted) return;
  final needsClinic = await context.read<CareCubit>().logSymptoms(
    symptoms: result.symptoms,
    severity: result.severity,
    note: result.note,
  );
  if (!context.mounted) return;
  if (needsClinic) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Please contact the clinic'),
        content: const Text(
          'These symptoms should be reviewed by a clinician. We have not made a diagnosis or changed your care plan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              WhatsAppLauncher.launch(
                message:
                    'Hello, I am reporting symptoms from my Dr. Hair daily routine check-in and would like clinical guidance.',
              );
            },
            child: const Text('Contact clinic'),
          ),
        ],
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.read<CareCubit>().state.isCareEventSyncPending
              ? 'Saved on this device. It will sync when you are online.'
              : 'Symptom check-in saved.',
        ),
      ),
    );
  }
}
