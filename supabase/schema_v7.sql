-- Study Desk v7 — an optional morning study slot.
-- Run AFTER catch_up.sql (or after schema_v6.sql).
--
-- Some families revise before school rather than only after it. This is off
-- unless the parent turns it on, and it has its own weekly timetable, kept
-- separate from the after-school one.

alter table plans add column if not exists morning_on boolean not null default false;
alter table plans add column if not exists morning    jsonb   not null
  default '{"Mon":[],"Tue":[],"Wed":[],"Thu":[],"Fri":[],"Sat":[],"Sun":[]}'::jsonb;
