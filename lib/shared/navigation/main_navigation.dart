import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../src/features/home/presentation/pages/home_page.dart';
import '../../src/features/wardrobe/presentation/pages/wardrobe_page.dart';
import '../../src/features/profile/presentation/pages/profile_page.dart';
import '../../src/features/home/domain/providers/image_provider.dart';
import '../../src/features/detection/presentation/pages/detection_page.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/theme/snaplook_icons.dart';

final selectedIndexProvider = StateProvider<int>((ref) => 0);
final scrollToTopTriggerProvider = StateProvider<int>((ref) => 0);
final isAtHomeRootProvider = StateProvider<bool>((ref) => true);

// Global navigator keys
final homeNavigatorKey = GlobalKey<NavigatorState>();
final wardrobeNavigatorKey = GlobalKey<NavigatorState>();
final profileNavigatorKey = GlobalKey<NavigatorState>();

final homeScrollControllerProvider = Provider<ScrollController?>((ref) => null);

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  final ImagePicker _picker = ImagePicker();

  void _handleTabTap(int index) {
    final currentIndex = ref.read(selectedIndexProvider);

    if (currentIndex == index) {
      final navigatorKey = _getNavigatorKey(index);
      if (navigatorKey?.currentState?.canPop() ?? false) {
        navigatorKey!.currentState!.popUntil((route) => route.isFirst);
      } else {
        _scrollToTop(index);
      }
    } else {
      ref.read(selectedIndexProvider.notifier).state = index;
    }
  }

  GlobalKey<NavigatorState>? _getNavigatorKey(int index) {
    switch (index) {
      case 0:
        return homeNavigatorKey;
      case 1:
        return wardrobeNavigatorKey;
      case 2:
        return profileNavigatorKey;
      default:
        return null;
    }
  }

  void _scrollToTop(int index) {
    ref.read(scrollToTopTriggerProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedIndexProvider);

    final pages = [
      Navigator(
        key: homeNavigatorKey,
        initialRoute: '/',
        onGenerateRoute: (settings) {
          return PageRouteBuilder(
            settings: settings,
            pageBuilder: (context, animation, secondaryAnimation) {
              return const HomePage();
            },
            transitionDuration: const Duration(milliseconds: 300),
            reverseTransitionDuration: const Duration(milliseconds: 300),
          );
        },
      ),
      Navigator(
        key: wardrobeNavigatorKey,
        initialRoute: '/',
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => const WardrobePage(),
            settings: settings,
          );
        },
      ),
      Navigator(
        key: profileNavigatorKey,
        initialRoute: '/',
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => const ProfilePage(),
            settings: settings,
          );
        },
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: IndexedStack(index: selectedIndex, children: pages),
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
          minimum: const EdgeInsets.only(bottom: 6),
          child: Container(
            height: 64, // slightly taller for easier tap
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: _NavigationItem(
                      icon: SnaplookIcons.homeOutline,
                      selectedIcon: SnaplookIcons.homeFilled,
                      label: 'Home',
                      index: 0,
                      isSelected: selectedIndex == 0,
                      onTap: () => _handleTabTap(0),
                      iconSize: 25.0,
                      selectedIconSize: 26.0,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _NavigationItem(
                      icon: SnaplookIcons.heartOutline,
                      selectedIcon: SnaplookIcons.heartFilled,
                      label: 'Wardrobe',
                      index: 1,
                      isSelected: selectedIndex == 1,
                      onTap: () => _handleTabTap(1),
                      iconSize: 25.0,
                      selectedIconSize: 29.0,
                      selectedIconOffset: const Offset(2, 0),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _NavigationItem(
                      icon: SnaplookIcons.profileOutline,
                      selectedIcon: SnaplookIcons.profileFilled,
                      label: 'Profile',
                      index: 2,
                      isSelected: selectedIndex == 2,
                      onTap: () => _handleTabTap(2),
                      iconSize: 25.0,
                      selectedIconSize: 26.0,
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        ref.read(selectedImagesProvider.notifier).setImage(image);

        if (mounted) {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (context) => const DetectionPage(),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _shareApp() {
    Share.share(
      'Check out Snaplook - The AI-powered fashion discovery app! Find similar clothing items by taking photos. Download now!',
      subject: 'Discover Fashion with Snaplook',
    );
  }
}

class _NavigationItem extends StatelessWidget {
  final IconData? icon;
  final IconData? selectedIcon;
  final String? svgIcon;
  final String? selectedSvgIcon;
  final String label;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final double? iconSize;
  final double? selectedIconSize;
  final double? topPadding;
  final Offset? selectedIconOffset;

  const _NavigationItem({
    this.icon,
    this.selectedIcon,
    this.svgIcon,
    this.selectedSvgIcon,
    required this.label,
    required this.index,
    required this.isSelected,
    required this.onTap,
    this.iconSize,
    this.selectedIconSize,
    this.topPadding,
    this.selectedIconOffset,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // ✅ expand tap area even if transparent
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: SizedBox(
        width: 80, // wider hitbox
        height: 56, // fits bottom bar
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(top: topPadding ?? 0.0),
            child: _buildIcon(),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    final color =
        isSelected ? AppColors.secondary : AppColors.onSurfaceVariant;

    final size = isSelected && selectedIconSize != null
        ? selectedIconSize!
        : (iconSize ?? 28.0);

    Widget iconWidget;

    if (svgIcon != null && selectedSvgIcon != null) {
      iconWidget = SvgPicture.asset(
        isSelected ? selectedSvgIcon! : svgIcon!,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    } else if (icon != null && selectedIcon != null) {
      iconWidget = Icon(
        isSelected ? selectedIcon! : icon!,
        color: color,
        size: size,
      );
    } else {
      iconWidget = const SizedBox.shrink();
    }

    if (isSelected && selectedIconOffset != null) {
      return Transform.translate(
        offset: selectedIconOffset!,
        child: iconWidget,
      );
    }

    return iconWidget;
  }
}

class _FloatingActionBar extends StatelessWidget {
  final VoidCallback onSnapTap;
  final VoidCallback onUploadTap;
  final VoidCallback onShareTap;

  const _FloatingActionBar({
    required this.onSnapTap,
    required this.onUploadTap,
    required this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFFf2003c),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(
          color: const Color(0xFFf2003c),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 35,
            offset: const Offset(0, 6),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _FloatingActionButtonSvg(
              svgIcon: 'assets/icons/camera_filled.svg',
              label: 'Snap',
              onTap: onSnapTap,
            ),
            _FloatingActionButtonSvg(
              svgIcon: 'assets/icons/upload_filled.svg',
              label: 'Upload',
              onTap: onUploadTap,
            ),
            _FloatingActionButtonSvg(
              svgIcon: 'assets/icons/tutorials_filled.svg',
              label: 'Tutorials',
              onTap: () {},
            ),
            _FloatingActionButtonSvg(
              svgIcon: 'assets/icons/share_filled.svg',
              label: 'Share',
              onTap: onShareTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingActionButtonSvg extends StatelessWidget {
  final String svgIcon;
  final String label;
  final VoidCallback onTap;

  const _FloatingActionButtonSvg({
    required this.svgIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                svgIcon,
                width: 24,
                height: 24,
                colorFilter:
                    const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
