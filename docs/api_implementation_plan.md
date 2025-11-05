# Snaplook Backend API Implementation Plan

## Overview
Smart caching system that saves API costs and provides instant results for duplicate images while building comprehensive user history/favorites.

## Key Features

### 1. Smart Image Caching
- **Cache Key**: Image URL + SHA256 hash
- **Cache Hit**: Return results instantly (no SerpAPI call)
- **Cache Miss**: Run full analysis, store results
- **Expiration**: 30 days (configurable)
- **Popular Content**: Keep high-traffic items longer

### 2. Cost Savings
- Same Instagram post analyzed by 1000 users = 1 SerpAPI call (not 1000!)
- Popular fashion influencer posts cached instantly
- Estimated savings: 60-80% of API costs

### 3. User Features
- Search history (chronological, with thumbnails)
- Favorite individual products (heart button)
- Save entire searches (save button)
- Cross-device sync via Supabase

## API Endpoints

### Cache & Analysis

```
POST /api/v1/analyze
Request:
{
  "user_id": "uuid",
  "image_url": "https://...",  // OR
  "image_base64": "...",        // OR
  "cloudinary_url": "...",      // (from iOS upload)
  "search_type": "instagram|photos|camera",
  "source_url": "https://instagram.com/...",  // optional
  "source_username": "@fashionblogger"  // optional
}

Response (Cache Hit):
{
  "cached": true,
  "cache_age_seconds": 3600,
  "search_id": "uuid",
  "image_cache_id": "uuid",
  "total_results": 20,
  "detected_garments": [{...}],
  "search_results": [{...}]
}

Response (Cache Miss):
{
  "cached": false,
  "search_id": "uuid",
  "image_cache_id": "uuid",
  "total_results": 20,
  "detected_garments": [{...}],
  "search_results": [{...}]
}
```

### User History

```
GET /api/v1/users/{user_id}/searches?limit=20&offset=0
Response:
{
  "searches": [
    {
      "id": "uuid",
      "search_type": "instagram",
      "source_url": "...",
      "source_username": "@user",
      "cloudinary_url": "...",
      "total_results": 18,
      "created_at": "2025-11-05T...",
      "is_saved": false
    }
  ],
  "total": 45,
  "limit": 20,
  "offset": 0
}
```

### Favorites (Heart Button)

```
POST /api/v1/favorites
Request:
{
  "user_id": "uuid",
  "search_id": "uuid",  // optional
  "product": {
    "product_name": "...",
    "brand": "...",
    "price": 49.99,
    "image_url": "...",
    "purchase_url": "...",
    "category": "dresses"
  }
}

Response:
{
  "favorite_id": "uuid",
  "created_at": "..."
}

DELETE /api/v1/favorites/{favorite_id}
Response: {success: true}

GET /api/v1/users/{user_id}/favorites?limit=20&offset=0
Response:
{
  "favorites": [{...}],
  "total": 12
}
```

### Saved Searches (Save Button)

```
POST /api/v1/searches/{search_id}/save
Request:
{
  "user_id": "uuid",
  "name": "Cute Summer Dress"  // optional
}

Response:
{
  "saved_search_id": "uuid"
}

DELETE /api/v1/saved-searches/{saved_search_id}
Response: {success: true}

GET /api/v1/users/{user_id}/saved-searches
Response:
{
  "saved_searches": [
    {
      "id": "uuid",
      "name": "Cute Summer Dress",
      "search": {...},  // Full search details
      "created_at": "..."
    }
  ]
}
```

## Implementation Steps

### Phase 1: Database Setup (30 min)
1. Run `database_schema.sql` in Supabase
2. Test tables and RLS policies
3. Create service role key for server

### Phase 2: Server Implementation (2-3 hours)
Files to create/modify:

```
server/
├── supabase_client.py       # NEW: Supabase client setup
├── cache_manager.py          # NEW: Cache check/store logic
├── hash_utils.py             # NEW: Image hashing
├── api_routes.py             # NEW: API endpoints
└── fashion_detector_server.py # MODIFY: Integrate caching
```

### Phase 3: iOS Integration (1-2 hours)
- Modify ShareExtension to call new API
- Add authentication (Supabase Auth)
- Heart button → POST /api/v1/favorites
- Save button → POST /api/v1/searches/{id}/save

### Phase 4: Flutter App (2-3 hours)
- Wardrobe tab: Show favorites
- History tab: Show searches
- Implement pull-to-refresh
- Add authentication flow

## Cost Analysis

### Before (No Caching):
- 1000 users analyze same Instagram post = 1000 SerpAPI calls
- Cost: 1000 × $0.02 = $20

### After (With Caching):
- 1000 users analyze same post = 1 SerpAPI call + 999 cache hits
- Cost: 1 × $0.02 = $0.02
- **Savings: $19.98 (99.9%)**

### Realistic Estimate:
- Average 60-70% cache hit rate
- **Estimated savings: $1200-1500/month** (at 100k searches/month)

## Next Steps

Would you like me to:
1. **Start with Phase 1** - Create the database schema in Supabase?
2. **Or Phase 2** - Implement the Python server code first?
3. **Or see the complete server implementation** before we start?

I recommend starting with the database, then server, then clients. This is a 1-2 day implementation if we go methodically.
