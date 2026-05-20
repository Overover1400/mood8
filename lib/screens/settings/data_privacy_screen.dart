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
      backgroundColor: BrandColors.bgDeep(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: BrandColors.inkSoft(context), size: 18),
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
                  subtitle: 'downloads to your device',
                  children: [
                    SettingsTile(
                      icon: Icons.data_object_rounded,
                      title: 'Download JSON backup',
                      subtitle: _export.suggestedFilename('json'),
                      onTap: () => _doDownload(json: true),
                    ),
                    SettingsTile(
                      icon: Icons.table_chart_outlined,
                      title: 'Download CSV bundle (.zip)',
                      subtitle: _export.suggestedFilename('zip'),
                      onTap: () => _doDownload(json: false),
                    ),
                    SettingsTile(
                      icon: Icons.copy_all_rounded,
                      title: 'Copy JSON to clipboard',
                      subtitle: 'Fallback if download is blocked',
                      onTap: _doCopyJson,
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

  Future<void> _doCopyJson() async {
    try {
      await _export.copyToClipboard(_export.exportToJson());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('JSON copied — paste into a text file.'),
          backgroundColor: BrandColors.bgCard(context),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
      HapticFeedback.lightImpact();
    } catch (e) {
      if (!mounted) return;
      _toast('Copy failed: $e');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: BrandColors.bgCard(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Future<void> _doDownload({required bool json}) async {
    try {
      final ok = json
          ? await _export.downloadJson()
          : await _export.downloadCsvBundle();
      if (!mounted) return;
      if (!ok) {
        _toast(
            "Couldn't start the download. Try the clipboard fallback below.");
        return;
      }
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            json
                ? 'JSON backup downloading…'
                : 'CSV bundle downloading…',
          ),
          backgroundColor: BrandColors.bgCard(context),
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
          backgroundColor: BrandColors.bgCard(context),
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
          backgroundColor: BrandColors.bgCard(context),
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
        backgroundColor: BrandColors.bgCard(context),
        title: Text(title, style: TextStyle(color: BrandColors.ink(context))),
        content: Text(body, style: TextStyle(color: BrandColors.inkSoft(context))),
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
