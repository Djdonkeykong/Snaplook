"""
API routes with smart caching integration.
Add these routes to your FastAPI app.

IMPORTANT: user_id must be a valid auth.users.id from Supabase Auth.
"""

import os
import sys
import uuid
from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
import base64
from PIL import Image
import io
from datetime import datetime

from supabase_client import supabase_manager
from hash_utils import hash_image, normalize_url

# Force stdout to flush immediately for debugging
sys.stdout.reconfigure(line_buffering=True)

router = APIRouter(prefix="/api/v1")

# ============================================
# REQUEST/RESPONSE MODELS
# ============================================

class AnalyzeRequest(BaseModel):
    user_id: str  # Must be auth.users.id
    image_url: Optional[str] = None
    image_base64: Optional[str] = None
    cloudinary_url: Optional[str] = None
    search_type: str = "unknown"  # instagram, photos, camera, web
    source_url: Optional[str] = None
    source_username: Optional[str] = None
    skip_detection: bool = False
    country: Optional[str] = None  # ISO 3166-1 alpha-2 country code (e.g., 'US', 'NO', 'GB')
    language: Optional[str] = None  # Language code for interface (e.g., 'en', 'nb', 'fr')


class AnalyzeResponse(BaseModel):
    success: bool
    cached: bool
    cache_age_seconds: Optional[int] = None
    search_id: Optional[str] = None
    image_cache_id: Optional[str] = None
    total_results: int
    garments_searched: int = 0
    detected_garments: List[Dict[str, Any]]
    search_results: List[Dict[str, Any]]
    message: Optional[str] = None


class FavoriteRequest(BaseModel):
    user_id: str  # Must be auth.users.id
    product: Dict[str, Any]  # Contains product_id, product_name, brand, price, etc.


class SaveSearchRequest(BaseModel):
    user_id: str  # Must be auth.users.id
    name: Optional[str] = None


# ============================================
# CACHE CHECK ENDPOINT
# ============================================

@router.get("/cache/check")
async def check_cache(source_url: str):
    """
    Cache checking temporarily disabled.
    Always returns cache miss to ensure location-specific results.
    """
    # Cache checking disabled - always return miss
    # This ensures users always get fresh, location-appropriate results
    return {"cached": False}

@router.get("/instagram/cache")
async def check_instagram_cache(url: str):
    """
    Check if an Instagram URL has a cached image URL.
    Returns cached image URL when available.
    """
    if not supabase_manager.enabled:
        return {"cached": False}

    image_url = supabase_manager.check_instagram_url_cache(url)
    if image_url:
        return {"cached": True, "image_url": image_url}
    return {"cached": False}


# ============================================
# ANALYZE ENDPOINT WITH CACHING
# ============================================

@router.post("/analyze", response_model=AnalyzeResponse)
async def analyze_with_caching(
    request: AnalyzeRequest,
    background_tasks: BackgroundTasks
):
    """
    Main analysis endpoint with smart caching.

    Flow:
    1. Check cache by URL/hash
    2. If cache hit: Return instant results + create user_search entry
    3. If cache miss: Run full analysis + store in cache + create user_search entry

    NOTE: user_id must be a valid auth.users.id
    """
    # Log IMMEDIATELY when function is called, before any processing
    print(f"\n[ANALYZE] >>> ENDPOINT FUNCTION CALLED <<<", flush=True)
    sys.stdout.flush()

    try:
        print(f"\n{'='*80}", flush=True)
        print(f"[ANALYZE] 🚀 NEW REQUEST RECEIVED", flush=True)
        print(f"{'='*80}", flush=True)
        sys.stdout.flush()  # Force immediate flush
        print(f"[ANALYZE] user_id: {request.user_id}")
        print(f"[ANALYZE] search_type: '{request.search_type}'")
        print(f"[ANALYZE] country: '{request.country}', language: '{request.language}'")
        print(f"[ANALYZE] skip_detection: {request.skip_detection}")
        print(f"[ANALYZE] source_url: {request.source_url}")
        print(f"[ANALYZE] source_username: {request.source_username}")

        # Prepare image and compute hash
        image_url = None
        image_hash = None
        image_obj = None

        print(f"[ANALYZE] 📸 Image source check:")
        print(f"  - has image_url: {bool(request.image_url)}")
        print(f"  - has cloudinary_url: {bool(request.cloudinary_url)}")
        print(f"  - has image_base64: {bool(request.image_base64)}")

        if request.image_url:
            image_url = normalize_url(request.image_url)
            print(f"[ANALYZE] Using image_url: {image_url[:100]}...")
        elif request.cloudinary_url:
            image_url = request.cloudinary_url
            print(f"[ANALYZE] Using cloudinary_url: {image_url[:100]}...")

        # Decode image if base64 provided (for hashing)
        if request.image_base64:
            base64_len = len(request.image_base64)
            print(f"[ANALYZE] 🔍 Decoding base64 image ({base64_len} chars, ~{base64_len * 3 / 4 / 1024:.1f}KB)")
            image_data = base64.b64decode(request.image_base64)
            print(f"[ANALYZE] Decoded to {len(image_data)} bytes ({len(image_data) / 1024:.1f}KB)")

            print(f"[ANALYZE] Opening PIL Image for hashing...")
            image_obj = Image.open(io.BytesIO(image_data))
            print(f"[ANALYZE] Image size: {image_obj.size}, mode: {image_obj.mode}")

            print(f"[ANALYZE] Computing image hash...")
            image_hash = hash_image(image_obj)
            print(f"[ANALYZE] Image hash: {image_hash}")

        # Cache checking disabled - always run full analysis for location-specific results
        print(f"[ANALYZE] 🔄 Running full analysis (cache disabled for location-aware results)")

        # Import the existing detection function
        from fashion_detector_server import run_full_detection_pipeline

        print(f"[ANALYZE] 🎯 Calling run_full_detection_pipeline...")
        print(f"[ANALYZE]   - skip_detection: {request.skip_detection}")
        print(f"[ANALYZE]   - country: {request.country}")
        print(f"[ANALYZE]   - language: {request.language}")

        # Run the full detection pipeline
        detection_result = run_full_detection_pipeline(
            image_base64=request.image_base64,
            image_url=request.image_url,
            cloudinary_url=request.cloudinary_url,
            skip_detection=request.skip_detection,
            country=request.country,
            language=request.language
        )

        print(f"[ANALYZE] ✅ Detection pipeline completed")
        print(f"[ANALYZE]   - success: {detection_result.get('success')}")
        print(f"[ANALYZE]   - total_results: {detection_result.get('total_results', 0)}")
        print(f"[ANALYZE]   - garments_searched: {detection_result.get('garments_searched', 0)}")
        print(f"[ANALYZE]   - has cloudinary_url: {bool(detection_result.get('cloudinary_url'))}")

        if not detection_result['success']:
            print(f"[ANALYZE] ❌ Detection failed: {detection_result.get('message', 'Unknown error')}")
            if image_obj:
                print(f"[ANALYZE] 🧹 Closing image_obj (error path)")
                image_obj.close()
            return AnalyzeResponse(
                success=False,
                cached=False,
                total_results=0,
                garments_searched=0,
                detected_garments=[],
                search_results=[],
                message=detection_result.get('message', 'Analysis failed')
            )

        # Store results for user history (cache lookups are disabled)
        cache_id = None
        print(f"[ANALYZE] 💾 Cache storage check:")
        print(f"  - supabase_enabled: {supabase_manager.enabled}")
        print(f"  - has user_id: {bool(request.user_id)}")
        print(f"  - has cloudinary_url: {bool(detection_result.get('cloudinary_url'))}")

        if supabase_manager.enabled and request.user_id and detection_result.get('cloudinary_url'):
            cache_hash = image_hash or (hash_image(image_obj) if image_obj else None) or uuid.uuid4().hex
            print(f"[ANALYZE] Storing cache with hash: {cache_hash}")

            cache_id = supabase_manager.store_cache(
                image_url=image_url or detection_result.get('cloudinary_url'),
                image_hash=cache_hash,
                cloudinary_url=detection_result['cloudinary_url'],
                detected_garments=detection_result.get('detected_garments', []),
                search_results=detection_result.get('results', [])
            )
            print(f"[ANALYZE] ✅ Cache stored with ID: {cache_id}")
        else:
            print(f"[ANALYZE] ⏭️  Skipping cache storage")

        # Close image object to prevent memory leak
        if image_obj:
            print(f"[ANALYZE] 🧹 Closing image_obj (success path)")
            image_obj.close()
            print(f"[ANALYZE] ✅ image_obj closed successfully")

        # Also save to Instagram URL cache if this is an Instagram share
        # This allows future requests for the same Instagram URL to skip scraping
        print(f"[ANALYZE] 📷 Instagram cache check:")
        print(f"  - search_type: {request.search_type}")
        print(f"  - has source_url: {bool(request.source_url)}")

        if supabase_manager.enabled and request.search_type == "instagram" and request.source_url and detection_result.get('cloudinary_url'):
            print(f"[ANALYZE] Saving Instagram URL mapping...")
            supabase_manager.save_instagram_url_cache(
                instagram_url=request.source_url,
                image_url=detection_result['cloudinary_url'],
                extraction_method='server_upload'
            )
            print(f"[ANALYZE] ✅ Instagram URL cached: {request.source_url[:50]}... -> Cloudinary")
        else:
            print(f"[ANALYZE] ⏭️  Skipping Instagram URL cache")

        # Create user search entry
        search_id = None
        print(f"[ANALYZE] 📝 User search creation check:")
        print(f"  - supabase_enabled: {supabase_manager.enabled}")
        print(f"  - has cache_id: {bool(cache_id)}")

        if supabase_manager.enabled and cache_id:
            print(f"[ANALYZE] Creating user search entry...")
            search_id = supabase_manager.create_user_search(
                user_id=request.user_id,
                image_cache_id=cache_id,
                search_type=request.search_type,
                source_url=request.source_url,
                source_username=request.source_username
            )
            print(f"[ANALYZE] ✅ User search created with ID: {search_id}")
        else:
            print(f"[ANALYZE] ⏭️  Skipping user search creation")

        print(f"\n[ANALYZE] 🎉 ANALYSIS COMPLETE")
        print(f"[ANALYZE]   - search_id: {search_id}")
        print(f"[ANALYZE]   - cache_id: {cache_id}")
        print(f"[ANALYZE]   - total_results: {detection_result.get('total_results', 0)}")
        print(f"[ANALYZE]   - garments_searched: {detection_result.get('garments_searched', 0)}")
        print(f"{'='*80}\n")

        return AnalyzeResponse(
            success=True,
            cached=False,
            search_id=search_id,
            image_cache_id=cache_id,
            total_results=detection_result.get('total_results', 0),
            garments_searched=detection_result.get('garments_searched', 0),
            detected_garments=detection_result.get('detected_garments', []),
            search_results=detection_result.get('results', [])
        )

    except Exception as e:
        print(f"\n{'='*80}")
        print(f"[ANALYZE] ❌❌❌ FATAL ERROR ❌❌❌")
        print(f"{'='*80}")
        print(f"[ANALYZE] Error type: {type(e).__name__}")
        print(f"[ANALYZE] Error message: {e}")
        print(f"[ANALYZE] Full traceback:")
        import traceback
        traceback.print_exc()
        print(f"{'='*80}\n")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================
# FAVORITES ENDPOINTS
# ============================================

@router.post("/favorites")
async def add_favorite(request: FavoriteRequest):
    """Add product to user_favorites table (idempotent)"""
    if not supabase_manager.enabled:
        raise HTTPException(status_code=503, detail="Database not available")

    product = request.product
    product_id = product.get('id', product.get('product_id', ''))

    # Try to add favorite
    favorite_id = supabase_manager.add_favorite(
        user_id=request.user_id,
        product_id=product_id,
        product_name=product.get('product_name', ''),
        brand=product.get('brand', ''),
        price=float(product.get('price', 0)),
        image_url=product.get('image_url', ''),
        purchase_url=product.get('purchase_url'),
        category=product.get('category', '')
    )

    if favorite_id:
        return {"success": True, "favorite_id": favorite_id, "already_existed": False}
    else:
        # If it returns None, it means it already exists (duplicate)
        # Make this idempotent - check if it exists and return success
        existing = supabase_manager.get_existing_favorite(request.user_id, product_id)
        if existing:
            return {"success": True, "favorite_id": existing['id'], "already_existed": True}
        else:
            raise HTTPException(status_code=400, detail="Failed to add favorite")


@router.delete("/favorites/{favorite_id}")
async def remove_favorite(favorite_id: str, user_id: str):
    """Remove favorite"""
    if not supabase_manager.enabled:
        raise HTTPException(status_code=503, detail="Database not available")

    success = supabase_manager.remove_favorite(user_id, favorite_id)

    if success:
        return {"success": True}
    else:
        raise HTTPException(status_code=400, detail="Failed to remove favorite")


@router.get("/users/{user_id}/favorites")
async def get_favorites(user_id: str, limit: int = 50, offset: int = 0):
    """Get user favorites"""
    if not supabase_manager.enabled:
        raise HTTPException(status_code=503, detail="Database not available")

    favorites = supabase_manager.get_user_favorites(user_id, limit, offset)

    return {
        "favorites": favorites,
        "total": len(favorites),
        "limit": limit,
        "offset": offset
    }


@router.post("/users/{user_id}/favorites/check")
async def check_favorites(user_id: str, product_ids: List[str]):
    """
    Check which product IDs are already favorited by the user.
    Returns a list of product_ids that are in favorites.
    """
    if not supabase_manager.enabled:
        raise HTTPException(status_code=503, detail="Database not available")

    favorited_ids = supabase_manager.check_favorited_products(user_id, product_ids)

    return {
        "favorited_product_ids": favorited_ids
    }


# ============================================
# SAVED SEARCHES ENDPOINTS
# ============================================

@router.post("/searches/{search_id}/save")
async def save_search(search_id: str, request: SaveSearchRequest):
    """Save entire search"""
    if not supabase_manager.enabled:
        raise HTTPException(status_code=503, detail="Database not available")

    saved_id = supabase_manager.save_search(
        user_id=request.user_id,
        search_id=search_id,
        name=request.name
    )

    if saved_id:
        return {"success": True, "saved_search_id": saved_id}
    else:
        raise HTTPException(status_code=400, detail="Failed to save search or already saved")


@router.delete("/saved-searches/{saved_search_id}")
async def unsave_search(saved_search_id: str, user_id: str):
    """Unsave a search"""
    if not supabase_manager.enabled:
        raise HTTPException(status_code=503, detail="Database not available")

    success = supabase_manager.unsave_search(user_id, saved_search_id)

    if success:
        return {"success": True}
    else:
        raise HTTPException(status_code=400, detail="Failed to unsave search")


# ============================================
# USER HISTORY ENDPOINTS
# ============================================

@router.get("/users/{user_id}/searches")
async def get_user_searches(user_id: str, limit: int = 20, offset: int = 0):
    """Get user search history"""
    if not supabase_manager.enabled:
        raise HTTPException(status_code=503, detail="Database not available")

    searches = supabase_manager.get_user_searches(user_id, limit, offset)

    return {
        "searches": searches,
        "total": len(searches),
        "limit": limit,
        "offset": offset
    }
