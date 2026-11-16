import 'dart:async';
import 'dart:convert';

import 'package:dr_hair/core/widgets/app_button.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/app_destination.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/storage/app_local_cache.dart';
import '../../../auth/presentation/viewmodels/auth_cubit.dart';
import '../../../auth/presentation/viewmodels/auth_state.dart';
import '../../../care/domain/models/care_models.dart';
import '../../../care/presentation/viewmodels/care_cubit.dart';
import '../../data/assistant_chat_api.dart';
import '../../data/assistant_chat_history_store.dart';
import '../../domain/assistant_chat_message.dart';
import '../../domain/assistant_chat_thread.dart';

Future<void> showAssistantChatSheet(
  BuildContext context, {
  AssistantChatClient? client,
  String? threadId,
  bool startNew = false,
}) {
  if (client == null) {
    final authState = context.read<AuthCubit?>()?.state;
    final isAuthenticated =
        authState?.isAuthenticated == true ||
        (authState?.status == AuthStatus.loading && authState?.user != null);
    if (!isAuthenticated) {
      String returnPath = RouteNames.mainShell;
      try {
        returnPath = GoRouterState.of(context).matchedLocation;
      } catch (_) {
        // Fall back to the home tab when invoked outside a GoRouter route.
      }
      context.go(
        '${RouteNames.signin}?redirect=${Uri.encodeComponent(returnPath)}',
      );
      return Future<void>.value();
    }
  }
  final mediaQuery = MediaQuery.of(context);
  final double topSpacing = mediaQuery.padding.top + 8.0;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.primaryDark.withValues(alpha: 0.42),
    builder: (context) => Padding(
      padding: EdgeInsets.only(top: topSpacing),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(
          color: Colors.white,
          child: AssistantChatView(
            client: client,
            threadId: threadId,
            startNew: startNew,
          ),
        ),
      ),
    ),
  );
}

class AssistantChatView extends StatefulWidget {
  const AssistantChatView({
    super.key,
    this.client,
    this.threadId,
    this.startNew = false,
  });

  final AssistantChatClient? client;
  final String? threadId;
  final bool startNew;

  @override
  State<AssistantChatView> createState() => _AssistantChatViewState();
}

class _AssistantChatViewState extends State<AssistantChatView> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final List<AssistantChatMessage> _messages = [];
  final StringBuffer _queuedStreamText = StringBuffer();
  late final AssistantChatClient _client = widget.client ?? AssistantChatApi();
  Timer? _streamFlushTimer;
  Timer? _retryCountdownTimer;
  StreamIterator<AssistantChatEvent>? _activeStream;
  bool _isStreaming = false;
  bool _isFocused = false;
  bool _stopRequested = false;
  bool _shouldFollowMessages = true;
  bool _showScrollToLatest = false;
  int _retrySeconds = 0;
  String? _errorMessage;
  String? _failedQuestion;

  String _preferredLanguage = 'English';
  bool _hasSelectedLanguage = false;
  late String _threadId;

  @override
  void initState() {
    super.initState();
    _threadId = widget.threadId ?? _newThreadId();
    _loadPersistedChatAndLanguage();
    _scrollController.addListener(_handleScrollChange);
    _focusNode.addListener(() {
      if (mounted) {
        setState(() => _isFocused = _focusNode.hasFocus);
        if (_focusNode.hasFocus) {
          Future.delayed(const Duration(milliseconds: 220), () {
            if (mounted) _scrollToBottom(force: true);
          });
        }
      }
    });
    _inputController.addListener(() {
      if (mounted) {
        setState(() {
          if (!_isStreaming &&
              _retrySeconds == 0 &&
              _inputController.text.isNotEmpty) {
            _errorMessage = null;
            _failedQuestion = null;
          }
        });
      }
    });
  }

  String _newThreadId() => DateTime.now().microsecondsSinceEpoch.toString();

  AssistantChatHistoryStore get _historyStore =>
      AssistantChatHistoryStore(patientId: _getPatientId());

  String _getPatientId() {
    try {
      final user = context.read<AuthCubit?>()?.state.user;
      return user?.patientId ?? user?.id ?? '';
    } catch (_) {
      return '';
    }
  }

  String _getCacheKey(String suffix) {
    try {
      final authState = context.read<AuthCubit?>()?.state;
      final patientId = authState?.user?.patientId ?? authState?.user?.id ?? '';
      return patientId.isNotEmpty
          ? AppLocalCache.patientKey(patientId, suffix)
          : suffix;
    } catch (_) {
      return suffix;
    }
  }

  void _loadPersistedChatAndLanguage() {
    try {
      final langKey = _getCacheKey('assistant_chat_preferred_lang_v1');
      final savedLang = AppLocalCache.instance.getString(langKey);
      if (savedLang != null && savedLang.isNotEmpty) {
        _preferredLanguage = savedLang;
        _hasSelectedLanguage = true;
      }

      final selectedThread = widget.threadId == null
          ? null
          : _historyStore.find(widget.threadId!);
      final loadedThread =
          selectedThread ??
          (widget.threadId == null && !widget.startNew
              ? _historyStore.load().firstOrNull
              : null);
      if (loadedThread != null && loadedThread.messages.isNotEmpty) {
        _threadId = loadedThread.id;
        _messages.addAll(loadedThread.messages);
        _scrollToBottom(animated: false);
      } else {
        // Migrate the previous single-conversation cache into the new thread
        // store. The history store excludes user-only and blank conversations.
        final legacyKey = _getCacheKey('assistant_chat_history_v1');
        final legacy = AppLocalCache.instance.getString(legacyKey);
        if (!widget.startNew && legacy != null && legacy.isNotEmpty) {
          final decoded = jsonDecode(legacy);
          if (decoded is List) {
            final loaded = decoded
                .whereType<Map>()
                .map(
                  (item) => AssistantChatMessage.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where((message) => message.content.trim().isNotEmpty)
                .toList();
            if (loaded.any((message) => !message.isUser)) {
              _messages.addAll(loaded);
              _saveChatHistory();
              _scrollToBottom(animated: false);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading assistant chat cache: $e');
    }
  }

  Future<void> _saveChatHistory() async {
    try {
      final nonEmptyMessages = _messages
          .where((message) => message.content.trim().isNotEmpty)
          .toList(growable: false);
      final firstQuestion = nonEmptyMessages.firstWhere(
        (message) => message.isUser,
        orElse: () => const AssistantChatMessage(role: 'user', content: ''),
      );
      final title = firstQuestion.content.trim().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      final thread = AssistantChatThread(
        id: _threadId,
        title: title.length > 54 ? '${title.substring(0, 51)}…' : title,
        updatedAt: DateTime.now(),
        messages: nonEmptyMessages,
      );
      await _historyStore.save(thread);
    } catch (e) {
      debugPrint('Error saving assistant chat history: $e');
    }
  }

  Future<void> _savePreferredLanguage(String lang) async {
    try {
      final langKey = _getCacheKey('assistant_chat_preferred_lang_v1');
      await AppLocalCache.instance.put(langKey, lang);
    } catch (e) {
      debugPrint('Error saving assistant chat language: $e');
    }
  }

  void _selectLanguage(String lang) {
    setState(() {
      _preferredLanguage = lang;
      _hasSelectedLanguage = true;
    });
    _savePreferredLanguage(lang);
  }

  @override
  void dispose() {
    _streamFlushTimer?.cancel();
    _retryCountdownTimer?.cancel();
    _activeStream?.cancel();
    _queuedStreamText.clear();
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send({String? suggestedText, bool retry = false}) async {
    if (_isStreaming) return;
    if (_retrySeconds > 0) return;
    final text = (suggestedText ?? _inputController.text).trim();
    if (text.isEmpty) return;
    if (text.length > 1200) {
      setState(
        () => _errorMessage = 'Keep your message under 1,200 characters.',
      );
      return;
    }

    if (!retry) {
      // A failed turn has no assistant response; remove that unanswered user
      // message so the next request still alternates roles for Gemini.
      if (_messages.isNotEmpty && _messages.last.role == 'user') {
        _messages.removeLast();
      }
      _messages.add(AssistantChatMessage(role: 'user', content: text));
      _inputController.clear();
    } else if (_messages.isNotEmpty && _messages.last.role == 'assistant') {
      // A stopped partial answer is replaced when the user retries.
      _messages.removeLast();
    }
    final assistantReplyIndex = _messages.length;
    _queuedStreamText.clear();
    _messages.add(const AssistantChatMessage(role: 'assistant', content: ''));
    setState(() {
      _isStreaming = true;
      _stopRequested = false;
      _errorMessage = null;
      _failedQuestion = null;
      _shouldFollowMessages = true;
      _showScrollToLatest = false;
    });
    _scrollToBottom(force: true);

    final conversation = _messages
        .where((message) => message.content.isNotEmpty)
        .toList(growable: false);
    final rawSlice = conversation.length > 11
        ? conversation.sublist(conversation.length - 11)
        : conversation;

    final requestMessages = <AssistantChatMessage>[];
    for (int i = 0; i < rawSlice.length; i++) {
      final msg = rawSlice[i];
      if (i == rawSlice.length - 1 && msg.isUser) {
        String langPrefix = '';
        if (_preferredLanguage == 'Hindi') {
          langPrefix = '[Reply strictly in Hindi (हिंदी)] ';
        } else if (_preferredLanguage == 'Hinglish') {
          langPrefix = '[Reply strictly in Hinglish (Hindi written in Roman/English alphabet)] ';
        }
        requestMessages.add(
          AssistantChatMessage(
            role: 'user',
            content: '$langPrefix${msg.content}',
          ),
        );
      } else {
        requestMessages.add(msg);
      }
    }

    final streamIterator = StreamIterator<AssistantChatEvent>(
      _client.streamReply(requestMessages),
    );
    _activeStream = streamIterator;
    try {
      while (await streamIterator.moveNext()) {
        if (!mounted) return;
        final event = streamIterator.current;
        if (event is AssistantChatTextDelta) {
          _queuedStreamText.write(event.text);
        } else if (event is AssistantChatActionProposal) {
          _streamFlushTimer?.cancel();
          _streamFlushTimer = null;
          _flushStreamedText(assistantReplyIndex);
          final current = _messages[assistantReplyIndex];
          final actionMessage =
              event.action['message']?.toString().trim() ?? '';
          _messages[assistantReplyIndex] = AssistantChatMessage(
            role: 'assistant',
            content: current.content.isEmpty
                ? (actionMessage.isEmpty
                      ? 'I can help with that in the app.'
                      : actionMessage)
                : current.content,
            action: event.action,
          );
          setState(() {});
        }
        _streamFlushTimer ??= Timer(
          const Duration(milliseconds: 36),
          () => _flushStreamedText(assistantReplyIndex),
        );
      }
      _streamFlushTimer?.cancel();
      _streamFlushTimer = null;
      _flushStreamedText(assistantReplyIndex);
      if (_stopRequested) {
        if (_messages[assistantReplyIndex].content.isEmpty) {
          _messages.removeAt(assistantReplyIndex);
        }
        setState(() {
          _errorMessage = 'Response stopped. Retry it or ask something else.';
          _failedQuestion = text;
        });
        _saveChatHistory();
        return;
      }
      if (_messages[assistantReplyIndex].content.isEmpty) {
        throw const AssistantChatException(
          'The assistant returned an empty reply. Please try again.',
        );
      }
      _saveChatHistory();
    } catch (error) {
      if (!mounted) return;
      _streamFlushTimer?.cancel();
      _streamFlushTimer = null;
      _queuedStreamText.clear();
      _messages.removeAt(assistantReplyIndex);
      if (!_stopRequested) {
        setState(() {
          _errorMessage = error is AssistantChatException
              ? error.message
              : 'The assistant is temporarily unavailable. Please try again.';
          _failedQuestion = text;
        });
        if (error is AssistantChatException && error.retryAfter != null) {
          _startRetryCountdown(error.retryAfter!);
        }
      }
    } finally {
      if (identical(_activeStream, streamIterator)) _activeStream = null;
      if (mounted) {
        setState(() => _isStreaming = false);
        _scrollToBottom();
      }
    }
  }

  void _flushStreamedText(int replyIndex) {
    _streamFlushTimer = null;
    if (!mounted || _queuedStreamText.isEmpty) return;
    final chunk = _queuedStreamText.toString();
    _queuedStreamText.clear();
    final current = _messages[replyIndex];
    _messages[replyIndex] = AssistantChatMessage(
      role: 'assistant',
      content: '${current.content}$chunk',
    );
    setState(() {});
    _scrollToBottom(animated: false);
  }

  void _scrollToBottom({bool animated = true, bool force = false}) {
    if (!_shouldFollowMessages && !force) {
      if (!_showScrollToLatest && mounted) {
        setState(() => _showScrollToLatest = true);
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final offset = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(offset);
      }
    });
  }

  void _handleScrollChange() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final nearBottom = position.maxScrollExtent - position.pixels < 88;
    _shouldFollowMessages = nearBottom;
    if (nearBottom && _showScrollToLatest) {
      setState(() => _showScrollToLatest = false);
    } else if (!nearBottom && !_showScrollToLatest) {
      setState(() => _showScrollToLatest = true);
    }
  }

  void _jumpToLatest() {
    _shouldFollowMessages = true;
    setState(() => _showScrollToLatest = false);
    _scrollToBottom(force: true);
  }

  void _stopStreaming() {
    if (!_isStreaming || _stopRequested) return;
    _stopRequested = true;
    _streamFlushTimer?.cancel();
    _streamFlushTimer = null;
    _activeStream?.cancel();
  }

  void _startRetryCountdown(Duration duration) {
    _retryCountdownTimer?.cancel();
    final seconds = duration.inSeconds.clamp(1, 60);
    setState(() => _retrySeconds = seconds);
    _retryCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _retrySeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _retrySeconds = 0);
        return;
      }
      setState(() => _retrySeconds -= 1);
    });
  }

  Future<void> _copyMessage(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Reply copied'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
  }

  void _regenerateLastReply() {
    if (_isStreaming || _messages.isEmpty) return;
    final lastAssistant = _messages.lastIndexWhere(
      (message) => !message.isUser,
    );
    if (lastAssistant <= 0 || !_messages[lastAssistant - 1].isUser) return;
    _send(suggestedText: _messages[lastAssistant - 1].content, retry: true);
  }

  Future<void> _confirmAssistantAction(Map<String, dynamic> action) async {
    final kind = action['kind']?.toString();
    if (kind == 'navigate') {
      final destination = AppDestination.screen(
        action['screen']?.toString() ?? '',
      );
      final location = destination.location;
      if (location == null || !AppDestination.isValidRoute(location)) return;
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.go(location);
      return;
    }

    final careCubit = context.read<CareCubit?>();
    if (careCubit == null) {
      _showActionResult('Care tools are unavailable right now.');
      return;
    }
    final token = context.read<AuthCubit?>()?.state.sessionToken;

    try {
      if (kind == 'routine') {
        final title = action['routineTitle']?.toString().trim() ?? '';
        final operation = action['operation']?.toString() ?? 'add';
        if (title.isEmpty || title.length > 80) return;
        if (operation == 'remove') {
          final matches = careCubit.state.routineTasks.where(
            (task) =>
                task.createdBy == 'patient' &&
                task.title.toLowerCase() == title.toLowerCase(),
          );
          if (matches.isEmpty) {
            _showActionResult('That routine step is no longer in your plan.');
            return;
          }
          await careCubit.removeRoutineTask(matches.first, sessionToken: token);
        } else {
          await careCubit.addCustomRoutineTask(
            title: title,
            subtitle: action['routineDetail']?.toString() ?? '',
            category: action['routineCategory']?.toString() ?? 'Lifestyle',
            timeOfDay: action['routineTime']?.toString() ?? 'Daily',
            sessionToken: token,
          );
        }
        _completeAction(
          action,
          operation == 'remove'
              ? 'Routine step removed.'
              : 'Routine step added.',
        );
        return;
      }

      if (kind == 'diet_plan') {
        final rawMeals = action['meals'];
        if (rawMeals is! List || rawMeals.isEmpty || rawMeals.length > 12) {
          return;
        }
        final meals = rawMeals
            .whereType<Map>()
            .map(
              (meal) => DietMeal(
                type: meal['type']?.toString() ?? 'Meal',
                name: meal['name']?.toString() ?? '',
                nutrients: meal['nutrients']?.toString() ?? '',
                benefit: meal['benefit']?.toString() ?? '',
              ),
            )
            .where((meal) => meal.name.trim().isNotEmpty)
            .toList(growable: false);
        final saved = await careCubit.saveAssistantDietPlan(
          title: action['planTitle']?.toString() ?? 'My meal plan',
          meals: meals,
        );
        if (!saved) return;
        _completeAction(action, 'Meal plan saved in your Nutrition guide.');
        return;
      }

      if (kind == 'reminder') {
        final title = action['reminderTitle']?.toString().trim() ?? '';
        final time = action['reminderTime']?.toString() ?? '';
        final parsedTime = _parseReminderTime(time);
        final rawDays = action['repeatDays'];
        final days = rawDays is List
            ? (rawDays
                  .map((day) => int.tryParse(day.toString()) ?? 0)
                  .where((day) => day >= 1 && day <= 7)
                  .toSet()
                  .toList()
                ..sort())
            : <int>[];
        if (title.isEmpty ||
            title.length > 80 ||
            parsedTime == null ||
            days.isEmpty) {
          return;
        }
        final saved = await careCubit.saveReminder(
          CareReminder(
            id: 'assistant_${DateTime.now().millisecondsSinceEpoch}',
            title: title,
            subtitle: action['reminderDetail']?.toString() ?? '',
            time: parsedTime,
            frequency: days.length == 7 ? 'Daily' : 'Custom',
            treatmentType: action['reminderType']?.toString() ?? 'Lifestyle',
            repeatDays: days,
          ),
          sessionToken: token,
        );
        if (!saved) return;
        _completeAction(action, 'Reminder added to Care reminders.');
      }
    } catch (_) {
      _showActionResult(
        'Could not save this change. Check your connection and try again.',
      );
    }
  }

  TimeOfDay? _parseReminderTime(String value) {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  void _completeAction(Map<String, dynamic> action, String message) {
    final index = _messages.lastIndexWhere(
      (item) => identical(item.action, action),
    );
    if (index >= 0) {
      final current = _messages[index];
      _messages[index] = AssistantChatMessage(
        role: current.role,
        content: current.content,
        action: {...action, 'completed': true},
      );
      setState(() {});
      _saveChatHistory();
    }
    _showActionResult(message);
  }

  void _showActionResult(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _actionLabel(Map<String, dynamic> action) {
    switch (action['kind']) {
      case 'navigate':
        return 'Open ${_screenLabel(action['screen']?.toString() ?? '')}';
      case 'routine':
        return action['operation'] == 'remove'
            ? 'Remove routine step'
            : 'Add to routine';
      case 'diet_plan':
        return 'Save meal plan';
      case 'reminder':
        return 'Create reminder';
      default:
        return 'Continue';
    }
  }

  bool _isSupportedAction(Map<String, dynamic>? action) {
    if (action == null) return false;
    switch (action['kind']) {
      case 'navigate':
        final path = AppDestination.screen(action['screen']?.toString() ?? '')
            .location;
        return AppDestination.isValidRoute(path);
      case 'routine':
        final title = action['routineTitle']?.toString().trim() ?? '';
        final operation = action['operation']?.toString() ?? 'add';
        return title.isNotEmpty &&
            title.length <= 80 &&
            const {'add', 'remove'}.contains(operation);
      case 'diet_plan':
        final meals = action['meals'];
        return (action['planTitle']?.toString().trim().isNotEmpty ?? false) &&
            meals is List &&
            meals.isNotEmpty &&
            meals.length <= 12;
      case 'reminder':
        final days = action['repeatDays'];
        return (action['reminderTitle']?.toString().trim().isNotEmpty ??
                false) &&
            _parseReminderTime(action['reminderTime']?.toString() ?? '') !=
                null &&
            days is List &&
            days.isNotEmpty &&
            days.every((day) {
              final value = int.tryParse(day.toString());
              return value != null && value >= 1 && value <= 7;
            });
      default:
        return false;
    }
  }

  String _screenLabel(String screen) => switch (screen) {
    'settings' => 'Settings',
    'assessment' => 'Assessment',
    'assessment_result' => 'Assessment results',
    'profile' => 'Profile',
    'routine' => 'Daily routine',
    'diet_plan' => 'Nutrition guide',
    'reminders' => 'Care reminders',
    'appointments' => 'Appointments',
    'orders' => 'Orders',
    'order_tracking' => 'Order tracking',
    'products' => 'Products',
    'cart' => 'Cart',
    'notifications' => 'Notifications',
    'videos' => 'Videos',
    'reviews' => 'Reviews',
    'assistant_history' => 'Previous chats',
    _ => 'Home',
  };

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final compactLayout =
        keyboardOpen || MediaQuery.sizeOf(context).width < 360;
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(compact: compactLayout),
            if (_messages.isEmpty)
              AnimatedSize(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: keyboardOpen
                    ? _buildCompactDisclosure()
                    : _buildDisclosure(),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 210),
                reverseDuration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 160),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.018),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: _messages.isEmpty
                    ? KeyedSubtree(
                        key: const ValueKey('assistant-welcome'),
                        child: _buildWelcome(),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('assistant-conversation'),
                        child: _buildMessages(reduceMotion: reduceMotion),
                      ),
              ),
            ),
            AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              transitionBuilder: (child, animation) => SizeTransition(
                sizeFactor: animation,
                alignment: Alignment.bottomCenter,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: _errorMessage == null
                  ? const SizedBox.shrink(key: ValueKey('no-chat-error'))
                  : _buildErrorBanner(key: const ValueKey('chat-error')),
            ),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({required bool compact}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Colors.white,
            Colors.white.withValues(alpha: 0.85),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.65, 0.88, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: AppColors.neutral300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 14, 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary5,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/images/WhiteLogo.png',
                    width: 24,
                    height: 28,
                    fit: BoxFit.contain,
                    semanticLabel: 'Dr. Hair logo',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Dr. Hair Assistant',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.primaryDark,
                                fontSize: compact ? 15 : 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      if (!compact) ...[
                        const SizedBox(height: 2),
                        const Text(
                          'Active AI · Care Guidance',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                InkWell(
                  onTap: _showLanguageSelectionSheet,
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary5,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _languageBadgeText(_preferredLanguage),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          LucideIcons.chevronDown,
                          size: 12,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildDisclosure() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFD8E8FB)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.shieldCheck, color: AppColors.primary, size: 15),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Chats stay on this device. Messages and relevant profile/care context go to Google Gemini; phone, email and scalp photos are not shared. Guidance is not a diagnosis or prescription.',
              style: TextStyle(
                color: AppColors.secondaryDark,
                fontSize: 10.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDisclosure() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(LucideIcons.shieldCheck, color: AppColors.primary, size: 14),
          SizedBox(width: 7),
          Expanded(
            child: Text(
              'Chat stays on this device · relevant care context goes to Gemini · not medical advice.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.secondaryDark,
                fontSize: 10,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _languageBadgeText(String lang) {
    switch (lang) {
      case 'Hindi':
        return '🇮🇳 हिंदी';
      case 'Hinglish':
        return '🇮🇳 Hinglish';
      case 'English':
      default:
        return '🇬🇧 English';
    }
  }

  void _showLanguageSelectionSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.neutral300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Preferred Language / भाषा चुनें',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select the language you want Dr. Hair Assistant to reply in:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              _buildLanguageListTile(
                sheetContext: sheetContext,
                code: 'Hindi',
                title: '🇮🇳 हिंदी (Hindi)',
                subtitle: 'Replies in clear Devanagari Hindi',
              ),
              _buildLanguageListTile(
                sheetContext: sheetContext,
                code: 'English',
                title: '🇬🇧 English',
                subtitle: 'Standard medical guidance in English',
              ),
              _buildLanguageListTile(
                sheetContext: sheetContext,
                code: 'Hinglish',
                title: '🇮🇳 Hinglish',
                subtitle: 'Hindi conversation in Roman/English alphabet',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageListTile({
    required BuildContext sheetContext,
    required String code,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _preferredLanguage == code;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary5 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        onTap: () {
          Navigator.of(sheetContext).pop();
          _selectLanguage(code);
        },
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? AppColors.primaryDark : AppColors.secondaryDark,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        trailing: isSelected
            ? const Icon(LucideIcons.check, color: AppColors.primary, size: 20)
            : null,
      ),
    );
  }

  Widget _buildLanguageSelectorBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _hasSelectedLanguage
              ? AppColors.border
              : AppColors.primary.withValues(alpha: 0.4),
          width: _hasSelectedLanguage ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _hasSelectedLanguage
                ? Colors.black.withValues(alpha: 0.02)
                : AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primary5,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.languages,
                  size: 15,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preferred Language / पसंदीदा भाषा',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Text(
                      'Select communication language',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildLangChip(
                  code: 'Hindi',
                  label: '🇮🇳 हिंदी',
                  isSelected: _preferredLanguage == 'Hindi',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildLangChip(
                  code: 'English',
                  label: '🇬🇧 English',
                  isSelected: _preferredLanguage == 'English',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildLangChip(
                  code: 'Hinglish',
                  label: '🇮🇳 Hinglish',
                  isSelected: _preferredLanguage == 'Hinglish',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLangChip({
    required String code,
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => _selectLanguage(code),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.primaryDark,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  List<String> _getPrompts() {
    switch (_preferredLanguage) {
      case 'Hindi':
        return const [
          'सूखी खोपड़ी (dry scalp) और डैंड्रफ के क्या कारण हैं?',
          'बाल झड़ने पर डॉक्टर से कब संपर्क करना चाहिए?',
          'बालों की देखभाल का आसान दैनिक रूटीन बताएं',
        ];
      case 'Hinglish':
        return const [
          'Scalp dryness aur dandruff ka kya reason hota hai?',
          'Hair fall hone par doctor se kab consult karein?',
          'Daily hair care routine ka easy plan batayein',
        ];
      case 'English':
      default:
        return const [
          'What can cause dry scalp?',
          'When should I ask a doctor about hair fall?',
          'Share a simple hair care routine',
        ];
    }
  }

  String _getComposerHint() {
    switch (_preferredLanguage) {
      case 'Hindi':
        return 'बालों या स्कैल्प के बारे में पूछें…';
      case 'Hinglish':
        return 'Hair ya scalp care ke bare me puchhein…';
      case 'English':
      default:
        return 'Ask about hair or scalp care…';
    }
  }

  Widget _buildWelcome() {
    final prompts = _getPrompts();
    final isHindi = _preferredLanguage == 'Hindi';
    final isHinglish = _preferredLanguage == 'Hinglish';

    final welcomeHeading = isHindi
        ? 'मैं आपके बालों और स्कैल्प की क्या मदद कर सकता हूँ?'
        : isHinglish
        ? 'Main aapke hair aur scalp care me kaise help kar sakta hu?'
        : 'How can I help with your hair or scalp?';

    final welcomeSubheading = isHindi
        ? 'अपने शब्दों में कोई भी सवाल पूछें। असिस्टेंट सामान्य देखभाल की जानकारी साझा कर सकता है।'
        : isHinglish
        ? 'Apne words me question puchhein. Assistant general care guidance provide karega.'
        : 'Ask a question in your own words. The assistant can share general care information and help you decide when to contact a clinician.';

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      children: [
        _buildLanguageSelectorBar(),
        const SizedBox(height: 15),
        Center(
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary5,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              LucideIcons.sparkles,
              color: AppColors.primary,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          welcomeHeading,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          welcomeSubheading,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 22),
        ...prompts.map(
          (prompt) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppButton(
              height: 45,
              onPressed: _isStreaming
                  ? null
                  : () => _send(suggestedText: prompt),

              foregroundColor: AppColors.primary,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),

              child: Center(
                child: Text(
                  textAlign: TextAlign.center,
                  prompt,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessages({required bool reduceMotion}) {
    final lastAssistantIndex = _messages.lastIndexWhere(
      (message) => !message.isUser,
    );
    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 66),
          itemCount: _messages.length,
          itemBuilder: (context, index) {
            final message = _messages[index];
            return TweenAnimationBuilder<double>(
              key: ValueKey('assistant-message-$index-${message.role}'),
              tween: Tween<double>(begin: 0, end: 1),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 9 * (1 - value)),
                  child: child,
                ),
              ),
              child: _MessageBubble(
                message: message,
                isStreaming: _isStreaming && index == _messages.length - 1,
                reduceMotion: reduceMotion,
                canRegenerate: index == lastAssistantIndex && !_isStreaming,
                onCopy: () => _copyMessage(message.content),
                onRegenerate: _regenerateLastReply,
                action: _isSupportedAction(message.action)
                    ? message.action
                    : null,
                actionLabel: message.action == null
                    ? ''
                    : _actionLabel(message.action!),
                onAction: message.action == null
                    ? null
                    : () => _confirmAssistantAction(message.action!),
              ),
            );
          },
        ),
        Positioned(
          right: 18,
          bottom: 12,
          child: IgnorePointer(
            ignoring: !_showScrollToLatest,
            child: AnimatedSlide(
              offset: _showScrollToLatest ? Offset.zero : const Offset(0, .4),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              child: AnimatedOpacity(
                opacity: _showScrollToLatest ? 1 : 0,
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 160),
                child: Material(
                  color: Colors.white,
                  elevation: 4,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    onTap: _jumpToLatest,
                    borderRadius: BorderRadius.circular(22),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 9,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.arrowDown,
                            size: 15,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Latest reply',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner({Key? key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Color(0xFF9A3412), fontSize: 12),
            ),
          ),
          if (_failedQuestion != null)
            TextButton.icon(
              onPressed: _isStreaming || _retrySeconds > 0
                  ? null
                  : () => _send(suggestedText: _failedQuestion, retry: true),
              icon: const Icon(LucideIcons.rotateCcw, size: 14),
              label: Text(
                _retrySeconds > 0 ? 'Try in ${_retrySeconds}s' : 'Retry',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    final messageLength = _inputController.text.length;
    final hasText = _inputController.text.trim().isNotEmpty;
    final double bottomPadding = viewInsetsBottom > 0
        ? 10.0
        : (safeBottom > 0 ? safeBottom + 4.0 : 12.0);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.88),
            Colors.white,
          ],
          stops: const [0.0, 0.35, 0.75],
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding + 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (messageLength >= 1000)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, right: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$messageLength / 1200',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: messageLength >= 1150
                        ? AppColors.danger
                        : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: _isFocused ? AppColors.primary : const Color(0xFFE2E8F0),
                width: _isFocused ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isFocused
                      ? AppColors.primary.withValues(alpha: 0.14)
                      : Colors.black.withValues(alpha: 0.07),
                  blurRadius: _isFocused ? 16 : 10,
                  offset: const Offset(0, 4),
                  spreadRadius: _isFocused ? 1 : 0,
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 1200,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.primaryDark,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: _getComposerHint(),
                      hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                      counterText: '',
                      filled: false,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildSendButton(hasText: hasText),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton({required bool hasText}) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final canSend = hasText && !_isStreaming && _retrySeconds == 0;
    final tooltip = _isStreaming
        ? 'Stop response'
        : _retrySeconds > 0
        ? 'Try again in $_retrySeconds seconds'
        : 'Send message';

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: _isStreaming || canSend,
        label: tooltip,
        child: AnimatedScale(
          scale: hasText || _isStreaming ? 1 : 0.92,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Material(
            color: _isStreaming
                ? const Color(0xFF64748B)
                : canSend
                ? AppColors.primary
                : AppColors.neutral300,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _isStreaming
                  ? _stopStreaming
                  : canSend
                  ? _send
                  : null,
              child: SizedBox(
                width: 42,
                height: 42,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 150),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Icon(
                      _isStreaming ? LucideIcons.square : LucideIcons.arrowUp,
                      key: ValueKey(
                        _isStreaming ? 'assistant-stop' : 'assistant-send',
                      ),
                      size: _isStreaming ? 15 : 21,
                      color: canSend || _isStreaming
                          ? Colors.white
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isStreaming,
    required this.reduceMotion,
    required this.canRegenerate,
    required this.onCopy,
    required this.onRegenerate,
    required this.action,
    required this.actionLabel,
    required this.onAction,
  });

  final AssistantChatMessage message;
  final bool isStreaming;
  final bool reduceMotion;
  final bool canRegenerate;
  final VoidCallback onCopy;
  final VoidCallback onRegenerate;
  final Map<String, dynamic>? action;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF0D9488)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isUser ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser ? null : Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: isUser
                  ? AppColors.primary.withValues(alpha: 0.16)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AnimatedSize(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: message.content.isEmpty && isStreaming
              ? SizedBox(
                  width: 48,
                  height: 18,
                  child: Center(
                    child: _TypingDotsIndicator(reduceMotion: reduceMotion),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SelectableText(
                      message.content,
                      style: TextStyle(
                        color: isUser ? Colors.white : AppColors.primaryDark,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    if (!isUser && action != null) ...[
                      const SizedBox(height: 10),
                      _AssistantActionCard(
                        action: action!,
                        label: actionLabel,
                        onPressed: onAction,
                      ),
                    ],
                    if (!isUser && message.content.isNotEmpty && !isStreaming)
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _BubbleAction(
                              icon: LucideIcons.copy,
                              label: 'Copy',
                              tooltip: 'Copy reply',
                              onPressed: onCopy,
                            ),
                            if (canRegenerate) ...[
                              const SizedBox(width: 4),
                              _BubbleAction(
                                icon: LucideIcons.rotateCcw,
                                label: 'Regenerate',
                                tooltip: 'Regenerate reply',
                                onPressed: onRegenerate,
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _AssistantActionCard extends StatelessWidget {
  const _AssistantActionCard({
    required this.action,
    required this.label,
    required this.onPressed,
  });

  final Map<String, dynamic> action;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final complete = action['completed'] == true;
    final kind = action['kind']?.toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE9E8)),
      ),
      child: Row(
        children: [
          Icon(
            switch (kind) {
              'navigate' => LucideIcons.arrowUpRight,
              'routine' => LucideIcons.listChecks,
              'diet_plan' => LucideIcons.salad,
              'reminder' => LucideIcons.bell,
              _ => LucideIcons.check,
            },
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              complete ? 'Saved' : label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          if (complete)
            const Icon(LucideIcons.check, size: 16, color: Color(0xFF059669))
          else
            TextButton(
              onPressed: onPressed,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 11),
                foregroundColor: Colors.white,
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                textStyle: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Confirm'),
            ),
        ],
      ),
    );
  }
}

class _BubbleAction extends StatelessWidget {
  const _BubbleAction({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TypingDotsIndicator extends StatefulWidget {
  const _TypingDotsIndicator({required this.reduceMotion});

  final bool reduceMotion;

  @override
  State<_TypingDotsIndicator> createState() => _TypingDotsIndicatorState();
}

class _TypingDotsIndicatorState extends State<_TypingDotsIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reduceMotion) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _TypingDotsIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion) {
      _controller.stop();
      _controller.value = 0;
    } else if (oldWidget.reduceMotion) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduceMotion) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 2.5, backgroundColor: AppColors.primary),
          SizedBox(width: 5),
          CircleAvatar(radius: 2.5, backgroundColor: AppColors.primary),
          SizedBox(width: 5),
          CircleAvatar(radius: 2.5, backgroundColor: AppColors.primary),
        ],
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.22;
            final progress = (_controller.value - delay) % 1.0;
            final scale =
                0.5 +
                0.5 * (1.0 - (progress - 0.5).abs() * 2.0).clamp(0.0, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(
                  alpha: (0.35 + 0.65 * scale).clamp(0.0, 1.0),
                ),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
