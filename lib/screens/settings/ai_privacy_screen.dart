import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../widgets/responsive_container.dart';

/// Settings → AI Coach → AI privacy. Plain-language explanation of
/// what the coach sees, where it goes, what it isn't used for, and
/// what the user controls. Static read-only screen — the actual
/// toggles live on the parent AI Coach section in [SettingsScreen].
class AiPrivacyScreen extends StatelessWidget {
  const AiPrivacyScreen({super.key});

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
        title: Text('AI privacy',
            style: Theme.of(context).textTheme.headlineSmall),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 600,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _Hero(),
                SizedBox(height: 22),
                _Section(
                  icon: Icons.visibility_outlined,
                  title: 'What the AI Coach sees',
                  body:
                      "When you chat with the coach, ask for a reflection, or open an AI insight, we send the model:\n\n"
                      "• Your messages in that conversation.\n"
                      "• A small snapshot of context — your name, your chosen identities, your latest mood/energy/focus check-in, and your current streak — so the coach can answer like it knows you.\n"
                      "• For habit-package suggestions, your stated goal.\n\n"
                      "We do NOT send your past chat history outside the current conversation, your contacts, your location, your email, or any payment details.",
                ),
                SizedBox(height: 14),
                _Section(
                  icon: Icons.cloud_outlined,
                  title: 'Where it goes',
                  body:
                      "Mood8's coach runs on OpenAI (the GPT-4o family of models). Your message is sent from our server to OpenAI's API over HTTPS, OpenAI generates the reply, and we send it back to your device. We don't train any model — OpenAI's API tier doesn't use API content for training by default.",
                ),
                SizedBox(height: 14),
                _Section(
                  icon: Icons.block_rounded,
                  title: "What we don't do",
                  body:
                      "We don't sell your data. We don't share it with advertisers. We don't use your conversations to build a profile for marketing. The coach exists to help you reflect on your habits — that's the only thing it does with what you tell it.",
                ),
                SizedBox(height: 14),
                _Section(
                  icon: Icons.tune_rounded,
                  title: 'What you control',
                  body:
                      "• Turn AI insights off any time from the AI Coach settings — patterns will stop being explained by the coach.\n"
                      "• Clear the chat from the Coach screen to wipe the conversation locally.\n"
                      "• Export or delete your account from Data & Privacy — deleting removes all your data from our server.\n"
                      "• Don't share anything with the coach you wouldn't put in an email. It's a thoughtful assistant, not a therapist.",
                ),
                SizedBox(height: 14),
                _Section(
                  icon: Icons.warning_amber_rounded,
                  title: "A real-talk note",
                  body:
                      "The AI Coach is here to help you build habits, not to replace a doctor or therapist. If you mention something serious — self-harm, an eating disorder, a medical issue — the coach will gently suggest you talk to a professional. Please do.",
                ),
                SizedBox(height: 28),
                _Footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.purple.withValues(alpha: 0.22),
            AppColors.pink.withValues(alpha: 0.14),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.pinkLight.withValues(alpha: 0.40),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.buttonGradient,
            ),
            child: const Icon(Icons.shield_moon_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How the AI Coach handles your data',
                  style: GoogleFonts.bricolageGrotesque(
                    color: BrandColors.ink(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Plain-language, no legalese. If something here surprises you, email hello@mood8.app.",
                  style: TextStyle(
                    color: BrandColors.inkSoft(context),
                    fontSize: 12.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
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

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.pinkLight, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.bricolageGrotesque(
                    color: BrandColors.ink(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: BrandColors.inkSoft(context),
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Last updated 2026 · Mood8',
        style: TextStyle(
          color: BrandColors.inkDim(context),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
