import 'package:flutter/material.dart';

/// A titled group of settings tiles rendered inside a single bordered card.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.topPadding = 22,
  });

  final String title;
  final List<Widget> children;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(4, topPadding, 4, 8),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  const Divider(height: 1, indent: 64, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A soft, rounded container used to lead a [ListTile] with an icon.
class SettingsTileIcon extends StatelessWidget {
  const SettingsTileIcon(this.icon, {super.key, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color effectiveColor = color ?? colorScheme.primary;

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 20, color: effectiveColor),
    );
  }
}

/// A settings row with an icon, title, subtitle and trailing chevron.
class SettingsActionTile extends StatelessWidget {
  const SettingsActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
    this.trailing,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? color;
  final Widget? trailing;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      enabled: enabled,
      leading: SettingsTileIcon(icon, color: color),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing:
          trailing ??
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: enabled ? null : colorScheme.onSurfaceVariant,
          ),
      onTap: enabled ? onTap : null,
    );
  }
}

/// A settings row with an icon and a trailing switch.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return SwitchListTile(
      secondary: SettingsTileIcon(icon, color: color ?? colorScheme.secondary),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}
