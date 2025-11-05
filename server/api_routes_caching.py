"""
API routes with smart caching integration.
Add these routes to your FastAPI app.

IMPORTANT: user_id must be a valid auth.users.id from Supabase Auth.
"""

from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
import base64
from PIL import Image
import io
from datetime import datetime

from supabase_client import supabase_manager
from hash_utils import hash_image, normalize_url

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


class AnalyzeResponse(BaseModel):
    success: bool
    cached: bool
    cache_age_seconds: Optional[int] = None
    search_id: Optional[str] = None
    image_cache_id: Optional[str] = None
    total_results: int
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

    try:
        # Prepare image and compute hash
        image_url = None
        image_hash = None
        image_obj = None

        if request.image_url:
            image_url = normalize_url(request.image_url)
        elif request.cloudinary_url:
            image_url = request.cloudinary_url

        # Decode image if base64 provided (for hashing)
        if request.image_base64:
            image_data = base64.b64decode(request.image_base64)
            image_obj = Image.open(io.BytesIO(image_data))
            image_hash = hash_image(image_obj)

        # Step 1: Check cache
        # For Instagram posts, check by source_url first (avoids re-downloading)
        cache_entry = None
        if supabase_manager.enabled:
            if request.search_type == "instagram" and request.source_url:
                cache_entry = supabase_manager.check_cache_by_source(request.source_url)

            # If no cache hit by source, try by image URL/hash
            if not cache_entry:
                cache_entry = supabase_manager.check_cache(
                    image_url=image_url,
                    image_hash=image_hash
                )

        # Step 2: Cache HIT - Return instant results
        if cache_entry:
            print(f"CACHE HIT - Returning instant results")

            # Calculate cache age
            cache_age = None
            if cache_entry.get('created_at'):
                created = datetime.fromisoformat(cache_entry['created_at'].replace('Z', '+00:00'))
                cache_age = int((datetime.now(created.tzinfo) - created).total_seconds())

            # Increment hit counter in background
            if supabase_manager.enabled:
                background_tasks.add_task(
                    supabase_manager.increment_cache_hit,
                    cache_entry['id']
                )

            # Create user search entry
            search_id = None
            if supabase_manager.enabled:
                search_id = supabase_manager.create_user_search(
                    user_id=request.user_id,
                    image_cache_id=cache_entry['id'],
                    search_type=request.search_type,
                    source_url=request.source_url,
                    source_username=request.source_username
                )

            return AnalyzeResponse(
                success=True,
                cached=True,
                cache_age_seconds=cache_age,
                search_id=search_id,
                image_cache_id=cache_entry['id'],
                total_results=cache_entry.get('total_results', 0),
                detected_garments=cache_entry.get('detected_garments', []),
                search_results=cache_entry.get('search_results', [])
            )

        # Step 3: Cache MISS - Run full analysis
        print(f"CACHE MISS - Running full analysis")

        # Import the existing detection function
        from fashion_detector_server import run_full_detection_pipeline

        # Run the full detection pipeline
        detection_result = run_full_detection_pipeline(
            image_base64=request.image_base64,
            image_url=request.image_url,
            cloudinary_url=request.cloudinary_url,
            skip_detection=request.skip_detection
        )

        if not detection_result['success']:
            return AnalyzeResponse(
                success=False,
                cached=False,
                total_results=0,
                detected_garments=[],
                search_results=[],
                message=detection_result.get('message', 'Analysis failed')
            )

        # Store in cache
        cache_id = None
        if supabase_manager.enabled and detection_result.get('cloudinary_url'):
            cache_id = supabase_manager.store_cache(
                image_url=image_url or detection_result.get('cloudinary_url'),
                image_hash=image_hash or hash_image(image_obj) if image_obj else "",
                cloudinary_url=detection_result['cloudinary_url'],
                detected_garments=detection_result.get('detected_garments', []),
                search_results=detection_result.get('results', [])
            )

        # Create user search entry
        search_id = None
        if supabase_manager.enabled and cache_id:
            search_id = supabase_manager.create_user_search(
                user_id=request.user_id,
                image_cache_id=cache_id,
                search_type=request.search_type,
                source_url=request.source_url,
                source_username=request.source_username
            )

        return AnalyzeResponse(
            success=True,
            cached=False,
            search_id=search_id,
            image_cache_id=cache_id,
            total_results=detection_result.get('total_results', 0),
            detected_garments=detection_result.get('detected_garments', []),
            search_results=detection_result.get('results', [])
        )

    except Exception as e:
        print(f"ERROR: Analyze endpoint error: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


# ============================================
# FAVORITES ENDPOINTS
# ============================================

@router.post("/favorites")
async def add_favorite(request: FavoriteRequest):
    """Add product to favorites table"""
    if not supabase_manager.enabled:
        raise HTTPException(status_code=503, detail="Database not available")

    product = request.product
    favorite_id = supabase_manager.add_favorite(
        user_id=request.user_id,
        product_id=product.get('id', product.get('product_id', '')),
        product_name=product.get('product_name', ''),
        brand=product.get('brand', ''),
        price=float(product.get('price', 0)),
        image_url=product.get('image_url', ''),
        purchase_url=product.get('purchase_url'),
        category=product.get('category', '')
    )

    if favorite_id:
        return {"success": True, "favorite_id": favorite_id}
    else:
        raise HTTPException(status_code=400, detail="Failed to add favorite or already exists")


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
