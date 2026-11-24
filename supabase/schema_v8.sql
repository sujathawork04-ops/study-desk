-- ============================================================================
-- Study Desk — v8: settings
--
-- Run this once in the Supabase SQL editor (Database → SQL editor → New query).
-- Safe to run more than once; nothing here deletes data.
--
-- Two small columns behind the new Settings ⚙️ screen:
--   parent_mobile — the parent's number, for reminders later. Not the child's.
--   theme_mode    — light / dark / system, so the app opens the way she left it.
--
-- The parent PIN is now OPTIONAL. It was always nullable, so there is nothing
-- to change here: an empty parent_pin simply means the parent tab opens
-- straight away, and Settings can turn it on or off.
-- ============================================================================

alter table students add column if not exists parent_mobile text;
alter table students add column if not exists theme_mode    text;

-- Check it worked — this should list both new columns.
select column_name
from information_schema.columns
where table_schema = 'public'
  and table_name   = 'students'
  and column_name in ('parent_mobile', 'theme_mode')
order by column_name;
