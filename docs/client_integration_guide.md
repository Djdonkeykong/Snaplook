# Client Integration Guide
## iOS ShareExtension & Flutter App

This guide shows exactly how to integrate the caching system into your iOS and Flutter clients.

---

## Part 1: Database Setup (DO THIS FIRST!)

### Step 1: Run SQL in Supabase

1. Go to your Supabase project: https://app.supabase.com
2. Navigate to **SQL Editor**
3. Copy and paste the entire contents of `docs/database_schema.sql`
4. Click **Run** to create all tables

### Step 2: Get Your Service Role Key

1. In Supabase, go to **Settings** → **API**
2. Copy your `service_role` key (NOT the `anon` key!)
3. Add to `server/.env`:
```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your_service_role_key_here
```

### Step 3: Install Python Dependencies

```bash
cd server
pip install supabase>=2.0.0
```

---

## Part 2: iOS ShareExtension Integration

### Update Detection API Call

**File**: `ios/shareExtension/RSIShareViewController.swift`

**Find this section** (around line 1718):
```swift
private func uploadAndDetect(imageData: Data) {
    // Current code uploads and detects
}
```

**Modify to include user_id and caching**:

```swift
private func uploadAndDetect(imageData: Data) {
    shareLog("START uploadAndDetect - image size: \(imageData.count) bytes")

    // Store the image for sharing later
    analyzedImageData = imageData

    // Stop status polling since we're now in detection mode
    stopStatusPolling()
    hasPresentedDetectionFailureAlert = false

    // NEW: Get user ID (you'll need to implement auth)
    let userId = getUserId() // See auth section below

    // NEW: Prepare request with user context
    let payload: [String: Any] = [
        "user_id": userId,
        "image_base64": imageData.base64EncodedString(),
        "search_type": detectSearchType(), // instagram, photos, camera
        "source_url": pendingInstagramUrl,
        "source_username": extractInstagramUsername(from: pendingInstagramUrl),
        "max_crops": 5,
        "max_results_per_garment": 10
    ]

    // Call new caching endpoint
    let endpoint = "\(AppConstants.serverBaseUrl)/api/v1/analyze"

    // Make request (existing code pattern)
    // ... rest of networking code
}

// NEW: Helper functions
private func getUserId() -> String {
    // TODO: Implement Supabase Auth
    // For now, use device ID or anonymous ID
    if let deviceId = UIDevice.current.identifierForVendor?.uuidString {
        return deviceId
    }
    return "anonymous"
}

private func detectSearchType() -> String {
    if pendingInstagramUrl != nil {
        return "instagram"
    }
    // Check source app
    if let sourceApp = readSourceApplicationBundleIdentifier() {
        if sourceApp.contains("photos") {
            return "photos"
        }
    }
    return "camera"
}

private func extractInstagramUsername(from url: String?) -> String? {
    guard let url = url else { return nil }
    let pattern = "instagram\\.com/([^/?]+)"
    if let regex = try? NSRegularExpression(pattern: pattern),
       let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)) {
        if let range = Range(match.range(at: 1), in: url) {
            return String(url[range])
        }
    }
    return nil
}
```

### Implement Save Button Action

**Find** `@objc private func saveAllTapped()` (around line 2000):

```swift
@objc private func saveAllTapped() {
    shareLog("Save All tapped")

    // Haptic feedback
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.impactOccurred()

    // NEW: Call save API
    guard let searchId = currentSearchId else {
        shareLog("ERROR: No search ID available")
        return
    }

    let userId = getUserId()
    let endpoint = "\(AppConstants.serverBaseUrl)/api/v1/searches/\(searchId)/save"

    var request = URLRequest(url: URL(string: endpoint)!)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    let body: [String: Any] = [
        "user_id": userId,
        "name": nil // User can add custom name later
    ]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            shareLog("Save search error: \(error)")
            return
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            shareLog("Save search failed")
            return
        }

        shareLog("✅ Search saved successfully")

        DispatchQueue.main.async {
            // Show success feedback
            self.showSaveSuccessMessage()
        }
    }
    task.resume()
}

private func showSaveSuccessMessage() {
    // TODO: Show toast/banner that search was saved
    // For now, just log
    shareLog("Search saved to your history!")
}

// NEW: Store search_id from detection response
private var currentSearchId: String?

// In your detection response handler, store the search_id:
// self.currentSearchId = detectionResponse.search_id
```

### Implement Heart Button Action

**Find** heart button tap handler (around line 1900):

```swift
@objc private func heartButtonTapped(_ sender: UIButton) {
    let index = sender.tag
    guard index < detectionResults.count else { return }

    let product = detectionResults[index]
    let isFavorited = sender.isSelected

    // Toggle state
    sender.isSelected = !isFavorited

    // Haptic feedback
    let generator = UIImpactFeedbackGenerator(style: .light)
    generator.impactOccurred()

    if !isFavorited {
        // Add to favorites
        addToFavorites(product: product, heartButton: sender)
    } else {
        // Remove from favorites
        removeFromFavorites(product: product, heartButton: sender)
    }
}

private func addToFavorites(product: DetectionResultItem, heartButton: UIButton) {
    let userId = getUserId()
    let endpoint = "\(AppConstants.serverBaseUrl)/api/v1/favorites"

    var request = URLRequest(url: URL(string: endpoint)!)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    let productData: [String: Any] = [
        "product_name": product.product_name,
        "brand": product.brand ?? "",
        "price": product.price ?? 0.0,
        "image_url": product.image_url,
        "purchase_url": product.purchase_url ?? "",
        "category": product.category
    ]

    let body: [String: Any] = [
        "user_id": userId,
        "search_id": currentSearchId,
        "product": productData
    ]

    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            shareLog("Add favorite error: \(error)")
            DispatchQueue.main.async {
                heartButton.isSelected = false // Revert on error
            }
            return
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            shareLog("Add favorite failed")
            DispatchQueue.main.async {
                heartButton.isSelected = false // Revert on error
            }
            return
        }

        shareLog("✅ Added to favorites")
    }
    task.resume()
}

private func removeFromFavorites(product: DetectionResultItem, heartButton: UIButton) {
    // TODO: Implement unfavorite
    // Need to track favorite_id when adding
    shareLog("Remove from favorites - TODO")
}
```

---

## Part 3: Flutter App Integration

### Create Supabase Service

**File**: `lib/services/supabase_service.dart` (NEW)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final supabase = Supabase.instance.client;

  // Get user favorites
  Future<List<Map<String, dynamic>>> getUserFavorites() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await supabase
        .from('v_user_favorites_enriched')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Get user search history
  Future<List<Map<String, dynamic>>> getUserSearches() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await supabase
        .from('v_user_recent_searches')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    return List<Map<String, dynamic>>.from(response);
  }

  // Remove favorite
  Future<void> removeFavorite(String favoriteId) async {
    await supabase
        .from('user_favorites')
        .delete()
        .eq('id', favoriteId);
  }
}
```

### Create Favorites Screen

**File**: `lib/src/features/wardrobe/presentation/pages/wardrobe_page.dart` (UPDATE)

```dart
import 'package:flutter/material.dart';
import '../../../../services/supabase_service.dart';

class WardrobePage extends StatefulWidget {
  const WardrobePage({super.key});

  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {
  final _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _loading = true);
    try {
      final favorites = await _supabaseService.getUserFavorites();
      setState(() {
        _favorites = favorites;
        _loading = false;
      });
    } catch (e) {
      print('Error loading favorites: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wardrobe'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('No favorites yet', style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 8),
                      Text('Heart products to save them here',
                           style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFavorites,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _favorites.length,
                    itemBuilder: (context, index) {
                      final product = _favorites[index];
                      return _buildProductCard(product);
                    },
                  ),
                ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Image.network(
                  product['image_url'] ?? '',
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.red),
                    onPressed: () => _removeFavorite(product['id']),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['brand'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  product['product_name'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                if (product['price'] != null)
                  Text(
                    '\$${product['price']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeFavorite(String favoriteId) async {
    try {
      await _supabaseService.removeFavorite(favoriteId);
      _loadFavorites(); // Refresh
    } catch (e) {
      print('Error removing favorite: $e');
    }
  }
}
```

---

## Part 4: Testing the Complete Flow

### 1. Start the Server

```bash
cd server
# Make sure .env is configured with Supabase credentials
uvicorn fashion_detector_server:app --reload --port 8000
```

### 2. Test Cache Hit/Miss

**First Request** (Cache Miss):
```bash
curl -X POST http://localhost:8000/api/v1/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test-user-123",
    "image_url": "https://example.com/dress.jpg",
    "search_type": "instagram",
    "source_url": "https://instagram.com/fashionista"
  }'

# Should return: "cached": false
```

**Second Request** (Cache Hit):
```bash
# Same request again
curl -X POST http://localhost:8000/api/v1/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "different-user-456",
    "image_url": "https://example.com/dress.jpg",
    "search_type": "instagram"
  }'

# Should return: "cached": true, "cache_age_seconds": 5
```

### 3. Test Favorites

```bash
# Add favorite
curl -X POST http://localhost:8000/api/v1/favorites \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test-user-123",
    "product": {
      "product_name": "Summer Dress",
      "brand": "Zara",
      "price": 49.99,
      "image_url": "https://...",
      "purchase_url": "https://...",
      "category": "dresses"
    }
  }'

# Get favorites
curl http://localhost:8000/api/v1/users/test-user-123/favorites
```

---

## Part 5: Deployment Checklist

- [ ] Run `database_schema.sql` in Supabase
- [ ] Add Supabase credentials to server `.env`
- [ ] Install `pip install supabase>=2.0.0`
- [ ] Test cache hit/miss locally
- [ ] Implement iOS save/favorite buttons
- [ ] Implement Flutter wardrobe/history screens
- [ ] Add Supabase Auth for real user IDs
- [ ] Monitor cache hit rate in Supabase dashboard
- [ ] Set up cache cleanup cron job (30 days)

---

## Expected Results

### Cost Savings
- **Before**: 100k searches/month × $0.02 = $2000
- **After** (60% cache hit rate): 40k API calls × $0.02 = $800
- **Savings**: $1200/month (60%)

### User Experience
- Cache hit: **Instant results** (< 100ms)
- Cache miss: Normal speed (3-5 seconds)
- Popular Instagram posts: Always instant after first analysis

---

## Next Steps

1. **Run the SQL schema** in Supabase NOW
2. **Configure server environment** with Supabase credentials
3. **Test caching locally** with curl commands
4. **Implement iOS buttons** (save/favorite)
5. **Build Flutter screens** (wardrobe/history)
6. **Deploy and monitor** cache hit rates

You now have a complete caching system that will save thousands of dollars per month!
