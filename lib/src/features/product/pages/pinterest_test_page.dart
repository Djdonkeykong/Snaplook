import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/detected_item.dart';

class PinterestTestPage extends StatefulWidget {
  const PinterestTestPage({super.key});

  @override
  State<PinterestTestPage> createState() => _PinterestTestPageState();
}

class _PinterestTestPageState extends State<PinterestTestPage> {
  List<Map<String, dynamic>> products = [];
  Map<String, dynamic>? selectedProduct;
  List<DetectedItem> detectedItems = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => isLoading = true);

    try {
      // Get product IDs that have detected items
      final detectedItemsResponse = await Supabase.instance.client
          .from('detected_items')
          .select('product_id')
          .limit(100);

      final productIds = (detectedItemsResponse as List)
          .map((item) => item['product_id'] as int)
          .toSet()
          .toList();

      print('Found ${productIds.length} products with detected items');

      if (productIds.isEmpty) {
        setState(() {
          products = [];
          isLoading = false;
        });
        return;
      }

      // Load products that have detected items
      final response = await Supabase.instance.client
          .from('products')
          .select('id, title, image_url, category')
          .inFilter('id', productIds)
          .limit(20);

      print('Loaded ${response.length} products');

      setState(() {
        products = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      print('Error loading products: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadDetectedItems(int productId) async {
    setState(() => isLoading = true);

    try {
      // Load detected items with embeddings
      final response = await Supabase.instance.client
          .from('detected_items')
          .select('id, item_type, bbox, confidence, embedding')
          .eq('product_id', productId);

      print('Raw response: ${response.length} items');

      final items = (response as List)
          .map((item) => DetectedItem.fromJson(item))
          .toList();

      print('Loaded ${items.length} detected items for product $productId');
      for (var item in items) {
        print('  - ${item.itemType}: bbox(${item.bbox.x1}, ${item.bbox.y1}, ${item.bbox.x2}, ${item.bbox.y2})');
      }

      setState(() {
        detectedItems = items;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading detected items: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Pinterest-Style Search Test'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Left: Product list
                SizedBox(
                  width: 300,
                  child: ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final isSelected = selectedProduct?['id'] == product['id'];

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: const Color(0xFFFFEBEE),
                        leading: Image.network(
                          product['image_url'],
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.image),
                        ),
                        title: Text(
                          product['title'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        subtitle: Text(
                          product['category'],
                          style: const TextStyle(fontSize: 10),
                        ),
                        onTap: () {
                          setState(() => selectedProduct = product);
                          _loadDetectedItems(product['id']);
                        },
                      );
                    },
                  ),
                ),
                const VerticalDivider(width: 1),
                // Right: Selected product with tap regions
                Expanded(
                  child: selectedProduct == null
                      ? const Center(
                          child: Text('Select a product to test'),
                        )
                      : _buildProductView(),
                ),
              ],
            ),
    );
  }

  Widget _buildProductView() {
    if (selectedProduct == null) return const SizedBox();

    return Column(
      children: [
        // Product info
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selectedProduct!['title'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Category: ${selectedProduct!['category']}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Detected items: ${detectedItems.length}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFf2003c),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        // Image with tap regions
        Expanded(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return InteractiveViewer(
                  child: _buildImageWithTapRegions(),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageWithTapRegions() {
    return Image.network(
      selectedProduct!['image_url'],
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        print('Error loading image: $error');
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 48, color: Colors.red),
              SizedBox(height: 8),
              Text('Failed to load image'),
            ],
          ),
        );
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            return FutureBuilder<ImageInfo>(
              future: _getImageInfo(selectedProduct!['image_url']),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return child;
                }

                final imageInfo = snapshot.data!;
                final imageWidth = imageInfo.image.width.toDouble();
                final imageHeight = imageInfo.image.height.toDouble();

                // Calculate display size
                final containerWidth = constraints.maxWidth;
                final containerHeight = constraints.maxHeight;
                final imageAspect = imageWidth / imageHeight;
                final containerAspect = containerWidth / containerHeight;

                double displayWidth, displayHeight;
                if (containerAspect > imageAspect) {
                  displayHeight = containerHeight;
                  displayWidth = displayHeight * imageAspect;
                } else {
                  displayWidth = containerWidth;
                  displayHeight = displayWidth / imageAspect;
                }

                // Scale bbox coordinates (which are in image coordinate system) to display size
                final scaleX = displayWidth / imageWidth;
                final scaleY = displayHeight / imageHeight;
                final offsetX = (containerWidth - displayWidth) / 2;
                final offsetY = (containerHeight - displayHeight) / 2;

                print('Image: ${imageWidth}x$imageHeight, Display: ${displayWidth}x$displayHeight, Scale: ${scaleX}x$scaleY, Offset: $offsetX,$offsetY');

                return Stack(
                  children: [
                    child,
                    ...detectedItems.map((item) {
                      final scaledLeft = item.bbox.x1 * scaleX + offsetX;
                      final scaledTop = item.bbox.y1 * scaleY + offsetY;
                      final scaledWidth = item.bbox.width * scaleX;
                      final scaledHeight = item.bbox.height * scaleY;

                      return Positioned(
                        left: scaledLeft,
                        top: scaledTop,
                        width: scaledWidth,
                        height: scaledHeight,
                        child: GestureDetector(
                          onTap: () {
                            print('Tapped on ${item.itemType}');
                            _onTapRegion(item);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFf2003c),
                                width: 2,
                              ),
                              color: const Color(0xFFf2003c).withOpacity(0.2),
                            ),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFf2003c),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${item.itemType}\n${(item.confidence * 100).toInt()}%',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<ImageInfo> _getImageInfo(String imageUrl) async {
    final imageProvider = NetworkImage(imageUrl);
    final completer = Completer<ImageInfo>();
    final stream = imageProvider.resolve(const ImageConfiguration());
    stream.addListener(ImageStreamListener((info, _) {
      if (!completer.isCompleted) {
        completer.complete(info);
      }
    }));
    return completer.future;
  }

  void _onTapRegion(DetectedItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Search for similar ${item.itemType}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Item type: ${item.itemType}'),
            Text('Confidence: ${(item.confidence * 100).toInt()}%'),
            const SizedBox(height: 16),
            const Text(
              'In a real app, this would search for similar items using the embedding.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _searchSimilarItems(item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFf2003c),
            ),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Future<void> _searchSimilarItems(DetectedItem item) async {
    print('Searching for similar ${item.itemType}...');

    if (item.embedding == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Item has no embedding'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Searching for similar items...'),
        backgroundColor: Color(0xFFf2003c),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final response = await Supabase.instance.client.rpc(
        'find_similar_detected_items',
        params: {
          'query_embedding': item.embedding!,
          'match_limit': 20,
          'item_type_filter': null,
        },
      );

      print('Search results: ${response.length} similar items found');

      if (!mounted) return;

      // Get product details for the results
      final productIds = response
          .map((r) => r['product_id'] as int)
          .toSet()
          .toList();

      final productsResponse = await Supabase.instance.client
          .from('products')
          .select('id, title, image_url, category')
          .inFilter('id', productIds);

      final productsMap = {
        for (var p in productsResponse) p['id']: p
      };

      // Show results in a dialog
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Similar ${item.itemType}s (${response.length})'),
          content: SizedBox(
            width: double.maxFinite,
            height: 500,
            child: response.isEmpty
                ? const Center(child: Text('No similar items found'))
                : ListView.builder(
                    itemCount: response.length,
                    itemBuilder: (context, index) {
                      final result = response[index];
                      final similarity =
                          (result['similarity'] * 100).toStringAsFixed(1);
                      final product = productsMap[result['product_id']];

                      return ListTile(
                        leading: product?['image_url'] != null
                            ? Image.network(
                                product!['image_url'],
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.image),
                              )
                            : const Icon(Icons.image),
                        title: Text(
                          product?['title'] ?? 'Unknown',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          '$similarity% match | ${result['item_type']}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFf2003c),
                          ),
                        ),
                        trailing: Text(
                          product?['category'] ?? '',
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error searching for similar items: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
