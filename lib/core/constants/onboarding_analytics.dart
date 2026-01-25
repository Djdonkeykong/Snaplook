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
    'onboarding_rating_social_proof': OnboardingStep(3, 'Rating Social Proof'),
    'onboarding_gender_selection': OnboardingStep(4, 'Gender Selection'),
    'onboarding_style_direction': OnboardingStep(5, 'Style Direction'),
    'onboarding_what_you_want': OnboardingStep(6, 'What You Want'),
    'onboarding_budget': OnboardingStep(7, 'Budget'),
    'onboarding_share_your_style': OnboardingStep(8, 'Share Your Style'),
    'onboarding_add_first_style': OnboardingStep(9, 'Add First Style'),
    'onboarding_tutorial_analysis': OnboardingStep(10, 'Tutorial Analysis'),
    'onboarding_notification_permission': OnboardingStep(11, 'Notification Permission'),
    'onboarding_trial_intro': OnboardingStep(12, 'Trial Intro'),
    'onboarding_trial_reminder': OnboardingStep(13, 'Trial Reminder'),
    'onboarding_paywall': OnboardingStep(14, 'Paywall'),
    'onboarding_generate_profile_prep': OnboardingStep(15, 'Generate Profile Prep'),
    'onboarding_calculating_profile': OnboardingStep(16, 'Calculating Profile'),
    'onboarding_profile_ready': OnboardingStep(17, 'Profile Ready'),
    'onboarding_welcome': OnboardingStep(18, 'Welcome'),
  };

  /// Tutorial screens (optional branch from step 9)
  static const Map<String, OnboardingStep> tutorialScreens = {
    'onboarding_instagram_tutorial': OnboardingStep(9, 'Instagram Tutorial', isTutorial: true),
    'onboarding_pinterest_tutorial': OnboardingStep(9, 'Pinterest Tutorial', isTutorial: true),
    'onboarding_tiktok_tutorial': OnboardingStep(9, 'TikTok Tutorial', isTutorial: true),
    'onboarding_x_tutorial': OnboardingStep(9, 'X Tutorial', isTutorial: true),
    'onboarding_imdb_tutorial': OnboardingStep(9, 'IMDB Tutorial', isTutorial: true),
    'onboarding_safari_tutorial': OnboardingStep(9, 'Safari Tutorial', isTutorial: true),
    'onboarding_photos_tutorial': OnboardingStep(9, 'Photos Tutorial', isTutorial: true),
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
  static const int totalSteps = 18;

  /// Key conversion milestones for funnel analysis.
  static const List<String> conversionMilestones = [
    'onboarding_how_it_works',       // Step 1: Entry
    'onboarding_gender_selection',   // Step 4: Started personalization
    'onboarding_budget',             // Step 7: Completed preferences
    'onboarding_add_first_style',    // Step 9: Engaged with style upload
    'onboarding_trial_intro',        // Step 12: Reached trial
    'onboarding_paywall',            // Step 14: Reached paywall
    'onboarding_welcome',            // Step 18: Completed
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
