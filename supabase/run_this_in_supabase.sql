-- =====================================================================
-- STUDY DESK — the whole database, in one file.
--
--   Supabase dashboard -> SQL Editor -> New query -> paste -> Run
--
-- Safe to run as often as you like. Every statement is "if not exists",
-- "or replace", or a guarded drop-then-create, so running it twice changes
-- nothing and running it on a half-built database fills in only the gaps.
--
-- WHY THIS FILE WAS REWRITTEN
--
-- The version before this one said in its own header: "This is v6 through
-- v11 together." It was telling the truth, and that was the problem — v2,
-- v3 and v4 were never in it. So a database built from the file the README
-- pointed at was missing:
--
--   * subscriptions, accounts, usage_daily, nudges, push_subscriptions
--     and the three functions the tutor calls (v2)
--   * students.country, .board_id, .grade                        (v3)
--   * students.timezone, .ay_start_month                         (v4)
--
-- None of that shows up until someone does the one thing that needs it.
-- Adding the FIRST child on a fresh account is that thing, and it failed
-- with "Could not find the 'ay_start_month' column of 'students'".
--
-- Every column and table the app reads or writes is below. If the app ever
-- gains another one, it belongs in this file on the same day.
-- =====================================================================

-- ---------------------------------------------- v2: accounts, billing, usage
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

drop policy if exists accounts_self on accounts;
create policy accounts_self on accounts
  for all using (id = auth.uid()) with check (id = auth.uid());
drop policy if exists subs_self on subscriptions;
create policy subs_self on subscriptions
  for select using (account_id = auth.uid());          -- only the server may write
drop policy if exists usage_own on usage_daily;
create policy usage_own on usage_daily
  for select using (owns_student(student_id));
drop policy if exists nudges_own on nudges;
create policy nudges_own on nudges
  for all using (owns_student(student_id)) with check (owns_student(student_id));
drop policy if exists push_self on push_subscriptions;
create policy push_self on push_subscriptions
  for all using (account_id = auth.uid()) with check (account_id = auth.uid());

-- ============================================================= realtime
-- Live parent view + live parent→child notes + live chat.
-- `alter publication ... add table` has no "if not exists" form, and adding a
-- table that is already a member raises 42710. Because the SQL editor runs
-- this whole file as one transaction, that one error rolled back EVERYTHING
-- above it — so a second run of this file undid the first. Hence the loop.
do $$
declare t text;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  foreach t in array array['days','tasks','practice','messages','nudges'] loop
    if to_regclass('public.' || t) is not null
       and not exists (
         select 1 from pg_publication_tables
         where pubname = 'supabase_realtime'
           and schemaname = 'public'
           and tablename = t)
    then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

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

-- ------------------------------------- v3: which country, board and class
alter table students add column if not exists country  text default 'IN';
alter table students add column if not exists board_id text default 'cbse';
alter table students add column if not exists grade    text;

-- keep the old free-text columns in step for anything already stored
update students set grade = coalesce(grade, class_label) where grade is null;

-- languages: {"first":"English","second":"Tamil","third":"Hindi"}
alter table students alter column languages set default
  '{"first":"English","second":null,"third":null}'::jsonb;

-- ------------------------------ v4: her timezone and when her year starts
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

-- ------------------------------------------------- v6 to v13, as before
alter table plans add column if not exists subjects jsonb not null default '[]'::jsonb;

update plans p
set subjects = (
  select to_jsonb(array_remove(array[
    'Maths',
    coalesce(s.languages->>'first', 'English'),
    s.languages->>'second',
    s.languages->>'third',
    'Science', 'Social', 'Computer', 'General Knowledge'
  ], null))
  from students s where s.id = p.student_id
)
where p.subjects = '[]'::jsonb or p.subjects is null;


-- v7 ------------------------------------------- the optional morning slot
-- Some families revise before school. Off unless you turn it on.
alter table plans add column if not exists morning_on boolean not null default false;
alter table plans add column if not exists morning    jsonb   not null
  default '{"Mon":[],"Tue":[],"Wed":[],"Thu":[],"Fri":[],"Sat":[],"Sun":[]}'::jsonb;


-- v8 ------------------------------------------------------------- settings
-- Behind the Settings screen: your mobile number, and light/dark.
alter table students add column if not exists parent_mobile text;
alter table students add column if not exists theme_mode    text;


-- v9 ------------------------------------------------ what she finds hard
-- A score says she got 6 out of 10. It does not say she keeps forgetting to
-- carry the ten. One row per skill, written by Teacher, closed when she has it.
create table if not exists skills (
  id          uuid primary key default gen_random_uuid(),
  student_id  uuid not null references students(id) on delete cascade,
  subject     text not null,
  skill       text not null,                    -- as Teacher wrote it
  skill_key   text not null,                    -- lowercased, for matching
  status      text not null default 'weak',     -- weak | fixed
  seen        int  not null default 1,          -- times it has come up
  note        text,
  first_seen  date not null default current_date,
  last_seen   date not null default current_date,
  updated_at  timestamptz default now()
);

create unique index if not exists skills_one_per_topic
  on skills (student_id, subject, skill_key);
create index if not exists skills_by_student on skills (student_id, status);

alter table skills enable row level security;

drop policy if exists "skills are the family's own" on skills;
create policy "skills are the family's own" on skills
  for all using (owns_student(student_id)) with check (owns_student(student_id));


-- v10 ------------------------------- how the school wants the homework done
-- Oral / Written / Reading / Practice — the diary row is the school telling
-- you how the work will be checked. The app kept the line and threw the row
-- away; now it keeps both.
alter table tasks    add column if not exists mode text;
alter table students add column if not exists read_aloud boolean not null default false;


-- v11 ------------------------------------ notes from the parents to Teacher
--   students.parent_note  the standing wish  ("go slowly with the tables")
--   days.parent_note      just for today     ("she has a cold, keep it short")
-- Neither is ever shown to the child.
alter table students add column if not exists parent_note text;
alter table days     add column if not exists parent_note text;


-- v12 ------------------------------------ how long each lesson is kept for
-- A borrowed worksheet and her own textbook chapter should not have the same
-- shelf life. 'day' is gone tomorrow, 'term' lasts the half-year, 'year' the
-- whole school year. Nothing is ever deleted by expiring — an old lesson just
-- stops being handed to Teacher.
alter table lessons add column if not exists keep     text not null default 'year';
alter table lessons add column if not exists saved_on date not null default current_date;


-- v13 --------------------------------------- how demanding Teacher is
-- gentle / firm / exacting. About standards, not warmth — the strictest still
-- speaks kindly. 'firm' is the default and what everyone already has.
alter table students add column if not exists strictness text not null default 'firm';


-- ------------------------------------------------------------- did it work?
-- This should list 12 rows. Anything missing means that statement did not run.
select table_name, column_name
from information_schema.columns
where table_schema = 'public'
  and ( (table_name = 'plans'    and column_name in ('subjects','morning_on','morning'))
     or (table_name = 'students' and column_name in ('parent_mobile','theme_mode','read_aloud','parent_note','strictness'))
     or (table_name = 'tasks'    and column_name = 'mode')
     or (table_name = 'days'     and column_name = 'parent_note')
     or (table_name = 'lessons'  and column_name in ('keep','saved_on')) )
order by table_name, column_name;


-- =====================================================================
-- Did it work? This should list every column and table the app needs.
-- =====================================================================
select 'column' as kind, table_name as name, column_name as detail
from information_schema.columns
where table_schema = 'public' and (
      (table_name = 'students' and column_name in
         ('country','board_id','grade','timezone','ay_start_month',
          'languages','parent_pin','parent_mobile','theme_mode',
          'read_aloud','parent_note','strictness'))
   or (table_name = 'plans'    and column_name in ('subjects','comps','off_days'))
   or (table_name = 'days'     and column_name = 'parent_note')
   or (table_name = 'lessons'  and column_name in ('keep','saved_on'))
   or (table_name = 'tasks'    and column_name in ('due','mode')) )
union all
select 'table', table_name, ''
from information_schema.tables
where table_schema = 'public'
  and table_name in ('accounts','subscriptions','usage_daily','nudges',
                     'push_subscriptions','skills')
union all
select 'function', routine_name, ''
from information_schema.routines
where routine_schema = 'public'
  and routine_name in ('ensure_subscription','entitled','bump_usage','owns_student')
order by kind, name, detail;

-- Anything missing from that list means a part of the app has nowhere to
-- save. Nothing missing means you are done.
