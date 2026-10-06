-- Register the daily-report Edge Function with pg_cron.
-- 04:00 UTC = 06:00 SAST, Monday–Friday.
create extension if not exists pg_net;

select cron.schedule(
  'send_daily_report',
  '0 4 * * 1-5',
  $$
  select
    net.http_post(
      url := 'https://glxxawxuwusxwjvezugo.supabase.co/functions/v1/send-daily-report',
      headers := jsonb_build_object('Content-Type', 'application/json'),
      body := '{}'::jsonb
    )
  $$
);
