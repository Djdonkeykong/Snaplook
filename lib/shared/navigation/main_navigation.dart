import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../src/features/home/presentation/pages/home_page.dart';
import '../../src/features/wardrobe/presentation/pages/wardrobe_page.dart';
import '../../src/features/discover/presentation/pages/discover_page.dart';
import '../../src/features/profile/presentation/pages/profile_page.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';

final selectedIndexProvider = StateProvider<int>((ref) => 0);

class MainNavigation extends ConsumerWidget {
  const MainNavigation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedIndexProvider);
    final spacing = context.spacing;

    // Define pages with IndexedStack to preserve state
    const pages = [
      HomePage(),
      WardrobePage(),
      ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(
              color: AppColors.outline.withOpacity(0.3),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: Container(
            height: 80,
            padding: EdgeInsets.symmetric(
              horizontal: spacing.l,
              vertical: spacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavigationItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  label: 'Home',
                  index: 0,
                  isSelected: selectedIndex == 0,
                  onTap: () => ref.read(selectedIndexProvider.notifier).state = 0,
                ),
                _NavigationItem(
                  icon: Icons.favorite_border_rounded,
                  selectedIcon: Icons.favorite_rounded,
                  label: 'Wardrobe',
                  index: 1,
                  isSelected: selectedIndex == 1,
                  onTap: () => ref.read(selectedIndexProvider.notifier).state = 1,
                ),
                _NavigationItem(
                  icon: Icons.account_circle_outlined,
                  selectedIcon: Icons.account_circle_rounded,
                  label: 'Profile',
                  index: 2,
                  isSelected: selectedIndex == 2,
                  onTap: () => ref.read(selectedIndexProvider.notifier).state = 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Icon(
          isSelected ? selectedIcon : icon,
          color: isSelected
              ? AppColors.secondary
              : AppColors.onSurfaceVariant,
          size: 30,
        ),
      ),
    );
  }
}