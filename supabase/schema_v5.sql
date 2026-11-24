-- Study Desk v5 — let the app start its own free trial, and add a free mode.
-- Run AFTER schema_v4.sql.
--
-- Why this is needed: schema_v2 created the 14-day trial row from a trigger on
-- auth.users. That trigger broke sign-up ("Database error saving new user") and
-- had to be dropped, so new accounts had NO subscription row at all — and the
-- app showed the "Study Desk plan" paywall before the family could even add a
-- child. Now the app asks for the trial itself, right after sign-in.

-- ------------------------------------------------- the app's own trial start
-- No parameters: it can only ever create a trial for the caller's own account.
create or replace function start_trial() returns subscriptions
language plpgsql security definer set search_path = public as $$
declare s subscriptions;
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  insert into accounts (id) values (auth.uid()) on conflict (id) do nothing;
  insert into subscriptions (account_id) values (auth.uid()) on conflict (account_id) do nothing;
  select * into s from subscriptions where account_id = auth.uid();
  return s;
end $$;

revoke all on function start_trial() from public;
grant execute on function start_trial() to authenticated;

-- ============================================================== free access
-- Two ways to use Study Desk without payment:
--
-- 1. FREE MODE (whole installation) — put this in the app's .env:
--        VITE_FREE_MODE=true
--    Nobody is ever shown a plan or a Subscribe button. Use this for your own
--    family and for the NGO tuition centre. The Anthropic API usage is still
--    billed to whoever owns the Claude key in the Edge Function secrets.
--
-- 2. FREE FOR ONE ACCOUNT — keep billing on for the public, but let a chosen
--    account (yours, or an NGO's) use it free. Replace the email and run:
--
-- insert into subscriptions (account_id, plan, status, max_students, daily_msg_limit, trial_ends_at)
-- select id, 'ngo', 'active', 25, 200, null from auth.users where email = 'you@example.com'
-- on conflict (account_id) do update
--   set plan = 'ngo', status = 'active', max_students = 25, daily_msg_limit = 200,
--       trial_ends_at = null, current_period_end = null, updated_at = now();

-- ---------------------------------------------------------------- one child
-- The trial covers ONE child, which is right for a single family. Raise it for
-- a centre (max_students is what the "Add another child" button checks):
--
-- update subscriptions set max_students = 25 where account_id = auth.uid();
