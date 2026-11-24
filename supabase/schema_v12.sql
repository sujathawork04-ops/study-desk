-- ============================================================================
-- Study Desk — v12: how long a lesson is kept
--
-- Run once in the Supabase SQL editor. Safe to run twice. Nothing is deleted.
--
-- A page borrowed from a friend, a worksheet handed out today, and her own
-- textbook chapter were all kept for ever and all weighed the same when the
-- app chose what to put in front of the tutor. Now the family says:
--
--   keep = 'day'   gone tomorrow
--   keep = 'term'  until the half-year ends
--   keep = 'year'  the whole school year   (the default, and the old behaviour)
--
-- Nothing expires by being deleted — an expired lesson simply stops being
-- handed to the tutor, and the family can extend it or remove it by hand.
-- ============================================================================

alter table lessons add column if not exists keep     text not null default 'year';
alter table lessons add column if not exists saved_on date not null default current_date;

-- Everything saved before today was saved under the old "keep for ever" rule.
-- Dating those from the start of this school year would expire them early, so
-- they keep the year they already have.
update lessons set keep = 'year' where keep is null;

select column_name
from information_schema.columns
where table_schema = 'public' and table_name = 'lessons'
  and column_name in ('keep', 'saved_on')
order by column_name;
