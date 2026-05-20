import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/feedback_service.dart';
import '../theme/app_theme.dart';

Future<void> showFeedbackDialog(
  BuildContext context, {
  FeedbackKind initialKind = FeedbackKind.general,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _FeedbackDialog(initialKind: initialKind),
  );
}

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog({required this.initialKind});
  final FeedbackKind initialKind;

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  late FeedbackKind _kind = widget.initialKind;
  final TextEditingController _ctrl = TextEditingController();
  bool _includeSnapshot = false;
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await FeedbackService().compose(
        kind: _kind,
        message: text,
        includeSnapshot: _includeSnapshot,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Mailto link copied. Paste into your mail app to send.',
          ),
          backgroundColor: BrandColors.bgCard(context),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not prepare feedback: $e'),
          backgroundColor: BrandColors.bgCard(context),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: BrandColors.bgCard(context),
      title: Text('Send feedback',
          style: TextStyle(color: BrandColors.ink(context))),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in FeedbackKind.values)
                  _KindChip(
                    label: k.label,
                    selected: k == _kind,
                    onTap: () => setState(() => _kind = k),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              autofocus: true,
              minLines: 4,
              maxLines: 8,
              cursorColor: AppColors.pinkLight,
              style: TextStyle(color: BrandColors.ink(context)),
              decoration: InputDecoration(
                hintText: 'What happened, what you expected, what you want…',
                hintStyle: TextStyle(
                  color: BrandColors.inkDim(context).withValues(alpha: 0.8),
                ),
                filled: true,
                fillColor: BrandColors.bg(context).withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppColors.purple.withValues(alpha: 0.30),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppColors.purple.withValues(alpha: 0.30),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.pinkLight,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Switch.adaptive(
                  value: _includeSnapshot,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.pink,
                  inactiveTrackColor: BrandColors.bg(context),
                  onChanged: (v) => setState(() => _includeSnapshot = v),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Include anonymous data counts (helps debugging)',
                    style: TextStyle(
                      color: BrandColors.inkDim(context),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _sending ? null : _send,
          child: Text(_sending ? 'Preparing…' : 'Copy mailto'),
        ),
        TextButton(
          onPressed: _sending
              ? null
              : () async {
                  await Clipboard.setData(
                    const ClipboardData(text: 'hello@mood8.app'),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Email copied: hello@mood8.app'),
                      backgroundColor: BrandColors.bgCard(context),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  );
                },
          child: const Text('Just copy email'),
        ),
      ],
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.buttonGradient : null,
          color: selected ? null : BrandColors.bg(context).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : AppColors.purple.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : BrandColors.inkSoft(context),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
