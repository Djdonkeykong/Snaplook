import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/snaplook_back_button.dart';

class HelpFaqPage extends StatelessWidget {
  const HelpFaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: SnaplookBackButton(
            onPressed: () => Navigator.of(context).pop(),
            showBackground: false,
          ),
        ),
        title: const Text(
          'Help & FAQ',
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(spacing.l),
        children: [
          _FaqItem(
            question: 'How do I save items to my favorites?',
            answer: 'Tap the heart icon on any product to add it to your favorites.',
          ),
          SizedBox(height: spacing.m),
          _FaqItem(
            question: 'How do I search for similar products?',
            answer: 'Take a photo or upload an image from your gallery, and we\'ll find similar fashion items for you.',
          ),
          SizedBox(height: spacing.m),
          _FaqItem(
            question: 'How do I delete my account?',
            answer: 'Go to Settings and tap "Delete Account" at the bottom of the page.',
          ),
        ],
      ),
    );
  }
}

class _FaqItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqItem({
    required this.question,
    required this.answer,
  });

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: EdgeInsets.all(spacing.m),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'PlusJakartaSans',
                        color: Colors.black,
                      ),
                    ),
                  ),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary,
                ),
              ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            Divider(height: 1, color: Colors.grey.shade300),
            Padding(
              padding: EdgeInsets.all(spacing.m),
              child: Text(
                widget.answer,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontFamily: 'PlusJakartaSans',
                height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
