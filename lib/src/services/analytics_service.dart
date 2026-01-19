import 'package:amplitude_flutter/amplitude.dart';
import 'package:amplitude_flutter/configuration.dart';
import 'package:amplitude_flutter/constants.dart';
import 'package:amplitude_flutter/default_tracking.dart';
import 'package:amplitude_flutter/events/base_event.dart';
import 'package:amplitude_flutter/events/identify.dart';
import 'package:flutter/foundation.dart';
import 'debug_log_service.dart';
import '../../core/constants/onboarding_analytics.dart';

class AnalyticsService {
  AnalyticsService._internal();
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;

  final _debugLog = DebugLogService();
  Amplitude? _client;
  bool _initialized = false;
  bool _initializing = false;
  bool _enabled = true;

  bool get isEnabled => _enabled && _client != null;

  Future<void> initialize({
    required String apiKey,
    bool enabled = true,
  }) async {
    if (_initialized || _initializing) return;
    _initializing = true;
    _enabled = enabled && apiKey.isNotEmpty;

    if (!_enabled) {
      _log('Disabled or missing API key; skipping initialization',
          level: DebugLogLevel.warning);
      _initializing = false;
      return;
    }

    final config = Configuration(
      apiKey: apiKey,
      logLevel: kDebugMode ? LogLevel.debug : LogLevel.warn,
      defaultTracking: const DefaultTrackingOptions(
        sessions: true,
        appLifecycles: true,
        deepLinks: false,
        attribution: false,
        pageViews: false,
        formInteractions: false,
        fileDownloads: false,
      ),
    );

    final client = Amplitude(config);
    final built = await client.isBuilt;

    if (!built) {
      _log('Initialization failed', level: DebugLogLevel.error);
      _initializing = false;
      return;
    }

    _client = client;
    _initialized = true;
    _initializing = false;
    _log('Initialized');
  }

  Future<void> track(
    String eventName, {
    Map<String, dynamic>? properties,
  }) async {
    if (!_initialized || _client == null) return;
    final event = BaseEvent(eventName, eventProperties: properties);
    await _client!.track(event);
  }

  Future<void> trackScreenView(String screenName) async {
    if (!_initialized || _client == null) return;
    await track('screen_view', properties: {'screen_name': screenName});
  }

  /// Track onboarding screen views with step numbers for funnel analysis.
  ///
  /// This sends an 'onboarding_screen_viewed' event with:
  /// - screen_name: The screen identifier
  /// - step_number: The step in the onboarding flow (1-16)
  /// - step_name: Human-readable step name
  /// - is_tutorial: Whether this is a tutorial sub-screen
  /// - is_milestone: Whether this is a key conversion milestone
  Future<void> trackOnboardingScreen(String screenName) async {
    if (!_initialized || _client == null) return;
    if (!OnboardingAnalytics.isOnboardingScreen(screenName)) {
      // Fall back to regular screen tracking for non-onboarding screens
      await trackScreenView(screenName);
      return;
    }

    final step = OnboardingAnalytics.getStep(screenName);
    final isMilestone = OnboardingAnalytics.conversionMilestones.contains(screenName);

    final properties = <String, dynamic>{
      'screen_name': screenName,
      'step_number': step?.stepNumber ?? 0,
      'step_name': step?.displayName ?? screenName,
      'is_tutorial': step?.isTutorial ?? false,
      'is_milestone': isMilestone,
      'total_steps': OnboardingAnalytics.totalSteps,
    };

    await track('onboarding_screen_viewed', properties: properties);

    // Also track milestone events separately for easier funnel creation
    if (isMilestone && step != null) {
      await track('onboarding_milestone_reached', properties: {
        'milestone': screenName,
        'step_number': step.stepNumber,
        'step_name': step.displayName,
      });
    }
  }

  Future<void> identifyUser({
    required String userId,
    Map<String, dynamic>? userProperties,
  }) async {
    if (!_initialized || _client == null) return;
    if (userId.isEmpty) return;

    await _client!.setUserId(userId);

    if (userProperties != null && userProperties.isNotEmpty) {
      await _setUserProperties(userProperties);
    }
  }

  Future<void> setUserProperties(Map<String, dynamic> userProperties) async {
    if (!_initialized || _client == null) return;
    if (userProperties.isEmpty) return;
    await _setUserProperties(userProperties);
  }

  Future<void> reset() async {
    if (!_initialized || _client == null) return;
    await _client!.reset();
  }

  Future<void> _setUserProperties(Map<String, dynamic> properties) async {
    final identify = Identify();
    properties.forEach(identify.set);
    await _client!.identify(identify);
  }

  void _log(String message, {DebugLogLevel level = DebugLogLevel.info}) {
    _debugLog.log(message, level: level, tag: 'Analytics');
    if (kDebugMode) {
      debugPrint('[Analytics] $message');
    }
  }
}
