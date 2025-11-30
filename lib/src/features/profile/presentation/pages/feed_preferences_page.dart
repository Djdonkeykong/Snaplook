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
                padding: EdgeInsets.fromLTRB(spacing.l, spacing.l, spacing.l, spacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      'Choose what you want to see in your feed',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black.withOpacity(0.6),
                        fontFamily: 'PlusJakartaSans',
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: spacing.l),
                    _SettingsCard(
                      children: [
                        _SettingsRow.radio(
                          label: "Men's Clothing",
                          selected: _selectedPreference == FeedPreference.men,
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            _savePreference(FeedPreference.men);
                          },
                        ),
                        _Divider(),
                        _SettingsRow.radio(
                          label: "Women's Clothing",
                          selected: _selectedPreference == FeedPreference.women,
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            _savePreference(FeedPreference.women);
                          },
                        ),
                        _Divider(),
                        _SettingsRow.radio(
                          label: 'Both',
                          selected: _selectedPreference == FeedPreference.both,
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            _savePreference(FeedPreference.both);
                          },
                        ),
                      ],
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

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFFECECEC),
      indent: 16,
      endIndent: 16,
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SettingsRow.radio({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Colors.black;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'PlusJakartaSans',
                  color: textColor,
                ),
              ),
            ),
            _RadioIcon(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _RadioIcon extends StatelessWidget {
  final bool selected;
  const _RadioIcon({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? const Color(0xFFF2003C) : const Color(0xFFD0D0D0),
          width: 1.5,
        ),
      ),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? const Color(0xFFF2003C) : Colors.transparent,
          ),
        ),
      ),
    );
  }
}
