import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

class CodeInput extends StatefulWidget {
  const CodeInput({
    super.key,
    required this.onComplete,
    this.length = 6,
    this.enabled = true,
    this.autoFocus = true,
  });

  final ValueChanged<String> onComplete;
  final int length;
  final bool enabled;
  final bool autoFocus;

  @override
  State<CodeInput> createState() => CodeInputState();
}

class CodeInputState extends State<CodeInput> {
  late final List<TextEditingController> _ctrls;
  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(widget.length, (_) => TextEditingController());
    _nodes = List.generate(widget.length, (_) => FocusNode());
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _nodes.first.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get value => _ctrls.map((c) => c.text).join();

  void clear() {
    for (final c in _ctrls) {
      c.clear();
    }
    if (mounted) {
      _nodes.first.requestFocus();
      setState(() {});
    }
  }

  void _onChanged(int index, String s) {
    if (s.length > 1) {
      // Paste path: fill all boxes from this position.
      final digits = s.replaceAll(RegExp(r'\D'), '');
      for (var i = 0;
          i < digits.length && index + i < widget.length;
          i++) {
        _ctrls[index + i].text = digits[i];
      }
      final filled = (index + digits.length).clamp(0, widget.length);
      if (filled >= widget.length) {
        _nodes.last.unfocus();
        widget.onComplete(value);
      } else {
        _nodes[filled].requestFocus();
      }
      setState(() {});
      return;
    }
    if (s.isNotEmpty) {
      if (index < widget.length - 1) {
        _nodes[index + 1].requestFocus();
      } else {
        _nodes[index].unfocus();
      }
    }
    if (value.length == widget.length &&
        !value.contains(RegExp(r'\D'))) {
      widget.onComplete(value);
    }
    setState(() {});
  }

  KeyEventResult _onKey(int index, FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _ctrls[index].text.isEmpty &&
        index > 0) {
      _nodes[index - 1].requestFocus();
      _ctrls[index - 1].clear();
      setState(() {});
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < widget.length; i++) ...[
          _Box(
            controller: _ctrls[i],
            node: _nodes[i],
            onChanged: (s) => _onChanged(i, s),
            onKey: (n, e) => _onKey(i, n, e),
            enabled: widget.enabled,
          ),
          if (i < widget.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _Box extends StatefulWidget {
  const _Box({
    required this.controller,
    required this.node,
    required this.onChanged,
    required this.onKey,
    required this.enabled,
  });

  final TextEditingController controller;
  final FocusNode node;
  final ValueChanged<String> onChanged;
  final KeyEventResult Function(FocusNode, KeyEvent) onKey;
  final bool enabled;

  @override
  State<_Box> createState() => _BoxState();
}

class _BoxState extends State<_Box> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.node.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = widget.node.hasFocus);
  }

  @override
  void dispose() {
    widget.node.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.controller.text.isNotEmpty;
    return Container(
      width: 44,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused
              ? AppColors.pinkLight
              : AppColors.purple
                  .withValues(alpha: hasValue ? 0.55 : 0.25),
          width: _focused ? 1.6 : 1,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: AppColors.pink.withValues(alpha: 0.30),
                  blurRadius: 18,
                ),
              ]
            : null,
      ),
      child: Focus(
        onKeyEvent: widget.onKey,
        child: TextField(
          controller: widget.controller,
          focusNode: widget.node,
          enabled: widget.enabled,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          textAlign: TextAlign.center,
          cursorColor: AppColors.pinkLight,
          maxLength: 1,
          style: TextStyle(
            color: BrandColors.ink(context),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isDense: true,
          ),
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}
