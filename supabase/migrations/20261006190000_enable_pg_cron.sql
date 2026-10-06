-- Enable pg_cron for scheduled Edge Function runs (daily report).
create extension if not exists pg_cron;
