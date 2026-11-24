// Her day, in order: what to do next, the diary, homework, practice — plus the
// optional morning slot, which sits first before noon.
import "dart:async";
import "dart:convert";
import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "../data/db.dart" as db;
import "../data/photos.dart";
import "../data/tutor.dart";
import "../models.dart";
import "../prompt.dart";
import "../rules.dart";
import "../state.dart";
import "../theme.dart";
import "../ui/mascot.dart";

enum TodaySection { today, practice }

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.onGoChat, required this.section});
  final void Function(String prefill, {bool withPhoto}) onGoChat;
  final TodaySection section;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  String status = "";
  bool err = false, showPhoto = false;
  String? photoUrl;
  Timer? waiting;

  /// Notes typed at home for her — shown once, at the top, then put away.
  List<Nudge> notes = [];
  String notesFor = "";

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.section != TodaySection.today) return;
    final state = Scope.of(context);
    final s = state.student;
    if (s == null || notesFor == s.id) return;
    notesFor = s.id;
    _loadNotes(s.id);
  }

  /// A note from home is a nice surprise, never a reason to stop the day.
  Future<void> _loadNotes(String studentId) async {
    try {
      final rows = await db.unseenNudges(studentId);
      if (mounted) {
        setState(() => notes = rows);
      }
    } catch (_) {
      // no notes shown; nothing else changes
    }
  }

  @override
  void dispose() { waiting?.cancel(); super.dispose(); }

  /// A visible clock while Teacher reads a page — a message that never moves
  /// looks like a frozen app, and this one honestly takes a few seconds.
  void _countUp(String what) {
    waiting?.cancel();
    var seconds = 0;
    if (mounted) {
      setState(() { status = "$what… 0s"; err = false; });
    }
    waiting = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      seconds++;
      if (mounted) {
        setState(() => status = seconds < 25
            ? "$what… ${seconds}s"
            : "$what… ${seconds}s (a busy page can take a little longer)");
      }
    });
  }

  Future<void> _snapDiary() async {
    final state = Scope.of(context);
    final picked = await ImagePicker().pickImage(
        source: ImageSource.camera, maxWidth: 1400, imageQuality: 80);
    if (picked == null) return;
    // The name is only a label — read the file itself before trusting it, and
    // convert an iPhone photo rather than sending her away to do it by hand.
    var bytes = await picked.readAsBytes();
    if (photoKind(bytes) == "heic") {
      if (mounted) {
        setState(() { status = kConvertingPhoto; err = false; });
      }
    }
    final ready = await readyPhoto(bytes);
    if (ready.problem.isNotEmpty) {
      if (mounted) {
        setState(() { status = ready.problem; err = true; });
      }
      return;
    }
    bytes = ready.bytes;
    // A second reading of the same day: the school wrote the list once, so
    // adding it again is almost never what anyone wants.
    var replace = false;
    if (state.tasks.isNotEmpty) {
      if (!mounted) return;
      final choice = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("Read the page again?"),
          content: Text("There are already ${state.tasks.length} jobs on today's list. "
              "Replacing keeps anything Teacher has already checked and re-reads the rest."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop("add"),
              child: const Text("Add to the list"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop("replace"),
              child: const Text("Replace"),
            ),
          ],
        ),
      );
      if (choice == null) return;
      replace = choice == "replace";
    }

    if (!mounted) return;
    if (mounted) {
      setState(() { status = "Saving your diary photo…"; err = false; });
    }

    try {
      // Keeping a copy of the page is a convenience — "See the page" later.
      // Reading the homework off it is the point, and the tutor is handed the
      // photo directly, so a storage problem must not stop the day's work.
      String? path;
      var photoKept = true;
      try {
        path = await db.uploadPhoto(state.student!.id, state.date, bytes);
      } catch (_) {
        photoKept = false;
      }

      state.day!
        ..diaryPhoto = path ?? state.day!.diaryPhoto
        ..diaryPostedAt = DateTime.now().toUtc().toIso8601String();
      await db.saveDay(state.day!);
      await state.reload();

      _countUp("Teacher is reading your diary");
      final out = await askTutorJson(
        studentId: state.student!.id,
        prompt: diaryPrompt(state.date, state.gradeDescription, state.subjects),
        maxTokens: 2500,
        images: ["data:${photoMime(bytes)};base64,${base64Encode(bytes)}"],
      );

      waiting?.cancel();
      if (out["readable"] == false) {
        if (mounted) {
          setState(() {
            status = "I couldn't read it clearly. Please retake the photo in good light.";
            err = true;
          });
        }
        return;
      }

      if (replace) {
        await db.removeUndoneTasks(state.student!.id, state.date);
        await state.reload();
      }

      var added = 0;
      final written = <String>[];
      for (final t in (out["tasks"] as List?) ?? const []) {
        final task = (t["task"] ?? "").toString().trim();
        if (task.isEmpty) continue;
        // Two readings of one line differ in their punctuation, not their
        // meaning — compare the letters and digits only.
        if (state.tasks.any((x) => sameTask(x.task, task))) continue;
        if (written.any((x) => sameTask(x, task))) continue;
        written.add(task);
        await db.addTask(state.student!.id, state.date,
            (t["subject"] ?? "Other").toString(), task,
            due: t["due"] as String?, mode: t["mode"] as String?);
        added++;
      }
      for (final t in (out["tests"] as List?) ?? const []) {
        final what = (t["what"] ?? "").toString().trim();
        if (what.isEmpty || state.plan!.exams.any((e) => e.what == what)) continue;
        state.plan!.exams.add(Exam(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          subject: (t["subject"] ?? "Other").toString(),
          what: what, date: (t["date"] ?? "").toString(),
        ));
      }
      if (out["teacherNote"] is String) {
        state.day!.teacherNote = out["teacherNote"] as String;
        await db.saveDay(state.day!);
      }
      await db.savePlan(state.plan!);
      await state.reload();
      waiting?.cancel();
      final found = added > 0
          ? "Found $added homework item${added > 1 ? "s" : ""}!"
          : "I didn't find any homework on this page.";
      if (mounted) {
        setState(() {
          status = photoKept
              ? found
              : "$found (The page itself couldn't be saved — check the 'photos' "
                "bucket in Supabase Storage. Nothing else is affected.)";
          err = false;
        });
      }
    } on TutorError catch (e) {
      waiting?.cancel();
      if (mounted) {
        setState(() { status = friendlyError(e.code, limit: e.limit, detail: e.detail); err = true; });
      }
    } catch (e) {
      // Anything else — a row the database refused, a surprise in the reply —
      // must still stop the clock and say something, never leave her watching
      // a counter that has stopped meaning anything.
      waiting?.cancel();
      if (mounted) {
        setState(() {
          status = "Teacher read the page but couldn't save it all: $e";
          err = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Scope.of(context);
    final plan = state.plan, day = state.day;
    if (plan == null || day == null) return const Center(child: CircularProgressIndicator());

    final dt = dayTypeOf(day, plan);
    final lock = homeworkLock(day, plan, state.tasks);
    final items = practiceItems(plan, state.date);
    final morning = morningItems(plan, state.date);
    final early = isMorning(state.student!.timezone);
    final restDay = dt.type == "holiday" || dt.type == "leave";

    final doneHw = state.tasks.where((t) => t.done).length;
    final donePr = items.where(state.practiceDone).length;
    final doneMorning = morning.where(state.practiceDone).length;

    if (widget.section == TodaySection.practice) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        if (early && morning.isNotEmpty) _morningCard(state, morning, doneMorning),
        if (early && morning.isNotEmpty) const SizedBox(height: 14),
        _practiceCard(state, items, donePr, lock),
        if (!early && morning.isNotEmpty) const SizedBox(height: 14),
        if (!early && morning.isNotEmpty) _morningCard(state, morning, doneMorning),
      ]);
    }

    final total = state.tasks.length + items.length + morning.length;
    final finished = doneHw + donePr + doneMorning;
    final pct = total == 0 ? (restDay ? 100 : 0) : (finished * 100 / total).round();
    final mood = restDay
        ? Mood.rest
        : total == 0
            ? Mood.hello
            : finished == total
                ? Mood.cheer
                : finished > 0 ? Mood.think : Mood.hello;

    return ListView(padding: const EdgeInsets.all(16), children: [
      _hero(state, pct, mood, dt, day, restDay, doneHw, donePr, doneMorning, items, morning),
      const SizedBox(height: 14),
      if (notes.isNotEmpty) ...[_notesCard(), const SizedBox(height: 14)],
      ..._nextUp(state, restDay, day, items, morning, early, doneHw, donePr, doneMorning),
      ..._competitionCards(state, plan),
      if (early && morning.isNotEmpty) ...[_morningCard(state, morning, doneMorning), const SizedBox(height: 14)],
      _diaryCard(state, day, dt, restDay),
      const SizedBox(height: 14),
      _homeworkCard(state, doneHw, restDay),
      const SizedBox(height: 14),
      _practiceCard(state, items, donePr, lock),
      if (!early && morning.isNotEmpty) ...[const SizedBox(height: 14), _morningCard(state, morning, doneMorning)],
      if (day.badges.isNotEmpty) ...[
        const SizedBox(height: 14),
        StepCard(badge: "⭐", title: "Badges today", children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final b in day.badges)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: C.hi, borderRadius: BorderRadius.circular(10)),
                child: Text(b, style: const TextStyle(color: C.hiInk, fontWeight: FontWeight.w700)),
              ),
          ]),
        ]),
      ],
      const SizedBox(height: 20),
    ]);
  }

  // ---------------------------------------------------------- competitions
  /// One card per competition that is close enough to be working on: how many
  /// days are left, which stage that puts her in, and the two ways in —
  /// practise today's step, or rehearse it out loud.
  List<Widget> _competitionCards(AppState state, Plan plan) {
    final comps = activeComps(plan, state.date);
    if (comps.isEmpty) return const [];

    return [
      for (final c in comps) ...[
        Builder(builder: (context) {
          final left = daysBetween(state.date, c.date);
          final stage = compStage(left, prepDays: c.prepDays);
          final s = kCompStages[stage] ?? ("🏆", "Coming up", "");
          final when = left <= 0 ? "Today!" : left == 1 ? "Tomorrow" : "in $left days";
          final spoken = compKind(c.type) == "spoken" || compKind(c.type) == "recitation";

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: C.hi.withValues(alpha: .22),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: C.sun.withValues(alpha: .55), width: 2),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(s.$1, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(c.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                Pill(when, tone: left <= 1 ? PillTone.no : PillTone.mid),
              ]),
              const SizedBox(height: 6),
              Text("${s.$2} — ${s.$3}", style: Theme.of(context).textTheme.bodySmall),
              if (c.details.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(c.details, style: Theme.of(context).textTheme.bodySmall),
                ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => widget.onGoChat(
                        "Let's prepare for my competition: ${c.name}"),
                    child: const Text("Practise with Teacher"),
                  ),
                ),
                if (spoken) const SizedBox(width: 8),
                if (spoken)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => widget.onGoChat(
                          "Here is my rehearsal for ${c.name}: "),
                      child: const Text("🎤 Rehearse"),
                    ),
                  ),
              ]),
            ]),
          );
        }),
        const SizedBox(height: 14),
      ],
    ];
  }

  // ------------------------------------------------------------------ hero
  Widget _hero(AppState state, int pct, Mood mood, DayKind dt, Day day, bool restDay,
      int doneHw, int donePr, int doneMorning, List<String> items, List<String> morning) {
    final tally = <String>[
      restDay
          ? "${kDayTypes[dt.type]!.$1} ${kDayTypes[dt.type]!.$2}"
          : (day.diaryPostedAt != null ? "📒 Diary in" : "📒 Diary to do"),
      if (state.tasks.isNotEmpty) "✏️ $doneHw/${state.tasks.length}",
      if (morning.isNotEmpty) "☀️ $doneMorning/${morning.length}",
      if (items.isNotEmpty) "🎯 $donePr/${items.length}",
      if (day.badges.isNotEmpty) "⭐ ${day.badges.length}",
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [C.blue, Color(0xFF4B6FD8), C.sky],
        ),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Hi ${state.student!.firstName}! 👋",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 2),
            Text(prettyDate(state.date),
                style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 13.5)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final x in tally)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(x, style: const TextStyle(
                      color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
            ]),
          ]),
        ),
        SizedBox(
          width: 80, height: 80,
          child: Stack(alignment: Alignment.center, children: [
            ProgressRing(pct: pct),
            Bob(child: Mascot(mood: mood, size: 58)),
          ]),
        ),
      ]),
    );
  }

  // --------------------------------------------------------------- next up
  List<Widget> _nextUp(AppState state, bool restDay, Day day, List<String> items,
      List<String> morning, bool early, int doneHw, int donePr, int doneMorning) {
    String? eyebrow, title, hint, label;
    VoidCallback? go;
    var rest = false;

    final morningLeft = morning.where((i) => !state.practiceDone(i)).toList();
    final taskLeft = state.tasks.where((t) => !t.done).toList();
    final itemLeft = items.where((i) => !state.practiceDone(i)).toList();

    if (early && morningLeft.isNotEmpty && !restDay) {
      eyebrow = "Before school · $doneMorning of ${morning.length} done";
      title = morningLeft.first.substring(9);
      hint = "A quick revision before you go";
      label = "☀️ Start morning revision";
      go = () => _startPractice(state, morningLeft.first);
    } else if (restDay && items.isEmpty && morningLeft.isEmpty) {
      eyebrow = "Today"; title = "A day off 🌴";
      hint = "No diary, no homework. Read a story, or ask Teacher something you've wondered about.";
      label = "Chat with Teacher"; rest = true;
      go = () => widget.onGoChat("");
    } else if (!restDay && day.diaryPostedAt == null) {
      eyebrow = "First thing"; title = "Snap your school diary";
      hint = "Teacher reads the page and writes your homework list for you.";
      label = "📷 Snap diary"; go = _snapDiary;
    } else if (taskLeft.isNotEmpty) {
      final t = taskLeft.first;
      eyebrow = "Homework · $doneHw of ${state.tasks.length} checked";
      title = t.subject; hint = t.task;
      if (taskMode(t.task, mode: t.mode) == "say") {
        label = t.mode == "oral" ? "🎤 Say it to Teacher" : "🎤 Read it to Teacher";
        go = () => widget.onGoChat(t.mode == "oral"
            ? "I have learnt my ${t.subject} homework: ${t.task}. Please ask me. "
            : "Here is my reading for ${t.subject}: ${t.task}. ");
      } else {
        label = "Show Teacher ✓";
        go = () => widget.onGoChat(
            "I finished my ${t.subject} homework: ${t.task}. Please check it! (photo of my notebook attached)",
            withPhoto: true);
      }
    } else if (itemLeft.isNotEmpty) {
      // Competitions have their own card just below, with the stage and the
      // days left on it — so this card takes the next ordinary subject and
      // steps aside when everything left is a competition.
      final plain = itemLeft.where((i) => !i.startsWith("Competition: ")).toList();
      if (plain.isNotEmpty) {
        eyebrow = "Practice · $donePr of ${items.length} done";
        title = plain.first.replaceFirst(RegExp(r"^Test: "), "");
        hint = "About 15 minutes with Teacher";
        label = "Practise now";
        go = () => _startPractice(state, plain.first);
      }
    }

    if (title == null) {
      if (restDay || (state.tasks.isEmpty && items.isEmpty && morning.isEmpty)) return const [];
      return [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(colors: [Color(0xFFFFF1D6), C.doneSoft]),
          ),
          child: Column(children: [
            const Mascot(mood: Mood.cheer, size: 86),
            const SizedBox(height: 8),
            Text("Everything done, ${state.student!.firstName}! 🎉",
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text("Homework checked and practice finished. Go and play.",
                textAlign: TextAlign.center),
          ]),
        ),
        const SizedBox(height: 14),
      ];
    }

    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? C.dPaper : C.paper,
          border: Border.all(color: rest ? C.done : C.hi, width: 2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(eyebrow!.toUpperCase(), style: const TextStyle(
              fontSize: 11.5, letterSpacing: 1, fontWeight: FontWeight.w700, color: C.inkSoft)),
          const SizedBox(height: 4),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(hint!, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: go,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              child: Text(label!, style: const TextStyle(fontSize: 16.5)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 14),
    ];
  }

  void _startPractice(AppState state, String item) {
    final plan = state.plan!;
    if (item.startsWith("Morning: ")) {
      final subject = item.substring(9);
      final ch = currentChapter(plan, subject);
      widget.onGoChat("Good morning! Let's do a short revision before school: $subject"
          "${ch == null ? "" : " — ${ch.name}"}");
    } else if (item.startsWith("Test: ")) {
      widget.onGoChat("Let's prepare for my test: ${item.substring(6)}");
    } else if (item.startsWith("Competition: ")) {
      widget.onGoChat("Let's prepare for my competition: ${item.substring(13)}");
    } else {
      final ch = currentChapter(plan, item);
      widget.onGoChat("Let's do my daily practice: $item${ch == null ? "" : " — ${ch.name}"}");
    }
  }

  // ----------------------------------------------------------------- cards
  /// Notes typed for her in the parent area. She taps to put them away, and
  /// they do not come back tomorrow.
  Widget _notesCard() => StepCard(
        badge: "💌",
        title: notes.length == 1 ? "A note for you" : "Notes for you",
        children: [
          for (final n in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text("${n.text}  — ${n.from}",
                  style: const TextStyle(fontSize: 15.5, height: 1.35)),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () async {
                final ids = [for (final n in notes) n.id];
                if (mounted) {
                  setState(() => notes = []);
                }
                try {
                  await db.markNudgesSeen(ids);
                } catch (_) {
                  // it will simply greet her once more next time
                }
              },
              child: const Text("Thank you ❤️"),
            ),
          ),
        ],
      );

  Widget _diaryCard(AppState state, Day day, DayKind dt, bool restDay) => StepCard(
        badge: "1",
        title: "Today's diary",
        done: day.diaryPostedAt != null || restDay,
        trailing: day.diaryPostedAt != null
            ? const Pill("Posted ✓", tone: PillTone.ok)
            : restDay
                ? Pill("${kDayTypes[dt.type]!.$1} ${kDayTypes[dt.type]!.$2}")
                : const Pill("Not yet", tone: PillTone.no),
        children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in kDayTypes.entries)
              ChoiceChip(
                label: Text("${e.value.$1} ${e.value.$2}"),
                selected: dt.type == e.key,
                onSelected: (_) async {
                  state.day!..dayType = e.key..dayTypeBy = "child";
                  await db.saveDay(state.day!);
                  await state.reload();
                },
              ),
          ]),
          if (!restDay) ...[
            const SizedBox(height: 10),
            Row(children: [
              OutlinedButton(
                onPressed: _snapDiary,
                child: Text(day.diaryPostedAt != null ? "Retake photo" : "📷 Snap diary"),
              ),
              const SizedBox(width: 8),
              if (day.diaryPhoto != null)
                OutlinedButton(
                  onPressed: () async {
                    final url = await db.photoUrl(day.diaryPhoto);
                    if (mounted) {
                      setState(() { showPhoto = !showPhoto; photoUrl = url; });
                    }
                  },
                  child: Text(showPhoto ? "Hide the page" : "See the page"),
                ),
            ]),
          ],
          if (showPhoto && photoUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(borderRadius: BorderRadius.circular(10),
                child: Image.network(photoUrl!, fit: BoxFit.contain)),
          ],
          if (day.teacherNote != null) ...[
            const SizedBox(height: 8),
            Text("Note from your teacher: ${day.teacherNote}",
                style: Theme.of(context).textTheme.bodySmall),
          ],
          if (status.isNotEmpty) ...[
            const SizedBox(height: 8),
            Note(status,
                tone: err
                    ? NoteTone.problem
                    : status.contains("✓")
                        ? NoteTone.good
                        : NoteTone.working),
          ],
        ],
      );

  Widget _homeworkCard(AppState state, int doneHw, bool restDay) => StepCard(
        badge: "2",
        title: "My homework",
        done: state.tasks.isNotEmpty && doneHw == state.tasks.length,
        trailing: state.tasks.isEmpty
            ? null
            : Pill("$doneHw/${state.tasks.length}",
                tone: doneHw == state.tasks.length ? PillTone.ok : PillTone.no),
        children: state.tasks.isEmpty
            ? [
                Column(children: [
                  const Text("📷", style: TextStyle(fontSize: 30)),
                  const SizedBox(height: 6),
                  Text("Your homework list comes from your diary.",
                      style: Theme.of(context).textTheme.bodySmall),
                  if (!restDay) ...[
                    const SizedBox(height: 8),
                    FilledButton(onPressed: _snapDiary, child: const Text("Snap it now")),
                  ],
                ]),
              ]
            : [
                for (final group in tasksBySubject(state.tasks)) ...[
                  // One heading per subject. Two Social tasks are two jobs, not
                  // two subjects — repeating the chip made it look duplicated.
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 6),
                    child: Row(children: [
                      _subjectChip(state, group.subject, group.tasks),
                      const SizedBox(width: 8),
                      if (group.tasks.length > 1)
                        Text("${group.tasks.where((t) => t.done).length}"
                            " of ${group.tasks.length} done",
                            style: Theme.of(context).textTheme.bodySmall),
                    ]),
                  ),
                for (final t in group.tasks)
                  _job(
                    done: t.done,
                    icon: t.done ? "✓" : "",
                    title: t.task,
                    subtitle: "",
                    isSubjectChip: false,
                    actions: t.done
                        ? const []
                        : [
                            OutlinedButton(
                              onPressed: () => widget.onGoChat(
                                  "Please help me with my ${t.subject} homework: ${t.task}"),
                              child: const Text("Help me"),
                            ),
                            if (taskMode(t.task, mode: t.mode) == "say")
                              FilledButton(
                                onPressed: () => widget.onGoChat(t.mode == "oral"
                                    ? "I have learnt my ${t.subject} homework: ${t.task}. Please ask me. "
                                    : "Here is my reading for ${t.subject}: ${t.task}. "),
                                child: Text(t.mode == "oral"
                                    ? "🎤 Say it to Teacher"
                                    : "🎤 Read it to Teacher"),
                              )
                            else
                              FilledButton(
                                onPressed: () => widget.onGoChat(
                                    "I finished my ${t.subject} homework: ${t.task}. Please check it! (photo of my notebook attached)",
                                    withPhoto: true),
                                child: const Text("Show Teacher ✓"),
                              ),
                          ],
                  ),
                ],
              ],
      );

  /// The subject label — tappable, because a diary's shorthand is often
  /// ambiguous and "Other" usually means the tutor couldn't tell.
  Widget _subjectChip(AppState state, String subject, List<Task> tasks) {
    final unknown = subject.toLowerCase() == "other";
    return PopupMenuButton<String>(
      tooltip: "Change subject",
      onSelected: (chosen) async {
        for (final t in tasks) {
          await db.setTaskSubject(t.id, chosen);
        }
        await state.reload();
        if (mounted) {
          setState(() {});
        }
      },
      itemBuilder: (_) => [
        for (final s in state.subjects) PopupMenuItem(value: s, child: Text(s)),
        const PopupMenuItem(value: "Other", child: Text("Other")),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: unknown ? C.warnSoft : C.blueSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(unknown ? "Which subject?" : subject.toUpperCase(),
              style: TextStyle(
                  color: unknown ? C.warn : C.blue,
                  fontWeight: FontWeight.w800, fontSize: 12.5)),
          const SizedBox(width: 4),
          Icon(Icons.expand_more_rounded, size: 15, color: unknown ? C.warn : C.blue),
        ]),
      ),
    );
  }

  Widget _practiceCard(AppState state, List<String> items, int donePr, String lock) => StepCard(
        badge: "🎯",
        title: "Daily practice",
        done: items.isNotEmpty && donePr == items.length,
        trailing: items.isEmpty ? null : Pill("$donePr/${items.length}",
            tone: donePr == items.length ? PillTone.ok : PillTone.mid),
        children: [
          Text(
            items.isEmpty
                ? "Nothing scheduled today — enjoy a story book or play outside! 🌳"
                : lock.isNotEmpty
                    ? "🔒 $lock"
                    : "Tests first, then the rest. About 15 minutes each.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          // Four subjects stacked made a laptop screen scroll past a half-empty
          // column. Two across on a wide window; still one on a phone.
          TwoUp(runGap: 0, children: [
          for (final item in items)
            _job(
              done: state.practiceDone(item),
              icon: state.practiceDone(item)
                  ? "✓"
                  : item.startsWith("Test: ") ? "📝" : item.startsWith("Competition: ") ? "🏆" : "📘",
              title: item.replaceFirst(RegExp(r"^(Test|Competition): "), ""),
              subtitle: _detail(state, item),
              actions: state.practiceDone(item)
                  ? [Pill("Done${state.practiceRow(item)?.score == null ? "" : " · ${state.practiceRow(item)!.score}"}",
                        tone: PillTone.ok)]
                  : [
                      FilledButton(
                        onPressed: lock.isEmpty ? () => _startPractice(state, item) : null,
                        child: Text(lock.isEmpty ? "Practise" : "🔒 After homework"),
                      ),
                    ],
            ),
          ]),
        ],
      );

  Widget _morningCard(AppState state, List<String> morning, int doneMorning) => StepCard(
        badge: "☀️",
        title: "Before school",
        done: doneMorning == morning.length,
        trailing: Pill("$doneMorning/${morning.length}",
            tone: doneMorning == morning.length ? PillTone.ok : PillTone.mid),
        children: [
          Text("A short revision to start the day. No homework needed — that comes this evening.",
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          for (final item in morning)
            _job(
              done: state.practiceDone(item),
              icon: state.practiceDone(item) ? "✓" : "🌅",
              title: item.substring(9),
              subtitle: _detail(state, item),
              actions: state.practiceDone(item)
                  ? [const Pill("Done", tone: PillTone.ok)]
                  : [FilledButton(onPressed: () => _startPractice(state, item), child: const Text("Revise"))],
            ),
        ],
      );

  String _detail(AppState state, String item) {
    final plan = state.plan!;
    if (item.startsWith("Test: ")) {
      final subject = item.substring(6);
      final e = upcomingExams(plan, state.date).where((x) => x.subject == subject);
      if (e.isEmpty) return "";
      final n = daysBetween(state.date, e.first.date);
      return "${e.first.what} — ${n == 1 ? "tomorrow (full mock test today!)" : "in $n days"}";
    }
    if (item.startsWith("Competition: ")) {
      final c = activeComps(plan, state.date).where((x) => "Competition: ${x.name}" == item);
      if (c.isEmpty) return "";
      final n = daysBetween(state.date, c.first.date);
      return "${kCompTypes[c.first.type] ?? c.first.type} · ${n == 0 ? "TODAY" : n == 1 ? "tomorrow" : "in $n days"}";
    }
    final subject = item.startsWith("Morning: ") ? item.substring(9) : item;
    final ch = currentChapter(plan, subject);
    return ch != null ? "Chapter: ${ch.name}" : "Teacher will ask what you're learning in class";
  }

  Widget _job({
    required bool done,
    required String icon,
    required String title,
    required String subtitle,
    required List<Widget> actions,
    bool isSubjectChip = false,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: done ? C.doneSoft : Colors.transparent,
        border: Border.all(color: done ? Colors.transparent : (dark ? C.dLine : C.line)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28, height: 28, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done ? C.done : (dark ? C.dGround : C.ground),
              border: Border.all(color: done ? Colors.transparent : C.line, width: 2),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(icon, style: TextStyle(fontSize: 15, color: done ? Colors.white : null)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (isSubjectChip)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(color: C.blueSoft, borderRadius: BorderRadius.circular(6)),
                  child: Text(title.toUpperCase(), style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: C.blue, letterSpacing: .5)),
                )
              else
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (subtitle.isNotEmpty)
                Text(subtitle, style: TextStyle(
                    fontSize: 14,
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done ? C.inkSoft : null)),
            ]),
          ),
        ]),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: actions),
        ],
      ]),
    );
  }
}

String prettyDate(String id) {
  const months = ["January", "February", "March", "April", "May", "June",
                  "July", "August", "September", "October", "November", "December"];
  const days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
  final p = id.split("-").map(int.parse).toList();
  final d = DateTime.utc(p[0], p[1], p[2]);
  return "${days[d.weekday - 1]}, ${p[2]} ${months[p[1] - 1]}";
}
