-- Study Desk — Supabase schema
-- Run this whole file in the Supabase SQL editor.
-- Every table is protected by row-level security: an adult account can only
-- see students it owns, and everything hanging off those students.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------- students
create table if not exists students (
  id           uuid primary key default gen_random_uuid(),
  owner_id     uuid not null references auth.users(id) on delete cascade,
  name         text not null,
  class_label  text default 'Class 4',
  board        text default 'CBSE',
  languages    jsonb default '{"first":"English","second":"Tamil","third":"Hindi"}'::jsonb,
  parent_pin   text,            -- sha-256 hex of the adult PIN
  child_pin    text,            -- optional: 4 digits, for shared centre devices
  created_at   timestamptz default now()
);

-- one row per student: timetable, chapters, exams, competitions, holidays
create table if not exists plans (
  student_id uuid primary key references students(id) on delete cascade,
  timetable  jsonb default '{"Mon":["Maths","Tamil"],"Tue":["English","Hindi"],"Wed":["EVS","Maths"],"Thu":["Tamil","Hindi"],"Fri":["English","EVS"],"Sat":["Weekly revision"],"Sun":[]}'::jsonb,
  week_off   jsonb default '["Sun"]'::jsonb,
  chapters   jsonb default '{}'::jsonb,   -- { "Maths": [{id,name,status}] }
  exams      jsonb default '[]'::jsonb,   -- [{id,subject,what,date}]
  comps      jsonb default '[]'::jsonb,   -- [{id,name,type,language,date,prepDays,details}]
  off_days   jsonb default '[]'::jsonb,   -- [{id,type,from,to,note}]
  updated_at timestamptz default now()
);

-- ------------------------------------------------------------------- days
create table if not exists days (
  id              uuid primary key default gen_random_uuid(),
  student_id      uuid not null references students(id) on delete cascade,
  date            date not null,
  day_type        text,                   -- school | nobag | holiday | leave
  day_type_by     text,                   -- child | adult
  diary_photo     text,                   -- storage path
  diary_posted_at timestamptz,
  teacher_note    text,
  badges          jsonb default '[]'::jsonb,
  parent_note     text,
  unique (student_id, date)
);

create table if not exists tasks (
  id         uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id) on delete cascade,
  date       date not null,
  subject    text not null,
  task       text not null,
  due        date,
  done       boolean default false,
  checked_by text,                        -- tutor | adult
  created_at timestamptz default now()
);

create table if not exists practice (
  id         uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id) on delete cascade,
  date       date not null,
  item       text not null,               -- "Maths" | "Test: Tamil" | "Competition: <name>"
  done       boolean default false,
  score      text,
  unique (student_id, date, item)
);

create table if not exists lessons (
  id         uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id) on delete cascade,
  ref        text not null,               -- chapter id, or "comp-<id>"
  subject    text,
  name       text,
  text       text,                        -- transcription the tutor teaches from
  pages      jsonb default '[]'::jsonb,   -- storage paths
  talks      jsonb default '{}'::jsonb,   -- cached 🎧 talks per language
  updated_at timestamptz default now(),
  unique (student_id, ref)
);

create table if not exists messages (
  id         uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id) on delete cascade,
  date       date not null,
  role       text not null,               -- user | assistant
  content    text not null,
  hidden     text,                        -- e.g. spelling-bee word the child must not see
  created_at timestamptz default now()
);

create index if not exists tasks_student_date on tasks(student_id, date);
create index if not exists practice_student_date on practice(student_id, date);
create index if not exists messages_student_date on messages(student_id, date, created_at);

-- --------------------------------------------------------------------- RLS
alter table students  enable row level security;
alter table plans     enable row level security;
alter table days      enable row level security;
alter table tasks     enable row level security;
alter table practice  enable row level security;
alter table lessons   enable row level security;
alter table messages  enable row level security;

create policy students_own on students
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- helper: does the signed-in adult own this student?
create or replace function owns_student(sid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from students s where s.id = sid and s.owner_id = auth.uid());
$$;

do $$
declare t text;
begin
  foreach t in array array['plans','days','tasks','practice','lessons','messages'] loop
    execute format(
      'create policy %I_own on %I for all using (owns_student(student_id)) with check (owns_student(student_id));',
      t, t);
  end loop;
end $$;

-- ----------------------------------------------------------------- storage
insert into storage.buckets (id, name, public)
values ('photos', 'photos', false)
on conflict (id) do nothing;

-- photos are stored at  <student_id>/<yyyy-mm-dd>/<uuid>.jpg
create policy "photos read own" on storage.objects for select
  using (bucket_id = 'photos' and owns_student(((storage.foldername(name))[1])::uuid));
create policy "photos write own" on storage.objects for insert
  with check (bucket_id = 'photos' and owns_student(((storage.foldername(name))[1])::uuid));
create policy "photos delete own" on storage.objects for delete
  using (bucket_id = 'photos' and owns_student(((storage.foldername(name))[1])::uuid));
