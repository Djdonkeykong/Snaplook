import 'package:flutter/material.dart';

const double kOnboardingPhoneAspectRatio = 1792 / 828;

class OnboardingPhoneFrame extends StatelessWidget {
  const OnboardingPhoneFrame({
    super.key,
    required this.child,
    this.maxWidth = 430,
    this.backgroundColor,
    this.aspectRatio,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final Color? backgroundColor;
  final double? aspectRatio;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= maxWidth) {
          return child;
        }

        final media = MediaQuery.of(context);
        final maxHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : media.size.height;
        final preferredHeight =
            aspectRatio == null ? maxHeight : maxWidth * aspectRatio!;
        final targetHeight =
            preferredHeight <= maxHeight ? preferredHeight : maxHeight;
        final adjustedSize = Size(maxWidth, targetHeight);
        final adjustedPadding = media.padding.copyWith(left: 0, right: 0);
        final adjustedViewPadding =
            media.viewPadding.copyWith(left: 0, right: 0);
        final adjustedViewInsets = media.viewInsets.copyWith(left: 0, right: 0);

        final adjustedMedia = media.copyWith(
          size: adjustedSize,
          padding: adjustedPadding,
          viewPadding: adjustedViewPadding,
          viewInsets: adjustedViewInsets,
        );

        return ColoredBox(
          color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
          child: Align(
            alignment: alignment,
            child: SizedBox(
              width: maxWidth,
              height: targetHeight,
              child: MediaQuery(
                data: adjustedMedia,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
