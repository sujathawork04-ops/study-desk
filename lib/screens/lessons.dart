// Snap the pages of a lesson so Teacher can teach and quiz from her own book.
import "dart:async";
import "dart:convert";
import "dart:typed_data";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";

import "../data/db.dart" as db;
import "../data/pdf.dart";
import "../data/photos.dart";
import "../data/pick_file.dart";
import "../data/save_file.dart";
import "../data/tutor.dart";
import "../models.dart";
import "../prompt.dart";
import "../rules.dart";
import "../state.dart";
import "../theme.dart";

class LessonsScreen extends StatefulWidget {
  const LessonsScreen({super.key});
  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  String? subject;
  String status = "";
  bool err = false, busy = false;

  /// Writing the archive out. Its own flag: it must not be blocked by, or
  /// block, a chapter being read.
  bool saving = false;

  Timer? waiting;

  /// Anything left out of this reading — pages past the cap, a PDF page that
  /// would not draw. Carried to the end rather than flashed on screen, because
  /// the line that said it used to be wiped by the next status a second later.
  String leftOut = "";

  /// How long the next lesson she snaps should be kept. Her own textbook is
  /// the common case, so the year is the default.
  String keep = "book";

  @override
  void dispose() { waiting?.cancel(); super.dispose(); }

  /// A number that moves. A status line that never changes is how a slow
  /// upload and a dead one look exactly alike.
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
        setState(() => status = seconds < 30
            ? "$what… ${seconds}s"
            : "$what… ${seconds}s (a full page takes a while)");
      }
    });
  }

  void _stopClock() => waiting?.cancel();

  /// "A new book has started" — the moment a parent actually knows, which is
  /// never a date on a calendar. Every chapter still being taught from for
  /// this subject is offered, all ticked, and whatever they leave ticked is
  /// put away together.
  ///
  /// Put away, not deleted: a school that carries on with the old book for
  /// another fortnight should cost a parent one tap to undo, not a year of
  /// photographs.
  Future<void> _startNewBook(AppState state, String subj) async {
    final older = lessonsToClear(state.lessons, subj);
    if (older.isEmpty) {
      if (mounted) {
        setState(() { status = "No $subj lessons to put away yet."; err = false; });
      }
      return;
    }

    final picked = {for (final l in older) l.ref};
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, redraw) => AlertDialog(
          title: Text("Starting a new $subj book?"),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Teacher will stop teaching from these. Nothing is deleted — "
                  "you can bring any of them back from the list below.",
                  style: Theme.of(dialogContext).textTheme.bodySmall),
              const SizedBox(height: 6),
              for (final l in older)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: picked.contains(l.ref),
                  onChanged: (v) => redraw(() =>
                      v == true ? picked.add(l.ref) : picked.remove(l.ref)),
                  title: Text(l.name),
                  subtitle: l.savedOn.isEmpty ? null : Text("saved ${l.savedOn}"),
                ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text("Put them away"),
            ),
          ],
        ),
      ),
    );
    if (go != true || picked.isEmpty || !mounted) return;

    try {
      await db.archiveLessons(state.student!.id, picked.toList());
      await state.reload();
      if (!mounted) return;
      if (mounted) {
        setState(() {
          status = "Put ${picked.length} $subj lesson(s) away. "
              "Snap the new book's pages whenever you're ready.";
          err = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { status = "Couldn't put them away. $e"; err = true; });
      }
    }
  }

  /// One batch of pages, transcribed.
  ///
  /// If even this much is too long for a single reply, it halves and tries
  /// again rather than giving up — a dense page with a full exercise set can
  /// outgrow the limit on its own.
  /// [firstPage] is which page of the chapter the first of these images is.
  /// It goes into the prompt, because without it the pages came back in the
  /// wrong order.
  Future<Map<String, dynamic>> _readSome(
    AppState state,
    String subj,
    List<String> images, {
    required int firstPage,
  }) async {
    try {
      return await askTutorJson(
        studentId: state.student!.id,
        prompt: lessonPrompt(subj, state.gradeDescription,
            from: firstPage, to: firstPage + images.length - 1),
        images: images,
        tier: "default",
        maxTokens: 8000,
      );
    } on TutorError catch (e) {
      if (e.code != "too_long" || images.length < 2) rethrow;
      final out = <String>[];
      var title = "";
      for (var k = 0; k < images.length; k++) {
        final one = images[k];
        final part = await _readSome(state, subj, [one], firstPage: firstPage + k);
        if (title.isEmpty) title = (part["title"] ?? "").toString();
        final t = (part["text"] ?? "").toString().trim();
        if (t.isNotEmpty) out.add(t);
      }
      return {"title": title, "text": out.join("\n\n")};
    }
  }

  /// Three things a matching chapter can mean, and the app cannot tell which
  /// from the photographs — so it asks, once, only when text would be lost.
  Future<ReadAction?> _askWhatThisIs(
      String existingName, String newTitle, Lesson old) async {
    final had = wordCount(old.text);
    return showDialog<ReadAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("“$existingName” is already saved"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            "It has ${old.pages.length} page${old.pages.length == 1 ? "" : "s"} "
            "and about $had words in it already.",
          ),
          if (newTitle.isNotEmpty && newTitle != existingName)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text("These pages came back as “$newTitle”."),
            ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(ReadAction.separateChapter),
            child: const Text("A different chapter"),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(ReadAction.replace),
            child: const Text("A better scan — replace it"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(ReadAction.addPages),
            child: const Text("More pages of it"),
          ),
        ],
      ),
    );
  }

  Future<void> _snapPages() async {
    final state = Scope.of(context);
    final subj = subject ?? state.subjects.first;
    // The moment a new book actually turns up is the moment someone points a
    // camera at it. So ask here, once, rather than hoping a parent finds a
    // tidy-up button months later.
    final existing = lessonsToClear(state.lessons, subj);
    if (existing.length >= 2) {
      if (!mounted) return;
      final fresh = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("Same book, or a new one?"),
          content: Text("There are already ${existing.length} $subj chapters saved. "
              "If this is a new book — next term's, or next year's — the old "
              "chapters can be put away so Teacher stops teaching from them."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text("Same book"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text("A new book"),
            ),
          ],
        ),
      );
      if (fresh == true) {
        await _startNewBook(state, subj);
        if (!mounted) return;
      }
    }

    // What the parent actually chose.
    //
    // In the browser that can be a scanned PDF — which is ALL a parent who
    // scanned a textbook has. The photo picker greys every PDF out, so she
    // stood in front of her own five chapters unable to pick one. The browser
    // gets a chooser that takes both; a phone keeps its camera roll.
    final List<Uint8List> raws;
    if (canPickAnyFile) {
      raws = await pickFiles("application/pdf,image/*", limit: kMaxLessonPages);
    } else {
      final picked = await ImagePicker().pickMultiImage(maxWidth: 1400, imageQuality: 80);
      raws = [for (final f in picked) await f.readAsBytes()];
    }
    if (raws.isEmpty) return;

    // Turn everything into pages FIRST. One HEIC among them, or one PDF that
    // will not open, would otherwise fail halfway through — after some pages
    // had already been uploaded.
    final pages = <Uint8List>[];
    var offered = 0;           // counted before the cap, so it can be reported
    var skipped = 0;           // PDF pages that would not draw
    leftOut = "";

    for (final raw in raws) {
      if (isPdfBytes(raw)) {
        if (!canReadPdfHere) {
          if (mounted) {
            setState(() { status = kPdfOnPhoneAdvice; err = true; });
          }
          return;
        }
        final count = await openPdf(raw);
        if (count == 0) {
          await closePdf();
          if (mounted) {
            setState(() { status = kPdfUnreadableAdvice; err = true; });
          }
          return;
        }
        offered += count;
        for (var i = 0; i < count && pages.length < kMaxLessonPages; i++) {
          if (mounted) {
            setState(() {
              status = "Turning page ${i + 1} of $count into a picture\u2026";
              err = false;
            });
          }
          final page = await renderPdfPage(i, width: 1400);
          if (page == null) { skipped++; continue; }
          pages.add(page);
        }
        await closePdf();
      } else {
        offered++;
        if (pages.length >= kMaxLessonPages) continue;
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
        pages.add(ready.bytes);
      }
    }

    if (pages.isEmpty) {
      if (mounted) {
        setState(() { status = kPdfUnreadableAdvice; err = true; });
      }
      return;
    }

    // NEVER silently. Whatever was left behind is carried to the end and said
    // there, where it stays on screen instead of being wiped a second later.
    final notes = <String>[];
    final cut = pagesToRead(offered);
    if (cut.note.isNotEmpty) notes.add(cut.note);
    if (skipped > 0) {
      notes.add("$skipped page${skipped == 1 ? "" : "s"} of that PDF wouldn\u2019t "
          "draw and ${skipped == 1 ? "was" : "were"} left out.");
    }
    leftOut = notes.join(" ");

    if (mounted) {
      setState(() { busy = true; err = false; });
    }
    _countUp("Saving pages");
    try {
      final images = <String>[];
      final paths = <String>[];
      for (final bytes in pages) {
        images.add("data:${photoMime(bytes)};base64,${base64Encode(bytes)}");
        // Same as the diary: keeping the page is a nicety, reading it is not.
        try {
          paths.add(await db.uploadPhoto(state.student!.id, state.date, bytes));
        } catch (_) {
          // no stored copy of this page; the transcription still happens
        }
      }

      // A whole chapter cannot be transcribed in one reply — the answer would
      // be longer than any single response is allowed to be, and what came
      // back was a fraction of the book with no sign that anything was
      // missing. So the pages are read a few at a time and joined up.
      final parts = <String>[];
      var title = "";
      for (var i = 0; i < images.length; i += kPagesPerRead) {
        final upto = (i + kPagesPerRead < images.length) ? i + kPagesPerRead : images.length;
        _countUp(images.length <= kPagesPerRead
            ? "Teacher is reading the lesson"
            : "Teacher is reading pages ${i + 1}–$upto of ${images.length}");

        final out =
            await _readSome(state, subj, images.sublist(i, upto), firstPage: i + 1);
        if (title.isEmpty) title = (out["title"] ?? "").toString().trim();
        final part = (out["text"] ?? "").toString().trim();
        if (part.isNotEmpty) parts.add(part);
      }

      final text = parts.join("\n\n");
      if (text.isEmpty) {
        _stopClock();
        if (mounted) {
          setState(() { status = "Couldn't read the pages. Try clearer photos in good light."; err = true; });
        }
        return;
      }

      final plan = state.plan!;
      final list = plan.chapters[subj] ?? (plan.chapters[subj] = <Chapter>[]);
      // Matched loosely on purpose: the same chapter read twice comes back
      // under two slightly different names, and comparing them exactly split
      // one book into three chapters with a third of the pages in each.
      var chapter = list.where((c) => sameLesson(c.name, title)).firstOrNull;
      var old = chapter == null
          ? null
          : state.lessons.where((l) => l.ref == chapter!.id).firstOrNull;

      // Only when there is something to lose. Loading a whole book must not
      // mean a dialog per chapter.
      var action = ReadAction.addPages;
      if (readNeedsAsking(
          matchedExisting: chapter != null, oldText: old?.text ?? "")) {
        if (!mounted) return;
        final chose = await _askWhatThisIs(chapter!.name, title, old!);
        if (chose == null) { _stopClock(); return; }      // she backed out
        action = chose;
      }

      if (chapter == null || action == ReadAction.separateChapter) {
        for (final c in list) {
          if (c.status == "learning") c.status = "todo";
        }
        chapter = Chapter(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: title.isEmpty ? "Current lesson" : title,
          status: "learning",
        );
        list.add(chapter);
        old = null;
        await db.savePlan(plan);
      }

      final out = applyRead(
        action,
        oldText: old?.text ?? "",
        oldPages: old?.pages ?? const [],
        newText: text,
        newPages: paths,
      );
      await db.saveLesson(
        state.student!.id,
        Lesson(
          ref: chapter.id, subject: subj, name: old?.name ?? chapter.name,
          text: out.text,
          pages: out.pages,
          keep: keep,
          savedOn: state.date,
        ),
      );
      await state.reload();
      _stopClock();
      final words = wordCount(text);
      if (mounted) {
        setState(() => status =
            "Teacher has read ${title.isEmpty ? "the lesson" : title} — "
            "${images.length} page${images.length == 1 ? "" : "s"}, "
            "about ${wordCount(text) >= 1000 ? "${(words / 100).round() * 100}" : "$words"} words ✓"
            "${leftOut.isEmpty ? "" : "\n$leftOut"}");
      }
    } on TutorError catch (e) {
      _stopClock();
      if (mounted) {
        setState(() { status = friendlyError(e.code, limit: e.limit, detail: e.detail); err = true; });
      }
    } catch (e) {
      // Anything else — the network dropping, storage refusing, the database
      // missing a column. Before this, such a failure left "Saving pages…" on
      // screen for ever and nobody knew the app had given up.
      _stopClock();
      if (mounted) {
        setState(() {
          status = "Couldn't finish saving the pages. $e";
          err = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Scope.of(context);
    final subjects = state.subjects;
    final subj = subject ?? (subjects.isEmpty ? "Maths" : subjects.first);
    final ay = state.student?.ayStartMonth ?? 4;
    bool current(Lesson l) =>
        lessonIsCurrent(l, today: state.date, ayStartMonth: ay);

    final read = state.lessons.where((l) => l.text.isNotEmpty).toList();
    final mine = read.where((l) => l.subject == subj).toList();
    final live = mine.where(current).toList();
    final overFor = mine.where((l) => !current(l)).toList();

    return ListView(padding: const EdgeInsets.all(16), children: [
      StepCard(
        badge: "📖",
        title: "My lessons",
        trailing: read.isEmpty
            ? null
            : Pill("${read.length} lesson${read.length == 1 ? "" : "s"}",
                tone: PillTone.ok),
        children: [
          Text(canPickAnyFile
              ? "Learned a new lesson in class? Add its pages — photographs, or "
                  "a scanned PDF of the chapter — so Teacher can teach and quiz "
                  "you from your own book."
              : "Learned a new lesson in class? Snap its pages so Teacher can "
                  "teach and quiz you from your own book.",
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: subj,
            isExpanded: true,
            items: [for (final s in subjects) DropdownMenuItem(value: s, child: Text(s))],
            onChanged: (v) => setState(() => subject = v),
          ),
          const SizedBox(height: 14),
          Text("Keep it for", style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in kKeepChoices.entries)
              ChoiceChip(
                label: Text("${e.value.$1} ${e.value.$2}"),
                selected: keep == e.key,
                onSelected: busy ? null : (_) => setState(() => keep = e.key),
              ),
          ]),
          const SizedBox(height: 4),
          Text(kKeepChoices[keep]!.$3, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy ? null : _snapPages,
            // A parent with a scanned chapter looked at "Snap lesson pages"
            // and reasonably concluded the app only wanted photographs.
            child: Text(busy
                ? "Working…"
                : canPickAnyFile
                    ? "📄 Add lesson pages or a PDF"
                    : "📷 Snap lesson pages"),
          ),
          if (live.isNotEmpty) ...[
            const SizedBox(height: 6),
            OutlinedButton(
              onPressed: busy ? null : () => _startNewBook(state, subj),
              child: const Text("📦 Starting a new book"),
            ),
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
          const SizedBox(height: 12),
          if (live.isEmpty && overFor.isEmpty)
            Column(children: [
              const Text("📚", style: TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text("No $subj lessons yet. Snap the pages of the one you're learning now.",
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            ]),
          for (final l in live) _lessonRow(state, l, ay, put: false),
          if (overFor.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text("Put away — from older books. Teacher no longer teaches from "
                "these, and ⋯ brings any of them back.",
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            for (final l in overFor) _lessonRow(state, l, ay, put: true),
          ],
        ],
      ),
      // Every subject, not just the one on screen: a copy of half an archive
      // is not a copy.
      if (state.lessons.isNotEmpty) ...[
        const SizedBox(height: 18),
        Row(children: [
          OutlinedButton.icon(
            onPressed: saving ? null : () => _saveCopy(state),
            icon: const Icon(Icons.save_alt, size: 18),
            label: Text(saving ? "Saving…" : "Save a copy of every lesson"),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          "Everything Teacher has read, in one file you keep. Worth doing after "
          "each new book — re-reading the books costs the same time and money "
          "all over again.",
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
      ],
    ]);
  }

  /// Write the whole archive out, for every subject.
  Future<void> _saveCopy(AppState state) async {
    if (mounted) {
      setState(() { saving = true; status = ""; err = false; });
    }
    try {
      final text = lessonArchive(
        state.lessons,
        studentName: state.student!.name,
        grade: state.gradeDescription,
        onDate: state.date,
      );
      final name = archiveFileName(state.student!.name, state.date);
      final saved = await saveTextFile(name, text);
      if (!saved) {
        // No browser to hand a file to. The clipboard still gets it out of the
        // app, which is the point — silently doing nothing would not.
        await Clipboard.setData(ClipboardData(text: text));
      }
      if (mounted) {
        setState(() {
          status = saved
              ? "Saved $name — ${state.lessons.length} chapters ✓"
              : "Copied all ${state.lessons.length} chapters. Paste them into a "
                  "note or an email to keep them ✓";
          err = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          status = "Couldn't write the file. Try again, or ask on a computer.";
          err = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }
  /// Fold one lesson into another that is really the same chapter.
  ///
  /// [keep] survives and gains whatever [drop] had that it did not. The same
  /// pages read twice do not double the words — an exact repeat is dropped —
  /// so joining two identical readings leaves one clean copy.
  Future<void> _join(AppState state, Lesson keep, Lesson drop) async {
    final plan = state.plan!;
    await db.saveLesson(
      state.student!.id,
      Lesson(
        ref: keep.ref,
        subject: keep.subject,
        name: keep.name,
        text: mergeLessonText(keep.text, drop.text),
        pages: mergePages(keep.pages, drop.pages),
        keep: keep.keep,
        savedOn: keep.savedOn.isEmpty ? drop.savedOn : keep.savedOn,
      ),
    );
    removeChapter(plan, drop.ref, drop.subject);
    await db.savePlan(plan);
    await db.removeLesson(state.student!.id, drop.ref);
    await state.reload();
  }

  /// Re-file a lesson under the subject it actually belongs to.
  ///
  /// The pages were read correctly; only the dropdown was wrong. Nothing is
  /// re-photographed and nothing is read again — the transcription stays
  /// exactly as it is and simply moves.
  Future<void> _moveSubject(AppState state, Lesson l) async {
    final choices = state.subjects.where((x) => x != l.subject).toList();
    if (choices.isEmpty) return;

    final to = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text("Put \"${l.name}\" under"),
        children: [
          for (final x in choices)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(x),
              child: Text(x),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text("Cancel",
                style: Theme.of(dialogContext).textTheme.bodySmall),
          ),
        ],
      ),
    );
    if (to == null || !mounted) return;

    // Arriving next to a copy of itself is the common case, not an edge one:
    // the same chapter gets photographed under the wrong subject, then again
    // under the right one. Left alone it shows as two identical rows.
    final twin = twinOf(l, state.lessons, inSubject: to);
    if (twin != null) {
      if (!mounted) return;
      final join = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("There is already one of these"),
          content: Text("$to already has \"${twin.name}\" — ${lessonSize(twin)}. "
              "Join them into one lesson? Pages read twice are not counted twice."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text("Keep both"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text("Join them"),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (join == true) {
        try {
          await _join(state, twin, l);
          if (!mounted) return;
          setState(() {
            subject = to;
            status = "Joined into one \"${twin.name}\" under $to ✓";
            err = false;
          });
        } catch (e) {
          if (mounted) {
            setState(() { status = "Couldn't join them. $e"; err = true; });
          }
        }
        return;
      }
    }

    try {
      final plan = state.plan!;
      // Both halves, or neither: the row that holds the words, and the chapter
      // that says which subject it is filed under.
      moveChapter(plan, l.ref, l.subject, to);
      await db.savePlan(plan);
      await db.setLessonSubject(state.student!.id, l.ref, to);
      await state.reload();
      if (!mounted) return;
      setState(() {
        subject = to;                       // show her where it went
        status = "\"${l.name}\" is now under $to ✓";
        err = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() { status = "Couldn't move it. $e"; err = true; });
      }
    }
  }

  /// What Teacher actually wrote down, in full.
  ///
  /// This is the only honest answer to "did it read all my pages?". A tick
  /// and a chapter name look identical whether twenty-three pages went in or
  /// one did; the words themselves do not.
  void _showTranscription(Lesson l) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.name),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(lessonSize(l), style: Theme.of(dialogContext).textTheme.bodySmall),
              const SizedBox(height: 10),
              SelectableText(
                l.text.isEmpty ? "Nothing was read from these pages." : l.text,
                style: const TextStyle(fontSize: 13.5, height: 1.4),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  /// One saved lesson: what it is, how long it is kept, and the two things a
  /// parent might want — keep it longer, or remove it now.
  Widget _lessonRow(AppState state, Lesson l, int ay, {required bool put}) {
    final twin = put ? null : twinOf(l, state.lessons);
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text(put ? "📕" : "✓", style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.name, maxLines: 2, overflow: TextOverflow.ellipsis),
              Text(
                [lessonSize(l), keepLabel(l, ay)].where((x) => x.isNotEmpty).join(" · "),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ]),
          ),
          PopupMenuButton<String>(
            tooltip: "How long to keep it",
            onSelected: (choice) async {
              if (choice == "see") {
                _showTranscription(l);
                return;
              }
              if (choice == "move") {
                await _moveSubject(state, l);
                return;
              }
              if (choice == "join" && twin != null) {
                // The fuller of the two survives, so nothing is ever lost by
                // joining the wrong way round.
                final keep = l.text.length >= twin.text.length ? l : twin;
                final drop = identical(keep, l) ? twin : l;
                try {
                  await _join(state, keep, drop);
                  if (mounted) {
                    setState(() {
                      status = "Joined into one \"${keep.name}\" ✓";
                      err = false;
                    });
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() { status = "Couldn't join them. $e"; err = true; });
                  }
                }
                return;
              }
              if (choice == "remove") {
                await db.removeLesson(state.student!.id, l.ref);
              } else {
                await db.setLessonKeep(state.student!.id, l.ref, choice);
              }
              await state.reload();
              if (mounted) {
                setState(() {});
              }
            },
            itemBuilder: (_) => [
              if (put)
                const PopupMenuItem(value: "book", child: Text("↩ Bring it back"))
              else
                for (final e in kKeepChoices.entries)
                  PopupMenuItem(
                    value: e.key,
                    child: Text("${e.value.$1} ${e.value.$2}"),
                  ),
              if (!put) const PopupMenuItem(value: kArchived, child: Text("📦 Put it away")),
              const PopupMenuItem(value: "see", child: Text("👀 See what Teacher read")),
              const PopupMenuItem(value: "move", child: Text("🎒 Put it under another subject")),
              if (twin != null)
                const PopupMenuItem(value: "join", child: Text("🔗 Join with the other copy")),
              const PopupMenuDivider(),
              const PopupMenuItem(value: "remove", child: Text("🗑 Remove for good")),
            ],
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Text("⋯", style: TextStyle(fontSize: 17)),
            ),
          ),
        ]),
      );
  }
}

extension _First<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
