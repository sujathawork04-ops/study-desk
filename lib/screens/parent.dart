// The parent area, behind a PIN: today at a glance, then one tidy list of
// sections that open one at a time. Deliberately plain — it is for scanning.
import "dart:convert";
import "dart:typed_data";

import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";
import "package:supabase_flutter/supabase_flutter.dart" show AuthException;

import "../curricula.dart";
import "../data/db.dart" as db;
import "../data/photos.dart";
import "../data/tutor.dart";
import "../models.dart";
import "../prompt.dart";
import "../rules.dart";
import "../state.dart";
import "../theme.dart";
import "settings.dart";
import "setup.dart";
import "today.dart" show prettyDate;

class ParentScreen extends StatefulWidget {
  const ParentScreen({super.key});
  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  bool forgot = false;
  String open = "";
  String msg = "";
  final pin = TextEditingController();
  final pin2 = TextEditingController();
  final note = TextEditingController();
  final forTeacher = TextEditingController();        // always
  final forTeacherToday = TextEditingController();   // just today
  String notesSeededFor = "";
  bool savingNote = false;
  String noteStatus = "";
  final newSubject = TextEditingController();
  final exSubject = TextEditingController();
  final exWhat = TextEditingController();
  final exDate = TextEditingController();
  final compName = TextEditingController();
  final compType = TextEditingController();
  final compDate = TextEditingController();
  final compDetails = TextEditingController();
  final newChapter = TextEditingController();
  String chapterSubject = "";
  bool reading = false;
  String readStatus = "";

  /// Fill the two note boxes from the database once per child per day, and
  /// never again while she is typing in them.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = Scope.of(context);
    final s = state.student;
    final d = state.day;
    if (s == null || d == null) return;
    final key = "${s.id}|${d.date}";
    if (notesSeededFor == key) return;
    notesSeededFor = key;

    // Filling a text box tells its listeners, and the Save buttons listen —
    // so this is a rebuild, and didChangeDependencies runs during the build
    // phase. It waits for the frame to end, as the chat's prefill does.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      forTeacher.text = s.parentNote ?? "";
      forTeacherToday.text = d.parentNote ?? "";
    });
  }

  @override
  void dispose() {
    pin.dispose(); pin2.dispose(); note.dispose(); newSubject.dispose();
    forTeacher.dispose(); forTeacherToday.dispose();
    exSubject.dispose(); exWhat.dispose(); exDate.dispose();
    compName.dispose(); compType.dispose(); compDate.dispose(); compDetails.dispose();
    newChapter.dispose();
    super.dispose();
  }

  /// Reopens the first-time questions for a child who already exists — a new
  /// school, a different board, a move abroad, or simply next year's class.
  Future<void> _editDetails(AppState state, Student student) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (routeContext) => SetupScreen(
        first: false,
        existing: student,
        existingSubjects: state.subjects,
        onDone: (s) async {
          await state.choose(s);
          if (routeContext.mounted) Navigator.of(routeContext).pop();
        },
      ),
    ));
    if (mounted) {
      setState(() {});
    }
  }


  /// Photograph the school's exam timetable; the tutor reads the rows and they
  /// are folded into the plan, portions and all.
  Future<void> _snapTimetable(AppState state, Plan plan, Future<void> Function() savePlan) async {
    final picked = await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 85);
    if (picked.isEmpty) return;

    final sheets = <Uint8List>[];
    for (final f in picked.take(4)) {
      final raw = await f.readAsBytes();
      if (photoKind(raw) == "heic") {
        if (mounted) {
          setState(() => readStatus = kConvertingPhoto);
        }
      }
      final ready = await readyPhoto(raw);
      if (ready.problem.isNotEmpty) {
        if (mounted) {
          setState(() => readStatus = ready.problem);
        }
        return;
      }
      sheets.add(ready.bytes);
    }

    if (mounted) {
      setState(() { reading = true; readStatus = "Reading the timetable…"; });
    }
    try {
      final images = [
        for (final bytes in sheets)
          "data:${photoMime(bytes)};base64,${base64Encode(bytes)}"
      ];

      final out = await askTutorJson(
        studentId: state.student!.id,
        prompt: examTimetablePrompt(state.date, state.gradeDescription,
            state.subjects, state.student!.languages),
        images: images,
        tier: "default",
        // A dozen papers with their portions — longer than a chat reply.
        maxTokens: 3000,
      );

      if (out["readable"] == false) {
        if (mounted) {
          setState(() => readStatus = "Couldn't read it. Try a straighter photo in good light.");
        }
        return;
      }

      final fresh = <Exam>[];
      for (final e in (out["exams"] as List?) ?? const []) {
        final subject = (e["subject"] ?? "").toString().trim();
        final date = (e["date"] ?? "").toString().trim();
        if (subject.isEmpty || date.isEmpty) continue;
        fresh.add(Exam(
          id: "${DateTime.now().microsecondsSinceEpoch}-${fresh.length}",
          subject: subject,
          what: (e["what"] ?? "").toString().trim(),
          date: date,
        ));
      }

      final before = plan.exams.length;
      plan.exams = mergeExams(plan.exams, fresh);
      await savePlan();
      if (mounted) {
        setState(() => readStatus = fresh.isEmpty
            ? "No exam rows found in that photo."
            : "Saved ${plan.exams.length - before} new paper(s), "
              "${fresh.length} row(s) read. Check the dates below.");
      }
    } on TutorError catch (e) {
      if (mounted) {
        setState(() => readStatus = friendlyError(e.code, limit: e.limit, detail: e.detail));
      }
    } catch (e) {
      // Not the tutor — the network, storage, or the database. Reported rather
      // than left as a status line that never changes.
      if (mounted) {
        setState(() => readStatus = "Couldn't finish reading the timetable. $e");
      }
    } finally {
      if (mounted) {
        setState(() => reading = false);
      }
    }
  }

  Future<void> _pickDate(TextEditingController into) async {
    final now = DateTime.now();
    final chosen = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (chosen == null) return;
    into.text = "${chosen.year.toString().padLeft(4, "0")}-"
        "${chosen.month.toString().padLeft(2, "0")}-"
        "${chosen.day.toString().padLeft(2, "0")}";
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openSettings(AppState state) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scope(state: state, child: const SettingsScreen()),
    ));
    if (mounted) {
      setState(() {});
    }
  }

  void _submitPin(Student student) {
    if (pinHash(pin.text) == student.parentPin) {
      Scope.of(context).unlockParent();
      if (mounted) {
        setState(() => msg = "");
      }
      pin.clear();
    } else {
      if (mounted) {
        setState(() => msg = "Wrong PIN. Forgotten it? Use your account password below.");
      }
    }
  }

  /// The way back in when the PIN is forgotten: the account password. Whoever
  /// can sign in owns the account, so it is proof enough — and it clears the
  /// PIN rather than revealing it.
  Future<void> _forgotPin(Student student) async {
    final email = db.sb.auth.currentUser?.email ?? "";
    if (pin2.text.isEmpty) {
      if (mounted) {
        setState(() => msg = "Type your account password.");
      }
      return;
    }
    try {
      await db.sb.auth.signInWithPassword(email: email, password: pin2.text);
    } on AuthException {
      if (mounted) {
        setState(() => msg = "That's not the password for $email.");
      }
      return;
    }
    try {
      await db.updateStudent(student.id, {"parent_pin": null});
    } catch (e) {
      if (mounted) {
        setState(() => msg = "Couldn't turn the PIN off: $e");
      }
      return;
    }
    student.parentPin = null;
    // Signing in just now reloaded the children, so read the row back rather
    // than trusting this copy of it.
    if (!mounted) return;
    await Scope.of(context).refreshStudent();
    pin.clear(); pin2.clear();
    if (!mounted) return;
    Scope.of(context).unlockParent();
    if (mounted) {
      setState(() { forgot = false; msg = ""; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Scope.of(context);
    final student = state.student;
    final plan = state.plan, day = state.day;
    if (student == null || plan == null || day == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // A PIN is optional. With none set the tab simply opens — set one from
    // Settings ⚙️ if you'd rather your child couldn't edit her own homework.
    final locked = parentTabLocked(pin: student.parentPin, unlocked: state.parentUnlocked);
    if (locked) {
      return ListView(padding: const EdgeInsets.all(16), children: [
      // The app has moved ahead of the database. Everything still works, minus
      // whatever those columns were for — and here is the one thing to do
      // about it, in words rather than a PostgrestException.
      if (db.schemaGaps.isNotEmpty) ...[
        Sheet(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text("⚠️", style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(child: Text("Your database needs updating",
                style: Theme.of(context).textTheme.titleMedium)),
          ]),
          const SizedBox(height: 8),
          Text("Nothing has been lost — ${student.firstName}'s work is saved. "
              "But some newer parts of the app are switched off until you run "
              "the update, because the database has no room for what they save.",
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text("Missing: ${db.schemaGaps.toList().join(", ")}",
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text("To fix it: open supabase.com → your project → SQL Editor → New "
              "query, paste the whole of supabase/run_this_in_supabase.sql from "
              "the app folder, and press Run. It is safe to run twice.",
              style: Theme.of(context).textTheme.bodySmall),
        ])),
        const SizedBox(height: 14),
      ],
        const SizedBox(height: 8),
        Sheet(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text("🔒", style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text("Parent area", style: Theme.of(context).textTheme.titleLarge),
          ]),
          const SizedBox(height: 8),
          Text("Enter your PIN to see and edit homework, the plan and progress.",
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          TextField(
            controller: pin, obscureText: true, keyboardType: TextInputType.number,
            maxLength: 6, autofocus: true,
            onSubmitted: (_) => _submitPin(student),
            decoration: const InputDecoration(labelText: "PIN", counterText: ""),
          ),
          const SizedBox(height: 10),
          FilledButton(onPressed: () => _submitPin(student), child: const Text("Unlock")),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() { forgot = !forgot; msg = ""; }),
              child: Text(forgot ? "Back to the PIN" : "I forgot my PIN"),
            ),
          ),
          if (forgot) ...[
            Text("Type your account password instead and the PIN is turned off.",
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            TextField(
              controller: pin2, obscureText: true,
              onSubmitted: (_) => _forgotPin(student),
              decoration: InputDecoration(
                  labelText: "Password for ${db.sb.auth.currentUser?.email ?? "your account"}"),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
                onPressed: () => _forgotPin(student), child: const Text("Turn the PIN off")),
          ],
          if (msg.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 10),
                child: Note(msg, tone: NoteTone.problem)),
        ])),
      ]);
    }

    final dt = dayTypeOf(day, plan);
    final items = practiceItems(plan, state.date);
    final doneHw = state.tasks.where((t) => t.done).length;
    final donePr = items.where(state.practiceDone).length;
    final subjects = state.subjects;

    Future<void> savePlan() async {
      await db.savePlan(plan);
      await state.reload();
      if (mounted) {
        setState(() {});
      }
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      Sheet(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text("${student.firstName} · ${prettyDate(state.date)}",
              style: Theme.of(context).textTheme.titleMedium)),
          if ((student.parentPin ?? "").isNotEmpty)
            TextButton(onPressed: state.lockParent, child: const Text("🔒 Lock")),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          Pill(
            dt.type != "school"
                ? "${kDayTypes[dt.type]!.$1} ${kDayTypes[dt.type]!.$2}"
                : day.diaryPostedAt != null ? "Diary posted ✓" : "⚠ Diary not posted",
            tone: dt.type != "school" ? PillTone.mid : day.diaryPostedAt != null ? PillTone.ok : PillTone.no,
          ),
          Pill("Homework $doneHw/${state.tasks.length}",
              tone: state.tasks.isNotEmpty && doneHw == state.tasks.length ? PillTone.ok : PillTone.no),
          Pill("Practice $donePr/${items.length}",
              tone: items.isNotEmpty && donePr == items.length ? PillTone.ok : PillTone.mid),
          Pill("${day.badges.length} ⭐"),
        ]),
        const SizedBox(height: 8),
        Text(homeworkLock(day, plan, state.tasks).isEmpty
            ? "Homework finished — practice is open."
            : homeworkLock(day, plan, state.tasks),
            style: Theme.of(context).textTheme.bodySmall),
      ])),
      const SizedBox(height: 14),

      Sheet(child: Column(children: [
        _section("today", "📅", "Today", kDayTypes[dt.type]!.$2, [
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in kDayTypes.entries)
              ChoiceChip(
                label: Text("${e.value.$1} ${e.value.$2}"),
                selected: dt.type == e.key,
                onSelected: (_) async {
                  day..dayType = e.key..dayTypeBy = "adult";
                  await db.saveDay(day);
                  await state.reload();
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
          ]),
          if (day.teacherNote != null) Padding(padding: const EdgeInsets.only(top: 8),
              child: Text("Teacher's note in diary: ${day.teacherNote}",
                  style: Theme.of(context).textTheme.bodySmall)),
        ]),

        _section("hw", "📒", "Homework", "$doneHw of ${state.tasks.length} checked", [
          for (final t in state.tasks)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: t.done,
              title: Text(t.task),
              subtitle: Text(t.subject, style: Theme.of(context).textTheme.bodySmall),
              secondary: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () async { await db.removeTask(t.id); await state.reload(); setState(() {}); },
              ),
              onChanged: (v) async {
                await db.setTaskDone(t.id, v ?? false, "adult");
                await state.reload();
                if (mounted) {
                  setState(() {});
                }
              },
            ),
          if (state.tasks.isEmpty)
            Text("Nothing yet — it appears once she snaps her diary.",
                style: Theme.of(context).textTheme.bodySmall),
        ]),

        _section("msg", "💌", "Notes", "A note pops up in her app straight away", [
          Row(children: [
            Expanded(child: TextField(controller: note,
                decoration: const InputDecoration(hintText: "Well done on your Maths! 🌟"))),
            const SizedBox(width: 8),
            // Same rule as the Save buttons: nothing typed, nothing to press.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: note,
              builder: (_, value, __) => FilledButton(
                onPressed: value.text.trim().isEmpty
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await db.sendNudge(student.id, "Home", note.text.trim());
                        note.clear();
                        messenger.showSnackBar(const SnackBar(content: Text("Sent 💌")));
                      },
                child: const Text("Send"),
              ),
            ),
          ]),
        ]),

        _section("forteacher", "🗣️", "Notes for Teacher",
            (student.parentNote ?? "").isEmpty && (day.parentNote ?? "").isEmpty
                ? "Tell the tutor what to work on"
                : "Teacher is reading your note", [
          Text("Only Teacher reads this — ${student.firstName} never sees it. "
              "Say what you want worked on, or what to go easy on. Teacher folds "
              "it into the lesson quietly, and will still never hand her an answer.",
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: forTeacher,
            maxLines: 4,
            maxLength: kNoteMax,
            decoration: const InputDecoration(
              labelText: "Always",
              hintText: "Please go slowly with the tables — she guesses instead of working it out. "
                  "She reads Tamil better than she writes it.",
            ),
          ),
          _saveRow(
            box: forTeacher,
            saved: student.parentNote,
            label: "Save",
            onSave: () async {
              final messenger = ScaffoldMessenger.of(context);
              final text = tidyNote(forTeacher.text);
              await db.setParentNote(student.id, text);
              await state.refreshStudent();
              forTeacher.text = text;
              messenger.showSnackBar(SnackBar(content: Text(
                  text.isEmpty ? "Cleared" : "Saved — Teacher reads it next time 🗣️")));
              // Saved first, read second: a slow reading never costs her words.
              await _readNote(state, student, plan, savePlan, text);
            },
          ),
          const SizedBox(height: 6),
          const Divider(height: 1),
          const SizedBox(height: 14),
          TextField(
            controller: forTeacherToday,
            maxLines: 3,
            maxLength: kNoteMax,
            decoration: InputDecoration(
              labelText: "Just for today — ${prettyDate(state.date)}",
              hintText: "She has a cold, keep it short. No practice tonight, "
                  "we are out for a wedding.",
            ),
          ),
          _saveRow(
            box: forTeacherToday,
            saved: day.parentNote,
            label: "Save for today",
            onSave: () async {
              final messenger = ScaffoldMessenger.of(context);
              final text = tidyNote(forTeacherToday.text);
              day.parentNote = text.isEmpty ? null : text;
              await db.saveDay(day);
              await state.reload();
              forTeacherToday.text = text;
              messenger.showSnackBar(SnackBar(content: Text(
                  text.isEmpty ? "Cleared" : "Saved for today 🗣️")));
              await _readNote(state, student, plan, savePlan, text);
            },
          ),
          const SizedBox(height: 4),
          Text("Today's note is gone by tomorrow. The one above stays until you change it. "
              "Write dates in plainly — \"Social test on the 30th, lessons 4 and 5\" — and "
              "Teacher offers to put them in her plan.",
              style: Theme.of(context).textTheme.bodySmall),
          if (noteStatus.isNotEmpty) ...[
            const SizedBox(height: 8),
            Note(noteStatus,
                tone: noteStatus.startsWith("Couldn't")
                    ? NoteTone.problem
                    : noteStatus.contains("Added") || noteStatus.contains("Saved")
                        ? NoteTone.good
                        : NoteTone.working),
          ],
        ]),

        _section("subj", "🎒", "Subjects", subjects.join(", "), [
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final x in subjects)
              InputChip(
                label: Text(x),
                onDeleted: () async { plan.subjects = [...subjects]..remove(x); await savePlan(); },
              ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: newSubject,
                decoration: const InputDecoration(hintText: "Add a subject…"))),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                final n = newSubject.text.trim();
                if (n.isEmpty || subjects.contains(n)) return;
                plan.subjects = [...subjects, n];
                newSubject.clear();
                await savePlan();
              },
              child: const Text("Add"),
            ),
          ]),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async { plan.timetable = spreadTimetable(subjects); await savePlan(); },
            child: const Text("Rebuild the weekly timetable from this list"),
          ),
        ]),

        _section("morn", "☀️", "Morning study",
            plan.morningOn ? "On" : "Off", [
          Text("For families who revise before school. It is short, and never locked behind "
              "homework — homework only arrives in the afternoon.",
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () async {
              plan.morningOn = !plan.morningOn;
              if (plan.morningOn && !kWeek.any((w) => (plan.morning[w] ?? []).isNotEmpty)) {
                plan.morning = emptyWeek();
                const days = ["Mon", "Tue", "Wed", "Thu", "Fri"];
                for (var i = 0; i < days.length && i < subjects.length; i++) {
                  plan.morning[days[i]] = [subjects[i]];
                }
              }
              await savePlan();
            },
            child: Text(plan.morningOn ? "✓ Morning study is on" : "Turn on morning study"),
          ),
          if (plan.morningOn)
            for (final w in kWeek)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 44, child: Text(w, style: const TextStyle(fontWeight: FontWeight.w700))),
                  Expanded(
                    child: Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final s in [...subjects, "Weekly revision"])
                        FilterChip(
                          label: Text(s),
                          selected: (plan.morning[w] ?? []).contains(s),
                          onSelected: (_) async {
                            final list = plan.morning[w] ?? (plan.morning[w] = []);
                            list.contains(s) ? list.remove(s) : list.add(s);
                            await savePlan();
                          },
                        ),
                    ]),
                  ),
                ]),
              ),
        ]),

        _section("time", "🗓️", "After-school timetable",
            "Off: ${plan.weekOff.isEmpty ? "none" : plan.weekOff.join(", ")}", [
          for (final w in kWeek)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 44, child: Text(w, style: const TextStyle(fontWeight: FontWeight.w700))),
                Expanded(
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final s in [...subjects, "Weekly revision"])
                      FilterChip(
                        label: Text(s),
                        selected: (plan.timetable[w] ?? []).contains(s),
                        onSelected: (_) async {
                          final list = plan.timetable[w] ?? (plan.timetable[w] = []);
                          list.contains(s) ? list.remove(s) : list.add(s);
                          await savePlan();
                        },
                      ),
                  ]),
                ),
              ]),
            ),
          const SizedBox(height: 4),
          Text("Weekly off", style: Theme.of(context).textTheme.bodySmall),
          Wrap(spacing: 6, children: [
            for (final w in kWeek)
              FilterChip(
                label: Text(w),
                selected: plan.weekOff.contains(w),
                onSelected: (_) async {
                  plan.weekOff.contains(w) ? plan.weekOff.remove(w) : plan.weekOff.add(w);
                  await savePlan();
                },
              ),
          ]),
        ]),



        _section("prog", "📈", "How she's doing",
            () {
              final open = state.skills.where((k) => k.open).length;
              return open == 0
                  ? "Nothing flagged"
                  : "$open thing${open > 1 ? "s" : ""} to work on";
            }(), [
          Text("Built from three weeks of practice, and from what Teacher noticed "
              "while working with her. Teacher uses this to choose what to revise — "
              "it is never read out to her.",
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),

          for (final p in state.progress)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.subject, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      [
                        p.sessions == 0
                            ? "not practised in 3 weeks"
                            : "${p.sessions} session${p.sessions > 1 ? "s" : ""}",
                        if (p.average != null) "${(p.average! * 100).round()}% average",
                        if (p.chaptersTotal > 0)
                          "${p.chaptersDone}/${p.chaptersTotal} chapters",
                        if (p.current != null) "on ${p.current}",
                      ].join(" · "),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ]),
                ),
                if (p.average != null)
                  Pill("${(p.average! * 100).round()}%",
                      tone: p.average! >= 0.75
                          ? PillTone.ok
                          : p.average! >= 0.5 ? PillTone.mid : PillTone.no)
                else if (p.sessions == 0)
                  const Pill("not yet", tone: PillTone.no),
              ]),
            ),

          const Divider(height: 24),
          Text("What Teacher is working on with her",
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          if (state.skills.where((k) => k.open).isEmpty)
            Text("Nothing yet. Teacher writes a note here when the same mistake "
                "turns up more than once — a slip doesn't count.",
                style: Theme.of(context).textTheme.bodySmall)
          else
            for (final k in state.skills.where((k) => k.open))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("${k.subject}: ${k.skill}",
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      if ((k.note ?? "").isNotEmpty)
                        Text(k.note!, style: Theme.of(context).textTheme.bodySmall),
                    ]),
                  ),
                  Pill("seen ${k.seen}×", tone: k.seen >= 3 ? PillTone.no : PillTone.mid),
                ]),
              ),

          if (state.skills.where((k) => !k.open).isNotEmpty) ...[
            const SizedBox(height: 14),
            Text("Cracked it 🎉", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final k in state.skills.where((k) => !k.open))
                Pill("${k.subject}: ${k.skill}", tone: PillTone.ok),
            ]),
          ],
        ]),

        _section("tests", "📝", "Tests & exams",
            examsAhead(plan, state.date).isEmpty
                ? "Nothing coming up"
                : "${examsAhead(plan, state.date).length} coming up", [
          Text("Give the tutor the paper's date and its portions and she revises "
              "exactly that, in the style of the school's papers.",
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: reading ? null : () => _snapTimetable(state, plan, savePlan),
            child: Text(reading ? "Reading…" : "📸 Snap the exam timetable"),
          ),
          if (readStatus.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Note(readStatus,
                  tone: readStatus.startsWith("Couldn't")
                      ? NoteTone.problem
                      : readStatus.contains("Saved")
                          ? NoteTone.good
                          : NoteTone.working),
            ),
          const Divider(height: 24),
          for (final e in examsAhead(plan, state.date))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("${e.subject} · ${e.date}",
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (e.what.isNotEmpty)
                      Text(e.what, style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
                Pill(daysBetween(state.date, e.date) == 0
                        ? "Today"
                        : "in ${daysBetween(state.date, e.date)}d",
                    tone: daysBetween(state.date, e.date) <= 2 ? PillTone.no : PillTone.mid),
                IconButton(
                  icon: const Text("✕"),
                  tooltip: "Remove",
                  onPressed: () async { plan.exams.remove(e); await savePlan(); },
                ),
              ]),
            ),
          const SizedBox(height: 6),
          Text("Add one by hand", style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          TextField(controller: exSubject,
              decoration: const InputDecoration(labelText: "Subject")),
          const SizedBox(height: 8),
          TextField(controller: exWhat, minLines: 1, maxLines: 3,
              decoration: const InputDecoration(labelText: "Portions")),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(controller: exDate, readOnly: true,
                  onTap: () => _pickDate(exDate),
                  decoration: const InputDecoration(labelText: "Date", hintText: "Tap to choose")),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                if (exSubject.text.trim().isEmpty || exDate.text.isEmpty) return;
                plan.exams = mergeExams(plan.exams, [
                  Exam(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    subject: exSubject.text.trim(),
                    what: exWhat.text.trim(),
                    date: exDate.text,
                  ),
                ]);
                exSubject.clear(); exWhat.clear(); exDate.clear();
                await savePlan();
              },
              child: const Text("Add"),
            ),
          ]),
        ]),

        _section("comps", "🏆", "Competitions",
            plan.comps.isEmpty ? "None" : plan.comps.map((c) => c.name).join(", "), [
          Text("The tutor coaches these day by day — topic, then the material, "
              "then learning it, then rehearsal.",
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          for (final c in plan.comps)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text("${c.type}${c.date.isEmpty ? "" : " · ${c.date}"}",
                        style: Theme.of(context).textTheme.bodySmall),
                    if (c.details.isNotEmpty)
                      Text(c.details, style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
                IconButton(
                  icon: const Text("✕"),
                  tooltip: "Remove",
                  onPressed: () async { plan.comps.remove(c); await savePlan(); },
                ),
              ]),
            ),
          const Divider(height: 24),
          TextField(controller: compName,
              decoration: const InputDecoration(labelText: "What is it called?")),
          const SizedBox(height: 8),
          TextField(controller: compType,
              decoration: const InputDecoration(
                  labelText: "Kind", hintText: "Speech, recitation, quiz, drawing…")),
          const SizedBox(height: 8),
          TextField(controller: compDetails, minLines: 1, maxLines: 3,
              decoration: const InputDecoration(
                  labelText: "What the school said",
                  hintText: "2 minutes, topic: My favourite festival")),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(controller: compDate, readOnly: true,
                  onTap: () => _pickDate(compDate),
                  decoration: const InputDecoration(labelText: "Date", hintText: "Tap to choose")),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                if (compName.text.trim().isEmpty || compDate.text.isEmpty) return;
                plan.comps.add(Comp(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  name: compName.text.trim(),
                  type: compType.text.trim().isEmpty ? "Speech" : compType.text.trim(),
                  language: student.languages.first,
                  date: compDate.text,
                  prepDays: 10,
                  details: compDetails.text.trim(),
                ));
                compName.clear(); compType.clear(); compDate.clear(); compDetails.clear();
                await savePlan();
              },
              child: const Text("Add"),
            ),
          ]),
        ]),

        _section("chap", "📚", "Chapters",
            () {
              final learning = [
                for (final s in subjects)
                  if (currentChapter(plan, s) != null) "$s: ${currentChapter(plan, s)!.name}"
              ];
              return learning.isEmpty ? "Nothing marked yet" : learning.join(" · ");
            }(), [
          Text("The chapter marked ⭐ is the one the tutor teaches from. Photographing "
              "a lesson in the Lessons tab adds it here on its own.",
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: chapterSubject.isEmpty ? subjects.first : chapterSubject,
            decoration: const InputDecoration(labelText: "Subject"),
            items: [for (final s in subjects) DropdownMenuItem(value: s, child: Text(s))],
            onChanged: (v) => setState(() => chapterSubject = v ?? ""),
          ),
          const SizedBox(height: 10),
          for (final c in plan.chapters[chapterSubject.isEmpty ? subjects.first : chapterSubject]
              ?? const <Chapter>[])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Expanded(child: Text(c.name)),
                if (c.status == "learning") const Pill("⭐ learning", tone: PillTone.mid)
                else if (c.status == "done") const Pill("done", tone: PillTone.ok)
                else TextButton(
                  child: const Text("Mark as current"),
                  onPressed: () async {
                    final subj = chapterSubject.isEmpty ? subjects.first : chapterSubject;
                    for (final other in plan.chapters[subj] ?? const <Chapter>[]) {
                      if (other.status == "learning") other.status = "todo";
                    }
                    c.status = "learning";
                    await savePlan();
                  },
                ),
                IconButton(
                  icon: const Text("✕"),
                  tooltip: "Remove",
                  onPressed: () async {
                    final subj = chapterSubject.isEmpty ? subjects.first : chapterSubject;
                    plan.chapters[subj]?.remove(c);
                    await savePlan();
                  },
                ),
              ]),
            ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: TextField(controller: newChapter,
                decoration: const InputDecoration(hintText: "Add a chapter by name…"))),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                final n = newChapter.text.trim();
                if (n.isEmpty) return;
                final subj = chapterSubject.isEmpty ? subjects.first : chapterSubject;
                final list = plan.chapters[subj] ?? (plan.chapters[subj] = <Chapter>[]);
                list.add(Chapter(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  name: n,
                  status: list.any((c) => c.status == "learning") ? "todo" : "learning",
                ));
                newChapter.clear();
                await savePlan();
              },
              child: const Text("Add"),
            ),
          ]),
        ]),

        _section("who", "🎓", "Student & family",
            describeGrade(student.country, student.boardId, student.grade), [
          Text("${describeGrade(student.country, student.boardId, student.grade)} · school year "
              "${academicYearLabel(student.ayStartMonth)} · ${student.languages.all.join(", ")}",
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => _editDetails(state, student),
            child: const Text("✏️ Change school, board, class or subjects"),
          ),
          const SizedBox(height: 8),
          Text("Moved school, or moved up a class? This reopens the setup questions "
              "with her answers already filled in.",
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _openSettings(state),
            child: const Text("👧🧒 Children & add a sibling"),
          ),
        ]),

        _section("acct", "⚙️", "Settings & account",
            (student.parentPin ?? "").isEmpty ? "PIN off" : "PIN on", [
          Text(
            (student.parentPin ?? "").isEmpty
                ? "No parent PIN, so this tab opens straight away. Settings can add one."
                : "A PIN is asked for before this tab opens. Settings can change it or turn it off.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => _openSettings(state),
            child: const Text("⚙️ Open settings"),
          ),
          const SizedBox(height: 8),
          Text("Theme, children, parent PIN, email and mobile number.",
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => db.sb.auth.signOut(), child: const Text("Sign out")),
        ]),
      ])),
      const SizedBox(height: 20),
    ]);
  }

  /// What a tuition teacher does when a mother says "her Social test is on the
  /// 30th" — writes it in the planner.
  ///
  /// The note itself is already saved before this runs, so a slow or failed
  /// reading never costs the parent their words. Nothing reaches the plan
  /// until they have seen it and tapped Add: a wrong date in her plan is worse
  /// than no date at all.
  Future<void> _readNote(
    AppState state,
    Student student,
    Plan plan,
    Future<void> Function() savePlan,
    String text,
  ) async {
    if (text.trim().isEmpty) return;
    if (mounted) {
      setState(() => noteStatus = "Teacher is reading your note…");
    }

    NoteReading reading;
    try {
      final out = await askTutorJson(
        studentId: student.id,
        prompt: parentNotePrompt(
          note: text,
          date: state.date,
          grade: state.gradeDescription,
          subjects: state.subjects,
        ),
        tier: "default",
      );
      reading = readParentNote(
        out,
        today: state.date,
        idPrefix: DateTime.now().microsecondsSinceEpoch.toString(),
        subjects: state.subjects,
      );
    } on TutorError catch (e) {
      if (mounted) {
        if (mounted) {
          setState(() => noteStatus =
              "Your note is saved. Teacher couldn't look for dates just now — ${friendlyError(e.code, detail: e.detail)}");
        }
      }
      return;
    } catch (_) {
      if (mounted) {
        if (mounted) {
          setState(() => noteStatus =
              "Your note is saved. Teacher couldn't look for dates just now.");
        }
      }
      return;
    }

    if (!mounted) return;
    if (mounted) {
      setState(() => noteStatus = "");
    }

    if (noteReadingCount(reading) == 0) {
      if (mounted) {
        setState(() => noteStatus = reading.unclear.isEmpty
            ? "Saved. Nothing in it for the plan — Teacher will simply bear it in mind."
            : "Saved. Teacher couldn't place: ${reading.unclear.join("; ")}. "
                "Add a date and save again if that should be in her plan.");
      }
      return;
    }

    final picked = await _reviewNote(reading);
    if (picked == null || !mounted) return;

    final exams = [for (final e in reading.exams) if (picked.contains(e.id)) e];
    final comps = [for (final c in reading.comps) if (picked.contains(c.id)) c];
    final weak = [
      for (var i = 0; i < reading.weak.length; i++)
        if (picked.contains("w$i")) reading.weak[i]
    ];
    if (exams.isEmpty && comps.isEmpty && weak.isEmpty) return;

    plan.exams = mergeExams(plan.exams, exams);
    plan.comps = mergeComps(plan.comps, comps);
    await savePlan();
    for (final w in weak) {
      try {
        await db.noteWeakness(student.id, w.subject, w.skill, w.note);
      } catch (_) {
        // one that didn't stick is not worth losing the rest over
      }
    }
    await state.reload();
    if (!mounted) return;
    final added = [
      if (exams.isNotEmpty) "${exams.length} test${exams.length == 1 ? "" : "s"}",
      if (comps.isNotEmpty) "${comps.length} competition${comps.length == 1 ? "" : "s"}",
      if (weak.isNotEmpty) "${weak.length} thing${weak.length == 1 ? "" : "s"} to watch",
    ].join(", ");
    if (mounted) {
      setState(() => noteStatus = "Added to her plan: $added.");
    }
  }

  /// The parent sees exactly what Teacher understood, and unticks anything
  /// wrong. Returns the ids they kept, or null if they closed it.
  Future<Set<String>?> _reviewNote(NoteReading reading) {
    final picked = <String>{
      ...reading.exams.map((e) => e.id),
      ...reading.comps.map((c) => c.id),
      for (var i = 0; i < reading.weak.length; i++) "w$i",
    };

    return showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, redraw) => AlertDialog(
          title: const Text("Teacher read your note"),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Untick anything that isn't right. Your note itself stays "
                  "exactly as you wrote it.",
                  style: Theme.of(dialogContext).textTheme.bodySmall),
              const SizedBox(height: 6),
              for (final e in reading.exams)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: picked.contains(e.id),
                  onChanged: (v) => redraw(() =>
                      v == true ? picked.add(e.id) : picked.remove(e.id)),
                  title: Text("📝 ${e.subject} test · ${prettyDate(e.date)}"),
                  subtitle: e.what.isEmpty ? null : Text(e.what),
                ),
              for (final c in reading.comps)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: picked.contains(c.id),
                  onChanged: (v) => redraw(() =>
                      v == true ? picked.add(c.id) : picked.remove(c.id)),
                  title: Text("🏆 ${c.name} · ${prettyDate(c.date)}"),
                  subtitle: Text(kCompTypes[c.type] ?? c.type),
                ),
              for (var i = 0; i < reading.weak.length; i++)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: picked.contains("w$i"),
                  onChanged: (v) => redraw(() =>
                      v == true ? picked.add("w$i") : picked.remove("w$i")),
                  title: Text("👀 ${reading.weak[i].subject}: ${reading.weak[i].skill}"),
                  subtitle: const Text("Teacher will work on this quietly"),
                ),
              if (reading.unclear.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text("Teacher couldn't place: ${reading.unclear.join("; ")}",
                    style: Theme.of(dialogContext).textTheme.bodySmall),
              ],
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Not now"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(picked),
              child: const Text("Add to her plan"),
            ),
          ],
        ),
      ),
    );
  }

  /// A Save button that is only alive while there is something to save.
  ///
  /// It watches the box itself rather than the screen, so it wakes on the
  /// first keystroke and goes back to sleep the moment the text matches what
  /// is stored — which is the honest signal a parent wants: a dead button
  /// means your words are in.
  Widget _saveRow({
    required TextEditingController box,
    required String? saved,
    required String label,
    required Future<void> Function() onSave,
  }) =>
      Align(
        alignment: Alignment.centerRight,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: box,
          builder: (_, value, __) {
            final changed = noteChanged(value.text, saved);
            return Row(mainAxisSize: MainAxisSize.min, children: [
              if (!changed && (saved ?? "").isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text("Saved ✓", style: Theme.of(context).textTheme.bodySmall),
                ),
              FilledButton(
                // Dead when nothing has changed, and while a save is in flight
                // — a second tap would write the same note twice.
                onPressed: (!changed || savingNote)
                    ? null
                    : () async {
                        if (mounted) {
                          setState(() => savingNote = true);
                        }
                        try {
                          await onSave();
                        } finally {
                          if (mounted) {
                            setState(() => savingNote = false);
                          }
                        }
                      },
                child: Text(label),
              ),
            ]);
          },
        ),
      );

  Widget _section(String id, String icon, String title, String sub, List<Widget> children) {
    final isOpen = open == id;
    return Column(children: [
      InkWell(
        onTap: () => setState(() => open = isOpen ? "" : id),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Text(icon, style: const TextStyle(fontSize: 19)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15.5,
                    color: isOpen ? C.blue : null)),
                if (sub.isNotEmpty)
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            Text(isOpen ? "▲" : "▼", style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ),
      if (isOpen)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      const Divider(height: 1),
    ]);
  }
}
