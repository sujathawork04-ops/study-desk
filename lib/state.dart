// One place holding today's data for the chosen child, so every screen shows
// the same thing and a single reload() refreshes them all.
import "package:flutter/material.dart";
import "curricula.dart";
import "data/db.dart" as db;
import "models.dart";
import "rules.dart";
import "theme.dart";

class AppState extends ChangeNotifier {
  Student? student;
  Plan? plan;
  Day? day;
  List<Task> tasks = [];
  List<PracticeRow> practice = [];
  List<PracticeRow> recentPractice = [];      // the last three weeks
  List<SkillNote> skills = [];                // what she finds hard
  List<Lesson> lessons = [];
  String explainLang = "first";     // first | second | third
  bool loading = false;

  /// Whether the parent tab is open right now. It lives here rather than in
  /// the tab itself so that turning a PIN on from Settings locks it at once,
  /// and so switching child never carries one child's unlock to another.
  bool parentUnlocked = false;

  /// The date the loaded day, homework and practice belong to. The app is often
  /// left open overnight, and "today" quietly becomes yesterday's screen.
  String loadedDate = "";

  String get date => student == null ? todayId("UTC") : todayId(student!.timezone);

  List<String> get subjects =>
      (plan?.subjects.isNotEmpty ?? false) ? plan!.subjects : defaultSubjects(student?.languages);

  // Both are read while screens are still settling after a child is chosen,
  // so neither may insist a child is already there.
  String get gradeDescription {
    final s = student;
    return s == null ? "" : describeGrade(s.country, s.boardId, s.grade);
  }

  String get academicYear {
    final s = student;
    return s == null
        ? ""
        : "${academicYearLabel(s.ayStartMonth)} — ${academicYearPart(s.ayStartMonth)}";
  }

  Future<void> choose(Student s) async {
    student = s;
    // Drop the previous child's day before her sister's arrives, so no screen
    // ever shows one child's homework under another child's name.
    plan = null; day = null;
    tasks = []; practice = []; lessons = []; recentPractice = []; skills = [];
    parentUnlocked = false;
    appTheme.value = themeModeFrom(s.themeMode);
    notifyListeners();
    await reload();
  }

  /// Settings changed something on the child's row — keep every screen in step.
  void studentChanged() => notifyListeners();

  /// Read the child's row again. Signing in (the "I forgot my PIN" route) makes
  /// the app reload its children, so after any change to that row we re-read it
  /// rather than trusting the copy we happen to be holding.
  Future<void> refreshStudent() async {
    final s = student;
    if (s == null) return;
    final fresh = await db.getStudent(s.id);
    if (fresh == null) return;
    student = fresh;
    appTheme.value = themeModeFrom(fresh.themeMode);
    notifyListeners();
  }

  /// Which load is the current one. Every load takes a ticket on the way in
  /// and checks it on the way out.
  int _epoch = 0;

  /// The last load failed. Without this, a failed load left `loading` true for
  /// ever and the whole app sat on a spinner with nothing to press.
  bool loadFailed = false;

  Future<void> reload() async {
    final s = student;
    if (s == null) return;
    final ticket = ++_epoch;
    loading = true;
    loadFailed = false;
    notifyListeners();
    final d = date;
    try {
      final results = await Future.wait([
        db.getDay(s.id, d), db.getPlan(s.id), db.getTasks(s.id, d),
        db.getPractice(s.id, d), db.getLessons(s.id),
        db.getPracticeSince(s.id, shiftDate(d, -21)),
        db.getSkills(s.id),
      ]);

      // A newer load started while these were in flight, or the family has
      // moved to another child. Drop it on the floor: showing it would put one
      // girl's homework under her sister's name.
      if (loadIsStale(
          startedAt: ticket, now: _epoch, sameChild: identical(student, s))) {
        return;
      }

      day = results[0] as Day;
      plan = results[1] as Plan;
      tasks = results[2] as List<Task>;
      practice = results[3] as List<PracticeRow>;
      lessons = results[4] as List<Lesson>;
      recentPractice = results[5] as List<PracticeRow>;
      skills = results[6] as List<SkillNote>;
      loadedDate = d;
    } catch (_) {
      // Anything at all — no network, a row that will not decode, two devices
      // inserting today's row at once. What must not happen is silence.
      if (ticket == _epoch) loadFailed = true;
    } finally {
      // Only the newest load may clear the flag; an overtaken one saying
      // "finished" would stop the spinner on a load still running.
      if (ticket == _epoch) {
        loading = false;
        notifyListeners();
      }
    }
  }


  /// Midnight passed where the child is, so what is on screen is yesterday's.
  bool get dayHasRolledOver => loadedDate.isNotEmpty && loadedDate != date;

  /// Called when the app comes back to the front, and once a minute while it is
  /// open. Cheap when nothing has changed — it only looks at the clock.
  Future<void> refreshIfNewDay() async {
    if (!dayHasRolledOver || loading) return;
    await reload();
  }

  void setExplainLang(String l) { explainLang = l; notifyListeners(); }

  void unlockParent() { parentUnlocked = true; notifyListeners(); }
  void lockParent() { parentUnlocked = false; notifyListeners(); }

  /// Back to "Who's studying?" — used by the header and the parent tab.
  void clearStudent() {
    student = null;
    parentUnlocked = false;
    plan = null; day = null;
    tasks = []; practice = []; lessons = []; recentPractice = []; skills = [];
    notifyListeners();
  }

  /// The language the tutor should explain in right now.
  String get talkLanguage {
    final l = student?.languages;
    return switch (explainLang) {
      "second" => l?.second ?? l?.first ?? "English",
      "third" => l?.third ?? l?.first ?? "English",
      _ => l?.first ?? "English",
    };
  }

  bool practiceDone(String item) =>
      practice.any((p) => p.item == item && p.done);

  /// How each subject is going — the tutor uses it to choose what to revise.
  List<SubjectProgress> get progress =>
      plan == null ? const [] : subjectProgress(plan!, recentPractice, subjects);

  PracticeRow? practiceRow(String item) {
    for (final p in practice) {
      if (p.item == item) return p;
    }
    return null;
  }
}

class Scope extends InheritedNotifier<AppState> {
  const Scope({super.key, required AppState state, required super.child}) : super(notifier: state);
  static AppState of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<Scope>()!.notifier!;
}
