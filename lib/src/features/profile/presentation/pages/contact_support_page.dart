import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';

class ContactSupportPage extends StatelessWidget {
  const ContactSupportPage({super.key});

  Future<void> _sendEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@snaplook.com',
      query: 'subject=Snaplook Support Request',
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Contact Support',
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(spacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Get in Touch',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'PlusJakartaSans',
                color: Colors.black,
              ),
            ),
            SizedBox(height: spacing.m),
            Text(
              'Have a question or need assistance? We\'re here to help!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontFamily: 'PlusJakartaSans',
                height: 1.5,
              ),
            ),
            SizedBox(height: spacing.xl),
            Container(
              padding: EdgeInsets.all(spacing.l),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.email_outlined, color: AppColors.secondary, size: 24),
                      SizedBox(width: spacing.m),
                      const Text(
                        'Email Support',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'PlusJakartaSans',
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing.m),
                  const Text(
                    'support@snaplook.com',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'PlusJakartaSans',
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: spacing.sm),
                  Text(
                    'We typically respond within 24 hours',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing.l),
            GestureDetector(
              onTap: _sendEmail,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Center(
                  child: Text(
                    'Send Email',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'PlusJakartaSans',
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
