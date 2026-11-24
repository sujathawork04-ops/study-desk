-- ============================================================================
-- Study Desk — v13: how demanding Teacher is
--
-- Run once in the Supabase SQL editor. Safe to run twice. Nothing is deleted.
--
--   gentle    encouraging; having the idea is enough to move on
--   firm      the full answer and the working; nothing ticked until it's right
--   exacting  exam standard; every step shown, wrong ones asked again tomorrow
--
-- 'firm' is the default, and it is what every child already using the app
-- gets. It is about STANDARDS, never about warmth: the strictest setting still
-- speaks kindly to a nine-year-old sitting on her own.
-- ============================================================================

alter table students add column if not exists strictness text not null default 'firm';

select column_name, column_default
from information_schema.columns
where table_schema = 'public' and table_name = 'students' and column_name = 'strictness';
