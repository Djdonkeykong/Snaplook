-- Function to deduct credits based on garment count
-- For paid users: deduct 1 credit per garment from paid_credits_remaining
-- For free users: deduct 1 from free_analyses_remaining (regardless of garment count)

CREATE OR REPLACE FUNCTION deduct_credits(
  p_user_id UUID,
  p_garment_count INTEGER
)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT,
  free_analyses_remaining INTEGER,
  paid_credits_remaining INTEGER,
  subscription_status TEXT
) AS $$
DECLARE
  v_subscription_status TEXT;
  v_is_trial BOOLEAN;
  v_free_analyses INTEGER;
  v_paid_credits INTEGER;
  v_has_active_subscription BOOLEAN;
BEGIN
  -- Get current user status
  SELECT
    users.subscription_status,
    users.is_trial,
    users.free_analyses_remaining,
    users.paid_credits_remaining
  INTO
    v_subscription_status,
    v_is_trial,
    v_free_analyses,
    v_paid_credits
  FROM users
  WHERE id = p_user_id;

  -- Check if user exists
  IF NOT FOUND THEN
    RETURN QUERY SELECT
      false,
      'User not found'::TEXT,
      0,
      0,
      'free'::TEXT;
    RETURN;
  END IF;

  -- Determine if user has active subscription
  v_has_active_subscription := (v_subscription_status = 'active' OR v_is_trial = true);

  -- Handle credit deduction based on subscription type
  IF v_has_active_subscription THEN
    -- PAID USER: Deduct credits per garment
    IF v_paid_credits >= p_garment_count THEN
      -- Sufficient credits - deduct them
      UPDATE users
      SET
        paid_credits_remaining = paid_credits_remaining - p_garment_count,
        total_analyses_performed = total_analyses_performed + 1,
        updated_at = NOW()
      WHERE id = p_user_id
      RETURNING
        free_analyses_remaining,
        paid_credits_remaining
      INTO
        v_free_analyses,
        v_paid_credits;

      RETURN QUERY SELECT
        true,
        format('Deducted %s credits', p_garment_count)::TEXT,
        v_free_analyses,
        v_paid_credits,
        v_subscription_status;
    ELSE
      -- Insufficient credits
      RETURN QUERY SELECT
        false,
        format('Insufficient credits. Need %s, have %s', p_garment_count, v_paid_credits)::TEXT,
        v_free_analyses,
        v_paid_credits,
        v_subscription_status;
    END IF;
  ELSE
    -- FREE USER: Deduct 1 analysis (regardless of garment count)
    IF v_free_analyses > 0 THEN
      -- Has free analysis remaining
      UPDATE users
      SET
        free_analyses_remaining = free_analyses_remaining - 1,
        total_analyses_performed = total_analyses_performed + 1,
        updated_at = NOW()
      WHERE id = p_user_id
      RETURNING
        free_analyses_remaining,
        paid_credits_remaining
      INTO
        v_free_analyses,
        v_paid_credits;

      RETURN QUERY SELECT
        true,
        'Deducted 1 free analysis'::TEXT,
        v_free_analyses,
        v_paid_credits,
        v_subscription_status;
    ELSE
      -- No free analyses remaining
      RETURN QUERY SELECT
        false,
        'No free analyses remaining'::TEXT,
        v_free_analyses,
        v_paid_credits,
        v_subscription_status;
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION deduct_credits(UUID, INTEGER) TO authenticated;

-- Comment explaining the function
COMMENT ON FUNCTION deduct_credits IS 'Deducts credits based on garment count. For paid users: 1 credit per garment. For free users: 1 analysis regardless of garment count.';
