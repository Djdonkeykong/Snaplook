-- Function to add credits after a consumable credit pack purchase.
-- Called from the Flutter app after a successful RevenueCat purchase.

CREATE OR REPLACE FUNCTION add_purchased_credits(
  p_user_id UUID,
  p_amount INTEGER
)
RETURNS void AS $$
BEGIN
  UPDATE users
  SET
    paid_credits_remaining = paid_credits_remaining + p_amount,
    updated_at = NOW()
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User % not found', p_user_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION add_purchased_credits(UUID, INTEGER) TO authenticated;

COMMENT ON FUNCTION add_purchased_credits IS
  'Atomically adds credits to a user after purchasing a consumable credit pack.';
