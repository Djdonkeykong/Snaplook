import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'shared/navigation/main_navigation.dart';
import 'src/features/home/domain/providers/image_provider.dart';
import 'src/features/home/domain/providers/pending_share_provider.dart';
import 'src/features/detection/presentation/pages/detection_page.dart';
import 'src/features/auth/presentation/pages/login_page.dart';
import 'src/features/auth/domain/providers/auth_provider.dart';
import 'src/features/splash/presentation/pages/splash_page.dart';
import 'src/services/instagram_service.dart';
import 'src/shared/services/video_preloader.dart';
import 'dart:io';

// Custom LocalStorage implementation using SharedPreferences
// This avoids flutter_secure_storage crash on iOS 18.6.2
class SharedPreferencesLocalStorage extends LocalStorage {
  @override
  Future<void> initialize() async {
    // No initialization needed for SharedPreferences
  }

  @override
  Future<bool> hasAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('supabase_token');
  }

  @override
  Future<String?> accessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('supabase_token');
  }

  @override
  Future<void> removePersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('supabase_token');
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('supabase_token', persistSessionString);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (optional - won't crash if missing)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print('Warning: .env file not found. Using environment variables from build.');
  }

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: SharedPreferencesLocalStorage(),
    ),
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

  // Track if we have pending shared media to handle after app init
  List<SharedMediaFile>? _pendingSharedMedia;

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

    // ShareHandlerService is NO LONGER NEEDED!
    // The receive_sharing_intent package's RSIShareViewController
    // automatically handles everything via ReceiveSharingIntent.getInitialMedia()
    // which we're already listening to above

    // Listen to media sharing coming from outside the app while the app is in the memory.
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      print("===== MEDIA STREAM (App in Memory) =====");
      print("[SHARE EXTENSION] Received shared media: ${value.length} files");
      for (var file in value) {
        print("[SHARE EXTENSION] Shared file: ${file.path}");
        print("[SHARE EXTENSION]   - type: ${file.type}");
        print("[SHARE EXTENSION]   - mimeType: ${file.mimeType}");
        print("[SHARE EXTENSION]   - thumbnail: ${file.thumbnail}");
        print("[SHARE EXTENSION]   - duration: ${file.duration}");
      }
      if (value.isNotEmpty) {
        print("[SHARE EXTENSION] Handling shared media immediately (app is open)");
        _handleSharedMedia(value);
      } else {
        print("[SHARE EXTENSION] No media files received in stream");
      }
    }, onError: (err) {
      print("[SHARE EXTENSION ERROR] getIntentDataStream error: $err");
    });

    // Get the media sharing coming from outside the app while the app is closed.
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      print("===== INITIAL MEDIA (App was Closed) =====");
      print("[SHARE EXTENSION] Initial shared media: ${value.length} files");
      for (var file in value) {
        print("[SHARE EXTENSION] Initial shared file: ${file.path}");
        print("[SHARE EXTENSION]   - type: ${file.type}");
        print("[SHARE EXTENSION]   - mimeType: ${file.mimeType}");
        print("[SHARE EXTENSION]   - thumbnail: ${file.thumbnail}");
        print("[SHARE EXTENSION]   - duration: ${file.duration}");
      }
      if (value.isNotEmpty) {
        print("[SHARE EXTENSION] Storing pending shared media - will handle after app init");
        // Store the shared media and wait for app to fully initialize
        _pendingSharedMedia = value;
        // Tell the library that we are done processing the intent.
        ReceiveSharingIntent.instance.reset();
        print("[SHARE EXTENSION] Reset sharing intent - pending media stored");

        // Process pending shared media after app initialization completes
        // Wait for splash screen (1.5s) + navigation (0.5s) + buffer (1s) = 3s
        Future.delayed(const Duration(milliseconds: 3000), () {
          print("[SHARE EXTENSION] Delayed callback triggered - checking for pending media");
          handlePendingSharedMedia();
        });
      } else {
        print("[SHARE EXTENSION] No initial media files received");
      }
    }).catchError((error) {
      print("[SHARE EXTENSION ERROR] Error getting initial media: $error");
    });
  }

  void _handleSharedMedia(List<SharedMediaFile> sharedFiles, {bool isInitial = false}) {
    print("[SHARE EXTENSION] _handleSharedMedia called - isInitial: $isInitial, files: ${sharedFiles.length}");
    if (sharedFiles.isEmpty) {
      print("[SHARE EXTENSION] No files to handle - returning");
      return;
    }

    final sharedFile = sharedFiles.first;
    print("[SHARE EXTENSION] Processing first file: ${sharedFile.path}");
    print("[SHARE EXTENSION] File type: ${sharedFile.type}");

    if (sharedFile.type == SharedMediaType.image) {
      print("[SHARE EXTENSION] Handling image file");
      // Handle actual image files
      final String normalizedPath = sharedFile.path.startsWith('file://')
          ? Uri.parse(sharedFile.path).toFilePath()
          : sharedFile.path;
      final imageFile = XFile(normalizedPath);
      print("[SHARE EXTENSION] Setting image in provider: ${imageFile.path}");
      ref.read(selectedImagesProvider.notifier).setImage(imageFile);

      // Also set in pending share provider so HomePage can handle navigation
      print("[SHARE EXTENSION] Setting pending shared image for HomePage");
      ref.read(pendingSharedImageProvider.notifier).state = imageFile;
      print("[SHARE EXTENSION] Pending share set - HomePage will handle navigation");
    } else if (sharedFile.type == SharedMediaType.text) {
      print("[SHARE EXTENSION] Handling text/URL: ${sharedFile.path}");
      // Handle text sharing (like Instagram URLs)
      _handleSharedText(sharedFile.path);
    } else {
      print("[SHARE EXTENSION] Unknown file type: ${sharedFile.type}");
    }
  }

  void handlePendingSharedMedia() {
    if (_pendingSharedMedia == null || _pendingSharedMedia!.isEmpty) {
      print("[SHARE EXTENSION] No pending media to handle");
      return;
    }

    final pending = _pendingSharedMedia!;
    print("[SHARE EXTENSION] Handling pending media (${pending.length} files)");
    _pendingSharedMedia = null;

    _handleSharedMedia(pending, isInitial: true);
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
