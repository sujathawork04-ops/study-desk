-- Study Desk v2 — public rollout: subscriptions, usage limits, realtime, push, consent.
-- Run AFTER schema.sql, in the Supabase SQL editor.

-- =============================================================== accounts
-- One row per signed-in adult (parent or NGO volunteer).
create table if not exists accounts (
  id                 uuid primary key references auth.users(id) on delete cascade,
  display_name       text,
  phone              text,
  -- DPDP Act 2023: record that the adult consented to their child's data being processed
  consent_given_at   timestamptz,
  consent_version    text,
  is_ngo             boolean default false,
  created_at         timestamptz default now()
);

create or replace function ensure_account() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into accounts (id) values (new.id) on conflict do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function ensure_account();

-- ========================================================== subscriptions
-- status: trialing | active | past_due | cancelled | expired
create table if not exists subscriptions (
  account_id        uuid primary key references auth.users(id) on delete cascade,
  plan              text not null default 'free',        -- free | family | ngo
  status            text not null default 'trialing',
  max_students      int  not null default 1,
  daily_msg_limit   int  not null default 40,            -- per student, abuse guard
  provider          text,                                -- razorpay
  provider_sub_id   text,
  current_period_end timestamptz,
  trial_ends_at     timestamptz default (now() + interval '14 days'),
  updated_at        timestamptz default now()
);

create or replace function ensure_subscription(uid uuid) returns subscriptions
language plpgsql security definer set search_path = public as $$
declare s subscriptions;
begin
  insert into subscriptions (account_id) values (uid) on conflict do nothing;
  select * into s from subscriptions where account_id = uid;
  return s;
end $$;

-- Can this account use the tutor right now?
create or replace function entitled(uid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select status in ('active','trialing')
            and (current_period_end is null or current_period_end > now())
            and (status <> 'trialing' or trial_ends_at > now())
     from subscriptions where account_id = uid), false);
$$;

-- ================================================================ usage
-- One row per student per day; the tutor function bumps it before each call.
create table if not exists usage_daily (
  student_id   uuid not null references students(id) on delete cascade,
  date         date not null,
  messages     int  not null default 0,
  input_tokens bigint not null default 0,
  output_tokens bigint not null default 0,
  primary key (student_id, date)
);

create or replace function bump_usage(sid uuid, d date, msgs int, tin bigint, tout bigint)
returns int language plpgsql security definer set search_path = public as $$
declare total int;
begin
  insert into usage_daily (student_id, date, messages, input_tokens, output_tokens)
  values (sid, d, msgs, tin, tout)
  on conflict (student_id, date) do update
    set messages = usage_daily.messages + excluded.messages,
        input_tokens = usage_daily.input_tokens + excluded.input_tokens,
        output_tokens = usage_daily.output_tokens + excluded.output_tokens
  returning messages into total;
  return total;
end $$;

-- ================================================== parent → child notes
create table if not exists nudges (
  id         uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id) on delete cascade,
  from_name  text,
  text       text not null,
  seen       boolean default false,
  created_at timestamptz default now()
);

-- ============================================================ web push
create table if not exists push_subscriptions (
  id          uuid primary key default gen_random_uuid(),
  account_id  uuid not null references auth.users(id) on delete cascade,
  endpoint    text not null unique,
  p256dh      text not null,
  auth        text not null,
  user_agent  text,
  created_at  timestamptz default now()
);

-- ================================================================== RLS
alter table accounts           enable row level security;
alter table subscriptions      enable row level security;
alter table usage_daily        enable row level security;
alter table nudges             enable row level security;
alter table push_subscriptions enable row level security;

create policy accounts_self on accounts
  for all using (id = auth.uid()) with check (id = auth.uid());
create policy subs_self on subscriptions
  for select using (account_id = auth.uid());          -- only the server may write
create policy usage_own on usage_daily
  for select using (owns_student(student_id));
create policy nudges_own on nudges
  for all using (owns_student(student_id)) with check (owns_student(student_id));
create policy push_self on push_subscriptions
  for all using (account_id = auth.uid()) with check (account_id = auth.uid());

-- ============================================================= realtime
-- Live parent view + live parent→child notes + live chat.
alter publication supabase_realtime add table days;
alter publication supabase_realtime add table tasks;
alter publication supabase_realtime add table practice;
alter publication supabase_realtime add table messages;
alter publication supabase_realtime add table nudges;

-- Realtime respects RLS when the client connects with the user's JWT.
alter table days     replica identity full;
alter table tasks    replica identity full;
alter table practice replica identity full;
alter table nudges   replica identity full;

-- ================================================ nightly check (9 PM IST)
-- Needs the pg_cron and pg_net extensions (Database → Extensions).
-- Replace <PROJECT-REF> and <CRON-SECRET> before running.
create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.schedule(
  'study-desk-evening-check',
  '30 15 * * 1-5',                       -- 15:30 UTC = 21:00 IST, Mon–Fri
  $$
  select net.http_post(
    url     := 'https://<PROJECT-REF>.supabase.co/functions/v1/daily-check',
    headers := jsonb_build_object('content-type','application/json','x-cron-secret','<CRON-SECRET>'),
    body    := '{}'::jsonb
  );
  $$
);
