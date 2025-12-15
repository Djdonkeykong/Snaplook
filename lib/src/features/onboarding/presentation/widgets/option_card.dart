import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.sublabel,
  });

  final String label;
  final String? sublabel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 68),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFf2003c) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.black,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
            if (sublabel != null) ...[
              const SizedBox(height: 4),
              Text(
                sublabel!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color:
                      isSelected ? Colors.white.withOpacity(0.9) : const Color(0xFF6B7280),
                  fontFamily: 'PlusJakartaSans',
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
