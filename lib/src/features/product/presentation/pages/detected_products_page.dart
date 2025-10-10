import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'product_detail_page.dart';
import '../../../../../shared/navigation/main_navigation.dart' show isAtHomeRootProvider;

class DetectedProductsPage extends ConsumerStatefulWidget {
  const DetectedProductsPage({super.key});

  @override
  ConsumerState<DetectedProductsPage> createState() => _DetectedProductsPageState();
}

class _DetectedProductsPageState extends ConsumerState<DetectedProductsPage> {
  List<Map<String, dynamic>> products = [];
  bool isLoading = true;

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
          .limit(1000);

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
          .limit(100);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Products with Visual Search'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFf2003c),
              ),
            )
          : products.isEmpty
              ? const Center(
                  child: Text('No products with detected items found'),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return GestureDetector(
                      onTap: () {
                        // The floating bar was already hidden when we navigated here
                        // No need to hide again, but keep state consistent
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ProductDetailPage(
                              product: product,
                              heroTag: 'detected_${product['id']}',
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product image
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                child: product['image_url'] != null
                                    ? Image.network(
                                        product['image_url'],
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.image),
                                      )
                                    : const Icon(Icons.image),
                              ),
                            ),
                            // Product info
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product['title'] ?? 'Unknown',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFf2003c),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Visual Search',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
