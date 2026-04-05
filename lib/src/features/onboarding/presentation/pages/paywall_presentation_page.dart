import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../services/analytics_service.dart';
import 'welcome_free_analysis_page.dart';
import '../../../../../shared/navigation/main_navigation.dart';
import '../../../../services/superwall_service.dart';
import '../../../../services/subscription_sync_service.dart';
import '../../../../services/onboarding_state_service.dart';

/// A dedicated page that presents the paywall and handles navigation
/// This prevents the previous page from being visible when the paywall closes
class PaywallPresentationPage extends StatefulWidget {
  const PaywallPresentationPage({
    super.key,
    required this.userId,
    this.placement = 'onboarding_paywall',
    this.dismissToHomeIfNoPurchase = false,
  });

  final String? userId;
  final String placement;
  final bool dismissToHomeIfNoPurchase;

  @override
  State<PaywallPresentationPage> createState() =>
      _PaywallPresentationPageState();
}

class _PaywallPresentationPageState extends State<PaywallPresentationPage> {
  static const _splashAssetPath = 'assets/images/snaplook-logo-splash.png';
  static const _logoWidth = 93.027;
  bool _isLoading = true;
  bool _hasPresented = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService().trackOnboardingScreen('onboarding_paywall');
    // Present paywall after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _presentPaywall();
    });
  }

  Future<void> _presentPaywall() async {
    if (_hasPresented) return;
    _hasPresented = true;

    try {
      debugPrint('[PaywallPresentationPage] Presenting Superwall paywall...');
      final syncService = SubscriptionSyncService();
      final accessStateBeforePaywall = widget.userId != null
          ? await syncService.getUserAccessState(userId: widget.userId)
          : null;

      // Keep loading overlay visible while Superwall initializes
      await Future.delayed(const Duration(milliseconds: 500));

      // Present Superwall paywall (this will show Superwall's UI over our page)
      final didPurchase = await SuperwallService().presentPaywall(
        placement: widget.placement,
      );

      // Paywall has been dismissed - hide loading overlay
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (!mounted) return;

      debugPrint('[PaywallPresentationPage] Purchase result: $didPurchase');

      final grantedAccessState = widget.userId != null
          ? await syncService.waitForPurchaseGrant(
              userId: widget.userId!,
              previousAccessState: accessStateBeforePaywall,
              timeout: SubscriptionSyncService.purchaseGrantTimeout(
                placement: widget.placement,
                didPurchase: didPurchase,
              ),
            )
          : null;
      final accessStateAfterPaywall = widget.userId != null
          ? await syncService.refreshAccessState(userId: widget.userId!)
          : null;

      var hasAccessAfterPurchase = didPurchase ||
          grantedAccessState?.hasAccess == true ||
          syncService.gainedAccess(
            accessStateBeforePaywall,
            accessStateAfterPaywall,
          );

      // If user purchased and has account, sync purchase data to Supabase.
      if (hasAccessAfterPurchase && widget.userId != null) {
        // Show loading overlay while syncing
        if (mounted) {
          setState(() {
            _isLoading = true;
          });
        }

        try {
          debugPrint(
              '[PaywallPresentationPage] Purchase completed - waiting for RevenueCat to process...');

          // Wait briefly for RevenueCat to process the purchase and update entitlements
          await Future.delayed(const Duration(milliseconds: 500));

          debugPrint(
              '[PaywallPresentationPage] Syncing purchase data to Supabase...');
          final accessState = accessStateAfterPaywall ??
              grantedAccessState ??
              await syncService.syncSubscriptionToSupabase();
          hasAccessAfterPurchase = accessState?.hasAccess ?? didPurchase;
          await OnboardingStateService().markPaymentComplete(widget.userId!);
          debugPrint(
              '[PaywallPresentationPage] Purchase data synced successfully. '
              'hasAccess=$hasAccessAfterPurchase credits=${accessState?.paidCreditsRemaining}');
        } catch (e) {
          debugPrint(
              '[PaywallPresentationPage] Error syncing subscription: $e');
        }
      }

      if (!mounted) return;

      // Only navigate forward if user purchased
      if (!hasAccessAfterPurchase) {
        debugPrint(
            '[PaywallPresentationPage] User dismissed paywall without purchasing - going back');
        if (widget.dismissToHomeIfNoPurchase) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainNavigation()),
          );
          return;
        }
        Navigator.of(context).pop();
        return;
      }

      if (widget.userId == null) {
        debugPrint(
            '[PaywallPresentationPage] WARNING: No user found after paywall');
        Navigator.of(context).pop();
        return;
      }

      // Check if user has completed onboarding before
      final supabase = Supabase.instance.client;
      final userResponse = await supabase
          .from('users')
          .select('onboarding_state')
          .eq('id', widget.userId!)
          .maybeSingle();

      final hasCompletedOnboarding =
          userResponse?['onboarding_state'] == 'completed';

      debugPrint(
          '[PaywallPresentationPage] User purchased - navigating: hasCompletedOnboarding=$hasCompletedOnboarding');

      final nextPage = hasCompletedOnboarding
          ? const MainNavigation()
          : const WelcomeFreeAnalysisPage();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => nextPage),
        );
      }
    } catch (e) {
      debugPrint('[PaywallPresentationPage] Error during paywall: $e');
      // Go back on error
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.secondary,
        body: _isLoading
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: SizedBox(
                      width: _logoWidth,
                      child: Image.asset(
                        _splashAssetPath,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 44,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            strokeWidth: 2.4,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Loading paywall...',
                          style: TextStyle(
                            color: Color(0xF2FFFFFF),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
