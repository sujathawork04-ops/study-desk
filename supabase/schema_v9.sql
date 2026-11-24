-- ============================================================================
-- Study Desk — v9: what she finds hard
--
-- Run once in the Supabase SQL editor. Safe to run twice.
--
-- A score says she got 6 out of 10 in Maths. It does not say she keeps
-- forgetting to carry the ten. This table is the difference between a report
-- card and a tutor who remembers: one row per specific skill, written by the
-- tutor when it sees the same mistake, and closed when she has it.
--
-- Rows are the tutor's working notes about the WORK, never about the child —
-- "regrouping in subtraction", not "bad at maths".
-- ============================================================================

create table if not exists skills (
  id          uuid primary key default gen_random_uuid(),
  student_id  uuid not null references students(id) on delete cascade,
  subject     text not null,
  skill       text not null,                    -- as the tutor wrote it
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

-- Same rule as every other table here: a parent sees only their own children.
drop policy if exists "skills are the family's own" on skills;
create policy "skills are the family's own" on skills
  for all using (owns_student(student_id)) with check (owns_student(student_id));

-- ----------------------------------------------------------------- all done
select count(*) as skills_rows from skills;
