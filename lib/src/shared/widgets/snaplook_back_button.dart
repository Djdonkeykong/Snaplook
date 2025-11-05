import 'package:flutter/material.dart';

class SnaplookBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool showBackground;

  const SnaplookBackButton({
    super.key,
    this.onPressed,
    this.showBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );

    if (!showBackground) {
      return button;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: button,
    );
  }
}
