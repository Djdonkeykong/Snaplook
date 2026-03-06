-- Create notification_log table and schedule welcome drip notification cron job
-- This enables a 2-step automated welcome sequence:
--   Day 1 (~24h after signup): Nudge to try first scan
--   Day 3 (~72h after signup): Follow-up if still no scan

-- Enable pg_net extension (needed for cron to call Edge Functions via HTTP)
create extension if not exists pg_net with schema extensions;

-- Create notification_log table to track all sent notifications
create table if not exists public.notification_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  notification_type text not null,
  title text not null,
  body text not null,
  data jsonb,
  status text not null default 'sent',
  sent_at timestamptz not null default now()
);

-- Index for fast duplicate checks (e.g. has this user already received welcome_day1?)
create index if not exists idx_notification_log_user_type
  on public.notification_log (user_id, notification_type);

-- Enable RLS (service-role only, no user-facing policies)
alter table public.notification_log enable row level security;

comment on table public.notification_log is 'Tracks all push notifications sent to users for deduplication and auditing';

-- Store project URL in vault (used by cron job below)
-- Note: service_role_key is also stored separately via:
--   select vault.create_secret('sb_secret_...', 'service_role_key');
select vault.create_secret('https://tlqpkoknwfptfzejpchy.supabase.co', 'project_url');

-- Schedule daily cron job at 10:00 AM UTC to send welcome drip notifications
-- send-welcome-notifications has verify_jwt=false so no auth header needed
do $outer$
declare
  v_job_id integer;
begin
  select jobid into v_job_id
  from cron.job
  where jobname = 'send-welcome-notifications-daily';

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;

  perform cron.schedule(
    'send-welcome-notifications-daily',
    '0 10 * * *',  -- Every day at 10:00 AM UTC
    $cron$
    select net.http_post(
      url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/send-welcome-notifications',
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body := '{}'::jsonb
    );
    $cron$
  );
end $outer$;
