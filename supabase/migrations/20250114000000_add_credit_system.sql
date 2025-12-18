-- Add credit system columns to users table
-- Free users get 1 free analysis, paid users get 100 credits/month

-- Add columns if they don't exist
ALTER TABLE users
ADD COLUMN IF NOT EXISTS free_analyses_remaining INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS paid_credits_remaining INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS credits_reset_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
ADD COLUMN IF NOT EXISTS total_analyses_performed INTEGER DEFAULT 0;

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_users_credits_reset_date ON users(credits_reset_date);

-- Add comment to explain the system
COMMENT ON COLUMN users.free_analyses_remaining IS 'Free users get 1 analysis (can include multiple garments)';
COMMENT ON COLUMN users.paid_credits_remaining IS 'Paid users: 1 credit = 1 garment search result. Monthly/yearly users get 100 credits/month';
COMMENT ON COLUMN users.credits_reset_date IS 'Date when monthly credits should reset for paid users';
COMMENT ON COLUMN users.total_analyses_performed IS 'Total number of analyses performed by user (for analytics)';
