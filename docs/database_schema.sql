-- Snaplook Database Schema for Supabase
-- Smart caching + user history/favorites system

-- ============================================
-- GLOBAL IMAGE CACHE (shared across all users)
-- ============================================
CREATE TABLE image_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Image identification (for cache hits)
    image_url TEXT UNIQUE, -- Original image URL (Instagram, Photos, etc.)
    image_hash TEXT UNIQUE, -- SHA256 hash of image content (for duplicate detection)
    cloudinary_url TEXT NOT NULL, -- Where we stored the analyzed image

    -- Analysis results (stored as JSONB for flexibility)
    detected_garments JSONB NOT NULL, -- YOLO detection results
    search_results JSONB NOT NULL, -- SerpAPI product results
    total_results INTEGER DEFAULT 0,

    -- Cache metadata
    cache_hits INTEGER DEFAULT 0, -- Track how often this cache is used
    expires_at TIMESTAMP WITH TIME ZONE, -- Cache expiration (30 days default)

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for fast cache lookups
CREATE INDEX idx_image_cache_url ON image_cache(image_url);
CREATE INDEX idx_image_cache_hash ON image_cache(image_hash);
CREATE INDEX idx_image_cache_expires ON image_cache(expires_at);

-- ============================================
-- USER SEARCH HISTORY
-- ============================================
CREATE TABLE user_searches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Link to global cache
    image_cache_id UUID NOT NULL REFERENCES image_cache(id) ON DELETE CASCADE,

    -- Search context
    search_type TEXT NOT NULL, -- 'instagram', 'photos', 'camera', 'web'
    source_url TEXT, -- Original Instagram/web URL if applicable
    source_username TEXT, -- Instagram username if applicable

    -- User annotations (optional)
    custom_name TEXT, -- User can rename their search

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for user queries
CREATE INDEX idx_user_searches_user ON user_searches(user_id, created_at DESC);
CREATE INDEX idx_user_searches_cache ON user_searches(image_cache_id);

-- ============================================
-- USER FAVORITES (hearted products)
-- ============================================
CREATE TABLE user_favorites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    search_id UUID REFERENCES user_searches(id) ON DELETE SET NULL, -- Optional: link to search

    -- Product details (denormalized for fast access)
    product_data JSONB NOT NULL, -- Full product object
    product_url TEXT NOT NULL,
    product_name TEXT NOT NULL,
    brand TEXT,
    category TEXT,
    image_url TEXT,
    price NUMERIC(10,2),

    -- User notes (future feature)
    notes TEXT,

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for user favorites queries
CREATE INDEX idx_user_favorites_user ON user_favorites(user_id, created_at DESC);
CREATE INDEX idx_user_favorites_search ON user_favorites(search_id);
CREATE UNIQUE INDEX idx_user_favorites_unique ON user_favorites(user_id, product_url);

-- ============================================
-- SAVED SEARCHES (Save All button)
-- ============================================
CREATE TABLE user_saved_searches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    search_id UUID NOT NULL REFERENCES user_searches(id) ON DELETE CASCADE,

    -- User can give it a name
    name TEXT,

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_saved_searches_user ON user_saved_searches(user_id, created_at DESC);
CREATE UNIQUE INDEX idx_saved_searches_unique ON user_saved_searches(user_id, search_id);

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================

-- Enable RLS
ALTER TABLE user_searches ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_saved_searches ENABLE ROW LEVEL SECURITY;

-- image_cache is public (no RLS - shared cache)
-- But only server can write to it

-- User can only see their own searches
CREATE POLICY "Users can view own searches"
    ON user_searches FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own searches"
    ON user_searches FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- User can only see/manage their own favorites
CREATE POLICY "Users can view own favorites"
    ON user_favorites FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own favorites"
    ON user_favorites FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own favorites"
    ON user_favorites FOR DELETE
    USING (auth.uid() = user_id);

-- User can only see/manage their own saved searches
CREATE POLICY "Users can view own saved searches"
    ON user_saved_searches FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own saved searches"
    ON user_saved_searches FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own saved searches"
    ON user_saved_searches FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================
-- FUNCTIONS FOR CLEANUP
-- ============================================

-- Function to clean expired cache entries
CREATE OR REPLACE FUNCTION clean_expired_cache()
RETURNS void AS $$
BEGIN
    DELETE FROM image_cache
    WHERE expires_at < NOW()
    AND cache_hits < 5; -- Keep popular ones even if expired
END;
$$ LANGUAGE plpgsql;

-- Function to update cache hit count
CREATE OR REPLACE FUNCTION increment_cache_hit(cache_id UUID)
RETURNS void AS $$
BEGIN
    UPDATE image_cache
    SET cache_hits = cache_hits + 1,
        updated_at = NOW()
    WHERE id = cache_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- VIEWS FOR COMMON QUERIES
-- ============================================

-- View: User's recent searches with cache data
CREATE OR REPLACE VIEW v_user_recent_searches AS
SELECT
    us.id,
    us.user_id,
    us.search_type,
    us.source_url,
    us.source_username,
    us.custom_name,
    us.created_at,
    ic.cloudinary_url,
    ic.total_results,
    ic.detected_garments,
    ic.search_results,
    EXISTS(
        SELECT 1 FROM user_saved_searches uss
        WHERE uss.search_id = us.id
    ) as is_saved
FROM user_searches us
JOIN image_cache ic ON us.image_cache_id = ic.id
ORDER BY us.created_at DESC;

-- View: User's favorites with search context
CREATE OR REPLACE VIEW v_user_favorites_enriched AS
SELECT
    uf.*,
    us.source_url,
    us.source_username,
    us.created_at as search_date
FROM user_favorites uf
LEFT JOIN user_searches us ON uf.search_id = us.id
ORDER BY uf.created_at DESC;
