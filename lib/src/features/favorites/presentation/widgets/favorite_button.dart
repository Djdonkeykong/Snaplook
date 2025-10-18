import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../detection/domain/models/detection_result.dart';
import '../../domain/providers/favorites_provider.dart';
import '../../../../../core/theme/snaplook_icons.dart';

class FavoriteButton extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isFavoriteProvider(product.id));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        try {
          await ref.read(favoritesProvider.notifier).toggleFavorite(product);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update favorites: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      child: Container(
        width: size + 16,
        height: size + 16,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Transform.translate(
            offset: isFavorite ? Offset.zero : const Offset(-1, 0),
            child: Icon(
              isFavorite ? SnaplookIcons.heartFilled : SnaplookIcons.heartOutline,
              size: isFavorite ? size * 0.85 : size * 0.75,
              color: isFavorite
                  ? (activeColor ?? const Color(0xFFf2003c))
                  : (inactiveColor ?? Colors.grey.shade600),
            ),
          ),
        ),
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
          color: isFavorite ? const Color(0xFFf2003c) : Colors.grey.shade400,
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
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
    );
  }
}
