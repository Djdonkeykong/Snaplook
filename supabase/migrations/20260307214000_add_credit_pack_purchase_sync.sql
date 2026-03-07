-- Idempotent credit-pack purchase grants and safer monthly reset behavior.
-- This migration:
-- 1) Adds a purchase-events ledger to prevent double credit grants.
-- 2) Adds apply_credit_purchase RPC for client/webhook sync.
-- 3) Preserves extra purchased credits on subscription activation and monthly reset.

create table if not exists public.credit_purchase_events (
  id bigserial primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  transaction_id text not null unique,
  product_id text not null,
  credits_added integer not null check (credits_added > 0),
  purchased_at timestamptz not null default now(),
  source text not null default 'unknown',
  created_at timestamptz not null default now()
);

create index if not exists idx_credit_purchase_events_user_id
  on public.credit_purchase_events(user_id);

create index if not exists idx_credit_purchase_events_product_id
  on public.credit_purchase_events(product_id);

alter table public.credit_purchase_events enable row level security;

create or replace function public.credit_pack_amount_for_product(p_product_id text)
returns integer
language plpgsql
immutable
as $$
declare
  v_product text := lower(coalesce(p_product_id, ''));
begin
  if v_product = '' then
    return 0;
  end if;

  if v_product = 'com.snaplook.credits20' or v_product like 'com.snaplook.credits20:%' then
    return 20;
  elsif v_product = 'com.snaplook.credits50' or v_product like 'com.snaplook.credits50:%' then
    return 50;
  elsif v_product = 'com.snaplook.credits100' or v_product like 'com.snaplook.credits100:%' then
    return 100;
  end if;

  return 0;
end;
$$;

create or replace function public.apply_credit_purchase(
  p_user_id uuid,
  p_product_id text,
  p_transaction_id text,
  p_purchased_at timestamptz default now(),
  p_source text default 'unknown'
)
returns table (
  success boolean,
  message text,
  credits_added integer,
  paid_credits_remaining integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_credits integer := public.credit_pack_amount_for_product(p_product_id);
  v_event_id bigint;
  v_current_credits integer;
begin
  if p_user_id is null then
    return query select false, 'Missing user id'::text, 0, 0;
    return;
  end if;

  if coalesce(trim(p_transaction_id), '') = '' then
    return query select false, 'Missing transaction id'::text, 0, 0;
    return;
  end if;

  if v_credits <= 0 then
    return query select false, format('Unsupported credit product: %s', coalesce(p_product_id, 'null'))::text, 0, 0;
    return;
  end if;

  -- Ensure user exists before recording event.
  select users.paid_credits_remaining
  into v_current_credits
  from public.users
  where users.id = p_user_id;

  if not found then
    return query select false, 'User not found'::text, 0, 0;
    return;
  end if;

  insert into public.credit_purchase_events (
    user_id,
    transaction_id,
    product_id,
    credits_added,
    purchased_at,
    source
  )
  values (
    p_user_id,
    p_transaction_id,
    p_product_id,
    v_credits,
    coalesce(p_purchased_at, now()),
    coalesce(p_source, 'unknown')
  )
  on conflict (transaction_id) do nothing
  returning id into v_event_id;

  if v_event_id is null then
    return query
    select
      true,
      'Transaction already processed'::text,
      0,
      coalesce(v_current_credits, 0);
    return;
  end if;

  update public.users
  set
    paid_credits_remaining = coalesce(public.users.paid_credits_remaining, 0) + v_credits,
    updated_at = now()
  where public.users.id = p_user_id
  returning public.users.paid_credits_remaining into v_current_credits;

  return query
  select
    true,
    format('Granted %s credits', v_credits)::text,
    v_credits,
    coalesce(v_current_credits, 0);
end;
$$;

grant execute on function public.apply_credit_purchase(uuid, text, text, timestamptz, text)
  to authenticated, service_role;

comment on function public.credit_pack_amount_for_product is
  'Returns the number of credits for a known credit-pack product id.';

comment on function public.apply_credit_purchase is
  'Idempotently grants credits for a RevenueCat non-subscription transaction.';

-- Preserve extra purchased credits when subscription becomes active.
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

-- Preserve any extra purchased credits on the monthly reset by topping up to at least 100.
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
  'Monthly top-up for active paid (non-trial) users. Preserves extra purchased credits above the monthly allowance.';
