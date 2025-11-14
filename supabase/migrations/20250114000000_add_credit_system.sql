-- Add credit system columns to profiles table
-- Free users get 1 free analysis, paid users get 100 credits/month

-- Add columns if they don't exist
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS free_analyses_remaining INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS paid_credits_remaining INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS subscription_tier TEXT DEFAULT 'free' CHECK (subscription_tier IN ('free', 'monthly', 'yearly')),
ADD COLUMN IF NOT EXISTS credits_reset_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
ADD COLUMN IF NOT EXISTS total_analyses_performed INTEGER DEFAULT 0;

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_profiles_subscription_tier ON profiles(subscription_tier);
CREATE INDEX IF NOT EXISTS idx_profiles_credits_reset_date ON profiles(credits_reset_date);

-- Add comment to explain the system
COMMENT ON COLUMN profiles.free_analyses_remaining IS 'Free users get 1 analysis (can include multiple garments)';
COMMENT ON COLUMN profiles.paid_credits_remaining IS 'Paid users: 1 credit = 1 garment search result. Monthly/yearly users get 100 credits/month';
COMMENT ON COLUMN profiles.subscription_tier IS 'User subscription level: free, monthly, or yearly';
COMMENT ON COLUMN profiles.credits_reset_date IS 'Date when monthly credits should reset for paid users';
COMMENT ON COLUMN profiles.total_analyses_performed IS 'Total number of analyses performed by user (for analytics)';
