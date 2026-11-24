# Keeping Study Desk running

The things that go wrong are not bugs, and they come back. This is what they
are and what to do, so nobody has to work it out twice.

---

## The project goes to sleep

**What you see:** "Couldn't reach the server" on the sign-in screen, or the
plan-needs-renewing message inside the app. Nothing loads.

**Why:** a free Supabase project pauses after about 7 days with no activity.
It is their cost control, not a fault. Study Desk is used in bursts — a week
of evenings, then a school holiday — which is exactly the pattern that trips
it.

**The part that catches people:** once it is paused, traffic does NOT wake it.
Someone has to press Restore. So the only real fix is to stop it ever going
idle for a week.

### The fix: a daily ping (free, five minutes, once)

Something external has to touch the project every day.

1. Sign up at **cron-job.org** (or UptimeRobot — either is free).
2. New job:
   - **URL** — `https://<your-project>.supabase.co/rest/v1/`
   - **Header** — `apikey` : your **anon** key
   - **Schedule** — once a day
3. Save.

The anon key is safe to put there. It is the publishable key, already inside
the web build that anyone can download. The `service_role` key must never go
anywhere near this, or anywhere outside Supabase.

You also get told by email when the project is down, which beats hearing it
from whoever is trying to use it.

### Why not the other ways

- **pg_cron** runs inside the database, so it may not register as the kind of
  traffic that keeps a project awake. Not worth betting on.
- **Supabase Cron** calling `daily-check` is tidier and may well work, but has
  the same uncertainty. Use it for the evening summary, not for this.
- **Supabase Pro**, about $25/month, never pauses and adds real backups. Not
  worth it for one or two families. It becomes worth it for the NGO centre —
  thirty children will hit the 1 GB storage ceiling long before anything else.

---

## Emails do not arrive

Supabase's own sender allows only a handful of emails an hour and often does
not deliver at all, so a custom SMTP sender is required before "Forgot
password" works for anyone. Supabase → Project Settings → Authentication →
SMTP Settings, with a sender address you have verified at the provider.

**Two things cost us three days, so check them first when mail stops:**

1. **The provider's IP allowlist.** If the SMTP provider is set to block
   unauthorised IPs and no IPs are listed, every Supabase send is refused
   before it is logged. The symptom is the giveaway: Supabase reports a send
   failure and the provider shows **zero** entries in its transactional log.
   Nothing was blocked at the provider — nothing arrived.
2. **The sender address must be verified**, not merely typed into Supabase.

**To reset somebody's password by hand meanwhile:** Supabase → Authentication
→ Users → ⋯ next to their row → **Reset password**, then tell them directly.

The reset link signs the person in and stops there, so the app must catch
`AuthChangeEvent.passwordRecovery` and show a "choose a new password" screen
(`lib/screens/new_password.dart`). Without it the single-use link is spent on
one silent sign-in and the password is never changed. Supabase → Authentication
→ URL Configuration must also carry the real site URL and `.../**` as a
redirect URL, or the link lands on a deploy-specific address instead.

---

## Adding a family

1. **Build and publish**
   ```
   cd ~/study-desk && sh check.sh && sh build-web.sh
   ```
   Drag `build/web` onto **app.netlify.com/drop**.

2. **Keep sign-ups closed.** Supabase → Authentication → Sign In / Providers →
   "Allow new users to sign up" → **off**. Without this, anyone who ever gets
   the link can make an account and spend your money.

3. **Create their account yourself.** Authentication → Users → Add user.
   Tick **Auto Confirm User** — otherwise they wait for an email that will not
   come (see above).

4. **After they have signed in once**, give them a plan. New accounts get a
   14-day trial and then stop:
   ```sql
   update subscriptions
   set status = 'active', plan = 'family',
       max_students = 2,          -- how many children
       daily_msg_limit = 60       -- PER CHILD, not per account
   where account_id = (select id from auth.users where email = 'them@example.com');
   ```

5. **Tell them plainly** that their child's photographed schoolwork goes
   through your project and your Anthropic key, that you can see their usage,
   and that you are paying. It is their child's data; they should agree to it
   knowingly.

---

## What it is costing you

```sql
select s.name, u.date, u.messages, u.input_tokens, u.output_tokens
from usage_daily u join students s on s.id = u.student_id
order by u.date desc limit 30;
```

`daily_msg_limit` is **per child**. Two children at 60 is up to 120 messages a
day on your key.

Note: a Claude.ai subscription does not cover this. The app uses the Anthropic
API, billed separately by usage.

---

## After changing the app

```
cd ~/study-desk && sh check.sh     # tests must pass first
sh build-web.sh                      # then rebuild
```
Drag `build/web` onto Netlify again. Everyone gets it on their next reload —
nothing to reinstall.

The build stamp at the bottom of Settings tells you which version is running.

---

## After the app gains a new column

Add it to `supabase/run_this_in_supabase.sql` **the same day**, and run that
file. That file is meant to be the whole database in one place; when it was
not, adding a first child failed with "Could not find the 'ay_start_month'
column" — a migration that had existed for months in a file nobody ran.

It is safe to run as often as you like. The check at the bottom lists every
column, table and function the app needs; anything missing from that list is a
part of the app with nowhere to save.

---

## Back up the lessons

Lessons tab → **Save a copy of every lesson** → keep the file somewhere that is
not Supabase.

The transcriptions are the only part of a scanned chapter that is ever read
back, and re-reading the books costs the same hours and money all over again.
Worth doing after each new book goes in. See `LESSON_ARCHIVE.md`.
