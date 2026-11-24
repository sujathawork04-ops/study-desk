// The questions asked ONCE per child: name, where she goes to school, board,
// class, school year, languages, subjects, and the guardian's consent.
import "package:flutter/material.dart";
import "../curricula.dart";
import "../data/db.dart" as db;
import "../models.dart";
import "../rules.dart";
import "../theme.dart";

/// The short names on the jump chips when an existing child is being edited.
const stepNames = ["Child", "Board & class", "School year", "Languages", "Subjects", "Review"];

class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.first,
    required this.onDone,
    this.existing,
    this.existingSubjects,
  });

  final bool first;
  final Future<void> Function(Student) onDone;

  /// Pass a child to reopen these same questions and CHANGE the answers —
  /// a new school, a new board, a move abroad, next year's class.
  final Student? existing;
  final List<String>? existingSubjects;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int step = 0;
  final name = TextEditingController();
  final ownSubject = TextEditingController();

  String country = "IN";
  String boardId = "cbse";
  String grade = "";
  String lang1 = "English", lang2 = "", lang3 = "";
  late int ayStart = academicYearFor(country).startMonth;
  late String zone = zoneForCountry(country);
  bool ayTouched = false, zoneTouched = false;
  bool subjectsTouched = false, consent = false, busy = false;
  late List<String> subjects = defaultSubjects(const StudentLanguages(first: "English"));
  String err = "";

  bool get editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    if (s == null) return;
    name.text = s.name;
    country = s.country;
    boardId = s.boardId;
    grade = s.grade;
    lang1 = s.languages.first;
    lang2 = s.languages.second ?? "";
    lang3 = s.languages.third ?? "";
    ayStart = s.ayStartMonth;
    zone = s.timezone;
    ayTouched = true;
    zoneTouched = true;
    subjectsTouched = true;
    subjects = [...?widget.existingSubjects];
    consent = true;                       // given when the child was added
  }

  @override
  void dispose() { name.dispose(); ownSubject.dispose(); super.dispose(); }

  Country? get c => findCountry(country);
  Board? get board => findBoard(country, boardId) ?? c?.boards.first;

  void _suggestSubjects() {
    if (subjectsTouched) return;
    if (mounted) {
      setState(() => subjects = defaultSubjects(StudentLanguages(
          first: lang1, second: lang2.isEmpty ? null : lang2, third: lang3.isEmpty ? null : lang3)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages();
    final page = pages[step];
    final last = step == pages.length - 1;
    final canSave = pages.every((p) => p.ok);
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Bounded(
          maxWidth: 620,
          child: ListView(padding: const EdgeInsets.all(20), children: [
          const SizedBox(height: 10),
          // Adding a child walks through the questions in order. Editing shows
          // all six at once, so you can jump straight to the one that changed.
          if (editing)
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (var i = 0; i < pages.length; i++)
                ChoiceChip(
                  label: Text(i < stepNames.length ? stepNames[i] : "Step ${i + 1}"),
                  selected: i == step,
                  onSelected: (_) => setState(() => step = i),
                ),
            ])
          else
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (step + 1) / pages.length,
                    minHeight: 7,
                    backgroundColor: C.blueSoft,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text("Step ${step + 1} of ${pages.length}", style: t.bodySmall),
            ]),
          const SizedBox(height: 16),
          Text(page.title, style: t.headlineSmall),
          if (page.hint.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(page.hint, style: t.bodySmall),
          ],
          const SizedBox(height: 16),
          ...page.body,
          if (err.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(err, style: const TextStyle(color: C.warn)),
          ],
          const SizedBox(height: 18),
          if (editing)
            // The buttons live in a bar pinned to the bottom instead, so Save
            // is one tap away even on the long Subjects step.
            const SizedBox(height: 4)
          else
            Row(children: [
              if (step > 0)
                TextButton(onPressed: () => setState(() => step--), child: const Text("Back"))
              else if (!widget.first)
                TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text("Cancel")),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: !page.ok || busy
                      ? null
                      : () => last ? _finish() : setState(() => step++),
                  child: Text(busy ? "Saving…" : last ? "Start studying 🎒" : "Next"),
                ),
              ),
            ]),
        ]),
        ),
      ),
      // Editing: Cancel · Next · Save, always on screen, whichever step is open.
      bottomNavigationBar: !editing
          ? null
          : SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(top: BorderSide(color: dark ? C.dLine : C.line)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                // heightFactor keeps this bar as tall as its buttons. Without
                // it the bar fills the screen and the questions get no room.
                child: Align(
                  alignment: Alignment.center,
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (!canSave)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text("Fill in the name and class before saving.",
                            style: t.bodySmall),
                      ),
                    Row(children: [
                      TextButton(
                        onPressed: busy ? null : () => Navigator.of(context).maybePop(),
                        child: const Text("Cancel"),
                      ),
                      const SizedBox(width: 8),
                      if (!last)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: page.ok ? () => setState(() => step++) : null,
                            child: const Text("Next"),
                          ),
                        ),
                      if (!last) const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: canSave && !busy ? _finish : null,
                          child: Text(busy ? "Saving…" : "Save changes ✓"),
                        ),
                      ),
                    ]),
                    ]),
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _finish() async {
    if (mounted) {
      setState(() { busy = true; err = ""; });
    }
    final langs = StudentLanguages(
        first: lang1, second: lang2.isEmpty ? null : lang2, third: lang3.isEmpty ? null : lang3);
    try {
      // Changing an existing child: same questions, an update instead of a new row.
      final old = widget.existing;
      if (old != null) {
        await db.updateStudent(old.id, {
          "name": name.text.trim(),
          "country": country,
          "board_id": boardId,
          "board": board?.short ?? board?.name ?? boardId,
          "grade": grade,
          "languages": langs.toJson(),
          "ay_start_month": ayStart,
          "timezone": zone,
        });
        final plan = await db.getPlan(old.id);
        plan.subjects = subjects;
        await db.savePlan(plan);
        await widget.onDone(Student(
          id: old.id,
          name: name.text.trim(),
          country: country,
          boardId: boardId,
          board: board?.short ?? board?.name ?? boardId,
          grade: grade,
          timezone: zone,
          ayStartMonth: ayStart,
          languages: langs,
          parentPin: old.parentPin,
          parentMobile: old.parentMobile,
          themeMode: old.themeMode,
        ));
        return;
      }

      await db.recordConsent();
      final student = await db.addStudent(
        name: name.text.trim(),
        country: country,
        boardId: boardId,
        boardName: board?.short ?? board?.name ?? boardId,
        grade: grade,
        languages: StudentLanguages(
            first: lang1, second: lang2.isEmpty ? null : lang2, third: lang3.isEmpty ? null : lang3),
        // Whatever this device says, not a hard-coded India — the app is meant
        // to work wherever the child goes to school.
        timezone: zone,
        ayStartMonth: ayStart,
        subjects: subjects,
      );
      await widget.onDone(student);
    } catch (e) {
      if (mounted) {
        setState(() => err = "Couldn't save: $e");
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  List<({String title, String hint, bool ok, List<Widget> body})> _pages() => [
        (
          title: editing
              ? "Change school details"
              : widget.first ? "Welcome! Who is studying?" : "Who is studying?",
          hint: editing
              ? "Moved school, changed board, or a new class this year? Change it here. "
                "Homework, chapters and progress already saved are kept."
              : "We ask these questions once. You can change any of them later in the Parent tab.",
          ok: name.text.trim().isNotEmpty,
          body: [
            _label("Student's name"),
            TextField(controller: name, onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: "e.g. Meera")),
            const SizedBox(height: 14),
            _label("Where do they go to school?"),
            _dropdown<String>(
              value: country,
              items: [for (final x in countries) (x.code, x.name)],
              onChanged: (v) => setState(() {
                country = v!;
                boardId = findCountry(v)?.boards.first.id ?? "";
                grade = "";
                if (!ayTouched) ayStart = academicYearFor(v).startMonth;
                if (!zoneTouched) zone = zoneForCountry(v);
              }),
            ),
            const SizedBox(height: 6),
            Text("This decides which boards and school year we show — not where you live.",
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        (
          title: "Which school board${c != null && c!.code != "XX" ? " in ${c!.name}" : ""}?",
          hint: "The tutor follows this board's syllabus, terms and methods, so school and home match.",
          ok: grade.isNotEmpty,
          body: [
            _label("Board / curriculum"),
            _dropdown<String>(
              value: boardId,
              items: [for (final b in c?.boards ?? const <Board>[]) (b.id, b.name)],
              onChanged: (v) => setState(() { boardId = v!; grade = ""; }),
            ),
            if (board?.note != null) ...[
              const SizedBox(height: 6),
              Text(board!.note!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 14),
            _label("Class / grade"),
            _dropdown<String>(
              value: grade.isEmpty ? null : grade,
              hint: "Choose…",
              items: [for (final g in board?.grades ?? const <String>[]) (g, g)],
              onChanged: (v) => setState(() => grade = v!),
            ),
          ],
        ),
        (
          title: "When does their school year run?",
          hint: "School years start at different times around the world, so please check this one.",
          ok: true,
          body: [
            _label("Where the clock is set"),
            _dropdown<String>(
              value: kZoneOffsets.containsKey(zone) ? zone : deviceZone(),
              items: [for (final z in kZonesByOffset) (z, zoneLabel(z))],
              onChanged: (v) => setState(() { zone = v!; zoneTouched = true; }),
            ),
            const SizedBox(height: 6),
            Text("This decides when her day starts and ends — which homework is "
                "today's, whether it is still morning for revision, and how many "
                "days are left before a test. Set it to where she goes to school.",
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            _label("Academic year"),
            _dropdown<int>(
              value: ayStart,
              items: [
                for (final o in academicYearOptions)
                  (o.startMonth,
                   "${o.label}${o.startMonth == academicYearFor(country).startMonth ? "  (usual here)" : ""}")
              ],
              onChanged: (v) => setState(() { ayStart = v!; ayTouched = true; }),
            ),
            const SizedBox(height: 8),
            Text("Right now that makes it ${academicYearLabel(ayStart)} — the ${academicYearPart(ayStart)}. "
                "The tutor uses this to pace revision.",
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        (
          title: "Which languages do they study?",
          hint: "The first is the language the tutor explains in; the others are school languages they are learning.",
          ok: lang2 != lang1 && (lang3.isEmpty || (lang3 != lang1 && lang3 != lang2)),
          body: [
            _label("First language (tutor explains in this)"),
            _dropdown<String>(value: lang1, items: [for (final l in languages) (l, l)],
                onChanged: (v) => setState(() { lang1 = v!; _suggestSubjects(); })),
            const SizedBox(height: 12),
            _label("Second language"),
            _dropdown<String>(value: lang2.isEmpty ? "" : lang2,
                items: [("", "None"), for (final l in languages.where((x) => x != lang1)) (l, l)],
                onChanged: (v) => setState(() { lang2 = v!; _suggestSubjects(); })),
            const SizedBox(height: 12),
            _label("Third language"),
            _dropdown<String>(value: lang3.isEmpty ? "" : lang3,
                items: [("", "None"),
                        for (final l in languages.where((x) => x != lang1 && x != lang2)) (l, l)],
                onChanged: lang2.isEmpty ? null : (v) => setState(() { lang3 = v!; _suggestSubjects(); })),
          ],
        ),
        (
          title: "Which subjects does she study?",
          hint: "Every school's list is different, so use your school's own words. You can change this any time.",
          ok: subjects.isNotEmpty,
          body: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final x in {...subjects, ...commonSubjects})
                FilterChip(
                  label: Text(x),
                  selected: subjects.contains(x),
                  onSelected: (_) => setState(() {
                    subjectsTouched = true;
                    subjects.contains(x) ? subjects.remove(x) : subjects.add(x);
                  }),
                ),
            ]),
            const SizedBox(height: 14),
            _label("Not in the list? Type it and press Add"),
            Row(children: [
              Expanded(child: TextField(controller: ownSubject,
                  decoration: const InputDecoration(hintText: "e.g. Moral Science"))),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  final n = ownSubject.text.trim();
                  if (n.isEmpty || subjects.contains(n)) return;
                  if (mounted) {
                    setState(() { subjectsTouched = true; subjects.add(n); ownSubject.clear(); });
                  }
                },
                child: const Text("Add"),
              ),
            ]),
            const SizedBox(height: 10),
            Text("Chosen: ${subjects.join(", ")}. Teacher builds her weekly practice from these, two a day.",
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        (
          title: editing ? "Check the changes" : "One last thing",
          hint: "",
          ok: editing || consent,
          body: [
            Sheet(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.text.trim().isEmpty ? "Your child" : name.text.trim(),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(describeGrade(country, boardId, grade), style: Theme.of(context).textTheme.bodySmall),
              Text("School year ${academicYearLabel(ayStart)} · ${zoneLabel(zone)}",
                  style: Theme.of(context).textTheme.bodySmall),
              Text([lang1, lang2, lang3].where((x) => x.isNotEmpty).join(" · "),
                  style: Theme.of(context).textTheme.bodySmall),
              Text(subjects.join(", "), style: Theme.of(context).textTheme.bodySmall),
            ])),
            const SizedBox(height: 14),
            if (!editing)
              CheckboxListTile(
              value: consent,
              onChanged: (v) => setState(() => consent = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                "I am this child's parent or guardian and I agree to their name, photos and "
                "study chats being stored, as described in the privacy policy.",
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ];

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(s, style: Theme.of(context).textTheme.bodySmall),
      );

  Widget _dropdown<T>({
    required T? value,
    required List<(T, String)> items,
    required void Function(T?)? onChanged,
    String? hint,
  }) =>
      DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        hint: hint == null ? null : Text(hint),
        items: [for (final (v, label) in items) DropdownMenuItem(value: v, child: Text(label))],
        onChanged: onChanged,
      );
}
