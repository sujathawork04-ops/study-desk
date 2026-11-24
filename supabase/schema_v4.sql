-- Study Desk v4 — the child's timezone and academic year.
-- Run AFTER schema_v3.sql.

alter table students add column if not exists timezone       text default 'Asia/Kolkata';
alter table students add column if not exists ay_start_month int  default 4;   -- 1 = January

-- Children already in the table keep working: give them the account's own
-- timezone guess and the usual school year for their country.
update students set timezone = 'Asia/Kolkata' where timezone is null;
update students set ay_start_month = 4         where ay_start_month is null;

-- ============================== evening check, in each child's own timezone
-- The daily-check function now runs EVERY HOUR and notifies only the children
-- for whom it is 21:00 locally. Replace the old daily job with an hourly one.
-- Replace <PROJECT-REF> and <CRON-SECRET> before running.
select cron.unschedule('study-desk-evening-check')
where exists (select 1 from cron.job where jobname = 'study-desk-evening-check');

select cron.schedule(
  'study-desk-evening-check',
  '0 * * * *',                          -- every hour, on the hour
  $$
  select net.http_post(
    url     := 'https://<PROJECT-REF>.supabase.co/functions/v1/daily-check',
    headers := jsonb_build_object('content-type','application/json','x-cron-secret','<CRON-SECRET>'),
    body    := '{}'::jsonb
  );
  $$
);
