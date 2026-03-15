import 'package:flutter/material.dart';
import 'package:optima_healthcare_mobile/app/theme.dart';

/// One quick action: circular icon + label (e.g. Video Call, Appointments).
class QuickActionItem {
  const QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

/// Welcome banner + quick action grid. Used on staff and patient dashboards.
class DashboardHomeContent extends StatelessWidget {
  const DashboardHomeContent({
    super.key,
    required this.displayName,
    this.welcomeSubtitle,
    required this.quickActions,
    this.viewProgressLabel,
    this.onViewProgress,
    this.supplementarySections = const [],
  });

  final String displayName;
  final String? welcomeSubtitle;
  final List<QuickActionItem> quickActions;
  final String? viewProgressLabel;
  final VoidCallback? onViewProgress;
  final List<Widget> supplementarySections;

  static String _displayNameFromUsername(String? username) {
    if (username == null || username.isEmpty) return 'there';
    final s = username.trim();
    if (s.contains('@')) return s.split('@').first;
    if (s.contains(' ')) return s.split(' ').first;
    return s.length > 1 ? s[0].toUpperCase() + s.substring(1) : s.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final name = displayName.isEmpty ? _displayNameFromUsername(null) : displayName;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $name!',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (welcomeSubtitle != null && welcomeSubtitle!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    welcomeSubtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                ],
                if (viewProgressLabel != null && onViewProgress != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onViewProgress,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.brandCharcoal,
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: Text(viewProgressLabel!, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ),
          if (supplementarySections.isNotEmpty) ...[
            const SizedBox(height: 24),
            ...supplementarySections,
          ],
          const SizedBox(height: 24),
          // Quick Actions
          Text(
            'Quick Actions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.brandCharcoal,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 20.0;
              final count = constraints.maxWidth < 360 ? 3 : 4;
              final size = (constraints.maxWidth - (count - 1) * spacing) / count;
              return Wrap(
                spacing: spacing,
                runSpacing: 16,
                children: quickActions.map((a) {
                  return _QuickActionChip(
                    size: size,
                    icon: a.icon,
                    label: a.label,
                    color: a.color,
                    onTap: a.onTap,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.size,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final double size;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: size,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: size * 0.4),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppTheme.brandCharcoal,
                fontSize: 12,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
