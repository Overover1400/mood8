import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/chat_message.dart';
import '../models/daily_data.dart';
import '../models/frequency.dart';
import '../models/habit_type.dart';
import '../models/reflection.dart';
import '../models/routine_category.dart';
import '../models/sfx_type.dart';
import '../services/ai_service.dart';
import '../services/badge_service.dart';
import '../services/chat_repository.dart';
import '../services/habit_repository.dart';
import '../services/haptic_service.dart';
import '../services/reflection_repository.dart';
import '../services/sfx_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import '../widgets/badge_unlock_modal.dart';
import '../widgets/chat_bubble.dart';
import 'paywall_screen.dart';
import '../widgets/loading_orb.dart';
import '../widgets/reflection_card.dart';
import '../widgets/responsive_container.dart';
import '../widgets/typing_indicator.dart';

enum _CoachTab { reflection, chat }

const List<String> _kChatStarters = [
  'Give me personalized habit packages',
  'Why was I tired today?',
  'What habit should I focus on?',
  'How am I doing this week?',
];

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final AiService _ai = AiService();
  final ReflectionRepository _reflections = ReflectionRepository();
  final ChatRepository _chats = ChatRepository();
  late final ValueListenable<Box<Reflection>> _reflectionListenable =
      _reflections.watchReflections();
  late final ValueListenable<Box<ChatMessage>> _chatListenable =
      _chats.watchMessages();

  _CoachTab _tab = _CoachTab.reflection;
  bool _generating = false;
  String? _generationError;

  @override
  void dispose() {
    _ai.close();
    super.dispose();
  }

  Future<void> _generateReflection({bool replace = false}) async {
    if (_generating) return;
    setState(() {
      _generating = true;
      _generationError = null;
    });
    try {
      final data = await DailyData.gather();
      final result = await _ai.getReflection(data);
      await _reflections.saveReflection(
        text: result.reflection,
        suggestion: result.suggestion,
        identityScores: result.identityScores,
      );
      SfxService().fire(SfxType.aiMessage);
      HapticService().medium();
      final awarded = await BadgeService().checkAndAwardBadges();
      if (awarded.isNotEmpty && mounted) {
        await showBadgeUnlockQueue(context, awarded);
      }
    } on AiException catch (e) {
      SfxService().fire(SfxType.errorGentle);
      setState(() => _generationError = e.message);
    } catch (e) {
      debugPrint('CoachScreen._generateReflection failed: $e');
      setState(() =>
          _generationError = 'Something went wrong. Try again in a moment.');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      body: Stack(
        children: [
          const _BackgroundGlow(),
          SafeArea(
            child: ResponsiveContainer(
              maxWidth: 560,
              child: Column(
                  children: [
                    const _CoachHeader(),
                    const SizedBox(height: 12),
                    _TabToggle(
                      value: _tab,
                      onChanged: (t) {
                        HapticService().selection();
                        setState(() => _tab = t);
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: _tab == _CoachTab.reflection
                            ? _ReflectionTab(
                                key: const ValueKey('reflection'),
                                listenable: _reflectionListenable,
                                repo: _reflections,
                                generating: _generating,
                                error: _generationError,
                                onGenerate: _generateReflection,
                                onRegenerate: _confirmRegenerate,
                              )
                            : _ChatTab(
                                key: const ValueKey('chat'),
                                listenable: _chatListenable,
                                repo: _chats,
                                ai: _ai,
                              ),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmRegenerate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrandColors.bgCard(context),
        title: Text(
          'Regenerate reflection?',
          style: TextStyle(color: BrandColors.ink(context)),
        ),
        content: Text(
          'This replaces today’s reflection with a fresh one.',
          style: TextStyle(color: BrandColors.inkSoft(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Regenerate',
              style: TextStyle(color: AppColors.pinkLight),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await _generateReflection(replace: true);
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.purple.withValues(alpha: 0.30),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -80,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.pink.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachHeader extends StatelessWidget {
  const _CoachHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.orbGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.pink.withValues(alpha: 0.40),
                  blurRadius: 14,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coach',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: 26,
                      ),
                ),
                Text(
                  'A quiet, honest second opinion.',
                  style: TextStyle(
                    color: BrandColors.inkDim(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabToggle extends StatelessWidget {
  const _TabToggle({required this.value, required this.onChanged});

  final _CoachTab value;
  final ValueChanged<_CoachTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: BrandColors.bgCard(context).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.purple.withValues(alpha: 0.20),
          ),
        ),
        child: Row(
          children: [
            _segment(context, "Tonight's reflection", _CoachTab.reflection),
            _segment(context, 'Chat', _CoachTab.chat),
          ],
        ),
      ),
    );
  }

  Widget _segment(BuildContext context, String label, _CoachTab tab) {
    final selected = tab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? AppColors.buttonGradient : null,
            borderRadius: BorderRadius.circular(22),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.pink.withValues(alpha: 0.35),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : BrandColors.inkDim(context),
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReflectionTab extends StatelessWidget {
  const _ReflectionTab({
    super.key,
    required this.listenable,
    required this.repo,
    required this.generating,
    required this.error,
    required this.onGenerate,
    required this.onRegenerate,
  });

  final ValueListenable<Box<Reflection>> listenable;
  final ReflectionRepository repo;
  final bool generating;
  final String? error;
  final VoidCallback onGenerate;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<Reflection>>(
      valueListenable: listenable,
      builder: (context, _, _) {
        final today = repo.getTodayReflection();
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (generating)
                _GeneratingPanel()
              else if (today != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ReflectionCard(reflection: today)
                        .animate()
                        .fadeIn(duration: 450.ms)
                        .slideY(
                            begin: 0.05,
                            end: 0,
                            curve: Curves.easeOut),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton.icon(
                        onPressed: onRegenerate,
                        icon: Icon(Icons.refresh_rounded,
                            color: AppColors.purpleLight, size: 16),
                        label: Text(
                          'Regenerate',
                          style: TextStyle(
                            color: AppColors.purpleLight,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                _EmptyReflection(onGenerate: onGenerate, error: error),
            ],
          ),
        );
      },
    );
  }
}

class _GeneratingPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const LoadingOrb(size: 130, label: 'Reading your day…'),
          const SizedBox(height: 20),
          Text(
            'Mood8 is connecting the dots from today’s\nmoods, energy, and routines.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: BrandColors.inkDim(context),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReflection extends StatelessWidget {
  const _EmptyReflection({required this.onGenerate, required this.error});

  final VoidCallback onGenerate;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.orbGradient,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Reflect on today',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Once a day, Mood8 reads your check-in, your routines, and your streak — and writes you a short, honest note about how the day went.',
            style: TextStyle(
              color: BrandColors.inkDim(context),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onGenerate,
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.buttonGradient,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.pink.withValues(alpha: 0.45),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Text(
                "Generate today's reflection",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFFF6B81), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error!,
                    style: const TextStyle(
                      color: Color(0xFFFF6B81),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatTab extends StatefulWidget {
  const _ChatTab({
    super.key,
    required this.listenable,
    required this.repo,
    required this.ai,
  });

  final ValueListenable<Box<ChatMessage>> listenable;
  final ChatRepository repo;
  final AiService ai;

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();

  bool _sending = false;
  String? _sendError;
  /// Latest proposed-habits block from the coach. Rendered as a
  /// gradient "Add these to my habits?" card pinned beneath the
  /// most recent assistant message. Cleared when the user accepts,
  /// declines, or sends another message.
  ProposedHabits? _pendingProposal;
  bool _addingProposal = false;
  List<ChatMessage> _messages = const [];

  /// Hive id of the single assistant message that should "type" out
  /// word-by-word right now. Set when a /coach/chat reply lands;
  /// cleared by the bubble itself via onRevealComplete so older
  /// messages render instantly when scrolled back into view.
  String? _revealingMessageId;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final initial = await widget.repo.getCurrentConversation();
    if (!mounted) return;
    setState(() => _messages = initial);
    _scrollToBottom();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return;
    _input.clear();
    setState(() {
      _sending = true;
      _sendError = null;
      // Sending a new turn invalidates the previous proposal — the
      // user either accepted, declined inline, or wants to keep
      // talking. Either way the old card shouldn't linger above the
      // new reply.
      _pendingProposal = null;
    });

    try {
      await widget.repo.addMessage(role: 'user', content: trimmed);
      final history = await widget.repo.getCurrentConversation();
      final context = await DailyData.gather();
      // Coach chat — same payload as /api/chat but routes through the
      // habit-design endpoint. May include a structured proposal.
      final result = await widget.ai.coachChat(history, context: context);
      final inserted = await widget.repo.addMessage(
          role: 'assistant', content: result.reply);
      // Mark THIS specific assistant message as the one that should
      // reveal word-by-word in its ChatBubble. Bubbles for older
      // messages keep their static text — only the one whose id
      // matches animates.
      _revealingMessageId = inserted.id;
      if (result.proposed != null && result.proposed!.habits.isNotEmpty) {
        _pendingProposal = result.proposed;
      }
      SfxService().fire(SfxType.aiMessage);
      HapticService().light();
    } on AiException catch (e) {
      SfxService().fire(SfxType.errorGentle);
      if (e.dailyLimitReached && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const PaywallScreen(
              contextNote: "You've hit today's free chat limit",
              highlightPlus: true,
            ),
          ),
        );
      } else {
        setState(() => _sendError = e.message);
      }
    } catch (e) {
      debugPrint('CoachScreen.chat send failed: $e');
      SfxService().fire(SfxType.errorGentle);
      setState(() => _sendError = "Couldn't send. Try again.");
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        final latest = await widget.repo.getCurrentConversation();
        if (mounted) {
          setState(() => _messages = latest);
          _scrollToBottom();
        }
      }
    }
  }

  Future<void> _acceptProposal() async {
    final proposal = _pendingProposal;
    if (proposal == null || _addingProposal) return;

    // Adding AI-managed habits is a Premium Plus feature. Free /
    // Premium users land on the paywall pre-flipped to the Plus
    // toggle; the chat itself stays available so they can keep
    // exploring the idea.
    if (!SubscriptionService().isPremiumPlus) {
      HapticService().light();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const PaywallScreen(
            contextNote: 'Adding AI-designed habits is a Premium Plus feature.',
            highlightPlus: true,
          ),
        ),
      );
      return;
    }

    setState(() => _addingProposal = true);
    try {
      final habits = HabitRepository();
      for (final p in proposal.habits) {
        final type = _mapType(p.type);
        final freq = _mapFrequency(p.frequency);
        await habits.addHabit(
          title: p.title,
          icon: p.icon ?? '✨',
          habitType: type,
          identity: 'Mood8 AI',
          category: RoutineCategory.mindful,
          frequency: freq,
          targetValue: type == HabitType.yesNo ? 1 : p.targetValue,
          targetUnit:
              type == HabitType.yesNo ? null : (p.targetUnit ?? ''),
          aiManaged: true,
          goalDescription: proposal.goal.isEmpty ? null : proposal.goal,
          programDurationDays: proposal.durationDays,
        );
      }
      HapticService().medium();
      SfxService().fire(SfxType.checkInSuccess);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${proposal.habits.length} '
            'habit${proposal.habits.length == 1 ? '' : 's'} added — '
            "they're on your Habits screen under Mood8 AI Habits.",
          ),
          backgroundColor: BrandColors.bgCard(context),
          duration: const Duration(seconds: 4),
        ),
      );
      setState(() => _pendingProposal = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't add: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _addingProposal = false);
    }
  }

  void _declineProposal() {
    HapticService().selection();
    setState(() => _pendingProposal = null);
  }

  HabitType _mapType(String? raw) {
    switch (raw) {
      case 'counter':
        return HabitType.counter;
      case 'duration':
        return HabitType.duration;
      case 'yes_no':
      default:
        return HabitType.yesNo;
    }
  }

  Frequency _mapFrequency(String? raw) {
    switch (raw) {
      case 'weekdays':
        return Frequency.weekdays;
      case 'weekends':
        return Frequency.weekends;
      case 'x_per_week':
        return Frequency.xPerWeek;
      case 'daily':
      default:
        return Frequency.daily;
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrandColors.bgCard(context),
        title: Text(
          'Clear chat?',
          style: TextStyle(color: BrandColors.ink(context)),
        ),
        content: Text(
          'This starts a fresh conversation. Past messages are removed.',
          style: TextStyle(color: BrandColors.inkSoft(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Clear',
              style: TextStyle(color: Color(0xFFFF6B81)),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.repo.clearCurrentConversation();
      setState(() => _messages = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<ChatMessage>>(
      valueListenable: widget.listenable,
      builder: (context, _, _) {
        final messages = widget.repo.getCurrentConversationSync();
        final list = messages.isEmpty ? _messages : messages;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Column(
            children: [
              Expanded(
                child: list.isEmpty
                    ? _ChatEmpty(onPick: _send)
                    : ListView.separated(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        cacheExtent: 500,
                        itemCount: list.length + (_sending ? 1 : 0),
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 14),
                        itemBuilder: (context, i) {
                          if (i >= list.length) {
                            return const TypingIndicator();
                          }
                          final msg = list[i];
                          final isLive =
                              msg.id == _revealingMessageId;
                          return ChatBubble(
                            // Keyed on the message id so swapping into
                            // a different position doesn't reuse the
                            // wrong _ChatBubbleState (which would
                            // either re-trigger the typing animation
                            // on an old message or hide a live reply).
                            key: ValueKey(msg.id),
                            message: msg,
                            reveal: isLive,
                            onRevealComplete: isLive
                                ? () {
                                    if (!mounted) return;
                                    if (_revealingMessageId == msg.id) {
                                      setState(
                                          () => _revealingMessageId = null);
                                    }
                                  }
                                : null,
                          );
                        },
                      ),
              ),
              if (_pendingProposal != null)
                _ProposalCard(
                  proposal: _pendingProposal!,
                  adding: _addingProposal,
                  onAccept: _acceptProposal,
                  onDecline: _declineProposal,
                ),
              if (_sendError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 2),
                  child: Text(
                    _sendError!,
                    style: const TextStyle(
                      color: Color(0xFFFF6B81),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              // One-tap shortcut into the habit-package design flow.
              // Visible mid-conversation too — most users won't think
              // to phrase the request themselves, and the empty-state
              // chips disappear once you've sent your first message.
              if (list.isNotEmpty && _pendingProposal == null && !_sending)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 2),
                  child: _QuickPromptChip(
                    label: 'Give me personalized habit packages',
                    onTap: () =>
                        _send('Give me personalized habit packages'),
                  ),
                ),
              const SizedBox(height: 8),
              _Composer(
                controller: _input,
                focus: _focus,
                sending: _sending,
                onSend: _send,
                onClear: list.isEmpty ? null : _clear,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _ChatEmpty extends StatelessWidget {
  const _ChatEmpty({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.orbGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.pink.withValues(alpha: 0.45),
                  blurRadius: 18,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            'Ask me anything about your day.',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'STARTERS',
            style: TextStyle(
              color: BrandColors.inkDim(context),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 10),
        for (final s in _kChatStarters) ...[
          _StarterChip(label: s, onTap: () => onPick(s)),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _StarterChip extends StatelessWidget {
  const _StarterChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: BrandColors.bgCard(context).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.purple.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded,
                color: AppColors.purpleLight, size: 14),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: BrandColors.inkSoft(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_rounded,
                color: BrandColors.inkDim(context), size: 16),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focus,
    required this.sending,
    required this.onSend,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool sending;
  final ValueChanged<String> onSend;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onClear != null)
          IconButton(
            onPressed: sending ? null : onClear,
            tooltip: 'Clear chat',
            icon: Icon(Icons.delete_outline_rounded,
                color: BrandColors.inkDim(context), size: 20),
          ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: BrandColors.bgCard(context).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.purple.withValues(alpha: 0.22),
              ),
            ),
            child: TextField(
              controller: controller,
              focusNode: focus,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: onSend,
              enabled: !sending,
              cursorColor: AppColors.pinkLight,
              style: TextStyle(color: BrandColors.ink(context), fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Message Mood8…',
                hintStyle: TextStyle(
                  color: BrandColors.inkDim(context).withValues(alpha: 0.8),
                ),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _SendButton(
          sending: sending,
          onTap: () => onSend(controller.text),
        ),
      ],
    );
  }
}

/// Small pill button rendered above the composer for one-tap entry
/// into a common Coach intent (currently: ask for personalized habit
/// packages). Hidden while the user is typing or has a proposal
/// already on screen.
class _QuickPromptChip extends StatelessWidget {
  const _QuickPromptChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () {
          HapticService().selection();
          onTap();
        },
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.purple.withValues(alpha: 0.22),
                AppColors.pink.withValues(alpha: 0.18),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.pinkLight.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: AppColors.pinkLight, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: BrandColors.ink(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.sending, required this.onTap});

  final bool sending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: sending ? null : onTap,
      child: Opacity(
        opacity: sending ? 0.6 : 1.0,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.buttonGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.pink.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            sending
                ? Icons.hourglass_top_rounded
                : Icons.arrow_upward_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

/// Gradient confirmation card the Coach renders below an assistant
/// turn when the model returned a structured habit proposal. Sits
/// between the chat list and the input. One tap to accept (creates
/// the habits as aiManaged=true, pulls the paywall for non-Plus
/// users), one tap to dismiss (drops the proposal — user can keep
/// chatting).
class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.adding,
    required this.onAccept,
    required this.onDecline,
  });

  final ProposedHabits proposal;
  final bool adding;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.purple.withValues(alpha: 0.32),
              AppColors.pink.withValues(alpha: 0.22),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.pinkLight.withValues(alpha: 0.45),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.pink.withValues(alpha: 0.24),
              blurRadius: 20,
              spreadRadius: -8,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.buttonGradient,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add these to your habits?',
                        style: GoogleFonts.bricolageGrotesque(
                          color: BrandColors.ink(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (proposal.goal.isNotEmpty)
                        Text(
                          'Goal · ${proposal.goal}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: BrandColors.inkSoft(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: BrandColors.bgDeep(context)
                        .withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.purple.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '${proposal.durationDays}d',
                    style: TextStyle(
                      color: BrandColors.inkSoft(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final h in proposal.habits) ...[
              _ProposalRow(habit: h),
              if (h != proposal.habits.last) const SizedBox(height: 6),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: adding ? null : onDecline,
                    child: Container(
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: BrandColors.bgDeep(context)
                            .withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppColors.purple.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        'Not now',
                        style: TextStyle(
                          color: BrandColors.inkSoft(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: adding ? null : onAccept,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: AppColors.buttonGradient,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.pink.withValues(alpha: 0.42),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        adding
                            ? 'Adding…'
                            : 'Add ${proposal.habits.length} '
                                'habit${proposal.habits.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProposalRow extends StatelessWidget {
  const _ProposalRow({required this.habit});
  final ProposedHabit habit;

  String _label() {
    final freq = switch (habit.frequency) {
      'weekdays' => 'Weekdays',
      'weekends' => 'Weekends',
      'x_per_week' => '${habit.targetValue ?? 1}× / week',
      _ => 'Daily',
    };
    if (habit.type == 'counter' && habit.targetValue != null) {
      return '$freq · ${habit.targetValue} ${habit.targetUnit ?? ''}'.trim();
    }
    if (habit.type == 'duration' && habit.targetValue != null) {
      return '$freq · ${habit.targetValue} '
          '${habit.targetUnit ?? 'minutes'}';
    }
    return freq;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: BrandColors.bgDeep(context).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          Text(habit.icon ?? '✨', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: BrandColors.ink(context),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _label(),
                  style: TextStyle(
                    color: BrandColors.inkDim(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
