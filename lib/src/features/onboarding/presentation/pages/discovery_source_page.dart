import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../shared/navigation/route_observer.dart';
import '../widgets/progress_indicator.dart';
import '../widgets/onboarding_bottom_bar.dart';
import 'awesome_intro_page.dart';

enum DiscoverySource { instagram, facebook, tiktok, youtube, google, tv }

final selectedDiscoverySourceProvider = StateProvider<DiscoverySource?>((ref) => null);

class DiscoverySourcePage extends ConsumerStatefulWidget {
  const DiscoverySourcePage({super.key});

  @override
  ConsumerState<DiscoverySourcePage> createState() => _DiscoverySourcePageState();
}

class _DiscoverySourcePageState extends ConsumerState<DiscoverySourcePage>
    with TickerProviderStateMixin, RouteAware {
  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<double>> _scaleAnimations;

  bool _isRouteAware = false;

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
    final route = ModalRoute.of(context);
    if (!_isRouteAware && route is PageRoute) {
      routeObserver.subscribe(this, route);
      _isRouteAware = true;
      if (route.isCurrent) {
        _startStaggeredAnimation();
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
    _startStaggeredAnimation();
  }

  @override
  void didPopNext() {
    _startStaggeredAnimation();
  }

  @override
  Widget build(BuildContext context) {
    final selectedSource = ref.watch(selectedDiscoverySourceProvider);
    final spacing = context.spacing;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.black,
              size: 20,
            ),
          ),
        ),
        centerTitle: true,
        title: const OnboardingProgressIndicator(
          currentStep: 2,
          totalSteps: 5,
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
              'Where did you hear\nabout us?',
              style: TextStyle(
                fontSize: 34,
                fontFamily: 'PlusJakartaSans',
                letterSpacing: -1.0,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                height: 1.3,
              ),
            ),

            SizedBox(height: spacing.l),

            // Discovery Source Options
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.only(bottom: spacing.l),
                physics: const BouncingScrollPhysics(),
                itemCount: 6,
                separatorBuilder: (_, __) => SizedBox(height: spacing.l),
                itemBuilder: (context, index) {
                  switch (index) {
                    case 0:
                      return AnimatedBuilder(
                        animation: _animationControllers[0],
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: _fadeAnimations[0],
                            child: ScaleTransition(
                              scale: _scaleAnimations[0],
                              child: _DiscoverySourceOption(
                                source: DiscoverySource.instagram,
                                label: 'Instagram',
                                icon: Image.asset('assets/icons/insta.png', width: 24, height: 24),
                                isSelected: selectedSource == DiscoverySource.instagram,
                                onTap: () => ref.read(selectedDiscoverySourceProvider.notifier).state = DiscoverySource.instagram,
                              ),
                            ),
                          );
                        },
                      );
                    case 1:
                      return AnimatedBuilder(
                        animation: _animationControllers[1],
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: _fadeAnimations[1],
                            child: ScaleTransition(
                              scale: _scaleAnimations[1],
                              child: _DiscoverySourceOption(
                                source: DiscoverySource.facebook,
                                label: 'Facebook',
                                icon: SvgPicture.asset('assets/icons/5296499_fb_facebook_facebook logo_icon.svg', width: 24, height: 24),
                                isSelected: selectedSource == DiscoverySource.facebook,
                                onTap: () => ref.read(selectedDiscoverySourceProvider.notifier).state = DiscoverySource.facebook,
                              ),
                            ),
                          );
                        },
                      );
                    case 2:
                      return AnimatedBuilder(
                        animation: _animationControllers[2],
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: _fadeAnimations[2],
                            child: ScaleTransition(
                              scale: _scaleAnimations[2],
                              child: _DiscoverySourceOption(
                                source: DiscoverySource.tiktok,
                                label: 'TikTok',
                                icon: SvgPicture.asset('assets/icons/4362958_tiktok_logo_social media_icon.svg', width: 24, height: 24),
                                isSelected: selectedSource == DiscoverySource.tiktok,
                                onTap: () => ref.read(selectedDiscoverySourceProvider.notifier).state = DiscoverySource.tiktok,
                              ),
                            ),
                          );
                        },
                      );
                    case 3:
                      return AnimatedBuilder(
                        animation: _animationControllers[3],
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: _fadeAnimations[3],
                            child: ScaleTransition(
                              scale: _scaleAnimations[3],
                              child: _DiscoverySourceOption(
                                source: DiscoverySource.youtube,
                                label: 'YouTube',
                                icon: SvgPicture.asset('assets/icons/5296521_play_video_vlog_youtube_youtube logo_icon.svg', width: 24, height: 24),
                                isSelected: selectedSource == DiscoverySource.youtube,
                                onTap: () => ref.read(selectedDiscoverySourceProvider.notifier).state = DiscoverySource.youtube,
                              ),
                            ),
                          );
                        },
                      );
                    case 4:
                      return AnimatedBuilder(
                        animation: _animationControllers[4],
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: _fadeAnimations[4],
                            child: ScaleTransition(
                              scale: _scaleAnimations[4],
                              child: _DiscoverySourceOption(
                                source: DiscoverySource.google,
                                label: 'Google',
                                icon: SvgPicture.asset('assets/icons/4975303_search_web_internet_google search_search engine_icon.svg', width: 24, height: 24),
                                isSelected: selectedSource == DiscoverySource.google,
                                onTap: () => ref.read(selectedDiscoverySourceProvider.notifier).state = DiscoverySource.google,
                              ),
                            ),
                          );
                        },
                      );
                    case 5:
                    default:
                      return AnimatedBuilder(
                        animation: _animationControllers[5],
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: _fadeAnimations[5],
                            child: ScaleTransition(
                              scale: _scaleAnimations[5],
                              child: _DiscoverySourceOption(
                                source: DiscoverySource.tv,
                                label: 'TV',
                                icon: SvgPicture.asset('assets/icons/9035017_tv_icon.svg', width: 24, height: 24),
                                isSelected: selectedSource == DiscoverySource.tv,
                                onTap: () => ref.read(selectedDiscoverySourceProvider.notifier).state = DiscoverySource.tv,
                              ),
                            ),
                          );
                        },
                      );
                  }
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: OnboardingBottomBar(
        primaryButton: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: selectedSource != null
                ? () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AwesomeIntroPage(),
                      ),
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: selectedSource != null ? const Color(0xFFf2003c) : Colors.grey.shade300,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: Text(
              'Continue',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'PlusJakartaSans',
                letterSpacing: -0.2,
                color: selectedSource != null ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoverySourceOption extends StatelessWidget {
  final DiscoverySource source;
  final String label;
  final Widget icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _DiscoverySourceOption({
    required this.source,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFf2003c) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: icon,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom brand icons
class _InstagramIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE1306C), Color(0xFFFD1D1D), Color(0xFFF77737)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
    );
  }
}

class _FacebookIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF1877F2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Center(
        child: Text(
          'f',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _TikTokIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Center(
        child: Text(
          '♪',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _YouTubeIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFFFF0000),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            color: Color(0xFF4285F4),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
