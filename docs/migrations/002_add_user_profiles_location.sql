-- Migration: Add user profiles with location support for localized search results
-- Created: 2025-11-09

-- ============================================
-- USER PROFILES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Location data for localized search
    country_code TEXT, -- ISO 3166-1 alpha-2 (e.g., 'US', 'GB', 'CA')
    country_name TEXT, -- Human-readable (e.g., 'United States')
    location TEXT, -- SearchAPI location string (e.g., 'United States', 'United Kingdom')
    detected_location TEXT, -- Auto-detected from IP/GPS
    manual_location BOOLEAN DEFAULT FALSE, -- User manually set location vs auto-detected

    -- User preferences
    preferred_currency TEXT DEFAULT 'USD', -- For price display
    preferred_language TEXT DEFAULT 'en', -- For search results

    -- Privacy settings
    enable_location BOOLEAN DEFAULT TRUE, -- User opted in/out of location-based results

    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX idx_user_profiles_country ON user_profiles(country_code);
CREATE INDEX idx_user_profiles_location_enabled ON user_profiles(enable_location);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Users can view their own profile
CREATE POLICY "Users can view own profile"
    ON user_profiles FOR SELECT
    USING (auth.uid() = id);

-- Users can insert their own profile (on signup)
CREATE POLICY "Users can insert own profile"
    ON user_profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
    ON user_profiles FOR UPDATE
    USING (auth.uid() = id);

-- ============================================
-- TRIGGER: Auto-update updated_at
-- ============================================
CREATE OR REPLACE FUNCTION update_user_profile_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_user_profile_timestamp
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_user_profile_updated_at();

-- ============================================
-- FUNCTION: Create default profile on user signup
-- ============================================
CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_profiles (id, country_code, country_name, location)
    VALUES (
        NEW.id,
        'US', -- Default to United States
        'United States',
        'United States'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-create profile when user signs up
CREATE TRIGGER trigger_create_user_profile
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION create_user_profile();

-- ============================================
-- HELPER FUNCTION: Get user's search location
-- ============================================
CREATE OR REPLACE FUNCTION get_user_search_location(user_uuid UUID)
RETURNS TEXT AS $$
DECLARE
    user_location TEXT;
    location_enabled BOOLEAN;
BEGIN
    -- Get user's location and privacy setting
    SELECT location, enable_location
    INTO user_location, location_enabled
    FROM user_profiles
    WHERE id = user_uuid;

    -- Return location if enabled, else default to 'United States'
    IF location_enabled THEN
        RETURN COALESCE(user_location, 'United States');
    ELSE
        RETURN 'United States'; -- Privacy fallback
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- LOCATION MAPPING DATA
-- ============================================
-- Common SearchAPI location strings
COMMENT ON COLUMN user_profiles.location IS
'SearchAPI location string. Common values:
- United States
- United Kingdom
- Canada
- Australia
- France
- Germany
- Italy
- Spain
- Japan
- South Korea
See: https://serpapi.com/locations';

COMMENT ON COLUMN user_profiles.country_code IS
'ISO 3166-1 alpha-2 country code (2 letters).
Examples: US, GB, CA, AU, FR, DE, IT, ES, JP, KR';

COMMENT ON COLUMN user_profiles.preferred_currency IS
'ISO 4217 currency code (3 letters).
Examples: USD, GBP, CAD, AUD, EUR, JPY, KRW';
