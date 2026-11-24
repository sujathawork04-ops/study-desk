-- v11 — notes from the parents to the tutor.
--
-- Two of them, because families ask two different kinds of thing:
--   students.parent_note  the standing wish   ("go slowly with the tables")
--   days.parent_note      just for today      ("she has a cold, keep it short")
--
-- Neither is ever shown to the child. Both are handed to the tutor at the top
-- of every conversation, under rules that say a note can never buy an answer.
-- Existing row-level security already covers both tables, so nothing else
-- changes: only the parent who owns the child can read or write these.

alter table students add column if not exists parent_note text;
alter table days     add column if not exists parent_note text;
