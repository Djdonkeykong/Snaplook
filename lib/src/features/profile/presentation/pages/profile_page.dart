import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(spacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: spacing.xl),

              // Profile Avatar Section
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: AppColors.secondary,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: AppColors.secondary,
                      ),
                    ),
                    SizedBox(height: spacing.m),
                    Text(
                      'Style Explorer',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      'Fashion enthusiast',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: spacing.xl),

              // Profile Options
              _ProfileOption(
                icon: Icons.favorite,
                title: 'Saved Items',
                subtitle: '0 items saved',
                onTap: () {},
              ),
              SizedBox(height: spacing.m),
              _ProfileOption(
                icon: Icons.history,
                title: 'Scan History',
                subtitle: 'View your recent scans',
                onTap: () {},
              ),
              SizedBox(height: spacing.m),
              _ProfileOption(
                icon: Icons.settings,
                title: 'Settings',
                subtitle: 'App preferences & privacy',
                onTap: () {},
              ),
              SizedBox(height: spacing.m),
              _ProfileOption(
                icon: Icons.help_outline,
                title: 'Help & Support',
                subtitle: 'Get help and contact us',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius.medium),
      child: Container(
        padding: EdgeInsets.all(spacing.m),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(radius.medium),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(radius.small),
              ),
              child: Icon(
                icon,
                color: AppColors.secondary,
                size: 22,
              ),
            ),
            SizedBox(width: spacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}