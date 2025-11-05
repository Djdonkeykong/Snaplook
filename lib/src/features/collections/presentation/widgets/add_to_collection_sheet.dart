import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/theme/snaplook_icons.dart';
import '../../domain/providers/collections_provider.dart';
import '../../domain/models/collection.dart';

class AddToCollectionSheet extends ConsumerStatefulWidget {
  final String productId;
  final String productName;
  final String brand;
  final double price;
  final String imageUrl;
  final String? purchaseUrl;
  final String category;

  const AddToCollectionSheet({
    super.key,
    required this.productId,
    required this.productName,
    required this.brand,
    required this.price,
    required this.imageUrl,
    this.purchaseUrl,
    required this.category,
  });

  @override
  ConsumerState<AddToCollectionSheet> createState() => _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends ConsumerState<AddToCollectionSheet> {
  void _showCreateCollectionDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Create Collection',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'Collection name',
                hintStyle: const TextStyle(
                  color: AppColors.textTertiary,
                  fontFamily: 'PlusJakartaSans',
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
              ),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Description (optional)',
                hintStyle: const TextStyle(
                  color: AppColors.textTertiary,
                  fontFamily: 'PlusJakartaSans',
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                return;
              }

              try {
                await ref.read(collectionsProvider.notifier).createCollection(
                      name: nameController.text.trim(),
                      description: descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                    );

                if (!mounted) return;
                Navigator.pop(context);

                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Collection "${nameController.text.trim()}" created',
                      style: const TextStyle(fontFamily: 'PlusJakartaSans'),
                    ),
                    backgroundColor: Colors.black,
                    duration: const Duration(milliseconds: 2500),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Error creating collection: ${e.toString()}',
                      style: const TextStyle(fontFamily: 'PlusJakartaSans'),
                    ),
                    backgroundColor: Colors.red,
                    duration: const Duration(milliseconds: 2500),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFf2003c),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Create',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToCollection(Collection collection) async {
    try {
      await ref.read(collectionItemsProvider(collection.id).notifier).addItem(
            productId: widget.productId,
            productName: widget.productName,
            brand: widget.brand,
            price: widget.price,
            imageUrl: widget.imageUrl,
            purchaseUrl: widget.purchaseUrl,
            category: widget.category,
          );

      // Refresh collections to update item counts
      await ref.read(collectionsProvider.notifier).refresh();

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added to "${collection.name}"',
            style: const TextStyle(fontFamily: 'PlusJakartaSans'),
          ),
          backgroundColor: Colors.black,
          duration: const Duration(milliseconds: 2500),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error adding to collection: ${e.toString()}',
            style: const TextStyle(fontFamily: 'PlusJakartaSans'),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(milliseconds: 2500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final collectionsAsync = ref.watch(collectionsProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(spacing.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Text(
                    'Add to Collection',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              SizedBox(height: spacing.m),

              // Create new collection button
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _showCreateCollectionDialog();
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(spacing.m),
                  decoration: BoxDecoration(
                    color: const Color(0xFFf2003c).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFf2003c),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          SnaplookIcons.addCircleOutline,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      SizedBox(width: spacing.m),
                      const Text(
                        'Create New Collection',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: spacing.l),

              // Collections list
              collectionsAsync.when(
                data: (collections) {
                  if (collections.isEmpty) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: spacing.xl),
                      child: Center(
                        child: Text(
                          'No collections yet.\nCreate your first one above!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  }

                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: collections.length,
                      separatorBuilder: (_, __) => SizedBox(height: spacing.m),
                      itemBuilder: (context, index) {
                        final collection = collections[index];
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            _addToCollection(collection);
                          },
                          child: Container(
                            padding: EdgeInsets.all(spacing.m),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                // Collection cover or icon
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: collection.coverImageUrl != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            collection.coverImageUrl!,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : const Icon(
                                          SnaplookIcons.addCircleOutline,
                                          color: AppColors.textSecondary,
                                          size: 24,
                                        ),
                                ),
                                SizedBox(width: spacing.m),
                                // Collection info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        collection.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'PlusJakartaSans',
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (collection.description != null)
                                        Text(
                                          collection.description!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                            fontFamily: 'PlusJakartaSans',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      Text(
                                        '${collection.itemCount} items',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textTertiary,
                                          fontFamily: 'PlusJakartaSans',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: AppColors.textTertiary,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => Padding(
                  padding: EdgeInsets.symmetric(vertical: spacing.xl),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFf2003c),
                    ),
                  ),
                ),
                error: (error, stack) => Padding(
                  padding: EdgeInsets.symmetric(vertical: spacing.xl),
                  child: Center(
                    child: Text(
                      'Error loading collections',
                      style: TextStyle(
                        color: Colors.red,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
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
