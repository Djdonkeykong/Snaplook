import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../detection/domain/models/detection_result.dart';
import '../../domain/providers/favorites_provider.dart';
import '../../../../../core/theme/snaplook_icons.dart';

class FavoriteButton extends ConsumerStatefulWidget {
  final DetectionResult product;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;

  const FavoriteButton({
    super.key,
    required this.product,
    this.size = 24,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    HapticFeedback.mediumImpact();

    _controller.forward().then((_) {
      _controller.reverse();
    });

    // Check current state before toggling
    final wasAlreadyFavorited = ref.read(isFavoriteProvider(widget.product.id));

    try {
      await ref.read(favoritesProvider.notifier).toggleFavorite(widget.product);

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              wasAlreadyFavorited ? 'Removed from favorites' : 'Added to favorites',
              style: const TextStyle(fontFamily: 'PlusJakartaSans'),
            ),
            duration: const Duration(milliseconds: 2500),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update favorites: ${e.toString()}',
              style: const TextStyle(fontFamily: 'PlusJakartaSans'),
            ),
            duration: const Duration(milliseconds: 2500),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = ref.watch(isFavoriteProvider(widget.product.id));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.75),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 3,
                    offset: const Offset(0, 1.5),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  isFavorite ? SnaplookIcons.heartFilled : SnaplookIcons.heartOutline,
                  size: 12,
                  color: isFavorite
                      ? (widget.activeColor ?? const Color(0xFFf2003c))
                      : (widget.inactiveColor ?? Colors.black),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Compact favorite icon for smaller spaces
class FavoriteIconButton extends ConsumerWidget {
  final DetectionResult product;
  final double size;

  const FavoriteIconButton({
    super.key,
    required this.product,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isFavoriteProvider(product.id));

    return IconButton(
      icon: Transform.translate(
        offset: isFavorite ? Offset.zero : const Offset(-1, 0),
        child: Icon(
          isFavorite ? SnaplookIcons.heartFilled : SnaplookIcons.heartOutline,
          size: isFavorite ? size * 0.85 : size * 0.75,
          color: isFavorite ? const Color(0xFFf2003c) : Colors.black,
        ),
      ),
      onPressed: () async {
        try {
          await ref.read(favoritesProvider.notifier).toggleFavorite(product);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update favorites: ${e.toString()}'),
              ),
            );
          }
        }
      },
    );
  }
}
