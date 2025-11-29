import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../../services/onboarding_state_service.dart';
import '../../domain/providers/feed_preference_provider.dart';

enum FeedPreference { men, women, both }

class FeedPreferencesPage extends ConsumerStatefulWidget {
  const FeedPreferencesPage({super.key});

  @override
  ConsumerState<FeedPreferencesPage> createState() =>
      _FeedPreferencesPageState();
}

class _FeedPreferencesPageState
    extends ConsumerState<FeedPreferencesPage> {
  FeedPreference? _selectedPreference;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentPreference();
  }

  Future<void> _loadCurrentPreference() async {
    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) return;

      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('users')
          .select('preferred_gender_filter')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null && mounted) {
        final filter = response['preferred_gender_filter'] as String?;
        setState(() {
          _selectedPreference = _filterToPreference(filter);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[FeedPreferences] Error loading preference: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  FeedPreference _filterToPreference(String? filter) {
    switch (filter) {
      case 'men':
        return FeedPreference.men;
      case 'women':
        return FeedPreference.women;
      case 'all':
        return FeedPreference.both;
      default:
        return FeedPreference.both;
    }
  }

  String _preferenceToFilter(FeedPreference preference) {
    switch (preference) {
      case FeedPreference.men:
        return 'men';
      case FeedPreference.women:
        return 'women';
      case FeedPreference.both:
        return 'all';
    }
  }

  Future<void> _savePreference(FeedPreference preference) async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) return;

      final filterValue = _preferenceToFilter(preference);

      await OnboardingStateService().saveUserPreferences(
        userId: user.id,
        preferredGenderFilter: filterValue,
      );

      if (mounted) {
        setState(() {
          _selectedPreference = preference;
          _isSaving = false;
        });

        // Notify home feed to refresh with new preference
        notifyFeedPreferenceChanged(ref);

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Feed preference updated',
              style: context.snackTextStyle(
                merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
              ),
            ),
            duration: const Duration(milliseconds: 2000),
            backgroundColor: Colors.black87,
          ),
        );
      }
    } catch (e) {
      debugPrint('[FeedPreferences] Error saving preference: $e');
      if (mounted) {
        setState(() => _isSaving = false);

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error updating preference',
              style: context.snackTextStyle(
                merge: const TextStyle(fontFamily: 'PlusJakartaSans'),
              ),
            ),
            duration: const Duration(milliseconds: 2500),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const SnaplookBackButton(),
        centerTitle: true,
        title: const Text(
          'Feed Preferences',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontFamily: 'PlusJakartaSans',
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.secondary,
              ),
            )
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: spacing.l),

                    // Description
                    Text(
                      'Choose what you want to see in your feed',
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'PlusJakartaSans',
                        height: 1.5,
                      ),
                    ),

                    SizedBox(height: spacing.xl),

                    // Preference Options
                    _PreferenceOption(
                      label: "Men's Clothing",
                      isSelected: _selectedPreference == FeedPreference.men,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _savePreference(FeedPreference.men);
                      },
                    ),

                    SizedBox(height: spacing.m),

                    _PreferenceOption(
                      label: "Women's Clothing",
                      isSelected:
                          _selectedPreference == FeedPreference.women,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _savePreference(FeedPreference.women);
                      },
                    ),

                    SizedBox(height: spacing.m),

                    _PreferenceOption(
                      label: 'Both',
                      isSelected: _selectedPreference == FeedPreference.both,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _savePreference(FeedPreference.both);
                      },
                    ),

                    if (_isSaving) ...[
                      SizedBox(height: spacing.l),
                      const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: AppColors.secondary,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _PreferenceOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PreferenceOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF2003C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF2003C)
                : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.black,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
        ),
      ),
    );
  }
}
