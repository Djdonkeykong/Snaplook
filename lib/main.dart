import 'package:path_provider/path_provider.dart';
import 'package:path_provider_foundation/path_provider_foundation.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
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
import 'src/services/share_extension_config_service.dart';
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

  if (Platform.isIOS) {
    PathProviderPlatform.instance = PathProviderFoundation();
    await DefaultCacheManager().getFileFromCache('__warmup__').catchError((_) {});
  }

  // Load environment variables (optional - won't crash if missing)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print(
      'Warning: .env file not found. Using environment variables from build.',
    );
  }

  // 🧠 Log which endpoint is active
  debugPrint('[Config] SERP_DETECT_ENDPOINT = ${AppConstants.serpDetectEndpoint}');
  debugPrint('[Config] SERP_DETECT_AND_SEARCH_ENDPOINT = ${AppConstants.serpDetectAndSearchEndpoint}');

  // Warm up path_provider so method channels are registered before cache usage.
  try {
    await getTemporaryDirectory();
  } catch (e) {
    debugPrint('[Config] path_provider warmup failed: $e');
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

  final scrapingBeeKey = AppConstants.scrapingBeeApiKey;
  if (scrapingBeeKey.isEmpty) {
    print(
      "[CONFIG WARNING] SCRAPINGBEE_API_KEY is empty - Instagram downloads will fail until configured.",
    );
  } else {
    final visible = scrapingBeeKey.length <= 6
        ? scrapingBeeKey
        : "${scrapingBeeKey.substring(0, 4)}…${scrapingBeeKey.substring(scrapingBeeKey.length - 2)}";
    print("[CONFIG] Loaded ScrapingBee API key ($visible)");
  }

  unawaited(
    ShareImportStatus.configure(
      scrapingBeeApiKey: AppConstants.scrapingBeeApiKey,
    ),
  );

  // Initialize shared config for iOS share extension
  unawaited(ShareExtensionConfigService.initializeSharedConfig());

  runApp(const ProviderScope(child: SnaplookApp()));
}

class _FetchingOverlay extends StatelessWidget {
  const _FetchingOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: const CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              Text(
              message,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class SnaplookApp extends ConsumerStatefulWidget {
  const SnaplookApp({super.key});

  @override
  ConsumerState<SnaplookApp> createState() => _SnaplookAppState();
}

class _SnaplookAppState extends ConsumerState<SnaplookApp>
    with WidgetsBindingObserver {
  late StreamSubscription _intentSub;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool _isNavigatingToDetection = false;
  bool _hasHandledInitialShare = false;
  bool _shouldIgnoreNextStreamEmission = false;
  bool _skipNextResumePendingCheck = false;
  List<String>? _lastInitialSharePaths;

  bool _isFetchingOverlayVisible = false;
  String _fetchingOverlayMessage = 'Fetching your photo...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ShareHandlerService is NO LONGER NEEDED!
    // The receive_sharing_intent package's RSIShareViewController
    // automatically handles everything via ReceiveSharingIntent.getInitialMedia()
    // which we're already listening to above

    // Listen to media sharing coming from outside the app while the app is in the memory.
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (value) {
        if (_shouldIgnoreNextStreamEmission && value.isNotEmpty) {
          final currentPaths = value.map((f) => f.path).toList(growable: false);
          final shouldSkip = _lastInitialSharePaths != null &&
              _arePathListsEqual(currentPaths, _lastInitialSharePaths!);
          if (shouldSkip) {
            print(
              "[SHARE EXTENSION] Ignoring duplicate stream emission for initial share",
            );
            _lastInitialSharePaths = null;
            _shouldIgnoreNextStreamEmission = false;
            return;
          }
          print(
            "[SHARE EXTENSION] Stream emission differs from initial share; processing normally",
          );
          _shouldIgnoreNextStreamEmission = false;
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
          unawaited(_handleSharedMedia(value));
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
            _lastInitialSharePaths =
                value.map((f) => f.path).toList(growable: false);
            ReceiveSharingIntent.instance.reset();
            print("[SHARE EXTENSION] Reset sharing intent");
            unawaited(_handleSharedMedia(value, isInitial: true));
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
        await _handleSharedMedia(pendingMedia);
      }
    } catch (e) {
      print(
        "[SHARE EXTENSION ERROR] Error checking pending media on resume: $e",
      );
    }
  }

  SharedMediaFile _selectSharedFile(List<SharedMediaFile> sharedFiles) {
    if (sharedFiles.length == 1) {
      final file = sharedFiles.first;
      print(
        "[SHARE EXTENSION] Single shared file received - using ${file.path} (${file.type})",
      );
      return file;
    }

    SharedMediaFile? firstExistingImage;
    SharedMediaFile? firstImage;
    SharedMediaFile? firstVideo;
    SharedMediaFile? firstFile;
    SharedMediaFile? firstTextOrUrl;
    SharedMediaFile? firstFallback;

    for (final file in sharedFiles) {
      firstFallback ??= file;
      final type = file.type;
      if (type == SharedMediaType.image) {
        firstImage ??= file;
        final normalizedPath = file.path.startsWith('file://')
            ? Uri.parse(file.path).toFilePath()
            : file.path;
        if (normalizedPath.isNotEmpty &&
            File(normalizedPath).existsSync()) {
          firstExistingImage ??= file;
        }
      } else if (type == SharedMediaType.video) {
        firstVideo ??= file;
      } else if (type == SharedMediaType.file) {
        firstFile ??= file;
      } else if (type == SharedMediaType.text || type == SharedMediaType.url) {
        firstTextOrUrl ??= file;
      }

      if (firstExistingImage != null) {
        break;
      }
    }

    final selected = firstExistingImage ??
        firstImage ??
        firstVideo ??
        firstFile ??
        firstTextOrUrl ??
        firstFallback!;

    print(
      "[SHARE EXTENSION] Selected shared file: ${selected.path} (type: ${selected.type})",
    );

    return selected;
  }

  bool _arePathListsEqual(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  Future<void> _handleSharedMedia(
    List<SharedMediaFile> sharedFiles, {
    bool isInitial = false,
  }) async {
    print(
      "[SHARE EXTENSION] _handleSharedMedia called - isInitial: $isInitial, files: ${sharedFiles.length}",
    );
    if (sharedFiles.isEmpty) {
      print("[SHARE EXTENSION] No files to handle - returning");
      return;
    }

    unawaited(ShareImportStatus.markProcessing());

    final sharedFile = _selectSharedFile(sharedFiles);
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
    } else if (sharedFile.type == SharedMediaType.text ||
        sharedFile.type == SharedMediaType.url) {
      print("[SHARE EXTENSION] Handling text/URL: ${sharedFile.path}");
      await _handleSharedText(sharedFile.path, fromShareExtension: true);
    } else {
      print("[SHARE EXTENSION] Unknown file type: ${sharedFile.type}");
    }
  }

  void _navigateToDetection() {
    if (_isNavigatingToDetection) {
      print("[SHARE EXTENSION] Navigation already in progress");
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

      ref.read(pendingSharedImageProvider.notifier).state = null;

      navigator
          .push(
            MaterialPageRoute(
              builder: (_) => const DetectionPage(),
              settings: const RouteSettings(name: 'detection-from-share'),
            ),
          )
          .whenComplete(() {
            _isNavigatingToDetection = false;
            ref.read(shareNavigationInProgressProvider.notifier).state = false;
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

  Future<void> _handleSharedText(
    String text, {
    bool fromShareExtension = false,
  }) async {
    print("Handling shared text: $text");

    final extractedUrl = _extractFirstUrl(text);
    final effectiveText = extractedUrl ?? text.trim();

    if (extractedUrl != null) {
      print("Extracted URL from text: $extractedUrl");
    }

    if (InstagramService.isInstagramUrl(effectiveText)) {
      await _downloadInstagramImage(effectiveText);
    } else {
      final parsed = Uri.tryParse(effectiveText.trim());
      if (parsed != null &&
          (parsed.scheme == 'http' || parsed.scheme == 'https')) {
        await _downloadGenericLink(effectiveText.trim());
      } else {
        _showUnsupportedMessage(text);
        await ShareImportStatus.markComplete();
      }
    }
  }

  String? _extractFirstUrl(String text) {
    if (text.isEmpty) {
      print("[SHARE EXTENSION] No text provided for URL extraction");
      return null;
    }

    final urlRegex = RegExp(
      r'(https?:\/\/[^\s<>"]+|www\.[^\s<>"]+)',
      caseSensitive: false,
    );
    final match = urlRegex.firstMatch(text);

    if (match == null) {
      print("[SHARE EXTENSION] No URL detected in shared text");
      return null;
    }

    var matchedUrl = match.group(0);
    if (matchedUrl == null || matchedUrl.isEmpty) {
      print("[SHARE EXTENSION] URL match found but empty");
      return null;
    }

    matchedUrl = matchedUrl.replaceAll(RegExp(r'[).,!?;:]+$'), '');
    if (!matchedUrl.toLowerCase().startsWith('http')) {
      matchedUrl = 'https://$matchedUrl';
    }

    print("[SHARE EXTENSION] Extracted URL: $matchedUrl");
    return matchedUrl;
  }

  void _showFetchingOverlay({required String title}) {
    if (!mounted) {
      return;
    }
    setState(() {
      _fetchingOverlayMessage = title;
      _isFetchingOverlayVisible = true;
    });
  }

  void _hideFetchingOverlay() {
    if (!mounted || !_isFetchingOverlayVisible) {
      return;
    }
    setState(() {
      _isFetchingOverlayVisible = false;
    });
  }

  Future<void> _downloadInstagramImage(String instagramUrl) async {
    _showFetchingOverlay(title: 'Fetching your photo...');
    try {
      ref.read(shareNavigationInProgressProvider.notifier).state = true;
      final imageFiles = await InstagramService.downloadImageFromInstagramUrl(
        instagramUrl,
      );

      if (imageFiles.isNotEmpty) {
        print('dY", Downloaded ${imageFiles.length} image(s) from Instagram');
        if (imageFiles.length > 1) {
          print('dYZï¿½ Carousel post detected - setting up image slider');
        }

        ref.read(selectedImagesProvider.notifier).setImages(imageFiles);
        ref.read(pendingSharedImageProvider.notifier).state = imageFiles.first;

        await ShareImportStatus.markComplete();

        _navigateToDetection();
      } else {
        ref.read(pendingSharedImageProvider.notifier).state = null;
        await ShareImportStatus.markComplete();
        _showInstagramErrorMessage();
        ref.read(shareNavigationInProgressProvider.notifier).state = false;
      }
    } catch (e) {
      print('Error downloading Instagram image: $e');

      ref.read(pendingSharedImageProvider.notifier).state = null;
      await ShareImportStatus.markComplete();
      _showInstagramErrorMessage();
      ref.read(shareNavigationInProgressProvider.notifier).state = false;
    } finally {
      _hideFetchingOverlay();
    }
  }

  Future<void> _downloadGenericLink(String url) async {
    _showFetchingOverlay(title: 'Fetching shared link...');
    try {
      ref.read(shareNavigationInProgressProvider.notifier).state = true;
      final imageFiles = await LinkScraperService.downloadImagesFromUrl(url);

      if (imageFiles.isNotEmpty) {
        ref.read(selectedImagesProvider.notifier).setImages(imageFiles);
        ref.read(pendingSharedImageProvider.notifier).state = imageFiles.first;

        await ShareImportStatus.markComplete();

        _navigateToDetection();
      } else {
        ref.read(pendingSharedImageProvider.notifier).state = null;
        await ShareImportStatus.markComplete();
        _showGenericLinkErrorMessage(url);
        ref.read(shareNavigationInProgressProvider.notifier).state = false;
      }
    } catch (e) {
      print('Error downloading images from shared link: $e');
      ref.read(pendingSharedImageProvider.notifier).state = null;
      await ShareImportStatus.markComplete();
      _showGenericLinkErrorMessage(url);
      ref.read(shareNavigationInProgressProvider.notifier).state = false;
    } finally {
      _hideFetchingOverlay();
    }
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
              '- Privacy settings on the post\n'
              '- Network connectivity issues\n'
              '- Instagram\'s anti-scraping measures\n\n'
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            if (_isFetchingOverlayVisible)
              Positioned.fill(
                child: _FetchingOverlay(
                  message: _fetchingOverlayMessage,
                ),
              ),
          ],
        );
      },
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