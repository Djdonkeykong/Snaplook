import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_refresh/easy_refresh.dart';
import '../../domain/providers/image_provider.dart';
import '../../domain/providers/pending_share_provider.dart';
import '../../../detection/presentation/pages/detection_page.dart';
import '../../../paywall/models/subscription_plan.dart';
import '../../../paywall/providers/credit_provider.dart';
import '../../../wardrobe/domain/providers/history_provider.dart';
import '../../../wardrobe/presentation/widgets/history_card.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/bottom_sheet_handle.dart';
import '../../../../shared/widgets/snaplook_circular_icon_button.dart';
import '../services/pip_tutorial_service.dart';
import '../../../../../core/theme/snaplook_icons.dart';
import '../../../../../shared/navigation/main_navigation.dart';

enum _TutorialSource {
  instagram,
  pinterest,
  tiktok,
  safari,
  photos,
  imdb,
  x,
  other,
}

const String _snapActionIcon = 'assets/icons/solar--camera-square-bold-new.svg';
const String _uploadActionIcon = 'assets/icons/upload_filled.svg';
const String _tutorialActionIcon = 'assets/icons/tutorials_filled.svg';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  ProviderSubscription<XFile?>? _pendingShareListener;
  bool _isProcessingPendingNavigation = false;
  final PipTutorialService _pipTutorialService = PipTutorialService();
  _TutorialSource? _loadingTutorialSource;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        _checkPendingSharedImage();
      });
    });

    _pendingShareListener ??= ref.listenManual<XFile?>(
      pendingSharedImageProvider,
      (previous, next) {
        if (next != null && mounted) {
          _handlePendingSharedImage(next);
        }
      },
    );
  }

  void _checkPendingSharedImage() {
    final pendingImage = ref.read(pendingSharedImageProvider);

    if (pendingImage != null && mounted) {
      _handlePendingSharedImage(pendingImage);
    }
  }

  void _handlePendingSharedImage(XFile image) {
    if (_isProcessingPendingNavigation || !mounted) {
      return;
    }

    if (ref.read(shareNavigationInProgressProvider)) {
      return;
    }

    _isProcessingPendingNavigation = true;

    final sourceUrl = ref.read(pendingShareSourceUrlProvider);

    ref.read(pendingSharedImageProvider.notifier).state = null;
    ref.read(pendingShareSourceUrlProvider.notifier).state = null;

    () async {
      try {
        ref.read(selectedImagesProvider.notifier).setImage(image);

        final fileImage = FileImage(File(image.path));
        await precacheImage(fileImage, context).catchError((_) {});

        if (!mounted) return;

        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (context) {
              return DetectionPage(
                searchType: 'share',
                sourceUrl: sourceUrl,
              );
            },
          ),
        );

      } catch (e) {
        debugPrint('Error handling pending shared image: $e');
      } finally {
        _isProcessingPendingNavigation = false;
      }
    }();
  }

  @override
  void dispose() {
    _pendingShareListener?.close();
    WidgetsBinding.instance.removeObserver(this);
    _pipTutorialService.stopTutorial();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pipTutorialService.stopTutorial();
    }
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
          final fileImage = FileImage(File(image.path));
          await precacheImage(fileImage, context).catchError((_) {});

          if (mounted) {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(builder: (context) => const DetectionPage()),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error picking image: $e',
              style: context.snackTextStyle(),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final spacing = context.spacing;
    final radius = context.radius;
    final historyAsync = ref.watch(historyProvider);

    final searches = historyAsync.valueOrNull ?? [];
    final isHistoryLoading = historyAsync.isLoading && !historyAsync.hasValue;
    final hasHistoryError = historyAsync.hasError && !historyAsync.hasValue;
    final hasHistory = searches.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Main content
          if (isHistoryLoading)
            Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                strokeWidth: 2,
              ),
            )
          else if (hasHistoryError)
            _buildErrorState(colorScheme)
          else if (!hasHistory)
            _buildCtaView(colorScheme)
          else
            _buildHistoryList(searches, spacing, radius, colorScheme),

          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: _buildTopBar(colorScheme, hasHistory),
          ),

          // Floating action bar (only when history exists)
          if (hasHistory)
            Positioned(
              bottom: 24,
              left: MediaQuery.of(context).size.width * 0.09,
              right: MediaQuery.of(context).size.width * 0.09,
              child: _FloatingActionBar(
                onSnapTap: () => _pickImage(ImageSource.camera),
                onUploadTap: () => _pickImage(ImageSource.gallery),
                onTutorialsTap: () => _showTutorialOptionsSheet(),
                onInfoTap: () => _showInfoBottomSheet(context),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(ColorScheme colorScheme, bool hasHistory) {
    return Row(
      children: [
        // Left spacer to balance
        SizedBox(width: hasHistory ? 40 : 40),
        // Center logo
        Expanded(
          child: Center(
            child: Image.asset(
              'assets/images/logo.png',
              height: 32,
              fit: BoxFit.contain,
            ),
          ),
        ),
        // Info icon - only when no history
        if (!hasHistory)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showInfoBottomSheet(context);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/info_icon.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    colorScheme.onSurface,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          )
        else
          const SizedBox(width: 40),
      ],
    );
  }

  Widget _buildCtaView(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/home-polaroids.png',
            width: 200,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Scan your first image\nwith Snaplook',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontFamily: 'PlusJakartaSans',
                letterSpacing: -0.5,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              _showImportOptionsSheet();
            },
            child: Container(
              width: 88,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: AppColors.secondary,
                  width: 1.0,
                ),
              ),
              child: Icon(
                Icons.add,
                size: 28,
                color: colorScheme.surface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ColorScheme colorScheme) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: colorScheme.error),
          const SizedBox(height: 16),
          Text(
            'Error loading history',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ref.invalidate(historyProvider);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.secondary,
              foregroundColor: colorScheme.onSecondary,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(
    List<Map<String, dynamic>> searches,
    AppSpacingExtension spacing,
    AppRadiusExtension radius,
    ColorScheme colorScheme,
  ) {
    return EasyRefresh(
      onRefresh: () async {
        ref.invalidate(historyProvider);
      },
      header: ClassicHeader(
        dragText: '',
        armedText: '',
        readyText: '',
        processingText: '',
        processedText: '',
        noMoreText: '',
        failedText: '',
        messageText: '',
        safeArea: false,
        showMessage: false,
        showText: false,
        processedDuration: Duration.zero,
        succeededIcon: const SizedBox.shrink(),
        iconTheme: const IconThemeData(
          color: Color(0xFFf2003c),
          size: 24,
        ),
        backgroundColor: colorScheme.surface,
      ),
      child: ListView.builder(
        // Account for top bar and floating bar
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 68,
          bottom: 110,
        ),
        itemCount: searches.length,
        itemBuilder: (context, index) {
          final search = searches[index];
          return Padding(
            padding: EdgeInsets.only(bottom: spacing.m),
            child: HistoryCard(
              search: search,
              spacing: spacing,
              radius: radius,
            ),
          );
        },
      ),
    );
  }

  void _showTutorialOptionsSheet() {
    final options = [
      _TutorialOptionData(
        label: 'Instagram',
        source: _TutorialSource.instagram,
        iconBuilder: () => Image.asset(
          'assets/icons/insta.png',
          width: 24,
          height: 24,
          gaplessPlayback: true,
        ),
      ),
      _TutorialOptionData(
        label: 'Pinterest',
        source: _TutorialSource.pinterest,
        iconBuilder: () => SvgPicture.asset(
          'assets/icons/pinterest.svg',
          width: 24,
          height: 24,
        ),
      ),
      _TutorialOptionData(
        label: 'TikTok',
        source: _TutorialSource.tiktok,
        iconBuilder: () => SvgPicture.asset(
          'assets/icons/4362958_tiktok_logo_social media_icon.svg',
          width: 24,
          height: 24,
        ),
      ),
      _TutorialOptionData(
        label: 'Photos',
        source: _TutorialSource.photos,
        iconBuilder: () => Image.asset(
          'assets/icons/photos.png',
          width: 24,
          height: 24,
          gaplessPlayback: true,
        ),
      ),
      _TutorialOptionData(
        label: 'IMDb',
        source: _TutorialSource.imdb,
        iconBuilder: () => Image.asset(
          'assets/icons/imdb.png',
          width: 24,
          height: 24,
          gaplessPlayback: true,
        ),
      ),
      _TutorialOptionData(
        label: 'Web Browsers',
        source: _TutorialSource.safari,
        iconBuilder: () => const _BrowserIconStack(),
      ),
      _TutorialOptionData(
        label: 'X',
        source: _TutorialSource.x,
        iconBuilder: () => Image.asset(
          'assets/icons/x-logo.png',
          width: 24,
          height: 24,
          gaplessPlayback: true,
        ),
      ),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (sheetContext) {
        final spacing = sheetContext.spacing;
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            return FractionallySizedBox(
              heightFactor: 0.9,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Stack(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing.l,
                          vertical: spacing.l,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BottomSheetHandle(
                              margin: EdgeInsets.only(bottom: spacing.m),
                            ),
                            Text(
                              'Share your look',
                              style: TextStyle(
                                fontSize: 34,
                                fontFamily: 'PlusJakartaSans',
                                letterSpacing: -1.0,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                                height: 1.3,
                              ),
                            ),
                            SizedBox(height: spacing.xs),
                            Text(
                              'Learn to share from your favorite apps',
                              style: TextStyle(
                                fontSize: 16,
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'PlusJakartaSans',
                              ),
                            ),
                            SizedBox(height: spacing.l),
                            Expanded(
                              child: ListView.separated(
                                physics: const BouncingScrollPhysics(),
                                padding: EdgeInsets.only(bottom: spacing.l),
                                itemCount: options.length,
                                separatorBuilder: (_, __) =>
                                    SizedBox(height: spacing.l),
                                itemBuilder: (_, index) {
                                  final option = options[index];
                                  return _TutorialAppCard(
                                    label: option.label,
                                    iconWidget: option.iconBuilder(),
                                    isEnabled: option.isEnabled,
                                    statusLabel: option.statusLabel,
                                    isLoading:
                                        _loadingTutorialSource == option.source,
                                    onTap: () => _onTutorialOptionSelected(
                                      option.source,
                                      sheetContext,
                                      sheetSetState,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: spacing.l,
                        right: spacing.l,
                        child: SnaplookCircularIconButton(
                          icon: Icons.close,
                          iconSize: 18,
                          backgroundColor:
                              colorScheme.surfaceContainerHighest,
                          iconColor: colorScheme.onSurface,
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          tooltip: 'Close',
                          semanticLabel: 'Close',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _onTutorialOptionSelected(
    _TutorialSource source,
    BuildContext sheetContext,
    StateSetter sheetSetState,
  ) async {
    if (!mounted) return;

    PipTutorialTarget? target;
    switch (source) {
      case _TutorialSource.instagram:
        target = PipTutorialTarget.instagram;
        break;
      case _TutorialSource.pinterest:
        target = PipTutorialTarget.pinterest;
        break;
      case _TutorialSource.photos:
        target = PipTutorialTarget.photos;
        break;
      case _TutorialSource.imdb:
        target = PipTutorialTarget.imdb;
        break;
      case _TutorialSource.safari:
        target = PipTutorialTarget.safari;
        break;
      case _TutorialSource.tiktok:
        target = PipTutorialTarget.tiktok;
        break;
      case _TutorialSource.x:
        target = PipTutorialTarget.x;
        break;
      default:
        return;
    }

    if (_loadingTutorialSource != null) {
      return;
    }

    setState(() {
      _loadingTutorialSource = source;
    });
    sheetSetState(() {});

    try {
      HapticFeedback.mediumImpact();

      await Future.delayed(const Duration(milliseconds: 1500));

      if (sheetContext.mounted) {
        await Navigator.of(sheetContext).maybePop();
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (!mounted) return;
      await _launchPipTutorial(target);
    } finally {
      if (mounted) {
        setState(() {
          _loadingTutorialSource = null;
        });
      }
      sheetSetState(() {});
    }
  }

  Future<void> _launchPipTutorial(PipTutorialTarget target) async {
    const instagramDeepLink =
        'https://www.instagram.com/p/DQSaR_FEsU8/?igsh=MTEyNzJuaXF6cDlmNA==';
    const pinterestDeepLink = 'https://pin.it/223au9vpX';
    const tiktokDeepLink = 'https://vm.tiktok.com/ZNRr4FE31/';
    const imdbDeepLink = 'https://www.imdb.com/';
    const xDeepLink =
        'https://x.com/iamjhud/status/1962314855802651108?s=46';
    const safariDeepLink =
        'https://media.glamour.com/photos/5ae09534ed441129f636ed0b/master/w_1600%2Cc_limit/Aimee_song_of_style_caroline_constas_polka_dot_puffer_sleeves_top_amo_distressed_jeans_dior_kitten_heels_pumps_le_specs_adam_selman_sunglasses_straw_bag_earrings.jpg';
    final videoAsset = switch (target) {
      PipTutorialTarget.instagram => 'assets/videos/instagram-tutorial.mp4',
      PipTutorialTarget.pinterest => 'assets/videos/pinterest-tutorial.mp4',
      PipTutorialTarget.tiktok => 'assets/videos/tiktok-tutorial.mp4',
      PipTutorialTarget.photos => 'assets/videos/photos-tutorial.mp4',
      PipTutorialTarget.imdb => 'assets/videos/imdb-tutorial.mp4',
      PipTutorialTarget.x => 'assets/videos/x-tutorial.mp4',
      PipTutorialTarget.safari => 'assets/videos/web-tutorial.mp4',
      _ => 'assets/videos/pip-test.mp4',
    };
    final deepLink = switch (target) {
      PipTutorialTarget.instagram => instagramDeepLink,
      PipTutorialTarget.pinterest => pinterestDeepLink,
      PipTutorialTarget.tiktok => tiktokDeepLink,
      PipTutorialTarget.photos => null,
      PipTutorialTarget.imdb => imdbDeepLink,
      PipTutorialTarget.x => xDeepLink,
      PipTutorialTarget.safari => safariDeepLink,
      _ => null,
    };
    try {
      await _pipTutorialService.startTutorial(
        target: target,
        videoAsset: videoAsset,
        deepLink: deepLink,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Picture-in-Picture tutorial not available right now.',
            style: context.snackTextStyle(
              merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showImportOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (sheetContext) {
        return _ImportOptionsBottomSheet(
          onSnapTap: () async {
            Navigator.of(sheetContext).pop();
            await Future.delayed(const Duration(milliseconds: 120));
            if (!mounted) return;
            _pickImage(ImageSource.camera);
          },
          onUploadTap: () async {
            Navigator.of(sheetContext).pop();
            await Future.delayed(const Duration(milliseconds: 120));
            if (!mounted) return;
            _pickImage(ImageSource.gallery);
          },
          onShareFromAppTap: () async {
            Navigator.of(sheetContext).pop();
            await Future.delayed(const Duration(milliseconds: 120));
            if (!mounted) return;
            _showTutorialOptionsSheet();
          },
        );
      },
    );
  }

  Future<void> _showInfoBottomSheet(BuildContext context) async {
    final spacing = context.spacing;

    await ref.read(creditBalanceProvider.notifier).refresh();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => _InfoBottomSheetContent(spacing: spacing),
    );
  }
}

class _FloatingActionBar extends StatelessWidget {
  final VoidCallback onSnapTap;
  final VoidCallback onUploadTap;
  final VoidCallback onTutorialsTap;
  final VoidCallback onInfoTap;

  const _FloatingActionBar({
    required this.onSnapTap,
    required this.onUploadTap,
    required this.onTutorialsTap,
    required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFf2003c),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(
          color: const Color(0xFFf2003c),
          width: 1.0,
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
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Expanded(
              child: _FloatingActionButtonSvg(
                svgIcon: _snapActionIcon,
                label: 'Snap',
                onTap: onSnapTap,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _FloatingActionButtonSvg(
                svgIcon: _uploadActionIcon,
                label: 'Upload',
                onTap: onUploadTap,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _FloatingActionButtonSvg(
                svgIcon: _tutorialActionIcon,
                label: 'Tutorials',
                onTap: onTutorialsTap,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _FloatingActionButtonSvg(
                svgIcon: 'assets/icons/info_icon.svg',
                label: 'Info',
                onTap: onInfoTap,
              ),
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
    return GestureDetector(
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
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
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
    );
  }
}

class _ImportOptionsBottomSheet extends StatelessWidget {
  final VoidCallback onSnapTap;
  final VoidCallback onUploadTap;
  final VoidCallback onShareFromAppTap;

  const _ImportOptionsBottomSheet({
    required this.onSnapTap,
    required this.onUploadTap,
    required this.onShareFromAppTap,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.l,
                vertical: spacing.l,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BottomSheetHandle(
                    margin: EdgeInsets.only(bottom: spacing.m),
                  ),
                  Text(
                    'Find your look',
                    style: TextStyle(
                      fontSize: 34,
                      fontFamily: 'PlusJakartaSans',
                      letterSpacing: -1.0,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    'Pick your starting point',
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                  SizedBox(height: spacing.l),
                  Row(
                    children: [
                      Expanded(
                        child: _ImportOptionTile(
                          svgIcon: _snapActionIcon,
                          label: 'Snap',
                          onTap: onSnapTap,
                        ),
                      ),
                      SizedBox(width: spacing.s),
                      Expanded(
                        child: _ImportOptionTile(
                          svgIcon: _uploadActionIcon,
                          label: 'Upload',
                          onTap: onUploadTap,
                        ),
                      ),
                      SizedBox(width: spacing.s),
                      Expanded(
                        child: _ImportOptionTile(
                          svgIcon: _tutorialActionIcon,
                          label: 'Share',
                          onTap: onShareFromAppTap,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing.l),
                ],
              ),
            ),
            Positioned(
              top: spacing.l,
              right: spacing.l,
              child: SnaplookCircularIconButton(
                icon: Icons.close,
                iconSize: 18,
                backgroundColor: colorScheme.surfaceContainerHighest,
                iconColor: colorScheme.onSurface,
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Close',
                semanticLabel: 'Close',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportOptionTile extends StatelessWidget {
  final String svgIcon;
  final String label;
  final VoidCallback onTap;

  const _ImportOptionTile({
    required this.svgIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        height: 84,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              svgIcon,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(colorScheme.onSurface, BlendMode.srcIn),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
                fontFamily: 'PlusJakartaSans',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBottomSheetContent extends ConsumerWidget {
  final AppSpacingExtension spacing;

  const _InfoBottomSheetContent({required this.spacing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditBalance = ref.watch(creditBalanceProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.all(spacing.l),
              child: creditBalance.when(
                      data: (balance) {
                        final membershipType = balance.hasActiveSubscription
                            ? (balance.isTrialSubscription ? 'Premium (Trial)' : 'Premium')
                            : 'Free';
                        final maxCredits =
                            SubscriptionPlan.monthly.creditsPerMonth;
                        final creditsRemaining =
                            balance.availableCredits.clamp(0, maxCredits).toInt();
                        final creditsPercentage = maxCredits > 0
                            ? (creditsRemaining / maxCredits).clamp(0.0, 1.0)
                            : 0.0;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BottomSheetHandle(
                              margin: EdgeInsets.only(bottom: spacing.m),
                            ),

                            Text(
                              'Membership',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurfaceVariant,
                                fontFamily: 'PlusJakartaSans',
                              ),
                            ),

                            const SizedBox(height: 2),

                            Text(
                              membershipType,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                                fontFamily: 'PlusJakartaSans',
                                letterSpacing: -0.3,
                              ),
                            ),

                            SizedBox(height: spacing.l),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '$creditsRemaining',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? colorScheme.onSurface
                                        : AppColors.secondary,
                                    fontFamily: 'PlusJakartaSans',
                                    letterSpacing: -2,
                                  ),
                                ),
                                Text(
                                  ' / $maxCredits',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurfaceVariant,
                                    fontFamily: 'PlusJakartaSans',
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: spacing.xs),

                            Text(
                              'Credits Remaining',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                                fontFamily: 'PlusJakartaSans',
                              ),
                            ),

                            SizedBox(height: spacing.l),

                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: creditsPercentage,
                                minHeight: 6,
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).brightness == Brightness.dark
                                      ? colorScheme.onSurface
                                      : AppColors.secondary,
                                ),
                              ),
                            ),

                            SizedBox(height: spacing.m),

                            Text(
                              'Resets monthly on the 1st',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                                fontFamily: 'PlusJakartaSans',
                              ),
                            ),

                            SizedBox(height: spacing.l),

                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(spacing.m),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withOpacity(
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? 0.4
                                      : 0.6,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  SizedBox(width: spacing.m),
                                  Expanded(
                                    child: Text(
                                      'Each garment costs 1 credit. If there are multiple items in a photo, cropping to just one helps conserve credits.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: colorScheme.onSurfaceVariant,
                                        fontFamily: 'PlusJakartaSans',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: spacing.l),
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (error, stackTrace) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BottomSheetHandle(
                            margin: EdgeInsets.only(bottom: spacing.m),
                          ),
                          Icon(
                            Icons.error_outline,
                            size: 28,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          SizedBox(height: spacing.s),
                          Text(
                            'Unable to load credits',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                              fontFamily: 'PlusJakartaSans',
                            ),
                          ),
                          SizedBox(height: spacing.xs),
                          Text(
                            'Please try again.',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                              fontFamily: 'PlusJakartaSans',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: spacing.m),
                        ],
                      ),
                    ),
            ),
            Positioned(
              top: spacing.l,
              right: spacing.l,
              child: SnaplookCircularIconButton(
                icon: Icons.close,
                iconSize: 18,
                backgroundColor: colorScheme.surfaceContainerHighest,
                iconColor: colorScheme.onSurface,
                onPressed: () => Navigator.pop(context),
                tooltip: 'Close',
                semanticLabel: 'Close',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialOptionData {
  final String label;
  final _TutorialSource source;
  final Widget Function() iconBuilder;
  final bool isEnabled;
  final String? statusLabel;

  const _TutorialOptionData({
    required this.label,
    required this.source,
    required this.iconBuilder,
    this.isEnabled = true,
    this.statusLabel,
  });
}

class _TutorialAppCard extends StatelessWidget {
  final String label;
  final Widget iconWidget;
  final VoidCallback onTap;
  final bool isLoading;
  final bool isEnabled;
  final String? statusLabel;

  const _TutorialAppCard({
    required this.label,
    required this.iconWidget,
    required this.onTap,
    this.isLoading = false,
    this.isEnabled = true,
    this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        if (isLoading) return;
        if (!isEnabled) {
          HapticFeedback.lightImpact();
          return;
        }
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                          ),
                        )
                      : Opacity(
                          opacity: isEnabled ? 1 : 0.5,
                          child: iconWidget,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  isLoading ? 'Preparing your tutorial...' : label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isEnabled
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                    fontFamily: 'PlusJakartaSans',
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (isLoading)
                const SizedBox.shrink()
              else if (!isEnabled)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Text(
                    statusLabel ?? 'Coming soon',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                      fontFamily: 'PlusJakartaSans',
                      letterSpacing: -0.2,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrowserIconStack extends StatelessWidget {
  final double size;

  const _BrowserIconStack({this.size = 28});

  @override
  Widget build(BuildContext context) {
    final iconSize = size * 0.62;
    final step = iconSize * 0.6;
    final totalWidth = iconSize + (step * 2);

    return SizedBox(
      width: totalWidth,
      height: iconSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            child: Image.asset(
              'assets/icons/firefox.png',
              width: iconSize,
              height: iconSize,
              gaplessPlayback: true,
            ),
          ),
          Positioned(
            left: step,
            child: Image.asset(
              'assets/icons/brave.png',
              width: iconSize,
              height: iconSize,
              gaplessPlayback: true,
            ),
          ),
          Positioned(
            left: step * 2,
            child: Image.asset(
              'assets/icons/safari.png',
              width: iconSize,
              height: iconSize,
              gaplessPlayback: true,
            ),
          ),
        ],
      ),
    );
  }
}
