import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/export_service.dart';
import '../../services/onboarding_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_container.dart';
import '../../widgets/settings/settings_section.dart';
import '../../widgets/settings/settings_tile.dart';

class DataPrivacyScreen extends StatefulWidget {
  const DataPrivacyScreen({super.key});

  @override
  State<DataPrivacyScreen> createState() => _DataPrivacyScreenState();
}

class _DataPrivacyScreenState extends State<DataPrivacyScreen> {
  final ExportService _export = ExportService();

  @override
  Widget build(BuildContext context) {
    final stats = _export.stats();
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.inkSoft, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Data & Privacy',
            style: Theme.of(context).textTheme.headlineSmall),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 560,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsSection(
                  title: 'Snapshot',
                  children: [
                    SettingsTile(
                      icon: Icons.storage_rounded,
                      title: stats.headline,
                      subtitle:
                          '${stats.habitLogs} habit logs · ${stats.reflections} reflections · ${stats.insights} insights',
                    ),
                  ],
                ),
                SettingsSection(
                  title: 'Export',
                  subtitle: 'copied to clipboard',
                  children: [
                    SettingsTile(
                      icon: Icons.data_object_rounded,
                      title: 'Export as JSON',
                      subtitle: _export.suggestedFilename('json'),
                      onTap: () => _doExport(json: true),
                    ),
                    SettingsTile(
                      icon: Icons.table_chart_outlined,
                      title: 'Export as CSV',
                      subtitle: _export.suggestedFilename('csv'),
                      onTap: () => _doExport(json: false),
                    ),
                  ],
                ),
                SettingsSection(
                  title: 'Danger zone',
                  children: [
                    SettingsTile(
                      icon: Icons.refresh_rounded,
                      title: 'Reset onboarding',
                      subtitle: 'Keeps data, runs onboarding again',
                      onTap: _confirmResetOnboarding,
                    ),
                    SettingsTile(
                      icon: Icons.delete_outline_rounded,
                      title: 'Delete all data',
                      subtitle: 'Erases everything on this device',
                      destructive: true,
                      onTap: _confirmDeleteAll,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _doExport({required bool json}) async {
    try {
      final content = json ? _export.exportToJson() : _export.exportToCsv();
      await _export.copyToClipboard(content);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${json ? 'JSON' : 'CSV'} export copied — paste into a text file.',
          ),
          backgroundColor: AppColors.bgCard,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
      HapticFeedback.lightImpact();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.bgCard,
        ),
      );
    }
  }

  Future<void> _confirmResetOnboarding() async {
    final ok = await _confirm(
      title: 'Reset onboarding?',
      body:
          'This clears your profile + routines + habits and runs onboarding again.',
      cta: 'Reset',
      destructive: true,
    );
    if (ok != true) return;
    await OnboardingService().reset();
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _confirmDeleteAll() async {
    final ok1 = await _confirm(
      title: 'Delete all data?',
      body:
          'This permanently erases every check-in, routine, habit, reflection, and insight.',
      cta: 'Continue',
      destructive: true,
    );
    if (ok1 != true) return;
    final ok2 = await _confirm(
      title: 'Are you sure?',
      body: 'This cannot be undone.',
      cta: 'Yes, delete everything',
      destructive: true,
    );
    if (ok2 != true) return;
    try {
      await _export.clearAllData();
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete: $e'),
          backgroundColor: AppColors.bgCard,
        ),
      );
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String cta,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text(title, style: const TextStyle(color: AppColors.ink)),
        content: Text(body, style: const TextStyle(color: AppColors.inkSoft)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              cta,
              style: TextStyle(
                color: destructive
                    ? const Color(0xFFFF6B81)
                    : AppColors.pinkLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
