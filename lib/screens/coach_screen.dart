import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/chat_message.dart';
import '../models/daily_data.dart';
import '../models/reflection.dart';
import '../models/sfx_type.dart';
import '../services/ai_service.dart';
import '../services/badge_service.dart';
import '../services/chat_repository.dart';
import '../services/haptic_service.dart';
import '../services/reflection_repository.dart';
import '../services/sfx_service.dart';
import '../theme/app_theme.dart';
import '../widgets/badge_unlock_modal.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/loading_orb.dart';
import '../widgets/reflection_card.dart';
import '../widgets/responsive_container.dart';
import '../widgets/typing_indicator.dart';

enum _CoachTab { reflection, chat }

const List<String> _kChatStarters = [
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
            _segment("Tonight's reflection", _CoachTab.reflection),
            _segment('Chat', _CoachTab.chat),
          ],
        ),
      ),
    );
  }

  Widget _segment(String label, _CoachTab tab) {
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
              color: selected ? Colors.white : AppColors.inkDim,
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
  List<ChatMessage> _messages = const [];

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
    });

    try {
      await widget.repo.addMessage(role: 'user', content: trimmed);
      final history = await widget.repo.getCurrentConversation();
      final context = await DailyData.gather();
      final reply = await widget.ai.chat(history, context: context);
      await widget.repo.addMessage(role: 'assistant', content: reply);
      SfxService().fire(SfxType.aiMessage);
      HapticService().light();
    } on AiException catch (e) {
      SfxService().fire(SfxType.errorGentle);
      setState(() => _sendError = e.message);
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
                          return ChatBubble(message: list[i]);
                        },
                      ),
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
