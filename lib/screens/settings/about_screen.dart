import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/feedback_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/feedback_dialog.dart';
import '../../widgets/responsive_container.dart';
import '../../widgets/settings/settings_section.dart';
import '../../widgets/settings/settings_tile.dart';

const String kMood8Version = '0.1.0';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
        title: Text('About', style: Theme.of(context).textTheme.headlineSmall),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 560,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.orbGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.pink.withValues(alpha: 0.40),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Mood8',
                          style: GoogleFonts.bricolageGrotesque(
                            color: BrandColors.ink(context),
                            fontSize: 32,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'v$kMood8Version',
                          style: TextStyle(
                            color: BrandColors.inkDim(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SettingsSection(
                  title: 'Legal',
                  children: [
                    SettingsTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'Privacy Policy',
                      subtitle: 'mood8.app/privacy.html',
                      onTap: () => _copy(context, 'https://mood8.app/privacy.html'),
                    ),
                    SettingsTile(
                      icon: Icons.gavel_rounded,
                      title: 'Terms of Service',
                      subtitle: 'mood8.app/terms.html',
                      onTap: () => _copy(context, 'https://mood8.app/terms.html'),
                    ),
                  ],
                ),
                SettingsSection(
                  title: 'Contact',
                  children: [
                    SettingsTile(
                      icon: Icons.alternate_email_rounded,
                      title: 'Contact developer',
                      subtitle: 'Send a message — we read every one',
                      onTap: () => showFeedbackDialog(
                        context,
                        initialKind: FeedbackKind.general,
                      ),
                    ),
                    SettingsTile(
                      icon: Icons.bug_report_outlined,
                      title: 'Report an issue',
                      subtitle: 'Describe what went wrong',
                      onTap: () => showFeedbackDialog(
                        context,
                        initialKind: FeedbackKind.bug,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Center(
                  child: Text(
                    'Made with 💜 for people becoming.',
                    style: TextStyle(
                      color: BrandColors.inkDim(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
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

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $text'),
        backgroundColor: BrandColors.bgCard(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
