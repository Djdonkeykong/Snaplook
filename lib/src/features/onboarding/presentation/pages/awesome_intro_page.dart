import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../widgets/progress_indicator.dart';
import '../widgets/onboarding_bottom_bar.dart';
import 'add_first_style_page.dart';
import 'discovery_source_page.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../../../../services/onboarding_state_service.dart';
import '../../../auth/domain/providers/auth_provider.dart';

class AwesomeIntroPage extends ConsumerStatefulWidget {
  const AwesomeIntroPage({super.key});

  @override
  ConsumerState<AwesomeIntroPage> createState() => _AwesomeIntroPageState();
}

class _AwesomeIntroPageState extends ConsumerState<AwesomeIntroPage> {
  static const double _heroAspectRatio = 1170 / 2532; // matches asset dimensions
  late final AssetImage _heroImage;
  Future<void>? _heroPrecache;
  bool _isHeroReady = false;

  @override
  void initState() {
    super.initState();
    _heroImage = const AssetImage('assets/images/social_media_share_mobile_screen.png');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache image for instant loading and only show once decoded to avoid flicker.
    _heroPrecache ??= precacheImage(_heroImage, context).then((_) {
      if (mounted) {
        setState(() {
          _isHeroReady = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const SnaplookBackButton(),
        centerTitle: true,
        title: const OnboardingProgressIndicator(
          currentStep: 2,
          totalSteps: 14,
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
              'Share your style,\nfind the look',
              textAlign: TextAlign.start,
              style: TextStyle(
                fontSize: 34,
                fontFamily: 'PlusJakartaSans',
                letterSpacing: -1.0,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                height: 1.3,
              ),
            ),

            SizedBox(height: spacing.xl * 2),

            // Phone illustration
            Expanded(
              flex: 3,
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double targetWidth = constraints.maxWidth * 0.77;
                    return SizedBox(
                      width: targetWidth,
                      child: AspectRatio(
                        aspectRatio: _heroAspectRatio,
                        child: Stack(
                          children: [
                            if (_isHeroReady)
                              Image(
                                image: _heroImage,
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                              )
                            else
                              const SizedBox.expand(),
                            // White gradient overlay for fade effect
                            Positioned.fill(
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.center,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.transparent,
                                      Color(0x10FFFFFF),
                                      Color(0x20FFFFFF),
                                      Color(0x30FFFFFF),
                                      Color(0x50FFFFFF),
                                      Color(0x70FFFFFF),
                                      Color(0x90FFFFFF),
                                      Color(0xB0FFFFFF),
                                      Color(0xD0FFFFFF),
                                      Colors.white,
                                    ],
                                    stops: [
                                      0.0,
                                      0.4,
                                      0.5,
                                      0.55,
                                      0.6,
                                      0.65,
                                      0.7,
                                      0.8,
                                      0.85,
                                      0.92,
                                      1.0
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            SizedBox(height: spacing.xl),

            // Description text
            const Center(
              child: Text(
                'Share fashion images from Instagram, Pinterest,\nor any app to find similar styles and products!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'PlusJakartaSans',
                  letterSpacing: -0.3,
                ),
              ),
            ),

            SizedBox(height: spacing.l),
          ],
        ),
      ),
      bottomNavigationBar: OnboardingBottomBar(
        primaryButton: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();

              final user = ref.read(authServiceProvider).currentUser;
              if (user != null) {
                await OnboardingStateService().updateCheckpoint(
                  user.id,
                  OnboardingCheckpoint.tutorial,
                );
              }

              if (!context.mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AddFirstStylePage(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFf2003c),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text(
              'Show me how',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'PlusJakartaSans',
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
