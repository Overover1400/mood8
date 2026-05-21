import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/share_card_data.dart';
import '../services/haptic_service.dart';
import '../services/share_service.dart';
import '../theme/app_theme.dart';
import '../widgets/share_card.dart';

/// Live preview of the share card. Lets the user flip between the
/// three templates + two formats, then taps Share to invoke
/// [ShareService.shareCard].
class ShareProgressScreen extends StatefulWidget {
  const ShareProgressScreen({
    super.key,
    this.initialTemplate = ShareCardTemplate.weekRecap,
    this.initialFormat = ShareCardFormat.square,
  });

  final ShareCardTemplate initialTemplate;
  final ShareCardFormat initialFormat;

  @override
  State<ShareProgressScreen> createState() => _ShareProgressScreenState();
}

class _ShareProgressScreenState extends State<ShareProgressScreen> {
  late ShareCardTemplate _template = widget.initialTemplate;
  late ShareCardFormat _format = widget.initialFormat;
  ShareCardData? _data;
  bool _busy = false;
  String? _error;
  final GlobalKey _boundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final d = await ShareService().buildCurrentSnapshot();
    if (!mounted) return;
    setState(() => _data = d);
  }

  Future<void> _onShare() async {
    if (_busy || _data == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    HapticService().medium();
    final ok = await ShareService().shareCard(
      _boundaryKey,
      format: _format,
      shareText: _shareText(),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _error = "Couldn't open the share sheet.";
    });
  }

  String _shareText() {
    switch (_template) {
      case ShareCardTemplate.weekRecap:
        return 'My week on Mood8 ✨ — mood8.app';
      case ShareCardTemplate.streakMilestone:
        final d = _data!;
        return '${d.streakDays}-day streak on Mood8 🔥 — mood8.app';
      case ShareCardTemplate.identityProgress:
        return 'Becoming who I want to be — mood8.app';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      body: SafeArea(
        child: Column(
          children: [
            _Header(onClose: () => Navigator.of(context).maybePop()),
            Expanded(
              child: _data == null
                  ? const Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor:
                              AlwaysStoppedAnimation(Color(0xFFEC4899)),
                        ),
                      ),
                    )
                  : _Preview(
                      data: _data!,
                      template: _template,
                      format: _format,
                      boundaryKey: _boundaryKey,
                    ),
            ),
            _TemplatePicker(
              current: _template,
              onSelect: (t) => setState(() => _template = t),
            ),
            const SizedBox(height: 10),
            _FormatToggle(
              current: _format,
              onSelect: (f) => setState(() => _format = f),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFF472B6),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                children: [
                  Expanded(
                    child: _SecondaryButton(
                      label: 'Save',
                      icon: Icons.download_rounded,
                      onTap: _busy ? null : _onSave,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _PrimaryButton(
                      label: _busy ? 'Preparing…' : 'Share',
                      onTap: _busy ? null : _onShare,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    if (_busy || _data == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    HapticService().light();
    final ok = await ShareService().saveCardToDevice(
      _boundaryKey,
      format: _format,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _error = "Couldn't save the card.";
    });
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: Icon(
              Icons.close_rounded,
              color: BrandColors.inkSoft(context),
            ),
          ),
          Expanded(
            child: Text(
              'Share your progress',
              style: GoogleFonts.instrumentSerif(
                color: BrandColors.ink(context),
                fontStyle: FontStyle.italic,
                fontSize: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.data,
    required this.template,
    required this.format,
    required this.boundaryKey,
  });

  final ShareCardData data;
  final ShareCardTemplate template;
  final ShareCardFormat format;
  final GlobalKey boundaryKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Reserve a little margin around the card.
        final available = Size(
          constraints.maxWidth - 40,
          constraints.maxHeight - 40,
        );
        // Compute uniform scale so the card fits within the available
        // box while keeping its aspect ratio.
        final scale = (available.width / format.width)
            .clamp(0, available.height / format.height)
            .toDouble();
        return Center(
          child: SizedBox(
            width: format.width * scale,
            height: format.height * scale,
            child: FittedBox(
              fit: BoxFit.fill,
              child: ShareCard(
                data: data,
                template: template,
                format: format,
                boundaryKey: boundaryKey,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TemplatePicker extends StatelessWidget {
  const _TemplatePicker({required this.current, required this.onSelect});
  final ShareCardTemplate current;
  final ValueChanged<ShareCardTemplate> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          for (final t in ShareCardTemplate.values) ...[
            _Chip(
              label: t.label,
              selected: t == current,
              onTap: () => onSelect(t),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FormatToggle extends StatelessWidget {
  const _FormatToggle({required this.current, required this.onSelect});
  final ShareCardFormat current;
  final ValueChanged<ShareCardFormat> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final f in ShareCardFormat.values) ...[
          _Chip(
            label: f.label,
            selected: f == current,
            onTap: () => onSelect(f),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.buttonGradient : null,
          color: selected
              ? null
              : BrandColors.bgCard(context).withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : AppColors.purple.withValues(alpha: 0.22),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : BrandColors.inkSoft(context),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.6 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(27),
            boxShadow: [
              BoxShadow(
                color: AppColors.pink.withValues(alpha: 0.45),
                blurRadius: 22,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.6 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: BrandColors.bgCard(context).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(27),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: BrandColors.ink(context), size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: BrandColors.ink(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
