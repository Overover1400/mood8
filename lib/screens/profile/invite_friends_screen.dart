import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/auth_service.dart';
import '../../services/haptic_service.dart';
import '../../services/referral_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_container.dart';
import '../auth/register_screen.dart';

/// Settings → Invite friends.
///
/// Shows the user's own code and link, what it has earned, and a field
/// to enter a friend's code. Guests are asked to create an account
/// first: only real accounts get a code, and rewards are paid only to
/// real accounts.
class InviteFriendsScreen extends StatefulWidget {
  const InviteFriendsScreen({super.key});

  @override
  State<InviteFriendsScreen> createState() => _InviteFriendsScreenState();
}

class _InviteFriendsScreenState extends State<InviteFriendsScreen> {
  ReferralInfo? _info;
  bool _loading = true;
  bool _applying = false;
  String? _codeMessage;
  bool _codeOk = false;
  final _codeCtrl = TextEditingController();

  bool get _isGuest => AuthService().currentUser?.isGuest ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final info = _isGuest ? null : await ReferralService().me();
    if (!mounted) return;
    setState(() {
      _info = info;
      _loading = false;
    });
  }

  Future<void> _share() async {
    final info = _info;
    if (info == null) return;
    HapticService().light();
    await Share.share(
      'I use Mood8 to build habits that stick. Join with my link and we '
      'both get ${info.rewardDays} days of Premium:\n${info.url}',
      subject: 'Join me on Mood8',
    );
  }

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    HapticService().selection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('$what copied'),
          duration: const Duration(milliseconds: 1200)),
    );
  }

  Future<void> _applyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty || _applying) return;
    setState(() {
      _applying = true;
      _codeMessage = null;
    });
    final r = await ReferralService().claim(code, source: 'manual');
    if (!mounted) return;
    setState(() {
      _applying = false;
      _codeOk = r.ok;
      _codeMessage = r.ok
          ? 'Code applied — you both get Premium days.'
          : (r.message ?? 'Couldn\'t use that code.');
    });
    if (r.ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: BrandColors.inkSoft(context), size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Invite friends',
            style: Theme.of(context).textTheme.headlineSmall),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 520,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _content(context),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final info = _info;
    if (info == null) return _unavailable(context);
    final ink = BrandColors.ink(context);
    final dim = BrandColors.inkDim(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Give ${info.rewardDays} days of Premium, get ${info.rewardDays}.',
          style: TextStyle(
              color: ink, fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'When a friend joins through your link and creates an account, '
          'you both get ${info.rewardDays} days of Premium. Up to '
          '${info.maxRewarded} friends.',
          style: TextStyle(color: dim, fontSize: 14, height: 1.45),
        ),
        const SizedBox(height: 20),
        _card(
          context,
          child: Column(
            children: [
              Text('YOUR CODE',
                  style: TextStyle(
                      color: dim,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5)),
              const SizedBox(height: 8),
              Text(info.code,
                  style: TextStyle(
                      color: ink,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copy(info.code, 'Code'),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy code'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copy(info.url, 'Link'),
                      icon: const Icon(Icons.link_rounded, size: 16),
                      label: const Text('Copy link'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Share invite'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _stat(context, '${info.invited}', 'Invited'),
            const SizedBox(width: 10),
            _stat(context, '${info.joined}', 'Joined'),
            const SizedBox(width: 10),
            _stat(context, '${info.daysEarned}', 'Days earned'),
          ],
        ),
        if (info.invitedBy == null) ...[
          const SizedBox(height: 24),
          Text('Have a friend\'s code?',
              style: TextStyle(
                  color: ink, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Works for the first few days after you sign up.',
              style: TextStyle(color: dim, fontSize: 12.5)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 12,
                  decoration: const InputDecoration(
                      hintText: 'Enter code', counterText: ''),
                  onSubmitted: (_) => _applyCode(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _applying ? null : _applyCode,
                child: _applying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Apply'),
              ),
            ],
          ),
          if (_codeMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_codeMessage!,
                  style: TextStyle(
                      color: _codeOk ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 13)),
            ),
        ] else ...[
          const SizedBox(height: 20),
          Text('You joined through ${info.invitedBy}.',
              style: TextStyle(color: dim, fontSize: 13)),
        ],
      ],
    );
  }

  Widget _unavailable(BuildContext context) {
    final ink = BrandColors.ink(context);
    final dim = BrandColors.inkDim(context);
    final guest = _isGuest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        Text(
          guest
              ? 'Create a free account to invite friends'
              : 'Couldn\'t load your invite',
          style: TextStyle(
              color: ink, fontSize: 18, fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          guest
              ? 'Invite codes and Premium rewards belong to real accounts.'
              : 'Check your connection and try again.',
          style: TextStyle(color: dim, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: guest
              ? () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const RegisterScreen()))
              : () {
                  setState(() => _loading = true);
                  _load();
                },
          child: Text(guest ? 'Create account' : 'Try again'),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, {required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BrandColors.bgCard(context),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: AppColors.purple.withValues(alpha: 0.34)),
        ),
        child: child,
      );

  Widget _stat(BuildContext context, String value, String label) => Expanded(
        child: _card(
          context,
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      color: BrandColors.ink(context),
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      color: BrandColors.inkDim(context), fontSize: 11.5)),
            ],
          ),
        ),
      );
}
