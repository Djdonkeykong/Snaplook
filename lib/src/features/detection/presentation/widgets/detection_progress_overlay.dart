import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/theme_extensions.dart';

class DetectionProgressOverlay extends StatelessWidget {
  final String statusText;
  final double progress;
  final double overlayOpacity;

  const DetectionProgressOverlay({
    super.key,
    required this.statusText,
    required this.progress,
    this.overlayOpacity = 0.65,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final screenWidth = MediaQuery.of(context).size.width;
    final double clampedProgressWidth =
        ((screenWidth * 0.45).clamp(160.0, 240.0)).toDouble();

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(overlayOpacity),
        padding: EdgeInsets.symmetric(horizontal: spacing.l),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(
                radius: 18,
                color: Colors.white,
              ),
              SizedBox(height: spacing.l * 1.1),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  statusText,
                  key: ValueKey(statusText),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'PlusJakartaSans',
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              SizedBox(height: spacing.l),
              SizedBox(
                width: clampedProgressWidth,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 5,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
