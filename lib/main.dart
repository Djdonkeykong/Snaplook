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
import 'shared/navigation/route_observer.dart';
import 'src/features/home/domain/providers/image_provider.dart';
import 'src/features/home/domain/providers/pending_share_provider.dart';
import 'src/features/detection/presentation/pages/detection_page.dart';
import 'src/features/splash/presentation/pages/splash_page.dart';
import 'src/services/instagram_service.dart';
import 'src/shared/services/video_preloader.dart';
import 'src/shared/services/share_import_status.dart';
import 'src/services/link_scraper_service.dart';
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
    print(
      'Warning: .env file not found. Using environment variables from build.',
    );
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

class _SnaplookAppState extends ConsumerState<SnaplookApp>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late StreamSubscription _intentSub;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Progress tracking for Instagram downloads
  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;

  bool _isNavigatingToDetection = false;
  bool _hasHandledInitialShare = false;
  bool _shouldIgnoreNextStreamEmission = false;
  bool _skipNextResumePendingCheck = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize progress animation controller
    _progressAnimationController = AnimationController(
      duration: const Duration(
        milliseconds: 500,
      ), // 500ms for smooth transitions
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressAnimationController,
        curve: Curves.easeInOut,
      ),
    );

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
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (value) {
        if (_shouldIgnoreNextStreamEmission && value.isNotEmpty) {
          print(
            "[SHARE EXTENSION] Ignoring first stream emission after initial share",
          );
          _shouldIgnoreNextStreamEmission = false;
          return;
        }
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
          print(
            "[SHARE EXTENSION] Handling shared media immediately (app is open)",
          );
          _handleSharedMedia(value);
        } else {
          print("[SHARE EXTENSION] No media files received in stream");
        }
      },
      onError: (err) {
        print("[SHARE EXTENSION ERROR] getIntentDataStream error: $err");
      },
    );

    // Get the media sharing coming from outside the app while the app is closed.
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((value) {
          if (_hasHandledInitialShare) {
            print("[SHARE EXTENSION] Initial media already handled; skipping");
            return;
          }
          print("===== INITIAL MEDIA (App was Closed) =====");
          print(
            "[SHARE EXTENSION] Initial shared media: ${value.length} files",
          );
          for (var file in value) {
            print("[SHARE EXTENSION] Initial shared file: ${file.path}");
            print("[SHARE EXTENSION]   - type: ${file.type}");
            print("[SHARE EXTENSION]   - mimeType: ${file.mimeType}");
            print("[SHARE EXTENSION]   - thumbnail: ${file.thumbnail}");
            print("[SHARE EXTENSION]   - duration: ${file.duration}");
          }
          if (value.isNotEmpty) {
            print(
              "[SHARE EXTENSION] Handling initial shared media immediately",
            );
            _hasHandledInitialShare = true;
            _skipNextResumePendingCheck = true;
            _shouldIgnoreNextStreamEmission = true;
            ReceiveSharingIntent.instance.reset();
            print("[SHARE EXTENSION] Reset sharing intent");
            _handleSharedMedia(value, isInitial: true);
          } else {
            print("[SHARE EXTENSION] No initial media files received");
          }
        })
        .catchError((error) {
          print("[SHARE EXTENSION ERROR] Error getting initial media: $error");
        });

    // Ensure we catch any pending share when the app is already running.
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForPendingSharedMediaOnResume();
    }
    super.didChangeAppLifecycleState(state);
  }

  Future<void> _checkForPendingSharedMediaOnResume() async {
    if (_skipNextResumePendingCheck) {
      _skipNextResumePendingCheck = false;
      return;
    }
    if (_hasHandledInitialShare) {
      // Initial share already queued for HomePage; avoid double-handling before UI is ready.
      return;
    }
    try {
      final pendingMedia = await ReceiveSharingIntent.instance
          .getInitialMedia();
      if (pendingMedia.isNotEmpty) {
        print(
          "[SHARE EXTENSION] Found pending media after resume: ${pendingMedia.length} files",
        );
        ReceiveSharingIntent.instance.reset();
        _handleSharedMedia(pendingMedia);
      }
    } catch (e) {
      print(
        "[SHARE EXTENSION ERROR] Error checking pending media on resume: $e",
      );
    }
  }

  void _handleSharedMedia(
    List<SharedMediaFile> sharedFiles, {
    bool isInitial = false,
  }) {
    print(
      "[SHARE EXTENSION] _handleSharedMedia called - isInitial: $isInitial, files: ${sharedFiles.length}",
    );
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
      final fileExists = File(imageFile.path).existsSync();
      print("[SHARE EXTENSION] Normalized path: ${imageFile.path}");
      print("[SHARE EXTENSION] File exists: $fileExists");
      ref.read(selectedImagesProvider.notifier).setImage(imageFile);

      // Also set in pending share provider so HomePage can handle navigation
      if (isInitial) {
        print(
          "[SHARE EXTENSION] Setting pending shared image for HomePage (initial share)",
        );
        _skipNextResumePendingCheck = true;
        ref.read(pendingSharedImageProvider.notifier).state = imageFile;
        _hasHandledInitialShare = true;
        _shouldIgnoreNextStreamEmission = true;
        unawaited(ShareImportStatus.markComplete());
        print("[SHARE EXTENSION] Deferring navigation to home init");
        return;
      }

      // Clear any stale pending share and navigate immediately when the app is already running.
      unawaited(ShareImportStatus.markComplete());
      ref.read(pendingSharedImageProvider.notifier).state = null;
      FocusManager.instance.primaryFocus?.unfocus();
      print("[SHARE EXTENSION] Navigating to DetectionPage immediately");
      _navigateToDetection();
    } else if (sharedFile.type == SharedMediaType.text || sharedFile.type == SharedMediaType.url) {
      print("[SHARE EXTENSION] Handling text/URL: ${sharedFile.path}");
      // Handle text sharing (like Instagram URLs)
      _handleSharedText(sharedFile.path);
    } else {
      print("[SHARE EXTENSION] Unknown file type: ${sharedFile.type}");
    }
  }

  void _navigateToDetection() {
    if (_isNavigatingToDetection) {
      print("[SHARE EXTENSION] Navigation already in progress");
      ref.read(pendingSharedImageProvider.notifier).state = null;
      return;
    }
    _isNavigatingToDetection = true;

    // Ensure the main navigation is showing the home tab before pushing detection.
    ref.read(selectedIndexProvider.notifier).state = 0;

    void pushRoute() {
      final navigator = navigatorKey.currentState;
      if (navigator == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => pushRoute());
        return;
      }

      // Clear the pending image so downstream listeners don't trigger a duplicate navigation.
      ref.read(pendingSharedImageProvider.notifier).state = null;

      navigator
          .push(MaterialPageRoute(builder: (_) => const DetectionPage()))
          .whenComplete(() {
            _isNavigatingToDetection = false;
          });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final homeNavigator = homeNavigatorKey.currentState;
      if (homeNavigator?.canPop() ?? false) {
        homeNavigator!.popUntil((route) => route.isFirst);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => pushRoute());
    });
  }

  void _handleSharedText(String text) async {
    print("Handling shared text: $text");

    // Check if it's an Instagram URL
    if (InstagramService.isInstagramUrl(text)) {
      await _downloadInstagramImage(text);
    } else {
      final parsed = Uri.tryParse(text.trim());
      if (parsed != null &&
          (parsed.scheme == 'http' || parsed.scheme == 'https')) {
        await _downloadGenericLink(text.trim());
      } else {
        _showUnsupportedMessage(text);
        await ShareImportStatus.markComplete();
      }
    }
  }

  Future<void> _downloadInstagramImage(String instagramUrl) async {
    // Reset progress animation to start fresh
    _progressAnimationController.reset();

    // Show progress dialog
    _showProgressDialog(title: 'Instagram Image Download');

    try {
      // Step 1: Initialize
      _updateProgress(0.1);
      await Future.delayed(const Duration(milliseconds: 300));

      // Step 2: API Request
      _updateProgress(0.3);

      // Run the download in background while updating progress
      final downloadFuture = InstagramService.downloadImageFromInstagramUrl(
        instagramUrl,
      );

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
        print('dY", Downloaded  image(s) from Instagram');
        if (imageFiles.length > 1) {
          print('dYZ? Carousel post detected - setting up image slider');
        }

        // Set all downloaded images in the provider
        ref.read(selectedImagesProvider.notifier).setImages(imageFiles);
        ref.read(pendingSharedImageProvider.notifier).state = imageFiles.first;

        await ShareImportStatus.markComplete();

        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _navigateToDetection();
            }
          });
        }
      } else {
        ref.read(pendingSharedImageProvider.notifier).state = null;
        await ShareImportStatus.markComplete();
        _showInstagramErrorMessage();
      }
    } catch (e) {
      print('Error downloading Instagram image: ');

      // Hide progress dialog
      if (navigatorKey.currentContext != null) {
        Navigator.of(navigatorKey.currentContext!).pop();
      }

      ref.read(pendingSharedImageProvider.notifier).state = null;
      await ShareImportStatus.markComplete();

      _showInstagramErrorMessage();
    }
  }

  Future<void> _downloadGenericLink(String url) async {
    _progressAnimationController.reset();
    _showProgressDialog(title: 'Fetching Shared Link');

    try {
      _updateProgress(0.2);
      final imageFiles = await LinkScraperService.downloadImagesFromUrl(url);
      _updateProgress(1.0);
      await Future.delayed(const Duration(milliseconds: 200));

      if (navigatorKey.currentContext != null) {
        Navigator.of(navigatorKey.currentContext!).pop();
      }

      if (imageFiles.isNotEmpty) {
        ref.read(selectedImagesProvider.notifier).setImages(imageFiles);
        ref.read(pendingSharedImageProvider.notifier).state = imageFiles.first;

        await ShareImportStatus.markComplete();

        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _navigateToDetection();
            }
          });
        }
      } else {
        ref.read(pendingSharedImageProvider.notifier).state = null;
        await ShareImportStatus.markComplete();
        _showGenericLinkErrorMessage(url);
      }
    } catch (e) {
      print('Error downloading images from shared link: ');
      if (navigatorKey.currentContext != null) {
        Navigator.of(navigatorKey.currentContext!).pop();
      }
      ref.read(pendingSharedImageProvider.notifier).state = null;
      await ShareImportStatus.markComplete();
      _showGenericLinkErrorMessage(url);
    }
  }

  void _showProgressDialog({required String title}) {
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
                    title,
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
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(
                            context,
                          ).colorScheme.secondary, // Golden yellow
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
    final Animation<double> progressTween =
        Tween<double>(begin: _progressAnimation.value, end: progress).animate(
          CurvedAnimation(
            parent: _progressAnimationController,
            curve: Curves.easeInOut,
          ),
        );

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
              'Try taking a screenshot instead and use the "Upload" button to analyze it.',
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

  void _showGenericLinkErrorMessage(String url) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentContext != null) {
        showDialog(
          context: navigatorKey.currentContext!,
          builder: (context) => AlertDialog(
            title: const Text('Couldn\'t Fetch Shared Link'),
            content: Text(
              'We weren\'t able to find any usable images on:\n\n$url\n\nTry sharing a page that includes photo content.',
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
              'Please share an image file instead.',
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
    WidgetsBinding.instance.removeObserver(this);
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
      navigatorObservers: [routeObserver],
      home: const SplashPage(),
    );
  }
}

