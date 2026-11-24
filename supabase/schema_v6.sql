-- Study Desk v6 — each child's own subject list.
-- Run AFTER schema_v5.sql.
--
-- "Social" or "Social Studies"? "Tamil" or "Language 2"? Schools differ, so the
-- family sets the list themselves (Parent tab → Subjects) and the whole app —
-- timetable, chapters, homework, lessons — uses their words.

alter table plans add column if not exists subjects jsonb not null default '[]'::jsonb;

-- Give existing plans a starting list, taken from the child's languages.
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
