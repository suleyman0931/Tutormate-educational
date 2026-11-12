import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/constants/app_constants.dart';
import '../../../app/theme/app_colors.dart';

/// About screen with app information and developer contact details.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _developerName = 'Suleyman Abdu';
  static const String _phonePrimary = '0931798929';
  static const String _phoneSecondary = '0909918195';
  static const String _telegram = '@suleyman_abdu';
  static const String _email = 'suleymanabdu0931@gmail.com';
  static const String _github = 'https://github.com/suleyman0931';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const _DeveloperHero(name: _developerName),
          const SizedBox(height: 24),
          const _SectionTitle('Get in touch'),
          _buildContactCard(context),
          const SizedBox(height: 20),
          const _SectionTitle('About TutorMate'),
          _buildAppCard(context),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '© 2026 $_developerName',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Built with Flutter',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _ContactTile(
            icon: Icons.phone_outlined,
            color: const Color(0xFF00897B),
            title: _phonePrimary,
            subtitle: 'Phone',
            onTap: () => _launch(
              context,
              'tel:+251931798929',
              copyText: _phonePrimary,
            ),
          ),
          const Divider(height: 1, indent: 72),
          _ContactTile(
            icon: Icons.phone_iphone_outlined,
            color: const Color(0xFF00897B),
            title: _phoneSecondary,
            subtitle: 'Phone (alternate)',
            onTap: () => _launch(
              context,
              'tel:+251909918195',
              copyText: _phoneSecondary,
            ),
          ),
          const Divider(height: 1, indent: 72),
          _ContactTile(
            icon: Icons.send_outlined,
            color: const Color(0xFF229ED9),
            title: _telegram,
            subtitle: 'Telegram',
            onTap: () => _launch(
              context,
              'https://t.me/suleyman_abdu',
              copyText: _telegram,
            ),
          ),
          const Divider(height: 1, indent: 72),
          _ContactTile(
            icon: Icons.email_outlined,
            color: const Color(0xFFE53935),
            title: _email,
            subtitle: 'Email',
            onTap: () => _launch(
              context,
              'mailto:$_email',
              copyText: _email,
            ),
          ),
          const Divider(height: 1, indent: 72),
          _ContactTile(
            icon: Icons.code_rounded,
            color: const Color(0xFF37474F),
            title: 'github.com/suleyman0931',
            subtitle: 'GitHub',
            onTap: () => _launch(
              context,
              _github,
              copyText: _github,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConstants.appName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Version 1.0.0 · Offline PDF Library',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'TutorMate is an offline educational PDF library and reading '
              'assistant for Grades 1-5. Organise your books, read and '
              'annotate PDFs, take notes, and ask the built-in AI Tutor '
              'questions about your textbooks.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _FeatureChip(icon: Icons.offline_pin_outlined, label: 'Offline'),
                _FeatureChip(
                  icon: Icons.auto_awesome_outlined,
                  label: 'AI Tutor',
                ),
                _FeatureChip(
                  icon: Icons.draw_outlined,
                  label: 'Annotations',
                ),
                _FeatureChip(
                  icon: Icons.lock_outline,
                  label: 'Private',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launch(
    BuildContext context,
    String url, {
    String? copyText,
  }) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }

    if (opened || !context.mounted) return;

    final fallback = copyText ?? url;
    await Clipboard.setData(ClipboardData(text: fallback));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No app found. Copied "$fallback" instead.')),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────

class _DeveloperHero extends StatelessWidget {
  const _DeveloperHero({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const CircleAvatar(
              radius: 56,
              backgroundColor: Color(0xFFE8EAF6),
              backgroundImage: AssetImage('assets/images/developer.jpg'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'App Developer & Designer',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Text(
            'Designed and developed TutorMate to make learning easier for '
            'students and teachers.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: onTap,
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
