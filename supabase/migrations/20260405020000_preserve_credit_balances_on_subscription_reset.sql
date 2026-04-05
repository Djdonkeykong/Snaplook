-- Preserve purchased/top-up credits when subscription credits activate or reset.
-- The users table currently stores credits in a single merged balance, so the
-- safest behavior is to top the balance up to 100 for active paid users rather
-- than overwriting it back to 100.

create or replace function public.apply_paid_credits_on_activation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_next_reset timestamptz := public.next_credit_reset_date();
begin
  if new.subscription_status = 'active' then
    if tg_op = 'INSERT' then
      if coalesce(new.paid_credits_remaining, 0) <= 0 then
        new.paid_credits_remaining := 100;
      else
        new.paid_credits_remaining := greatest(new.paid_credits_remaining, 100);
      end if;

      if coalesce(new.is_trial, false) = false and new.credits_reset_date is null then
        new.credits_reset_date := v_next_reset;
      end if;
    elsif tg_op = 'UPDATE' then
      if old.subscription_status is distinct from new.subscription_status
          and new.subscription_status = 'active' then
        new.paid_credits_remaining := greatest(coalesce(new.paid_credits_remaining, 0), 100);
      end if;

      if coalesce(old.is_trial, false) = false
          and coalesce(new.is_trial, false) = true then
        if coalesce(new.paid_credits_remaining, 0) <= 0 then
          new.paid_credits_remaining := 100;
        end if;
      end if;

      if coalesce(old.is_trial, false) = true
          and coalesce(new.is_trial, false) = false then
        new.paid_credits_remaining := greatest(coalesce(new.paid_credits_remaining, 0), 100);
      end if;

      if coalesce(new.is_trial, false) = false then
        if new.credits_reset_date is null
            or coalesce(old.is_trial, false) = true
            or old.subscription_status is distinct from new.subscription_status then
          new.credits_reset_date := v_next_reset;
        end if;
      end if;
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.reset_paid_credits_monthly()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_updated_count integer;
  v_next_reset timestamptz := public.next_credit_reset_date();
begin
  update public.users
  set paid_credits_remaining = greatest(coalesce(public.users.paid_credits_remaining, 0), 100),
      credits_reset_date = v_next_reset,
      updated_at = now()
  where public.users.subscription_status = 'active'
    and coalesce(public.users.is_trial, false) = false
    and (public.users.subscription_expires_at is null or public.users.subscription_expires_at > now())
    and (public.users.credits_reset_date is null or public.users.credits_reset_date <= date_trunc('month', now()));

  get diagnostics v_updated_count = row_count;

  if v_updated_count > 0 then
    raise notice 'Reset/top-up credits for % paid users. Next reset: %', v_updated_count, v_next_reset;
  else
    raise notice 'No users eligible for credit reset';
  end if;
end;
$$;

comment on function public.reset_paid_credits_monthly is
  'Monthly top-up of credits for active paid (non-trial) subscriptions. Preserves purchased/top-up credits by never reducing an existing balance.';
