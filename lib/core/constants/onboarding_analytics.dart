/// Onboarding analytics constants for funnel tracking.
///
/// Each screen in the onboarding flow is assigned a step number
/// to enable proper funnel analysis and drop-off tracking in Amplitude.
class OnboardingAnalytics {
  OnboardingAnalytics._();

  /// Ordered list of onboarding screens with their step numbers.
  /// The order reflects the actual user flow through onboarding.
  static const Map<String, OnboardingStep> screens = {
    'onboarding_how_it_works': OnboardingStep(1, 'How It Works'),
    'onboarding_personalization_intro': OnboardingStep(2, 'Personalization Intro'),
    'onboarding_gender_selection': OnboardingStep(3, 'Gender Selection'),
    'onboarding_style_direction': OnboardingStep(4, 'Style Direction'),
    'onboarding_what_you_want': OnboardingStep(5, 'What You Want'),
    'onboarding_budget': OnboardingStep(6, 'Budget'),
    'onboarding_share_your_style': OnboardingStep(7, 'Share Your Style'),
    'onboarding_add_first_style': OnboardingStep(8, 'Add First Style'),
    'onboarding_tutorial_analysis': OnboardingStep(9, 'Tutorial Analysis'),
    'onboarding_notification_permission': OnboardingStep(10, 'Notification Permission'),
    'onboarding_trial_intro': OnboardingStep(11, 'Trial Intro'),
    'onboarding_paywall': OnboardingStep(12, 'Paywall'),
    'onboarding_generate_profile_prep': OnboardingStep(13, 'Generate Profile Prep'),
    'onboarding_calculating_profile': OnboardingStep(14, 'Calculating Profile'),
    'onboarding_profile_ready': OnboardingStep(15, 'Profile Ready'),
    'onboarding_welcome': OnboardingStep(16, 'Welcome'),
  };

  /// Tutorial screens (optional branch from step 8)
  static const Map<String, OnboardingStep> tutorialScreens = {
    'onboarding_instagram_tutorial': OnboardingStep(8, 'Instagram Tutorial', isTutorial: true),
    'onboarding_pinterest_tutorial': OnboardingStep(8, 'Pinterest Tutorial', isTutorial: true),
    'onboarding_tiktok_tutorial': OnboardingStep(8, 'TikTok Tutorial', isTutorial: true),
    'onboarding_x_tutorial': OnboardingStep(8, 'X Tutorial', isTutorial: true),
    'onboarding_imdb_tutorial': OnboardingStep(8, 'IMDB Tutorial', isTutorial: true),
    'onboarding_safari_tutorial': OnboardingStep(8, 'Safari Tutorial', isTutorial: true),
    'onboarding_photos_tutorial': OnboardingStep(8, 'Photos Tutorial', isTutorial: true),
  };

  /// Get step info for a screen name, checking both main and tutorial screens.
  static OnboardingStep? getStep(String screenName) {
    return screens[screenName] ?? tutorialScreens[screenName];
  }

  /// Check if a screen name is an onboarding screen.
  static bool isOnboardingScreen(String screenName) {
    return screenName.startsWith('onboarding_');
  }

  /// Total number of main steps in the onboarding flow.
  static const int totalSteps = 16;

  /// Key conversion milestones for funnel analysis.
  static const List<String> conversionMilestones = [
    'onboarding_how_it_works',       // Step 1: Entry
    'onboarding_gender_selection',   // Step 3: Started personalization
    'onboarding_budget',             // Step 6: Completed preferences
    'onboarding_add_first_style',    // Step 8: Engaged with style upload
    'onboarding_trial_intro',        // Step 11: Reached trial
    'onboarding_paywall',            // Step 12: Reached paywall
    'onboarding_welcome',            // Step 16: Completed
  ];
}

/// Represents a step in the onboarding flow.
class OnboardingStep {
  final int stepNumber;
  final String displayName;
  final bool isTutorial;

  const OnboardingStep(
    this.stepNumber,
    this.displayName, {
    this.isTutorial = false,
  });
}
