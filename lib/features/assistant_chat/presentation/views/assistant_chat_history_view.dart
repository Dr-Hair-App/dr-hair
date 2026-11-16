import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/viewmodels/auth_cubit.dart';
import '../../data/assistant_chat_history_store.dart';
import '../../domain/assistant_chat_thread.dart';
import 'assistant_chat_view.dart';

class AssistantChatHistoryView extends StatefulWidget {
  const AssistantChatHistoryView({super.key});

  @override
  State<AssistantChatHistoryView> createState() =>
      _AssistantChatHistoryViewState();
}

class _AssistantChatHistoryViewState extends State<AssistantChatHistoryView> {
  late AssistantChatHistoryStore _store;
  List<AssistantChatThread> _threads = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<AuthCubit>().state.user;
    _store = AssistantChatHistoryStore(
      patientId: user?.patientId ?? user?.id ?? '',
    );
    _threads = _store.load();
  }

  Future<void> _openChat({String? threadId, bool startNew = false}) async {
    await showAssistantChatSheet(
      context,
      threadId: threadId,
      startNew: startNew,
    );
    if (mounted) setState(() => _threads = _store.load());
  }

  String _dateLabel(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final local = date.toLocal();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return 'Today · ${TimeOfDay.fromDateTime(local).format(context)}';
    }
    return '${MaterialLocalizations.of(context).formatMediumDate(local)} · ${TimeOfDay.fromDateTime(local).format(context)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: context.pop,
          icon: const Icon(LucideIcons.arrowLeft),
        ),
        title: const Text(
          'Previous AI chats',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: _threads.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: _threads.length,
              separatorBuilder: (_, _) => const SizedBox(height: 9),
              itemBuilder: (context, index) {
                final thread = _threads[index];
                final messageCount = thread.messages
                    .where((message) => message.isUser)
                    .length;
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () => _openChat(threadId: thread.id),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary5,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              LucideIcons.messageCircle,
                              color: AppColors.primary,
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  thread.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.primaryDark,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_dateLabel(context, thread.updatedAt)} · $messageCount ${messageCount == 1 ? 'question' : 'questions'}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            LucideIcons.chevronRight,
                            size: 17,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: _threads.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openChat(startNew: true),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('New chat'),
            ),
    );
  }

  Widget _buildEmptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.primary5,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.messagesSquare,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No previous chats yet',
            style: TextStyle(
              color: AppColors.primaryDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Your conversations will appear here after the assistant sends a reply.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => _openChat(startNew: true),
            icon: const Icon(LucideIcons.messageCircle, size: 17),
            label: const Text('Start a chat'),
          ),
        ],
      ),
    ),
  );
}
