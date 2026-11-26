# Study Desk

An AI home tutor for one nine-year-old — a Flutter app that reads her own CBSE
textbooks and teaches and quizzes her from them.

Most study apps teach a syllabus someone else wrote. This one is pointed at the
books actually on the child's desk: photograph the pages, or add the scanned
chapter as a PDF, and the tutor reads it once and teaches from it for the rest
of the term. When she asks "I don't get question 3", the tutor already knows
which question 3.

It runs in a browser and on Android. It is used every school day.

---

## What it does

- **Reads her books.** Photographed pages or a scanned PDF become a lesson. On
  the web the PDF is split into pages in the browser, so a chapter never leaves
  the machine as a PDF.
- **Teaches Socratically.** It is told, in `prompt.dart`, never to hand over an
  answer to her own homework — it asks the next question instead.
- **Marks her work** from a photograph of her notebook, and reads the school
  diary to work out what homework there is.
- **Explains with things she can move** — a pulley she can thread, a lever she
  can slide the fulcrum along, cards she can sort into groups — rather than
  with a wall of text.
- **Speaks and listens**, in English, Tamil or Hindi, each in its own script.
- **Keeps a parent's view** behind a PIN: what was practised, what was weak,
  and an export of every lesson ever read.

---

## How it is built

```
Flutter (web + Android)
      │  anon key only — never a secret
      ▼
Supabase · Postgres + row-level security + Auth + Storage
      │
      ▼
Edge Function `tutor` ──────────► Anthropic API
   the model key lives here, and only here
```

The app never holds the model key. It is a Supabase Edge Function secret, so
nothing in a browser's source or an APK can reach it — a child's device
compromising the family's API bill is not a risk this design has.

### The logic is pure, which is why there are 500 tests

Everything decidable lives in **`lib/rules.dart`** (1,899 lines) as pure
functions with no Flutter imports: which day it is, what to practise, whether
an answer is right, how a markdown line breaks into spans, how much effort a
pulley saves, what happens when the same chapter is scanned twice.

That means the interesting parts are testable without a device, an emulator or
a golden file. **33 test files, 500 passing tests**, the great majority of them
pure-logic tests that run in five seconds. The screens are deliberately thin —
they call a rule and draw the result — so only 40 widget tests are needed, for
the few places where the screen itself is the thing worth asserting on: the
PIN lock, the picture blocks, the settings card.

```bash
sh check.sh        # flutter analyze + flutter test, output to check-output.txt
```

A few of those tests exist because a real failure got past review: the markdown
regex that swallowed text between two bold runs, the chapter title taken from
the book's front matter, the reply discarded when the network dropped
mid-stream. Each one is pinned with a comment saying what went wrong.

---

## Privacy and safety

This app is used by a child, so some decisions are not negotiable:

- **Guardian consent is recorded before any child data is stored**, as the
  Digital Personal Data Protection Act 2023 requires.
- **Children have no accounts of their own** — no email, no password, no
  sign-up. A parent's account holds the children on it.
- **The tutor is forbidden to ask a child for personal details** — no address,
  no school name, no phone number — and is told so explicitly in its rules.
- **No key reaches a device.** `.env` is excluded from this repository, the
  `service_role` key is never used by the app, and the model key never leaves
  the Edge Function.
- Row-level security, not the app, decides who may read a row. The PIN keeps a
  nine-year-old out of the parent tab; it is not a security boundary and the
  code says so where it is defined.

---

## Running it

You need your own Supabase project and your own Anthropic API key.

```bash
git clone https://github.com/sujathawork04-ops/study-desk.git
cd study-desk
flutter pub get

cp .env.example .env        # fill in your Supabase URL and anon key
```

Then in your Supabase project:

1. Run `supabase/run_this_in_supabase.sql` in the SQL editor — it creates every
   table and policy from scratch and is safe to re-run.
2. `supabase functions deploy tutor`
3. Set the model key as a secret — **never in this repo, never in the app**:
   ```bash
   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
   ```

And locally:

```bash
sh run.sh            # run on a device or in Chrome
sh check.sh          # analyze + test
sh build-web.sh      # build/web, ready to host
sh build-android.sh  # an APK
```

---

## What is where

```
lib/
  rules.dart       PURE LOGIC — the whole decidable surface, and what the tests cover
  prompt.dart      THE TEACHING RULES, in words, including what the tutor must refuse
  blocks.dart      the tutor's hidden markers: BADGE / DONE / WIDGET / EXPLAIN
  models.dart      the shapes stored in Supabase
  state.dart       one child's day, one reload() for all of it
  curricula.dart   boards, grades, languages and school years by country
  config.dart      build-time values, passed with --dart-define
  data/            db · tutor (streaming) · speech · pdf · photos · heic · save_file
  ui/              mascot · pictures · manipulatives · explainer · prose
  screens/         sign_in · setup · home · today · lessons · chat · parent · settings
supabase/
  functions/tutor  the only thing that talks to the model
  functions/daily-check, functions/billing
  run_this_in_supabase.sql
test/              33 files
```

`data/pdf.dart`, `data/heic.dart`, `data/pick_file.dart` and `data/save_file.dart`
each have a web implementation and a stub, chosen by conditional export: the
browser can read a PDF and convert an iPhone photo, a phone cannot, and the
phone is told to say so rather than fail quietly.

---

## Deliberately not here

- **Push notifications.** The 9 PM parent alert needs Firebase Cloud Messaging
  on a phone rather than Web Push.
- **Billing.** Free mode only. There is a `billing` function, unused.
- **Realtime.** Pull to refresh.
- **Widget tests.** The logic is pure precisely so they are not needed.

## Further notes

- **[RUNNING_IT.md](RUNNING_IT.md)** — what goes wrong and comes back: the
  project sleeping, password-reset email, adding a family, what it costs.
- **[LESSON_ARCHIVE.md](LESSON_ARCHIVE.md)** — how a scanned-book archive is
  kept over years, and why the export matters more than the photographs.

## Licence

**AGPL-3.0** — see [LICENSE](LICENSE).

Use it, change it, run it for your school or your centre, free. The one
condition: if you deploy a changed version for other people to use, publish
your changes. The point of this project is that a child somewhere else gets
taught rather than told the answer; improvements to how that is done should
come back, not disappear into someone's private fork.

Earlier releases of this code were published under the MIT licence, and that
grant stands for those versions. Everything from build 62 onward is AGPL-3.0.
