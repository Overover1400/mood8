import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../main.dart' show AuthGate;
import '../../services/auth_service.dart';
import '../../services/haptic_service.dart';
import '../../services/subscription_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_container.dart';

/// Final confirmation screen for permanent account deletion. Full
/// screen instead of a dialog: the impact justifies giving the user
/// room to read what's about to be removed. The delete button stays
/// disabled until they type DELETE, matching the pattern GitHub +
/// Stripe use for irreversible ops.
///
/// On success we log the user out locally via AuthGate.resetAuth
/// (which wipes Hive + subscription cache + auth) and pop everything
/// above AuthGate — the rebuild lands them on WelcomeScreen. On
/// failure we surface the friendly error inline; nothing about the
/// local state has changed at that point.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _confirmController = TextEditingController();
  bool _submitting = false;
  String? _error;

  static const _confirmWord = 'DELETE';

  @override
  void initState() {
    super.initState();
    _confirmController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_submitting && _confirmController.text.trim() == _confirmWord;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    HapticService().heavy();
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await AuthService().deleteAccount();
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _submitting = false;
        _error = result.message;
      });
      return;
    }
    // Wipe local state + route back to WelcomeScreen. `resetAuth`
    // is the same helper the sign-out flow uses; it clears Hive,
    // the subscription cache, the timezone cache, and auth all in
    // one call, then pulses AuthGate to rebuild.
    await AuthGate.resetAuth();
    if (!mounted) return;
    // Pop everything above AuthGate; the rebuild picks up the
    // logged-out state and shows WelcomeScreen.
    Navigator.of(context).popUntil((r) => r.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your account and data have been deleted.'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: BrandColors.inkSoft(context),
            size: 18,
          ),
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Delete account',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 560,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                _HeroCard(),
                const SizedBox(height: 18),
                _DeletedList(),
                const SizedBox(height: 12),
                _PremiumWarning(),
                const SizedBox(height: 22),
                _ConfirmField(
                  controller: _confirmController,
                  confirmWord: _confirmWord,
                  enabled: !_submitting,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFF6B81),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _DestructiveButton(
                  label:
                      _submitting ? 'Deleting…' : 'Delete my account',
                  enabled: _canSubmit,
                  onTap: _submit,
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: BrandColors.inkSoft(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    'Also readable at mood8.app/delete-account',
                    style: TextStyle(
                      color: BrandColors.inkFaint(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B81).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFFF6B81).withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFFF6B81),
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This cannot be undone.',
                  style: GoogleFonts.bricolageGrotesque(
                    color: BrandColors.ink(context),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Deleting your account permanently removes everything "
            "stored on Mood8's servers. Your habits, streaks, "
            "check-ins, and history are unrecoverable after this "
            'request completes.',
            style: TextStyle(
              color: BrandColors.inkSoft(context),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// The list of things that get removed. Mirrors the copy on the
/// public /delete-account page so the app + web tell the same story.
class _DeletedList extends StatelessWidget {
  static const _items = [
    ('Account', 'Email, name, profile photo, bio'),
    ('Habits', 'Every habit and its completion history'),
    ('Check-ins', 'Mood, energy, and focus across your whole history'),
    ('Gratitude + intentions', 'Everything you wrote'),
    ('AI Coach', 'Full conversation history'),
    ('Challenges', 'Your participation, check-ins, badges, comments'),
    ('Reminders', 'Notification and reminder settings'),
    ('Synced data', 'Everything on the server that keeps devices in sync'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What's deleted",
            style: TextStyle(
              color: BrandColors.inkDim(context),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in _items) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.pink.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$1,
                          style: TextStyle(
                            color: BrandColors.ink(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.$2,
                          style: TextStyle(
                            color: BrandColors.inkSoft(context),
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Only rendered when the user has an active Premium subscription so
/// they know the recurring charge stops as part of the deletion. No
/// action needed on their side — the server calls Stripe's cancel API.
class _PremiumWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SubscriptionService(),
      builder: (context, _) {
        final sub = SubscriptionService();
        if (!sub.isPremium || sub.tier.isLifetime) {
          return const SizedBox.shrink();
        }
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.purple.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.purpleLight.withValues(alpha: 0.50),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                color: AppColors.pinkLight,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your Premium subscription will be canceled as '
                  'part of the deletion. No further charges.',
                  style: TextStyle(
                    color: BrandColors.inkSoft(context),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConfirmField extends StatelessWidget {
  const _ConfirmField({
    required this.controller,
    required this.confirmWord,
    required this.enabled,
  });

  final TextEditingController controller;
  final String confirmWord;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final matched = controller.text.trim() == confirmWord;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            style: TextStyle(
              color: BrandColors.inkSoft(context),
              fontSize: 13.5,
              height: 1.4,
            ),
            children: [
              const TextSpan(text: 'To confirm, type '),
              TextSpan(
                text: confirmWord,
                style: TextStyle(
                  color: BrandColors.ink(context),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const TextSpan(text: ' below.'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          enabled: enabled,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            // The confirm word is all caps; enforce that at the
            // formatter level so the user doesn't get stuck fighting
            // autocaps on some keyboards.
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
          ],
          style: TextStyle(
            color: BrandColors.ink(context),
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
          decoration: InputDecoration(
            hintText: confirmWord,
            hintStyle: TextStyle(
              color: BrandColors.inkFaint(context),
              letterSpacing: 1.2,
            ),
            filled: true,
            fillColor: BrandColors.bgCard(context).withValues(alpha: 0.7),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: matched
                    ? const Color(0xFFFF6B81)
                    : AppColors.purple.withValues(alpha: 0.25),
                width: matched ? 1.5 : 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: matched
                    ? const Color(0xFFFF6B81)
                    : AppColors.purple.withValues(alpha: 0.25),
                width: matched ? 1.5 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: matched
                    ? const Color(0xFFFF6B81)
                    : AppColors.purpleLight,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DestructiveButton extends StatelessWidget {
  const _DestructiveButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B81),
            borderRadius: BorderRadius.circular(28),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF6B81)
                          .withValues(alpha: 0.42),
                      blurRadius: 22,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.delete_forever_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.bricolageGrotesque(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
