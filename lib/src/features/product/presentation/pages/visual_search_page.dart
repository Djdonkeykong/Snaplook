import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:snaplook/core/theme/app_colors.dart';
import 'package:snaplook/src/shared/widgets/snaplook_circular_icon_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/detected_item.dart';

class VisualSearchPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const VisualSearchPage({
    super.key,
    required this.product,
  });

  @override
  State<VisualSearchPage> createState() => _VisualSearchPageState();
}

class _VisualSearchPageState extends State<VisualSearchPage> {
  List<DetectedItem> detectedItems = [];
  List<DetectedItem> gridEmbeddings = []; // Pre-computed grid cells
  bool isLoadingItems = true;
  String? selectedItemType;
  List<Map<String, dynamic>> similarProducts = [];
  bool isLoadingSearch = false;

  // Crop box state
  Rect? cropBox;
  bool showCropBox = false;
  Timer? _searchDebounceTimer;

  // Original image dimensions (fetched from network)
  Size? originalImageSize;

  // Minimum crop box size
  static const double minCropSize = 100.0;

  @override
  void initState() {
    super.initState();
    // Load pre-computed detected items from database
    _loadDetectedItems();
    // Get actual image dimensions
    _loadImageDimensions();
  }

  Future<void> _loadImageDimensions() async {
    try {
      final image = NetworkImage(widget.product['image_url']);
      final completer = Completer<ImageInfo>();
      final imageStream = image.resolve(const ImageConfiguration());

      imageStream.addListener(ImageStreamListener((info, _) {
        if (!completer.isCompleted) {
          completer.complete(info);
        }
      }));

      final imageInfo = await completer.future;
      setState(() {
        originalImageSize = Size(
          imageInfo.image.width.toDouble(),
          imageInfo.image.height.toDouble(),
        );
      });

      print('Original image size: ${imageInfo.image.width}x${imageInfo.image.height}');
    } catch (e) {
      print('Error loading image dimensions: $e');
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDetectedItems() async {
    // Disabled: detected_items table does not exist
    // setState(() => isLoadingItems = true);
    //
    // try {
    //   final productId = widget.product['id'];
    //
    //   final response = await Supabase.instance.client
    //       .from('detected_items')
    //       .select('id, item_type, bbox, confidence, embedding')
    //       .eq('product_id', productId);
    //
    //   print('[Detection] Loaded ${response.length} items from database');
    //
    //   final items = (response as List)
    //       .map((item) => DetectedItem.fromJson(item))
    //       .toList();
    //
    //   // Separate grid embeddings from other detected items
    //   final grids = items.where((item) => item.itemType.startsWith('grid_')).toList();
    //   final others = items.where((item) => !item.itemType.startsWith('grid_')).toList();
    //
    //   print('[Detection] Found ${grids.length} grid embeddings and ${others.length} fashion items');
    //
    //   setState(() {
    //     gridEmbeddings = grids;
    //     detectedItems = others;
    //     isLoadingItems = false;
    //
    //     // Enable crop box if we have grid embeddings
    //     if (grids.isNotEmpty) {
    //       showCropBox = true;
    //       print('[Detection] Crop box enabled (grid-based search)');
    //     }
    //   });
    //
    // } catch (e) {
    //   print('[Detection] Error loading items: $e');
    //   setState(() => isLoadingItems = false);
    // }

    // Set empty state to avoid errors
    setState(() {
      gridEmbeddings = [];
      detectedItems = [];
      isLoadingItems = false;
    });
  }

  String _getCategoryGroup(String itemType) {
    final type = itemType.toLowerCase();

    // Group similar items for better search results
    if (type.contains('shirt') ||
        type.contains('blouse') ||
        type.contains('top') ||
        type.contains('t-shirt') ||
        type.contains('sweatshirt') ||
        type.contains('sweater') ||
        type.contains('cardigan') ||
        type.contains('vest') ||
        type.contains('jacket')) {
      return 'tops';
    }

    if (type.contains('pants') ||
        type.contains('shorts') ||
        type.contains('skirt') ||
        type.contains('jeans') ||
        type.contains('trousers')) {
      return 'bottoms';
    }

    if (type.contains('coat')) {
      return 'outerwear';
    }

    if (type.contains('shoe') || type.contains('boot') || type.contains('sandal')) {
      return 'shoes';
    }

    if (type.contains('bag') || type.contains('wallet') || type.contains('purse')) {
      return 'bags';
    }

    if (type.contains('hat') || type.contains('cap') || type.contains('beanie')) {
      return 'headwear';
    }

    if (type.contains('dress') || type.contains('jumpsuit') || type.contains('romper')) {
      return 'dresses';
    }

    if (type.contains('belt') ||
        type.contains('scarf') ||
        type.contains('tie') ||
        type.contains('glove') ||
        type.contains('glasses') ||
        type.contains('watch')) {
      return 'accessories';
    }

    // Default: return original type
    return type;
  }

  Future<void> _searchSimilarItems(DetectedItem item) async {
    // Disabled: detected_items table does not exist
    setState(() {
      similarProducts = [];
      isLoadingSearch = false;
    });
    return;

    // if (item.embedding == null) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(
    //       content: Text('Error: Item has no embedding'),
    //       backgroundColor: Colors.red,
    //     ),
    //   );
    //   return;
    // }
    //
    // // Map to category group for UI display and search
    // final categoryGroup = _getCategoryGroup(item.itemType);
    //
    // setState(() {
    //   selectedItemType = categoryGroup; // Show group instead of specific type
    //   isLoadingSearch = true;
    //   similarProducts = [];
    // });
    //
    // try {
    //
    //   print('\n=== SEARCH DEBUG ===');
    //   print('[Search] Detected item type: ${item.itemType}');
    //   print('[Search] Category group: $categoryGroup');
    //   print('[Search] Embedding length: ${item.embedding!.length}');
    //   print('[Search] Looking for similar $categoryGroup items');
    //
    //   // Search WITHOUT item type filter, we'll filter by category group after
    //   final response = await Supabase.instance.client.rpc(
    //     'find_similar_detected_items',
    //     params: {
    //       'query_embedding': item.embedding!,
    //       'match_limit': 100,
    //       'item_type_filter': null,
    //     },
    //   );
    // } catch (e) {
    //   print('Error searching for similar items: $e');
    // }
  }

  DetectedItem? _findBestMatchingItem(Rect cropRect, Size imageSize) {
    if (detectedItems.isEmpty) return null;
    if (originalImageSize == null) {
      print('Original image size not loaded yet, using estimated scaling');
      return null;
    }

    print('\n=== Crop Detection Debug ===');
    print('Crop box: ${cropRect.left.toInt()},${cropRect.top.toInt()} -> ${cropRect.right.toInt()},${cropRect.bottom.toInt()} (${cropRect.width.toInt()}x${cropRect.height.toInt()})');
    print('Display size: ${imageSize.width.toInt()}x${imageSize.height.toInt()}');
    print('Original size: ${originalImageSize!.width.toInt()}x${originalImageSize!.height.toInt()}');
    print('Detected items: ${detectedItems.length}');

    DetectedItem? bestMatch;
    double bestOverlap = 0.0;

    // Calculate scaling factors from original to display
    final scaleX = imageSize.width / originalImageSize!.width;
    final scaleY = imageSize.height / originalImageSize!.height;

    print('Scale factors: ${scaleX.toStringAsFixed(2)}x, ${scaleY.toStringAsFixed(2)}y');

    for (final item in detectedItems) {
      // bbox coordinates are in original image pixels (typically 200-300px images)
      // Scale them to current display size
      final itemRect = Rect.fromLTRB(
        item.bbox.x1 * scaleX,
        item.bbox.y1 * scaleY,
        item.bbox.x2 * scaleX,
        item.bbox.y2 * scaleY,
      );

      print('  ${item.itemType}: bbox_orig=[${item.bbox.x1.toInt()},${item.bbox.y1.toInt()},${item.bbox.x2.toInt()},${item.bbox.y2.toInt()}]');
      print('    -> scaled: ${itemRect.left.toInt()},${itemRect.top.toInt()} -> ${itemRect.right.toInt()},${itemRect.bottom.toInt()} (${itemRect.width.toInt()}x${itemRect.height.toInt()})');

      // Calculate intersection over union (IoU)
      final intersection = cropRect.intersect(itemRect);

      if (intersection.isEmpty) {
        print('    -> No intersection');
        continue;
      }

      final intersectionArea = intersection.width * intersection.height;
      final cropArea = cropRect.width * cropRect.height;
      final itemArea = itemRect.width * itemRect.height;
      final unionArea = cropArea + itemArea - intersectionArea;

      final iou = intersectionArea / unionArea;
      print('    -> IoU: ${iou.toStringAsFixed(3)} (intersection: ${intersectionArea.toInt()}, crop: ${cropArea.toInt()}, item: ${itemArea.toInt()})');

      if (iou > bestOverlap) {
        bestOverlap = iou;
        bestMatch = item;
      }
    }

    // If no good overlap, find item with center closest to crop center
    if (bestMatch == null || bestOverlap < 0.1) {
      print('No good overlap found (best: ${bestOverlap.toStringAsFixed(3)}), using closest center');
      final cropCenter = cropRect.center;
      double minDistance = double.infinity;

      for (final item in detectedItems) {
        // Calculate center point and scale to display size
        final itemCenter = Offset(
          ((item.bbox.x1 + item.bbox.x2) / 2) * scaleX,
          ((item.bbox.y1 + item.bbox.y2) / 2) * scaleY,
        );

        final distance = (cropCenter - itemCenter).distance;
        print('  ${item.itemType}: center=${itemCenter.dx.toInt()},${itemCenter.dy.toInt()}, distance=${distance.toInt()}');

        if (distance < minDistance) {
          minDistance = distance;
          bestMatch = item;
        }
      }
    }

    print('SELECTED: ${bestMatch?.itemType} (overlap: ${bestOverlap.toStringAsFixed(3)})');
    print('=== End Debug ===\n');
    return bestMatch;
  }

  void _onImageTap(Offset tapPosition, Size containerSize) {
    // For grid-based search, tapping repositions the crop box
    if (gridEmbeddings.isEmpty && detectedItems.isEmpty) {
      print('No grid embeddings or detected items available');
      return;
    }

    print('[Tap] Position: ${tapPosition.dx.toInt()},${tapPosition.dy.toInt()}');

    // Try to find a detected item at tap position for auto-crop
    DetectedItem? tappedItem = _findItemAtTapPosition(tapPosition, containerSize);

    Rect newCropBox;

    if (tappedItem != null && originalImageSize != null) {
      // AUTO-CROP: User tapped on a detected item - frame it automatically
      print('[Auto-Crop] Tapped on ${tappedItem.itemType}, auto-framing...');

      // Scale bbox from original image to display size
      final scaleX = containerSize.width / originalImageSize!.width;
      final scaleY = containerSize.height / originalImageSize!.height;

      final scaledBbox = Rect.fromLTRB(
        tappedItem.bbox.x1 * scaleX,
        tappedItem.bbox.y1 * scaleY,
        tappedItem.bbox.x2 * scaleX,
        tappedItem.bbox.y2 * scaleY,
      );

      // Add 10% padding around the item for better framing
      final padding = 0.1;
      final paddingX = scaledBbox.width * padding;
      final paddingY = scaledBbox.height * padding;

      newCropBox = Rect.fromLTRB(
        (scaledBbox.left - paddingX).clamp(0.0, containerSize.width),
        (scaledBbox.top - paddingY).clamp(0.0, containerSize.height),
        (scaledBbox.right + paddingX).clamp(0.0, containerSize.width),
        (scaledBbox.bottom + paddingY).clamp(0.0, containerSize.height),
      );

      print('[Auto-Crop] Framed: ${newCropBox.left.toInt()},${newCropBox.top.toInt()} -> ${newCropBox.right.toInt()},${newCropBox.bottom.toInt()} (${newCropBox.width.toInt()}x${newCropBox.height.toInt()})');
    } else {
      // Manual crop: Show crop box centered around tap
      print('[Manual-Crop] No item at tap, using fixed 200x200 box');
      final cropSize = 200.0;
      final left = (tapPosition.dx - cropSize / 2).clamp(0.0, containerSize.width - cropSize);
      final top = (tapPosition.dy - cropSize / 2).clamp(0.0, containerSize.height - cropSize);

      newCropBox = Rect.fromLTWH(left, top, cropSize, cropSize);
    }

    setState(() {
      cropBox = newCropBox;
      showCropBox = true;
    });

    // If we have grid embeddings, search immediately with new position
    if (gridEmbeddings.isNotEmpty) {
      _searchWithCropEmbedding(newCropBox, containerSize);
    } else {
      // Old YOLO-based workflow
      final matchingItem = _findBestMatchingItem(newCropBox, containerSize);
      if (matchingItem != null) {
        _searchSimilarItems(matchingItem);
      }
    }
  }

  DetectedItem? _findItemAtTapPosition(Offset tapPosition, Size containerSize) {
    if (detectedItems.isEmpty || originalImageSize == null) {
      return null;
    }

    final scaleX = containerSize.width / originalImageSize!.width;
    final scaleY = containerSize.height / originalImageSize!.height;

    for (final item in detectedItems) {
      // Scale bbox to display size
      final scaledBbox = Rect.fromLTRB(
        item.bbox.x1 * scaleX,
        item.bbox.y1 * scaleY,
        item.bbox.x2 * scaleX,
        item.bbox.y2 * scaleY,
      );

      // Check if tap is inside this item's bbox
      if (scaledBbox.contains(tapPosition)) {
        print('[Tap Detection] Found ${item.itemType} at tap position');
        return item;
      }
    }

    print('[Tap Detection] No item found at tap position');
    return null;
  }

  void _onCropBoxAdjusted(Size imageSize) {
    // Don't search while dragging - only visual update
    // Search will happen on release (_onCropRelease)
  }

  void _onCropRelease(Size imageSize) {
    // User released crop - now search
    if (cropBox != null) {
      print('[Crop] User released crop, searching...');
      _searchWithCropEmbedding(cropBox!, imageSize);
    }
  }

  DetectedItem? _findNearestGridCell(Rect cropRect, Size displaySize) {
    if (gridEmbeddings.isEmpty) {
      print('[Grid] No grid embeddings available');
      return null;
    }

    if (originalImageSize == null) {
      print('[Grid] Original image size not loaded yet');
      return null;
    }

    // Scale crop box from display coordinates to original image coordinates
    final scaleX = originalImageSize!.width / displaySize.width;
    final scaleY = originalImageSize!.height / displaySize.height;

    final scaledCropRect = Rect.fromLTRB(
      cropRect.left * scaleX,
      cropRect.top * scaleY,
      cropRect.right * scaleX,
      cropRect.bottom * scaleY,
    );

    print('[Grid] Crop in display: ${cropRect.left.toInt()},${cropRect.top.toInt()} -> ${cropRect.right.toInt()},${cropRect.bottom.toInt()}');
    print('[Grid] Crop in original: ${scaledCropRect.left.toInt()},${scaledCropRect.top.toInt()} -> ${scaledCropRect.right.toInt()},${scaledCropRect.bottom.toInt()}');

    double maxOverlap = 0;
    DetectedItem? bestMatch;

    for (final gridCell in gridEmbeddings) {
      // Grid cell bbox is already in original image coordinates
      final gridRect = gridCell.bbox.toRect();
      final intersection = scaledCropRect.intersect(gridRect);

      if (intersection.isEmpty) continue;

      final overlapArea = intersection.width * intersection.height;
      final cropArea = scaledCropRect.width * scaledCropRect.height;
      final overlapPercent = overlapArea / cropArea;

      if (overlapPercent > maxOverlap) {
        maxOverlap = overlapPercent;
        bestMatch = gridCell;
      }
    }

    if (bestMatch != null) {
      print('[Grid] Found best match: ${bestMatch.itemType} with ${(maxOverlap * 100).toStringAsFixed(1)}% overlap');
    } else {
      print('[Grid] No grid cell found with sufficient overlap');
    }

    return bestMatch;
  }

  Future<void> _searchWithCropEmbedding(Rect crop, Size imageSize) async {
    // Disabled: detected_items table does not exist
    setState(() {
      isLoadingSearch = false;
      similarProducts = [];
      selectedItemType = 'items';
    });
    return;

    // try {
    //   setState(() {
    //     isLoadingSearch = true;
    //     similarProducts = [];
    //   });
    //
    //   print('\n=== GRID EMBEDDING SEARCH (INSTANT) ===');
    //
    //   // Find nearest pre-computed grid cell (NO API CALL!)
    //   final gridCell = _findNearestGridCell(crop, imageSize);
    //
    //   if (gridCell == null || gridCell.embedding == null) {
    //     print('[Grid] No grid cell found for crop region');
    //     setState(() {
    //       isLoadingSearch = false;
    //       selectedItemType = 'items';
    //     });
    //     return;
    //   }
    //
    //   print('[Grid] Using pre-computed embedding from ${gridCell.itemType}');
    //   final embedding = gridCell.embedding!;
    //
    //   // Search database with this embedding (no category filtering for Pinterest-style)
    //   final searchResponse = await Supabase.instance.client.rpc(
    //     'find_similar_detected_items',
    //     params: {
    //       'query_embedding': embedding,
    //       'match_limit': 50,
    //       'item_type_filter': null,
    //     },
    //   );
    // } catch (e) {
    //   print('[Crop] Error: $e');
    // }
  }

  void _updateCropBox(Rect newCropBox, Size containerSize) {
    // Ensure crop box stays within bounds
    final clampedRect = Rect.fromLTRB(
      newCropBox.left.clamp(0.0, containerSize.width - minCropSize),
      newCropBox.top.clamp(0.0, containerSize.height - minCropSize),
      newCropBox.right.clamp(minCropSize, containerSize.width),
      newCropBox.bottom.clamp(minCropSize, containerSize.height),
    );

    setState(() {
      cropBox = clampedRect;
    });

    _onCropBoxAdjusted(containerSize);
  }

  String _capitalizeItemType(String? itemType) {
    if (itemType == null) return 'Items';

    // Handle specific plural forms for category groups and item types
    final plurals = {
      // Category groups
      'tops': 'Tops',
      'bottoms': 'Bottoms',
      'outerwear': 'Outerwear',
      'shoes': 'Shoes',
      'bags': 'Bags',
      'headwear': 'Headwear',
      'accessories': 'Accessories',
      'dresses': 'Dresses',
      // Individual item types
      'shoe': 'Shoes',
      'dress': 'Dresses',
      'pants': 'Pants',
      'glasses': 'Glasses',
      'watch': 'Watches',
      'scarf': 'Scarves',
    };

    final normalized = itemType.toLowerCase();
    if (plurals.containsKey(normalized)) {
      return plurals[normalized]!;
    }

    // Default: capitalize first letter and add 's'
    return '${itemType[0].toUpperCase()}${itemType.substring(1)}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen image with tap detection
          Positioned.fill(
            child: GestureDetector(
              onTapDown: (details) {
                if (isLoadingItems) return;

                // Get tap position relative to the image
                final renderBox = context.findRenderObject() as RenderBox?;
                if (renderBox == null) return;

                final localPosition = details.localPosition;
                _onImageTap(localPosition, renderBox.size);
              },
              child: _buildImageWithOverlay(),
            ),
          ),

          // Top bar with back button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: 0,
                right: 8,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  SnaplookCircularIconButton(
                    icon: Icons.close,
                    iconSize: 20,
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                    semanticLabel: 'Close',
                    margin: const EdgeInsets.all(8),
                  ),
                  const Spacer(),
                  if (detectedItems.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Tap on items to search',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Crop box overlay
          if (showCropBox && cropBox != null)
            Positioned.fill(
              child: _buildCropBoxOverlay(),
            ),

          // Bottom sheet with results
          if (selectedItemType != null && similarProducts.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildResultsBottomSheet(),
            ),

          // Loading indicator
          if (isLoadingItems)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageWithOverlay() {
    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Image.network(
            widget.product['image_url'],
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
            // Request image at actual display size for best quality
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Icon(
                  Icons.error,
                  color: Colors.white,
                  size: 48,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCropBoxOverlay() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return Container();
    final containerSize = renderBox.size;

    // Initialize crop box at center if not set
    if (cropBox == null) {
      final cropSize = 200.0;
      final left = (containerSize.width / 2 - cropSize / 2).clamp(0.0, containerSize.width - cropSize);
      final top = (containerSize.height / 2 - cropSize / 2).clamp(0.0, containerSize.height - cropSize);

      // Use WidgetsBinding to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          cropBox = Rect.fromLTWH(left, top, cropSize, cropSize);
        });
      });

      // Return empty for now, will rebuild with cropBox initialized
      return Container();
    }

    return Stack(
      children: [
        // Dark overlay with transparent crop area
        Positioned.fill(
          child: CustomPaint(
            painter: _CropOverlayPainter(cropBox!),
          ),
        ),
        // Crop box with rounded corners
        Positioned(
          left: cropBox!.left,
          top: cropBox!.top,
          child: GestureDetector(
            onPanUpdate: (details) {
              final newCropBox = cropBox!.shift(details.delta);
              _updateCropBox(newCropBox, containerSize);
            },
            onPanEnd: (details) {
              _onCropRelease(containerSize);
            },
            child: Container(
              width: cropBox!.width,
              height: cropBox!.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  // Corner brackets (Pinterest style)
                  _buildCornerBracket(Alignment.topLeft),
                  _buildCornerBracket(Alignment.topRight),
                  _buildCornerBracket(Alignment.bottomLeft),
                  _buildCornerBracket(Alignment.bottomRight),
                  // Invisible resize handles
                  _buildResizeHandle(Alignment.topLeft, containerSize),
                  _buildResizeHandle(Alignment.topRight, containerSize),
                  _buildResizeHandle(Alignment.bottomLeft, containerSize),
                  _buildResizeHandle(Alignment.bottomRight, containerSize),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCornerBracket(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 30,
        height: 30,
        child: CustomPaint(
          painter: _CornerBracketPainter(alignment),
        ),
      ),
    );
  }

  Widget _buildResizeHandle(Alignment alignment, Size containerSize) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        onPanUpdate: (details) {
          final delta = details.delta;
          double newLeft = cropBox!.left;
          double newTop = cropBox!.top;
          double newRight = cropBox!.right;
          double newBottom = cropBox!.bottom;

          // Update based on which corner is being dragged
          if (alignment == Alignment.topLeft) {
            newLeft += delta.dx;
            newTop += delta.dy;
          } else if (alignment == Alignment.topRight) {
            newRight += delta.dx;
            newTop += delta.dy;
          } else if (alignment == Alignment.bottomLeft) {
            newLeft += delta.dx;
            newBottom += delta.dy;
          } else if (alignment == Alignment.bottomRight) {
            newRight += delta.dx;
            newBottom += delta.dy;
          }

          // Ensure minimum size
          if (newRight - newLeft >= minCropSize && newBottom - newTop >= minCropSize) {
            final newCropBox = Rect.fromLTRB(newLeft, newTop, newRight, newBottom);
            _updateCropBox(newCropBox, containerSize);
          }
        },
        onPanEnd: (details) {
          _onCropRelease(containerSize);
        },
        child: Container(
          width: 40,
          height: 40,
          color: Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildResultsBottomSheet() {
    print('[UI] Building bottom sheet with ${similarProducts.length} products, selectedItemType=$selectedItemType, isLoadingSearch=$isLoadingSearch');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Similar ${_capitalizeItemType(selectedItemType)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                if (isLoadingSearch)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFf2003c),
                    ),
                  )
                else if (similarProducts.isNotEmpty)
                  Text(
                    '(${similarProducts.length})',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),

          // Horizontal scrolling product grid
          SizedBox(
            height: 210,
            child: isLoadingSearch
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFf2003c),
                    ),
                  )
                : similarProducts.isEmpty
                    ? const Center(
                        child: Text('No similar items found'),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: similarProducts.length,
                        itemBuilder: (context, index) {
                          final result = similarProducts[index];
                          final similarity =
                              ((result['similarity'] ?? 0) * 100)
                                  .toStringAsFixed(0);

                          if (index == 0) {
                            final title = result['product_title'] as String?;
                            final titlePreview = title != null && title.length > 20 ? title.substring(0, 20) : (title ?? 'null');
                            print('[UI] First item in list: title=$titlePreview, matched_item=${result['item_type']}, product_category=${result['product_category']}, similarity=$similarity%');
                          }

                          return Container(
                            width: 140,
                            margin: const EdgeInsets.only(right: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Product image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    height: 140,
                                    color: Colors.grey.shade100,
                                    child: result['product_image_url'] != null
                                        ? Image.network(
                                            result['product_image_url'],
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(Icons.image),
                                          )
                                        : const Icon(Icons.image),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Item type badge (what was matched)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    result['item_type'] ?? 'unknown',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Similarity badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFf2003c),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$similarity% match',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Product title
                                Flexible(
                                  child: Text(
                                    result['product_title'] ?? 'Unknown',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

// Custom painter for dark overlay with transparent crop area
class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;

  _CropOverlayPainter(this.cropRect);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    // Draw the overlay with a cutout for the crop area
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(cropRect, const Radius.circular(20)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect;
  }
}

// Custom painter for corner brackets (Pinterest style)
class _CornerBracketPainter extends CustomPainter {
  final Alignment alignment;

  _CornerBracketPainter(this.alignment);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final bracketLength = 20.0;
    final cornerRadius = 20.0;
    final path = Path();

    if (alignment == Alignment.topLeft) {
      // Top-left rounded L bracket
      path.moveTo(bracketLength, 0);
      path.lineTo(cornerRadius, 0);
      path.arcToPoint(
        Offset(0, cornerRadius),
        radius: Radius.circular(cornerRadius),
        clockwise: false,
      );
      path.lineTo(0, bracketLength);
    } else if (alignment == Alignment.topRight) {
      // Top-right rounded L bracket
      path.moveTo(size.width - bracketLength, 0);
      path.lineTo(size.width - cornerRadius, 0);
      path.arcToPoint(
        Offset(size.width, cornerRadius),
        radius: Radius.circular(cornerRadius),
        clockwise: true,
      );
      path.lineTo(size.width, bracketLength);
    } else if (alignment == Alignment.bottomLeft) {
      // Bottom-left rounded L bracket
      path.moveTo(0, size.height - bracketLength);
      path.lineTo(0, size.height - cornerRadius);
      path.arcToPoint(
        Offset(cornerRadius, size.height),
        radius: Radius.circular(cornerRadius),
        clockwise: false,
      );
      path.lineTo(bracketLength, size.height);
    } else if (alignment == Alignment.bottomRight) {
      // Bottom-right rounded L bracket
      path.moveTo(size.width, size.height - bracketLength);
      path.lineTo(size.width, size.height - cornerRadius);
      path.arcToPoint(
        Offset(size.width - cornerRadius, size.height),
        radius: Radius.circular(cornerRadius),
        clockwise: true,
      );
      path.lineTo(size.width - bracketLength, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerBracketPainter oldDelegate) {
    return oldDelegate.alignment != alignment;
  }
}
