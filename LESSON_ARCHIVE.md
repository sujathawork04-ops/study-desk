# Keeping the lesson archive — analysis

**Date:** 14 October 2026 · **Build:** 2026-10-11 · 49
**Question:** books and chapters get scanned and uploaded as needed, over years. How is that archive maintained?

---

## What the archive actually is

Two things are stored per chapter, and they are not equally valuable.

| | What it is | Read back by the app? | Size |
|---|---|---|---|
| `lessons.text` | The transcription Teacher teaches from | **Yes — on every single question** | ~20 KB per chapter |
| `lessons.pages` | The photographs | **Never** | ~2.6 MB per chapter |

The page images are written to Supabase storage and after that are only **counted** (`pages.length` in the "already saved" dialog) and merged. No screen displays them, and nothing sends them to the model a second time. The transcription prompt says so outright: *"so a tutor can teach from it later without the pictures."*

**So the text is 0.8% of the footprint and 100% of the value.**

That ratio is the single most useful fact for maintaining this.

---

## Finding 1 — the valuable half has no backup at all (critical)

There is no export, no download, no backup anywhere in the code. Grepped for all of it; nothing.

Everything — every chapter transcribed, every hour spent scanning, every rupee of model cost — lives in exactly one free-tier Supabase project. The same project that paused on 1 October and had to be restored by hand.

**What that exposure is worth, concretely:** a full Class 4 load is ~90 chapters, roughly ₹1,400–2,300 of model calls and an afternoon of scanning. Rebuilding it means re-scanning the physical books and paying again. A free project that stays paused long enough can be removed by Supabase, and a deleted project is not recoverable.

**Fix: an export.** Every lesson's subject, chapter name, date and full text, written to one file she can keep. Re-importable. Cheap to build, and it is the difference between "the project died" being an afternoon's annoyance and a total loss.

This should be built before the second-semester scan, not after.

---

## Finding 2 — the worthless half is what fills the quota

Measured, at 220 KB per page (1400px JPEG, quality 80) and 12 pages a chapter:

| | Pages | Images | Text | Free tier (1 GB) |
|---|---|---|---|---|
| One child, one year | 1,080 | **232 MB** | 1.8 MB | fits |
| One child, Class 4–6 | 3,240 | **696 MB** | 5.3 MB | nearly full |
| NGO centre, 30 children, one year | 32,400 | **6,961 MB** | 52.7 MB | **7× over** |

So the archive that matters would fit a hundred times over. What fills the disk is images nothing reads.

**Options, in order of preference:**

1. **Stop keeping page images once a chapter is transcribed.** They are already treated as optional — the upload is wrapped in a `try` that shrugs off failure with "no stored copy of this page; the transcription still happens". Making that deliberate rather than incidental costs nothing and removes the growth problem entirely.
2. **Keep them for a term, then drop them.** A middle path if there is any wish to re-read a page later. Needs a reason, and there isn't an obvious one.
3. **Keep them.** Fine for one child for about three years. Not viable for the NGO centre at any size.

The NGO row is the one that decides this. Thirty children cannot share a 1 GB tier while storing pictures nobody looks at.

---

## Finding 3 — selection, once there are ninety chapters

Teacher is handed at most **3 chapters** per question, within a **40,000 character** budget, ranked by:

| Signal | Score |
|---|---|
| She named the chapter in her question | +120 |
| It is the chapter she is currently on | +100 |
| She named the subject | +50 |
| It is one of today's subjects | +20 |
| The chapter is marked done | −15 |

With two or three chapters stored this is untestable — everything reaches her. With ninety it becomes the whole experience: the right chapter arriving is the difference between Teacher teaching from her book and Teacher teaching from memory.

The ordering looks sound (naming a chapter beating the plan is right). What is unknown is behaviour at scale: a question that names neither subject nor chapter, late in the year, with fifteen chapters per subject stored. **Worth a test with a realistic archive before trusting it.**

---

## Finding 4 — the year boundary

Chapters carry `keep: 'year' | 'day' | 'archived'`, and "A new book" archives the current set. That is designed for *within* a year — second-term book replacing first-term.

Across years (Class 4 → 5 → 6) it is the same mechanism, so it should hold, but nothing has exercised it and the academic-year start month is a per-child setting. The failure mode is quiet: last year's chapters still scoring for selection and crowding out this year's. Worth one deliberate run-through at the next year boundary rather than discovering it mid-term.

---

## What maintaining this actually looks like

**Before the next scan session**

1. Build the export. This is the one that protects everything else.
2. Decide the page-image policy — recommendation: stop keeping them.
3. Make the Edge Function honour a free mode, so a lapsed subscription row cannot stop an upload mid-session (it already has once).
4. Resume a failed chapter read instead of discarding the batches already paid for.

**Each time a book is added**

- One chapter per save; chapter number in the title page if the book has one.
- Check the Lessons list afterwards: one row per chapter, sensible page and word counts.
- Export afterwards, and keep the file somewhere that is not Supabase.

**Each term**

- "A new book" when the textbook changes, so Teacher stops teaching from the old one.
- Glance at whether anything merged that should not have.

**Each year**

- Verify the year boundary behaved: last year's chapters archived, this year's current.

**Ongoing**

- The project sleeps after ~7 days idle. A daily scheduled ping removes that entirely.

---

## The one-line version

The transcriptions are the asset, they are 0.8% of the storage, and they are the only part with no backup. Everything else here is secondary to building an export.
