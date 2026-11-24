-- ============================================================================
-- Study Desk — v10: how the school wants the homework done
--
-- Run once in the Supabase SQL editor. Safe to run twice.
--
-- A school diary has rows: Oral, Written, Reading, Practice. That label is the
-- school telling you how the work will be checked — "Learn Q&A 1 to 3" on the
-- Oral row means the teacher will ASK her tomorrow, and turning it into
-- written work would be doing the wrong homework. The app kept the line and
-- threw the row away; now it keeps both.
--
--   oral | written | read | practice
-- ============================================================================

alter table tasks add column if not exists mode text;

-- Her own preference, remembered: a child studying alone should not have to
-- switch the reading voice back on every afternoon.
alter table students add column if not exists read_aloud boolean not null default false;

select column_name
from information_schema.columns
where table_schema = 'public'
  and ((table_name = 'tasks' and column_name = 'mode')
    or (table_name = 'students' and column_name = 'read_aloud'));
