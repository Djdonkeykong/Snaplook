"""
Supabase client for Snaplook backend.
Handles all database operations including caching, user history, and favorites.

IMPORTANT: Users MUST be authenticated via Supabase Auth before using these APIs.
The iOS app handles authentication and sends the auth user ID.
"""

import os
from typing import Optional, Dict, Any, List
from supabase import create_client, Client
from datetime import datetime, timedelta

# Get Supabase credentials from environment
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY")  # Service role key for server

class SupabaseManager:
    """Singleton manager for Supabase operations"""

    _instance: Optional['SupabaseManager'] = None
    _client: Optional[Client] = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self):
        if self._client is None:
            if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
                print("WARNING: Supabase credentials not found in environment")
                print("Set SUPABASE_URL and SUPABASE_SERVICE_KEY to enable caching")
                self._client = None
            else:
                self._client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
                print("Supabase client initialized")

    @property
    def client(self) -> Optional[Client]:
        return self._client

    @property
    def enabled(self) -> bool:
        return self._client is not None

    # ============================================
    # IMAGE CACHE OPERATIONS
    # ============================================

    def check_cache_by_source(self, source_url: str) -> Optional[Dict[str, Any]]:
        """
        Check if we've already analyzed this Instagram/source URL.
        Returns cache entry if found and not expired, None otherwise.
        """
        if not self.enabled:
            return None

        try:
            # Find a user_search with this source_url
            response = self.client.table('user_searches')\
                .select('image_cache_id, image_cache(*)')\
                .eq('source_url', source_url)\
                .order('created_at', desc=True)\
                .limit(1)\
                .execute()

            if response.data and len(response.data) > 0:
                search = response.data[0]
                cache_data = search.get('image_cache')

                if cache_data:
                    # Check if cache is still valid
                    expires_at_str = cache_data.get('expires_at')
                    if expires_at_str:
                        expires_at = datetime.fromisoformat(expires_at_str.replace('Z', '+00:00'))
                        if expires_at > datetime.now(expires_at.tzinfo):
                            print(f"Cache HIT for Instagram URL: {source_url[:50]}...")
                            return cache_data

            return None

        except Exception as e:
            print(f"Cache check by source error: {e}")
            return None

    def check_cache(self, image_url: Optional[str] = None, image_hash: Optional[str] = None) -> Optional[Dict[str, Any]]:
        """
        Check if image exists in cache by URL or hash.
        Returns cache entry if found and not expired, None otherwise.
        """
        if not self.enabled:
            return None

        try:
            # Try to find by URL first (fastest)
            if image_url:
                response = self.client.table('image_cache')\
                    .select('*')\
                    .eq('image_url', image_url)\
                    .gt('expires_at', datetime.now().isoformat())\
                    .single()\
                    .execute()

                if response.data:
                    print(f"Cache HIT for URL: {image_url[:50]}...")
                    return response.data

            # Try by hash if URL miss
            if image_hash:
                response = self.client.table('image_cache')\
                    .select('*')\
                    .eq('image_hash', image_hash)\
                    .gt('expires_at', datetime.now().isoformat())\
                    .single()\
                    .execute()

                if response.data:
                    print(f"Cache HIT for hash: {image_hash[:16]}...")
                    return response.data

            print(f"Cache MISS for image")
            return None

        except Exception as e:
            print(f"Cache check error: {e}")
            return None

    def store_cache(
        self,
        image_url: Optional[str],
        image_hash: str,
        cloudinary_url: str,
        detected_garments: List[Dict],
        search_results: List[Dict],
        expires_in_days: int = 30
    ) -> Optional[str]:
        """
        Store analysis results in cache.
        Returns cache ID if successful, None otherwise.
        """
        if not self.enabled:
            return None

        try:
            expires_at = datetime.now() + timedelta(days=expires_in_days)

            cache_entry = {
                'image_url': image_url,
                'image_hash': image_hash,
                'cloudinary_url': cloudinary_url,
                'detected_garments': detected_garments,
                'search_results': search_results,
                'total_results': len(search_results),
                'expires_at': expires_at.isoformat(),
                'cache_hits': 0
            }

            response = self.client.table('image_cache')\
                .insert(cache_entry)\
                .execute()

            if response.data:
                cache_id = response.data[0]['id']
                print(f"Stored in cache: {cache_id}")
                return cache_id

            return None

        except Exception as e:
            print(f"Cache store error: {e}")
            return None

    def increment_cache_hit(self, cache_id: str):
        """Increment cache hit counter"""
        if not self.enabled:
            return

        try:
            self.client.rpc('increment_cache_hit', {'cache_id': cache_id}).execute()
        except Exception as e:
            print(f"Cache hit increment error: {e}")

    # ============================================
    # USER SEARCH HISTORY
    # ============================================

    def create_user_search(
        self,
        user_id: str,
        image_cache_id: str,
        search_type: str,
        source_url: Optional[str] = None,
        source_username: Optional[str] = None
    ) -> Optional[str]:
        """
        Create a user search history entry.
        user_id must be a valid auth.users.id
        Returns search_id if successful.
        """
        if not self.enabled:
            return None

        try:
            search_entry = {
                'user_id': user_id,
                'image_cache_id': image_cache_id,
                'search_type': search_type,
                'source_url': source_url,
                'source_username': source_username
            }

            response = self.client.table('user_searches')\
                .insert(search_entry)\
                .execute()

            if response.data:
                search_id = response.data[0]['id']
                print(f"Created user search: {search_id}")
                return search_id

            return None

        except Exception as e:
            print(f"User search creation error: {e}")
            return None

    def get_user_searches(
        self,
        user_id: str,
        limit: int = 20,
        offset: int = 0
    ) -> List[Dict[str, Any]]:
        """Get user's search history with cache data"""
        if not self.enabled:
            return []

        try:
            response = self.client.from_('v_user_recent_searches')\
                .select('*')\
                .eq('user_id', user_id)\
                .order('created_at', desc=True)\
                .range(offset, offset + limit - 1)\
                .execute()

            return response.data or []

        except Exception as e:
            print(f"Get user searches error: {e}")
            return []

    # ============================================
    # FAVORITES - Using existing 'favorites' table
    # ============================================

    def add_favorite(
        self,
        user_id: str,
        product_id: str,
        product_name: str,
        brand: str,
        price: float,
        image_url: str,
        purchase_url: Optional[str],
        category: str
    ) -> Optional[str]:
        """
        Add a product to favorites table.
        user_id must be a valid auth.users.id
        """
        if not self.enabled:
            return None

        try:
            favorite_entry = {
                'user_id': user_id,
                'product_id': product_id,
                'product_name': product_name,
                'brand': brand,
                'price': price,
                'image_url': image_url,
                'purchase_url': purchase_url,
                'category': category
            }

            response = self.client.table('favorites')\
                .insert(favorite_entry)\
                .execute()

            if response.data:
                favorite_id = response.data[0]['id']
                print(f"Added favorite: {favorite_id}")
                return favorite_id

            return None

        except Exception as e:
            # Handle unique constraint violation (already favorited)
            if 'duplicate key' in str(e):
                print(f"Product already favorited by user")
                return None
            print(f"Add favorite error: {e}")
            return None

    def get_existing_favorite(
        self,
        user_id: str,
        product_id: str
    ) -> Optional[Dict[str, Any]]:
        """
        Check if a favorite already exists for this user and product.
        Returns the favorite entry if it exists, None otherwise.
        """
        if not self.enabled:
            return None

        try:
            response = self.client.table('favorites')\
                .select('*')\
                .eq('user_id', user_id)\
                .eq('product_id', product_id)\
                .limit(1)\
                .execute()

            if response.data and len(response.data) > 0:
                return response.data[0]

            return None

        except Exception as e:
            print(f"Get existing favorite error: {e}")
            return None

    def remove_favorite(self, user_id: str, favorite_id: str) -> bool:
        """Remove a favorite"""
        if not self.enabled:
            return False

        try:
            response = self.client.table('favorites')\
                .delete()\
                .eq('id', favorite_id)\
                .eq('user_id', user_id)\
                .execute()

            return True

        except Exception as e:
            print(f"Remove favorite error: {e}")
            return False

    def get_user_favorites(
        self,
        user_id: str,
        limit: int = 50,
        offset: int = 0
    ) -> List[Dict[str, Any]]:
        """Get user's favorites from favorites table"""
        if not self.enabled:
            return []

        try:
            response = self.client.table('favorites')\
                .select('*')\
                .eq('user_id', user_id)\
                .order('created_at', desc=True)\
                .range(offset, offset + limit - 1)\
                .execute()

            return response.data or []

        except Exception as e:
            print(f"Get user favorites error: {e}")
            return []

    # ============================================
    # SAVED SEARCHES
    # ============================================

    def save_search(
        self,
        user_id: str,
        search_id: str,
        name: Optional[str] = None
    ) -> Optional[str]:
        """Save an entire search"""
        if not self.enabled:
            return None

        try:
            saved_entry = {
                'user_id': user_id,
                'search_id': search_id,
                'name': name
            }

            response = self.client.table('user_saved_searches')\
                .insert(saved_entry)\
                .execute()

            if response.data:
                saved_id = response.data[0]['id']
                print(f"Saved search: {saved_id}")
                return saved_id

            return None

        except Exception as e:
            # Handle unique constraint (already saved)
            if 'duplicate key' in str(e):
                print(f"Search already saved by user")
                return None
            print(f"Save search error: {e}")
            return None

    def unsave_search(self, user_id: str, saved_search_id: str) -> bool:
        """Unsave a search"""
        if not self.enabled:
            return False

        try:
            response = self.client.table('user_saved_searches')\
                .delete()\
                .eq('id', saved_search_id)\
                .eq('user_id', user_id)\
                .execute()

            return True

        except Exception as e:
            print(f"Unsave search error: {e}")
            return False


# Singleton instance
supabase_manager = SupabaseManager()
