import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'shared/navigation/main_navigation.dart';
import 'src/features/home/domain/providers/image_provider.dart';
import 'src/features/detection/presentation/pages/detection_page.dart';
import 'src/features/auth/presentation/pages/login_page.dart';
import 'src/features/auth/domain/providers/auth_provider.dart';
import 'src/features/splash/presentation/pages/splash_page.dart';
import 'src/services/instagram_service.dart';
import 'src/shared/services/video_preloader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  // Preload video immediately on app startup
  VideoPreloader.instance.preloadShareVideo();

  runApp(const ProviderScope(child: SnaplookApp()));
}

class SnaplookApp extends ConsumerStatefulWidget {
  const SnaplookApp({super.key});

  @override
  ConsumerState<SnaplookApp> createState() => _SnaplookAppState();
}

class _SnaplookAppState extends ConsumerState<SnaplookApp> with TickerProviderStateMixin {
  late StreamSubscription _intentSub;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Progress tracking for Instagram downloads
  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize progress animation controller
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500), // 500ms for smooth transitions
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeInOut,
    ));

    _progressAnimation.addListener(() {
      setState(() {
        // Update the visual progress with animated value
      });
    });

    // Listen to media sharing coming from outside the app while the app is in the memory.
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      print("===== MEDIA STREAM =====");
      print("Received shared media: ${value.length} files");
      for (var file in value) {
        print("Shared file: ${file.path}");
        print("  - type: ${file.type}");
        print("  - mimeType: ${file.mimeType}");
        print("  - thumbnail: ${file.thumbnail}");
        print("  - duration: ${file.duration}");
      }
      if (value.isNotEmpty) {
        _handleSharedMedia(value);
      } else {
        print("No media files received in stream");
      }
    }, onError: (err) {
      print("getIntentDataStream error: $err");
    });

    // Get the media sharing coming from outside the app while the app is closed.
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      print("===== INITIAL MEDIA =====");
      print("Initial shared media: ${value.length} files");
      for (var file in value) {
        print("Initial shared file: ${file.path}");
        print("  - type: ${file.type}");
        print("  - mimeType: ${file.mimeType}");
        print("  - thumbnail: ${file.thumbnail}");
        print("  - duration: ${file.duration}");
      }
      if (value.isNotEmpty) {
        _handleSharedMedia(value);
        // Tell the library that we are done processing the intent.
        ReceiveSharingIntent.instance.reset();
      } else {
        print("No initial media files received");
      }
    }).catchError((error) {
      print("Error getting initial media: $error");
    });
  }

  void _handleSharedMedia(List<SharedMediaFile> sharedFiles) {
    if (sharedFiles.isEmpty) return;

    final sharedFile = sharedFiles.first;

    if (sharedFile.type == SharedMediaType.image) {
      // Handle actual image files
      final imageFile = XFile(sharedFile.path);
      ref.read(selectedImagesProvider.notifier).setImage(imageFile);

      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => const DetectionPage(),
        ),
      );
    } else if (sharedFile.type == SharedMediaType.text) {
      // Handle text sharing (like Instagram URLs)
      _handleSharedText(sharedFile.path);
    }
  }

  void _handleSharedText(String text) async {
    print("Handling shared text: $text");

    // Check if it's an Instagram URL
    if (InstagramService.isInstagramUrl(text)) {
      await _downloadInstagramImage(text);
    } else {
      _showUnsupportedMessage(text);
    }
  }

  Future<void> _downloadInstagramImage(String instagramUrl) async {
    // Reset progress animation to start fresh
    _progressAnimationController.reset();

    // Show progress dialog
    _showProgressDialog();

    try {
      // Step 1: Initialize
      _updateProgress(0.1);
      await Future.delayed(const Duration(milliseconds: 300));

      // Step 2: API Request
      _updateProgress(0.3);

      // Run the download in background while updating progress
      final downloadFuture = InstagramService.downloadImageFromInstagramUrl(instagramUrl);

      // Simulate progress stages while actual download happens
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _updateProgress(0.5);
      });

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) _updateProgress(0.7);
      });

      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) _updateProgress(0.9);
      });

      final imageFiles = await downloadFuture;

      // Complete
      _updateProgress(1.0);
      await Future.delayed(const Duration(milliseconds: 200));

      // Hide progress dialog
      if (navigatorKey.currentContext != null) {
        Navigator.of(navigatorKey.currentContext!).pop();
      }

      if (imageFiles.isNotEmpty) {
        print('📸 Downloaded ${imageFiles.length} image(s) from Instagram');
        if (imageFiles.length > 1) {
          print('🎠 Carousel post detected - setting up image slider');
        }

        // Set all downloaded images in the provider
        ref.read(selectedImagesProvider.notifier).setImages(imageFiles);

        // Navigate to detection page
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => const DetectionPage(),
          ),
        );
      } else {
        _showInstagramErrorMessage();
      }
    } catch (e) {
      print('Error downloading Instagram image: $e');

      // Hide progress dialog
      if (navigatorKey.currentContext != null) {
        Navigator.of(navigatorKey.currentContext!).pop();
      }

      _showInstagramErrorMessage();
    }
  }

  void _showProgressDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentContext != null) {
        showDialog(
          context: navigatorKey.currentContext!,
          barrierDismissible: false,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Instagram Image Download',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) => CircularProgressIndicator(
                        value: _progressAnimation.value,
                        strokeWidth: 6,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.secondary, // Golden yellow
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      }
    });
  }

  void _updateProgress(double progress) {
    // Update the animation to smoothly transition to new progress value
    final Animation<double> progressTween = Tween<double>(
      begin: _progressAnimation.value,
      end: progress,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeInOut,
    ));

    // Reset and start animation from current position to new progress
    _progressAnimationController.reset();
    _progressAnimation = progressTween;

    _progressAnimation.addListener(() {
      setState(() {
        // Trigger rebuild with new animated value
      });
    });

    _progressAnimationController.forward();
  }


  void _showInstagramErrorMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentContext != null) {
        showDialog(
          context: navigatorKey.currentContext!,
          builder: (context) => AlertDialog(
            title: const Text('Instagram Image Download Failed'),
            content: const Text(
              'Unable to download the image from Instagram. This can happen due to:\n\n'
              '• Privacy settings on the post\n'
              '• Network connectivity issues\n'
              '• Instagram\'s anti-scraping measures\n\n'
              'Try taking a screenshot instead and use the "Upload" button to analyze it.'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    });
  }

  void _showUnsupportedMessage(String content) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentContext != null) {
        showDialog(
          context: navigatorKey.currentContext!,
          builder: (context) => AlertDialog(
            title: const Text('Text Share Detected'),
            content: Text(
              'Received text content, but Snaplook analyzes images.\n\n'
              'Content: ${content.length > 100 ? content.substring(0, 100) + '...' : content}\n\n'
              'Please share an image file instead.'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _intentSub.cancel();
    _progressAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Snaplook',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      home: const SplashPage(),
    );
  }
}