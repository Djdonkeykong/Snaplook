import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../shared/navigation/route_observer.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../widgets/progress_indicator.dart';
import '../widgets/onboarding_bottom_bar.dart';
import 'instagram_tutorial_page.dart';
import 'pinterest_tutorial_page.dart';
import 'tiktok_tutorial_page.dart';
import 'safari_tutorial_page.dart';
import 'photos_tutorial_page.dart';
import 'notification_permission_page.dart';

class AddFirstStylePage extends ConsumerStatefulWidget {
  const AddFirstStylePage({super.key});

  @override
  ConsumerState<AddFirstStylePage> createState() => _AddFirstStylePageState();
}

class _AddFirstStylePageState extends ConsumerState<AddFirstStylePage>
    with TickerProviderStateMixin, RouteAware {
  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<double>> _scaleAnimations;

  bool _isRouteAware = false;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();

    _animationControllers = List.generate(6, (index) {
      return AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      );
    });

    _fadeAnimations = _animationControllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      );
    }).toList();

    _scaleAnimations = _animationControllers.map((controller) {
      return Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
      );
    }).toList();
  }

  void _startStaggeredAnimation() {
    // Reset all controllers first
    for (var controller in _animationControllers) {
      controller.reset();
    }

    // Then start staggered animation
    for (int i = 0; i < _animationControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted) {
          _animationControllers[i].forward();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only precache icons that are actually shown on this page
    precacheImage(const AssetImage('assets/icons/insta.png'), context);
    precacheImage(const AssetImage('assets/icons/safari.png'), context);
    precacheImage(const AssetImage('assets/icons/photos.png'), context);

    final route = ModalRoute.of(context);
    if (!_isRouteAware && route is PageRoute) {
      routeObserver.subscribe(this, route);
      _isRouteAware = true;
      if (route.isCurrent) {
        _startStaggeredAnimationOnce();
      }
    }
  }

  @override
  void dispose() {
    if (_isRouteAware) {
      routeObserver.unsubscribe(this);
    }
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didPush() {
    _startStaggeredAnimationOnce();
  }

  @override
  void didPopNext() {
    _hasAnimated = false; // allow re-run when returning
    _startStaggeredAnimation();
  }

  void _startStaggeredAnimationOnce() {
    if (_hasAnimated) return;
    _hasAnimated = true;
    _startStaggeredAnimation();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const SnaplookBackButton(),
        centerTitle: true,
        title: const OnboardingProgressIndicator(
          currentStep: 4,
          totalSteps: 10,
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: spacing.l),

            // Title
            const Text(
              'Add your first style',
              style: TextStyle(
                fontSize: 34,
                fontFamily: 'PlusJakartaSans',
                letterSpacing: -1.0,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                height: 1.3,
              ),
            ),

            SizedBox(height: spacing.m),

            // Subtitle
            const Text(
              'Learn to share from your favorite apps',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black,
                fontWeight: FontWeight.w500,
                fontFamily: 'PlusJakartaSans',
                letterSpacing: -0.3,
              ),
            ),

            SizedBox(height: spacing.l),

            // App List
            Expanded(
              child: _AppList(
                animationControllers: _animationControllers,
                fadeAnimations: _fadeAnimations,
                scaleAnimations: _scaleAnimations,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: OnboardingBottomBar(
        primaryButton: GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const NotificationPermissionPage(
                  continueToTrialFlow: true,
                ),
              ),
            );
          },
          child: const SizedBox(
            width: double.infinity,
            height: 56,
            child: Center(
              child: Text(
                'Skip',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black,
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.black,
                  decorationThickness: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppList extends ConsumerWidget {
  final List<AnimationController> animationControllers;
  final List<Animation<double>> fadeAnimations;
  final List<Animation<double>> scaleAnimations;

  const _AppList({
    required this.animationControllers,
    required this.fadeAnimations,
    required this.scaleAnimations,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;

    return ListView.separated(
      padding: EdgeInsets.only(bottom: spacing.l),
      physics: const BouncingScrollPhysics(),
      itemCount: 6,
      separatorBuilder: (_, __) => SizedBox(height: spacing.l),
      itemBuilder: (context, index) {
        switch (index) {
          case 0:
            return AnimatedBuilder(
              animation: animationControllers[0],
              builder: (context, child) {
                return FadeTransition(
                  opacity: fadeAnimations[0],
                  child: ScaleTransition(
                    scale: scaleAnimations[0],
                    child: _AppCard(
                      name: 'Instagram',
                      iconWidget: Image.asset('assets/icons/insta.png',
                          width: 24, height: 24, gaplessPlayback: true),
                      hasTutorial: true,
                      accentColor: const Color(0xFFE4405F),
                    ),
                  ),
                );
              },
            );
          case 1:
            return AnimatedBuilder(
              animation: animationControllers[1],
              builder: (context, child) {
                return FadeTransition(
                  opacity: fadeAnimations[1],
                  child: ScaleTransition(
                    scale: scaleAnimations[1],
                    child: _AppCard(
                      name: 'Pinterest',
                      iconWidget: SvgPicture.asset('assets/icons/pinterest.svg',
                          width: 24, height: 24),
                      hasTutorial: true,
                      accentColor: const Color(0xFFE60023),
                      isPinterest: true,
                    ),
                  ),
                );
              },
            );
          case 2:
            return AnimatedBuilder(
              animation: animationControllers[2],
              builder: (context, child) {
                return FadeTransition(
                  opacity: fadeAnimations[2],
                  child: ScaleTransition(
                    scale: scaleAnimations[2],
                    child: _AppCard(
                      name: 'TikTok',
                      iconWidget: SvgPicture.asset(
                          'assets/icons/4362958_tiktok_logo_social media_icon.svg',
                          width: 24,
                          height: 24),
                      hasTutorial: true,
                      accentColor: const Color(0xFF000000),
                      isTikTok: true,
                    ),
                  ),
                );
              },
            );
          case 3:
            return AnimatedBuilder(
              animation: animationControllers[3],
              builder: (context, child) {
                return FadeTransition(
                  opacity: fadeAnimations[3],
                  child: ScaleTransition(
                    scale: scaleAnimations[3],
                    child: _AppCard(
                      name: 'Safari',
                      iconWidget: Image.asset('assets/icons/safari.png',
                          width: 24, height: 24, gaplessPlayback: true),
                      hasTutorial: true,
                      accentColor: const Color(0xFF0A84FF),
                      isSafari: true,
                    ),
                  ),
                );
              },
            );
          case 4:
            return AnimatedBuilder(
              animation: animationControllers[4],
              builder: (context, child) {
                return FadeTransition(
                  opacity: fadeAnimations[4],
                  child: ScaleTransition(
                    scale: scaleAnimations[4],
                    child: _AppCard(
                      name: 'Photos',
                      iconWidget: Image.asset('assets/icons/photos.png',
                          width: 24, height: 24, gaplessPlayback: true),
                      hasTutorial: true,
                      accentColor: const Color(0xFFFF9500),
                      isPhotos: true,
                    ),
                  ),
                );
              },
            );
          case 5:
          default:
            return AnimatedBuilder(
              animation: animationControllers[5],
              builder: (context, child) {
                return FadeTransition(
                  opacity: fadeAnimations[5],
                  child: ScaleTransition(
                    scale: scaleAnimations[5],
                    child: _AppCard(
                      name: 'Other Apps',
                      iconWidget: Icon(Icons.apps,
                          size: 24, color: Colors.grey.shade700),
                      hasTutorial: false,
                      accentColor: Colors.grey.shade400,
                    ),
                  ),
                );
              },
            );
        }
      },
    );
  }
}

class _AppCard extends ConsumerWidget {
  final String name;
  final Widget iconWidget;
  final bool hasTutorial;
  final Color accentColor;
  final bool isPinterest;
  final bool isTikTok;
  final bool isSafari;
  final bool isPhotos;

  const _AppCard({
    required this.name,
    required this.iconWidget,
    required this.hasTutorial,
    required this.accentColor,
    this.isPinterest = false,
    this.isTikTok = false,
    this.isSafari = false,
    this.isPhotos = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (hasTutorial) {
          if (isPinterest) {
            ref.read(pinterestTutorialStepProvider.notifier).state =
                PinterestTutorialStep.step1;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const PinterestTutorialPage(),
              ),
            );
          } else if (isTikTok) {
            ref.read(tiktokTutorialStepProvider.notifier).state =
                TikTokTutorialStep.step1;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const TikTokTutorialPage(),
              ),
            );
          } else if (isSafari) {
            ref.read(safariTutorialStepProvider.notifier).state =
                SafariTutorialStep.step1;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SafariTutorialPage(),
              ),
            );
          } else if (isPhotos) {
            ref.read(photosTutorialStepProvider.notifier).state =
                PhotosTutorialStep.step1;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const PhotosTutorialPage(),
              ),
            );
          } else {
            ref.read(tutorialStepProvider.notifier).state =
                TutorialStep.tapShare;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const InstagramTutorialPage(),
              ),
            );
          }
        }
        // Removed navigation to NotificationPermissionPage for "Other Apps"
        // Now tapping "Other Apps" does nothing
      },
      child: Container(
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: iconWidget,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    fontFamily: 'PlusJakartaSans',
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
