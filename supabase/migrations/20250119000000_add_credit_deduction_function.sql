-- Function to deduct credits based on garment count
-- Deducts 1 credit per garment from paid_credits_remaining

CREATE OR REPLACE FUNCTION deduct_credits(
  p_user_id UUID,
  p_garment_count INTEGER
)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT,
  paid_credits_remaining INTEGER,
  subscription_status TEXT
) AS $$
DECLARE
  v_subscription_status TEXT;
  v_paid_credits INTEGER;
BEGIN
  -- Get current user status
  SELECT
    users.subscription_status,
    users.paid_credits_remaining
  INTO
    v_subscription_status,
    v_paid_credits
  FROM users
  WHERE id = p_user_id;

  -- Check if user exists
  IF NOT FOUND THEN
    RETURN QUERY SELECT
      false,
      'User not found'::TEXT,
      0,
      'active'::TEXT;
    RETURN;
  END IF;

  -- Deduct credits per garment
  IF v_paid_credits >= p_garment_count THEN
    -- Sufficient credits - deduct them
    UPDATE users
    SET
      paid_credits_remaining = paid_credits_remaining - p_garment_count,
      total_analyses_performed = total_analyses_performed + 1,
      updated_at = NOW()
    WHERE id = p_user_id
    RETURNING
      users.paid_credits_remaining
    INTO
      v_paid_credits;

    RETURN QUERY SELECT
      true,
      format('Deducted %s credits', p_garment_count)::TEXT,
      v_paid_credits,
      v_subscription_status;
  ELSE
    -- Insufficient credits
    RETURN QUERY SELECT
      false,
      format('Insufficient credits. Need %s, have %s', p_garment_count, v_paid_credits)::TEXT,
      v_paid_credits,
      v_subscription_status;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION deduct_credits(UUID, INTEGER) TO authenticated;

-- Comment explaining the function
COMMENT ON FUNCTION deduct_credits IS 'Deducts credits based on garment count. 1 credit per garment searched.';
