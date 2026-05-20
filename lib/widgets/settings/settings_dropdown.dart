import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import 'settings_tile.dart';

class SettingsDropdown<T> extends StatelessWidget {
  const SettingsDropdown({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final T value;
  final List<DropdownOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = options.firstWhere(
      (o) => o.value == value,
      orElse: () => options.first,
    );
    return SettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(current.label),
          const SizedBox(width: 4),
          Icon(Icons.expand_more_rounded,
              color: BrandColors.inkDim(context), size: 18),
        ],
      ),
      onTap: () => _open(context),
    );
  }

  Future<void> _open(BuildContext context) async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => _Sheet<T>(
        title: title,
        options: options,
        current: value,
        onPick: (v) {
          Navigator.of(ctx).pop();
          onChanged(v);
        },
      ),
    );
  }
}

class DropdownOption<T> {
  const DropdownOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.disabled = false,
  });
  final T value;
  final String label;
  final String? subtitle;
  final bool disabled;
}

class _Sheet<T> extends StatelessWidget {
  const _Sheet({
    required this.title,
    required this.options,
    required this.current,
    required this.onPick,
  });

  final String title;
  final List<DropdownOption<T>> options;
  final T current;
  final ValueChanged<T> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [BrandColors.bg(context), BrandColors.bgDeep(context)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.22),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: BrandColors.inkFaint(context).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              for (final o in options)
                _OptionRow<T>(
                  option: o,
                  selected: o.value == current,
                  onTap: o.disabled ? null : () => onPick(o.value),
                ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final DropdownOption<T> option;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: TextStyle(
                        color: disabled
                            ? BrandColors.inkDim(context)
                            : (selected ? AppColors.pinkLight : BrandColors.ink(context)),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (option.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        option.subtitle!,
                        style: TextStyle(
                          color: BrandColors.inkDim(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded,
                    color: AppColors.pinkLight, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
