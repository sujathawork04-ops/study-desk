-- Study Desk v3 — worldwide boards and grades.
-- Run AFTER schema.sql and schema_v2.sql.

alter table students add column if not exists country  text default 'IN';
alter table students add column if not exists board_id text default 'cbse';
alter table students add column if not exists grade    text;

-- keep the old free-text columns in step for anything already stored
update students set grade = coalesce(grade, class_label) where grade is null;

-- languages: {"first":"English","second":"Tamil","third":"Hindi"}
alter table students alter column languages set default
  '{"first":"English","second":null,"third":null}'::jsonb;
