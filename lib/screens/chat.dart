// Study with Teacher: streaming replies, photos, voice, read-aloud, and the
// interactive pictures the tutor sends.
import "dart:async";
import "dart:convert";
import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "../blocks.dart";
import "../curricula.dart";
import "../data/db.dart" as db;
import "../data/photos.dart";
import "../data/speech.dart";
import "../data/tutor.dart";
import "../models.dart";
import "../prompt.dart";
import "../rules.dart";
import "../state.dart";
import "../theme.dart";
import "../ui/explainer.dart";
import "../ui/mascot.dart";
import "../ui/prose.dart";
import "../ui/manipulatives.dart";
import "today.dart" show prettyDate;

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.prefill, this.wantsPhoto = false, required this.onPrefillUsed});
  final String? prefill;
  final bool wantsPhoto;
  final VoidCallback onPrefillUsed;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  List<Msg> msgs = [];
  String? streaming;
  /// Pages waiting to be sent. A finished mock test is three or four sheets;
  /// one photo per message meant marking it in three or four conversations.
  final List<String> photos = [];
  String status = "";
  /// Whether the less-used asks are showing.
  bool moreAsks = false;

  /// A send that failed, kept whole so Try again costs her nothing. `sending`
  /// is the only copy of her photographed pages once the tray is emptied.
  ({
    List<Msg> shown,
    List<String> sending,
    Msg userMsg,
    bool saved,
    String asking,
  })? retry;
  bool busy = false, err = false, listening = false, readAloud = false;
  Timer? clock;          // how long she has been speaking, for timed events
  int spokenSeconds = 0;

  String get _clock =>
      "${spokenSeconds ~/ 60}:${(spokenSeconds % 60).toString().padLeft(2, "0")}";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Her own choice, remembered — a child should not have to switch the
      // reading voice back on every single afternoon.
      final state = Scope.of(context);
      if (mounted && state.student != null) {
        if (mounted) {
          setState(() => readAloud = state.student!.readAloud);
        }
      }
      _load();
    });
  }

  @override
  void didUpdateWidget(covariant ChatScreen old) {
    super.didUpdateWidget(old);
    _takePrefill();
  }

  /// The last prefill acted on, so a rebuild does not replay it.
  String? takenPrefill;

  /// A question handed over from another tab — "Help me with my Maths
  /// homework", "🎤 Rehearse".
  ///
  /// Every line of this runs AFTER the frame, never during it. didUpdateWidget
  /// is called in the middle of building, and both filling the box and telling
  /// the shell the prefill has been taken change state — which the framework
  /// refuses mid-build. It used to get away with it because the chat was
  /// thrown away whenever another tab was showing; now that every tab stays
  /// alive, this runs on ordinary rebuilds and the timing has to be right.
  void _takePrefill() {
    final text = widget.prefill;
    if (text == null) {
      takenPrefill = null;        // ready for the next one, even if identical
      return;
    }
    if (text == takenPrefill) return;
    takenPrefill = text;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      input.text = text;
      if (widget.wantsPhoto) _pickPhoto();
      widget.onPrefillUsed();
      // "🎤 Rehearse" lands here — open the microphone for her, she is about
      // to perform, not type.
      if (text.startsWith("Here is my rehearsal") || text.startsWith("Here is my reading")) {
        if (!listening) _toggleMic();
      }
    });
  }

  @override
  void dispose() {
    clock?.cancel();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  /// Everything said since the last fresh start.
  ///
  /// Nothing is deleted — her day's work is still there, and a parent can
  /// still see it in the database. A fresh start is a line drawn under the
  /// conversation so the next question is not answered in the shadow of the
  /// last one: ask about Maths after an hour on islands and the tutor would
  /// keep reaching for the island.
  List<Msg> _sinceFreshStart(List<Msg> all) {
    for (var i = all.length - 1; i >= 0; i--) {
      if (all[i].hidden == kFreshStart) return all.sublist(i + 1);
    }
    return all;
  }

  Future<void> _load() async {
    final state = Scope.of(context);
    final list = await db.getMessages(state.student!.id, state.date);
    if (!mounted) return;
    if (mounted) {
      setState(() => msgs = _sinceFreshStart(list));
    }
    _takePrefill();
  }

  /// Draw the line. Asked for by the child or a parent, never automatic.
  Future<void> _startFresh(AppState state) async {
    if (msgs.isEmpty) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Start something new?"),
        content: const Text(
            "Teacher will begin fresh, without the last conversation in mind. "
            "Nothing you have done today is lost — your homework, your badges "
            "and your practice all stay exactly as they are."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("Keep talking"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text("Start fresh"),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    try {
      await db.addMessage(state.student!.id, state.date,
          Msg(role: "user", content: "", hidden: kFreshStart));
      if (mounted) {
        setState(() { msgs = []; status = ""; err = false; photos.clear(); });
      }
    } catch (e) {
      if (mounted) {
        setState(() { status = "Couldn't start fresh. $e"; err = true; });
      }
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickMultiImage(maxWidth: 1400, imageQuality: 80);
    if (picked.isEmpty) return;

    final room = kPhotosPerMessage - photos.length;
    if (room <= 0) {
      if (mounted) {
        setState(() {
          status = "That's $kPhotosPerMessage pages already — send these, then "
              "add the rest.";
          err = false;
        });
      }
      return;
    }

    for (final f in picked.take(room)) {
      final raw = await f.readAsBytes();
      if (photoKind(raw) == "heic") {
        if (mounted) {
          setState(() { status = kConvertingPhoto; err = false; });
        }
      }
      final ready = await readyPhoto(raw);
      if (ready.problem.isNotEmpty) {
        if (mounted) {
          setState(() { status = ready.problem; err = true; });
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        status = "";
        photos.add("data:${photoMime(ready.bytes)};base64,${base64Encode(ready.bytes)}");
      });
    }

    if (picked.length > room && mounted) {
      setState(() {
        status = "$kPhotosPerMessage pages at a time — send these, then add the rest.";
        err = false;
      });
    }
  }

  DayContext _context(AppState state, {String asking = ""}) {
    final plan = state.plan!, day = state.day!;
    final items = practiceItems(plan, state.date);
    final morning = morningItems(plan, state.date);

    ({String item, String detail, bool done, String? score}) row(String item) {
      final r = state.practiceRow(item);
      final subject = item.replaceFirst(RegExp(r"^(Test|Competition|Morning): "), "");
      final ch = currentChapter(plan, subject);
      final bits = [
        // A paper she is revising for: when it is, and what is on it. Without
        // this the tutor revises in general on the night before an exam.
        if (item.startsWith("Test: ")) testDetail(plan, subject, state.date),
        if (ch != null) "current chapter: ${ch.name}",
      ].where((x) => x.isNotEmpty);
      return (item: item, detail: bits.join(" · "),
              done: r?.done ?? false, score: r?.score);
    }

    return DayContext(
      studentName: state.student!.name,
      subjects: state.subjects,
      gradeDescription: state.gradeDescription,
      board: describeBoard(state.student!.country, state.student!.boardId),
      academicYear: state.academicYear,
      approxAge: approxAge(state.student!.grade),
      languages: state.student!.languages,
      prettyDate: prettyDate(state.date),
      explainLang: state.explainLang,
      dayType: dayTypeOf(day, plan).type,
      strictness: state.student!.strictness ?? "firm",
      parentNote: state.student!.parentNote ?? "",
      parentNoteToday: day.parentNote ?? "",
      tasks: [
        for (final t in state.tasks)
          (subject: t.subject, task: t.task, done: t.done, mode: t.mode ?? ""),
      ],
      practice: items.map(row).toList(),
      morning: morning.map(row).toList(),
      lessons: [
        // Not the first three ever saved — the ones this question is about.
        for (final l in lessonsForTurn(
          state.lessons,
          plan,
          today: state.date,
          ayStartMonth: state.student!.ayStartMonth,
          asking: asking,
          todaysSubjects: [
            for (final i in items) i.replaceFirst(RegExp(r"^(Test|Competition|Morning): "), ""),
          ],
        ))
          (name: "${l.subject} — ${l.name}", text: l.text)
      ],
      progress: state.progress,
      skills: [
        for (final k in state.skills)
          (subject: k.subject, skill: k.skill, note: k.note ?? "",
           seen: k.seen, open: k.open, lastSeen: k.lastSeen),
      ],
      badges: day.badges,
      lock: homeworkLock(day, plan, state.tasks),
      comps: [
        for (final c in activeComps(plan, state.date))
          (
            name: c.name,
            type: c.type,
            language: c.language.isEmpty ? state.student!.languages.first : c.language,
            date: c.date,
            daysLeft: daysBetween(state.date, c.date),
            stage: compStage(daysBetween(state.date, c.date), prepDays: c.prepDays),
            details: c.details,
          ),
      ],
    );
  }

  Future<void> _send([String? override]) async {
    final state = Scope.of(context);
    final body = (override ?? input.text).trim();
    if ((body.isEmpty && photos.isEmpty) || busy) return;

    final sending = [...photos];
    final note = sending.isEmpty
        ? ""
        : "\n[📷 sent ${sending.length} page${sending.length == 1 ? "" : "s"}]";
    final userMsg = Msg(role: "user",
        content: (body.isEmpty
                ? (sending.length == 1
                    ? "Here is a photo of my work."
                    : "Here are ${sending.length} pages of my work.")
                : body) +
            note);
    final shown = [...msgs, userMsg];

    if (mounted) {
      setState(() {
        msgs = shown; input.clear(); photos.clear();
        busy = true; streaming = ""; status = ""; err = false; retry = null;
      });
    }

    await _deliver(state,
        shown: shown, sending: sending, userMsg: userMsg, asking: body);
  }

  /// Everything that can fail, with her photos held until it has not.
  ///
  /// The box and the photo tray are emptied the moment she presses send, so
  /// until this succeeds the only copy of four photographed pages is the
  /// `sending` list. It used to be a local that went out of scope on the first
  /// exception: a dropped wifi connection destroyed the pages, and the error
  /// told her to press send again — which did nothing at all, because the box
  /// was empty and the guard in [_send] returned in silence. Now a failure
  /// keeps everything and offers Try again.
  Future<void> _deliver(
    AppState state, {
    required List<Msg> shown,
    required List<String> sending,
    required Msg userMsg,
    required String asking,
    bool userSaved = false,
  }) async {
    var saved = userSaved;
    try {
      // Inside the try, not above it. This await used to sit outside, so when
      // it threw — offline, an expired token — the exception escaped the whole
      // method, the finally never ran, and `busy` stayed true for the life of
      // the app: every button dead, the spinner spinning, nothing said.
      if (!saved) {
        await db.addMessage(state.student!.id, state.date, userMsg);
        saved = true;
      }
      _toBottom();

      final turns = <Map<String, String>>[
        {"role": "user", "content": buildSystemTurn(_context(state, asking: asking))},
        for (final m in shown.length > 20 ? shown.sublist(shown.length - 20) : shown)
          {
            "role": m.role,
            "content": m.content +
                (m.hidden == null
                    ? ""
                    : "\n(hidden) ${m.hidden!.split("\n").where((l) => !RegExp(r"^\s*(WIDGET|EXPLAIN):", caseSensitive: false).hasMatch(l)).join(" ")}"),
          },
      ];

      final reply = await askTutorStream(
        studentId: state.student!.id,
        messages: turns,
        images: sending,
        onDelta: (whole) { if (mounted) setState(() => streaming = whole); },
      );

      final lines = readTutorLines(reply);

      final hidden = [
        if (lines.spell.isNotEmpty) "SPELL: ${lines.spell.join(", ")}",
        if (lines.widgetLine.isNotEmpty) lines.widgetLine,
        if (lines.explainLine.isNotEmpty) lines.explainLine,
      ].join("\n");

      final bot = Msg(role: "assistant", content: lines.visible, hidden: hidden.isEmpty ? null : hidden);

      // SAVED BEFORE ANYTHING ELSE TOUCHES IT. She often wanders off to another
      // tab while Teacher is thinking, and the hidden lines below tick off
      // homework, score practice and write skill notes — a dozen writes, any of
      // which can fail. Applying them first meant one failed write threw away a
      // reply that had already arrived in full, and told her it was her save
      // that went wrong.
      await db.addMessage(state.student!.id, state.date, bot);
      if (mounted) {
        setState(() { msgs = [...shown, bot]; retry = null; });
      }

      // From here the answer is hers whatever happens.
      try {
        await _apply(state, lines);
        await state.reload();
      } catch (_) {
        // A badge not awarded or a tick not recorded is worth saying nothing
        // about: she has the teaching, which is what she asked for.
      }

      // Only speak to a child who is actually on this screen.
      if (mounted && readAloud) await Speech.instance.speak(plainWords(lines.visible));
      if (mounted && lines.spell.isNotEmpty) await Speech.instance.sayWord(lines.spell.last);
    } on TutorError catch (e) {
      _holdForRetry(shown, sending, userMsg, saved, asking,
          friendlyError(e.code, limit: e.limit, detail: e.detail));
    } catch (_) {
      // She is sitting here alone, so she is told in her own words that it
      // went wrong — never left watching a message that never changes.
      _holdForRetry(shown, sending, userMsg, saved, asking,
          "That didn't go through — nothing to do with you. Press Try again.");
    } finally {
      if (mounted) {
        setState(() { busy = false; streaming = null; });
      }
      _toBottom();
    }
  }

  void _holdForRetry(List<Msg> shown, List<String> sending, Msg userMsg, bool saved,
      String asking, String why) {
    if (!mounted) return;
    setState(() {
      status = why;
      err = true;
      retry = (
        shown: shown, sending: sending, userMsg: userMsg, saved: saved, asking: asking
      );
    });
  }

  Future<void> _tryAgain() async {
    final held = retry;
    if (held == null || busy) return;
    final state = Scope.of(context);
    setState(() { busy = true; streaming = ""; status = ""; err = false; });
    await _deliver(state,
        shown: held.shown,
        sending: held.sending,
        userMsg: held.userMsg,
        asking: held.asking,
        userSaved: held.saved);
  }

  /// The tutor's hidden lines: badges, homework ticked off, practice scored.
  Future<void> _apply(AppState state, TutorLines lines) async {
    final day = state.day!, plan = state.plan!;
    var dayChanged = false, planChanged = false;

    for (final b in lines.badges) {
      if (!day.badges.contains(b)) { day.badges.add(b); dayChanged = true; }
    }
    for (final n in lines.doneNumbers) {
      if (n >= 1 && n <= state.tasks.length) {
        final t = state.tasks[n - 1];
        if (!t.done) await db.setTaskDone(t.id, true, "tutor");
      }
    }
    final all = [...practiceItems(plan, state.date), ...morningItems(plan, state.date)];
    for (final (item, score) in lines.practiced) {
      final match = all.where((i) => i.toLowerCase() == item.toLowerCase());
      if (match.isNotEmpty) {
        await db.setPractice(state.student!.id, state.date, match.first, true,
            score.isEmpty ? null : score);
      }
    }
    for (final subject in lines.mastered) {
      final list = plan.chapters[subject];
      if (list == null) continue;
      final cur = list.where((c) => c.status == "learning").firstOrNull ??
                  list.where((c) => c.status != "done").firstOrNull;
      if (cur != null) {
        cur.status = "done";
        final next = list.where((c) => c.status == "todo").firstOrNull;
        if (next != null) next.status = "learning";
        planChanged = true;
      }
    }
    // What she found hard today, and what she has finally cracked.
    for (final w in lines.weak) {
      await db.noteWeakness(state.student!.id, w.subject, w.skill, w.note);
    }
    for (final f in lines.fixed) {
      await db.markSkillFixed(state.student!.id, f.subject, f.skill);
    }

    if (dayChanged) await db.saveDay(day);
    if (planChanged) await db.savePlan(plan);
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) {
          scroll.animateTo(scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  Future<void> _toggleMic() async {
    final state = Scope.of(context);
    if (listening) {
      clock?.cancel();
      await Speech.instance.stopListening();
      if (mounted) {
        setState(() { listening = false; status = ""; });
      }
      return;
    }
    final base = input.text.trim();
    final ok = await Speech.instance.listen(
      language: state.talkLanguage,
      onWords: (w) => setState(() => input.text = base.isEmpty ? w : "$base $w"),
      onDone: () {
        clock?.cancel();
        if (mounted) {
          setState(() { listening = false; status = ""; });
        }
      },
    );
    clock?.cancel();
    spokenSeconds = 0;
    if (ok) {
      // A speech or recitation usually has a time limit, so she can see how
      // long she has been going.
      clock = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted || !listening) { t.cancel(); return; }
        if (mounted) {
          setState(() {
            spokenSeconds++;
            status = "🎤 Listening… $_clock — press ⏹ when you finish";
          });
        }
      });
    }
    if (mounted) {
      setState(() {
        listening = ok;
        status = ok
            ? "🎤 Listening… 0:00 — press ⏹ when you finish"
            : "This phone can't do voice typing. Use the 🎤 on your keyboard instead.";
        err = !ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Scope.of(context);
    final langs = state.student!.languages;

    return Column(children: [
      Expanded(
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          children: [
            if (msgs.isEmpty) _welcome(state),
            for (var i = 0; i < msgs.length; i++) _bubble(msgs[i], i == msgs.length - 1),
            if (streaming != null) _plainBubble(streaming!.isEmpty ? "Thinking…" : streaming!),
          ],
        ),
      ),
      _composer(state, langs),
    ]);
  }

  /// What the child sees before she has asked anything: Chinnu, a greeting,
  /// and three big things to press — no empty box to stare at.
  Widget _welcome(AppState state) => Column(children: [
        const SizedBox(height: 18),
        const Bob(child: Mascot(size: 104)),
        const SizedBox(height: 14),
        Text("Hi ${state.student!.firstName}! 🌟",
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            "Ask me anything about today's work — or pick one of these and I'll start.",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 18),
        for (final (emoji, title, subtitle, ask) in const [
          ("🧩", "Explain it with pictures", "I'll draw it and you try it", "Explain it with pictures 🧩"),
          ("💡", "I'm stuck", "A hint first, never the answer", "I'm stuck, give me a hint"),
          ("📷", "Check my work", "Send a photo of your notebook", "Check my answer"),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: BigChoice(
              emoji: emoji,
              title: title,
              subtitle: subtitle,
              onTap: busy ? null : () => _send(ask),
            ),
          ),
        const SizedBox(height: 8),
      ]);

  Widget _bubble(Msg m, bool latest) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mine = m.role == "user";
    final widgetSpec = !mine && m.hidden != null ? WidgetSpec.parse(m.hidden!) : null;
    final walk = !mine && m.hidden != null ? Explainer.parse(m.hidden!) : null;
    final wide = widgetSpec != null || walk != null;

    final bubble = Container(
      width: wide ? double.infinity : null,
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
      decoration: BoxDecoration(
        color: mine ? C.blue : (dark ? C.dPaper : C.paper),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(mine ? 18 : 6),
          topRight: Radius.circular(mine ? 6 : 18),
          bottomLeft: const Radius.circular(18),
          bottomRight: const Radius.circular(18),
        ),
        boxShadow: mine ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .32 : .07),
            blurRadius: 14, offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!mine)
          Row(children: [
            Text("Teacher", style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 12.5,
                color: dark ? C.dBlue : C.blue)),
            const Spacer(),
            IconButton(
              tooltip: "Read this out",
              icon: const Text("🔊"), iconSize: 15,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 26),
              onPressed: () => Speech.instance.speak(plainWords(m.content)),
            ),
          ]),
        // Her own words go up exactly as she typed them; only the tutor writes
        // markdown, so only the tutor's side is laid out.
        mine
            ? Text(m.content,
                style: const TextStyle(
                    color: Colors.white, fontSize: 15.5, height: 1.45))
            : Prose(m.content, color: dark ? C.dInk : C.ink),
        if (walk != null) Walkthrough(explainer: walk, disabled: busy, onSend: (t) => _send(t)),
        if (widgetSpec != null)
          Manipulative(spec: widgetSpec, disabled: busy || !latest, onSend: (t) => _send(t)),
      ]),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine) ...[
            const Padding(padding: EdgeInsets.only(top: 2), child: Mascot(size: 30)),
            const SizedBox(width: 8),
          ],
          wide ? Expanded(child: bubble) : Flexible(child: bubble),
        ],
      ),
    );
  }

  Widget _plainBubble(String text) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(top: 2), child: Mascot(size: 30, mood: Mood.think)),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
            decoration: BoxDecoration(
              color: dark ? C.dPaper : C.paper,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6), topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18),
              ),
            ),
            child: Prose(text, color: dark ? C.dInk : C.ink),
          ),
        ),
      ]),
    );
  }

  Widget _composer(AppState state, StudentLanguages langs) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: dark ? C.dPaper : C.paper,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .38 : .09),
            blurRadius: 20, offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: [
        // Six chips in two permanent rows ate a quarter of the composer and
        // pushed the conversation off the top of the screen. The three she
        // reaches for most stay out; the rest are one tap away.
        if (msgs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final q in const [
                "I'm stuck, give me a hint",
                "Explain it with pictures 🧩",
                "Check my answer",
              ])
                ActionChip(label: Text(q), onPressed: busy ? null : () => _send(q)),
              if (moreAsks)
                for (final q in const [
                  "Check my handwriting ✍️",
                  "Quiz me for my test",
                  // A paper, not a conversation: every question at once, written
                  // on paper, photographed and marked. How tomorrow will happen.
                  "Give me the whole paper to write 📝",
                ])
                  ActionChip(label: Text(q), onPressed: busy ? null : () => _send(q)),
              ActionChip(
                avatar: Icon(moreAsks ? Icons.expand_less : Icons.expand_more, size: 18),
                label: Text(moreAsks ? "Less" : "More"),
                onPressed: () => setState(() => moreAsks = !moreAsks),
              ),
            ]),
          ),
        // One Wrap, not a Row with fixed trailing buttons: on a narrow phone
        // the controls move onto their own line instead of being squeezed.
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Text("Explains in", style: Theme.of(context).textTheme.bodySmall),
            ),
            for (final (key, label) in [
              ("first", langs.first),
              if (langs.second != null) ("second", langs.second!),
              if (langs.third != null) ("third", langs.third!),
            ])
              ChoiceChip(
                label: Text(label),
                selected: state.explainLang == key,
                onSelected: (_) => state.setExplainLang(key),
              ),
            // A broom with a tooltip was invisible: a nine-year-old does not
            // know what 🧹 means, and on a phone there is no hover to reveal
            // the tooltip at all. It says what it does now.
            if (msgs.isNotEmpty)
              ActionChip(
                avatar: const Icon(Icons.auto_awesome, size: 17),
                label: const Text("New chat"),
                tooltip: "Put the last conversation away and start fresh",
                onPressed: busy ? null : () => _startFresh(state),
              ),
            ActionChip(
              avatar: Text(readAloud ? "🔊" : "🔈", style: const TextStyle(fontSize: 14)),
              label: Text(readAloud ? "Reading aloud" : "Read aloud"),
              tooltip: readAloud
                  ? "Stop reading answers aloud"
                  : "Read Teacher's answers aloud",
              backgroundColor: readAloud ? (dark ? C.dBlueSoft : C.blueSoft) : null,
              onPressed: () async {
                final want = !readAloud;
                if (mounted) {
                  setState(() => readAloud = want);
                }
                state.student!.readAloud = want;
                try {
                  await db.updateStudent(state.student!.id, {"read_aloud": want});
                } catch (_) {
                  // works for today either way; it just won't be remembered
                }
              },
            ),
          ],
        ),
        if (photos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text("📷 ", style: TextStyle(fontSize: 14)),
                Text(
                    "${photos.length} page${photos.length == 1 ? "" : "s"} ready to send",
                    style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(photos.clear),
                  child: const Text("Remove all"),
                ),
              ]),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (var i = 0; i < photos.length; i++)
                  InputChip(
                    label: Text("Page ${i + 1}"),
                    onDeleted: () => setState(() => photos.removeAt(i)),
                  ),
              ]),
            ]),
          ),
        if (status.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Note(status,
                tone: err ? NoteTone.problem : NoteTone.working),
          ),
        // Only shown when there is really something to try again WITH. Telling
        // a child to press send again when her photos have gone is worse than
        // telling her nothing.
        if (retry != null && !busy)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              FilledButton.tonalIcon(
                onPressed: _tryAgain,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(retry!.sending.isEmpty
                    ? "Try again"
                    : "Try again with my ${retry!.sending.length} page"
                        "${retry!.sending.length == 1 ? "" : "s"}"),
              ),
            ]),
          ),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: input,
              minLines: 1, maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: busy ? null : (_) => _send(),
              decoration: InputDecoration(
                hintText: "Type or speak your doubt…",
                fillColor: dark ? C.dGround : C.ground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: dark ? C.dLine : C.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: dark ? C.dLine : C.line),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _CircleAction(
            emoji: listening ? "⏹" : "🎤",
            tooltip: listening ? "Stop listening" : "Speak your doubt",
            tint: listening ? C.warnSoft : null,
            onTap: _toggleMic,
          ),
          const SizedBox(width: 6),
          _CircleAction(
            emoji: "📷",
            tooltip: "Send a photo",
            onTap: busy ? null : _pickPhoto,
          ),
          const SizedBox(width: 6),
          SizedBox(
            height: 48, width: 48,
            child: FilledButton(
              onPressed: busy ? null : () => _send(),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
                minimumSize: const Size(48, 48),
              ),
              child: busy
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.arrow_upward_rounded, size: 22),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// The round 🎤 / 📷 buttons beside the message box.
class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.emoji, required this.tooltip, this.tint, this.onTap});
  final String emoji;
  final String tooltip;
  final Color? tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: tint ?? (dark ? C.dGround : C.ground),
        shape: CircleBorder(side: BorderSide(color: dark ? C.dLine : C.line)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48, height: 48,
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 19))),
          ),
        ),
      ),
    );
  }
}

extension _First<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
