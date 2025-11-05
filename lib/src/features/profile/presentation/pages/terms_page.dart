import 'package:flutter/material.dart';
import 'package:super_cupertino_navigation_bar/super_cupertino_navigation_bar.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SuperScaffold(
        appBar: SuperAppBar(
          title: const Text(
            'Terms and Conditions',
            style: TextStyle(
              color: Colors.black,
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w600,
              fontSize: 17,
            ),
          ),
          leadingWidth: 64,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: SnaplookBackButton(
              onPressed: () => Navigator.of(context).pop(),
              showBackground: false,
            ),
          ),
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          searchBar: SuperSearchBar(enabled: false),
          largeTitle: SuperLargeTitle(
            largeTitle: 'Terms and Conditions',
            textStyle: const TextStyle(
              fontSize: 30,
              fontFamily: 'PlusJakartaSans',
              letterSpacing: -1.0,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              height: 1.3,
            ),
            padding: EdgeInsets.symmetric(horizontal: spacing.l),
          ),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(spacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: spacing.m),
                Text(
                  'Last updated: ${DateTime.now().year}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
                SizedBox(height: spacing.xl),
                _TermsSection(
                  title: '1. Acceptance of Terms',
                  content:
                      'By accessing and using Snaplook, you accept and agree to be bound by the terms and conditions of this agreement.',
                ),
                SizedBox(height: spacing.l),
                _TermsSection(
                  title: '2. Use License',
                  content:
                      'Permission is granted to temporarily use Snaplook for personal, non-commercial purposes. This is the grant of a license, not a transfer of title.',
                ),
                SizedBox(height: spacing.l),
                _TermsSection(
                  title: '3. User Accounts',
                  content:
                      'You are responsible for maintaining the confidentiality of your account and password. You agree to accept responsibility for all activities that occur under your account.',
                ),
                SizedBox(height: spacing.l),
                _TermsSection(
                  title: '4. Content',
                  content:
                      'Our service allows you to post, link, store, share and otherwise make available certain information. You are responsible for the content that you post on or through the service.',
                ),
                SizedBox(height: spacing.l),
                _TermsSection(
                  title: '5. Prohibited Uses',
                  content:
                      'You may not use our service for any illegal or unauthorized purpose, to violate any laws, or to harm others in any way.',
                ),
                SizedBox(height: spacing.l),
                _TermsSection(
                  title: '6. Limitation of Liability',
                  content:
                      'Snaplook shall not be liable for any indirect, incidental, special, consequential or punitive damages resulting from your use of or inability to use the service.',
                ),
                SizedBox(height: spacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  final String title;
  final String content;

  const _TermsSection({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: 'PlusJakartaSans',
            color: Colors.black,
          ),
        ),
        SizedBox(height: spacing.sm),
        Text(
          content,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            fontFamily: 'PlusJakartaSans',
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
