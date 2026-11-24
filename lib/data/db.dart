// Every read and write. One Supabase project serves both the phone app and the
// web app, so a family can use either.
import "dart:typed_data";
import "package:supabase_flutter/supabase_flutter.dart";
import "../models.dart";
import "../rules.dart";

SupabaseClient get sb => Supabase.instance.client;

// ------------------------------------------------- when the database is behind
/// Columns this app writes that the database does not have yet.
///
/// The app and the database are versioned separately — a family updates the
/// app by rebuilding it, and the database by running a SQL file by hand — so
/// they drift apart, always in the same direction. Every time it has happened
/// the symptom was identical: a child photographs her homework, waits, and is
/// shown "PostgrestException(message: Could not find the 'mode' column…)".
///
/// Two rules now:
///   1. Never lose her work over a column. The write is retried without the
///      field the database does not know, so the lesson is still saved and
///      only the new trimming is missing.
///   2. Never let it be silent. The gap is recorded here and shown to the
///      parent, in their own words, with the file to run.
final Set<String> schemaGaps = <String>{};

final _missingColumn = RegExp(r"Could not find the '([^']+)' column");

/// Run a write, and if the database rejects a column it has never heard of,
/// drop that one field and try again. Returns after the first success.
Future<void> _tolerant(
  String what,
  Future<void> Function(Map<String, dynamic> row) write,
  Map<String, dynamic> row,
) async {
  final payload = {...row};
  // Four attempts: enough for a migration that added several columns at once,
  // and finite so a genuine error can never loop.
  for (var attempt = 0; attempt < 4; attempt++) {
    try {
      await write(payload);
      return;
    } on PostgrestException catch (e) {
      final name = _missingColumn.firstMatch(e.message)?.group(1);
      if (name == null || !payload.containsKey(name)) rethrow;
      schemaGaps.add("$what.$name");
      payload.remove(name);
    }
  }
  // Still failing after dropping four unknown columns: the database is far
  // enough behind that guessing further would be dishonest.
  await write(payload);
}

// ------------------------------------------------------------------ students
Future<List<Student>> listStudents() async {
  final rows = await sb.from("students").select().order("created_at");
  return (rows as List).map((r) => Student.fromJson(r as Map<String, dynamic>)).toList();
}

/// One child, straight from the database — used after changing something on
/// her row (the PIN, her school) so the app never shows a stale answer.
Future<Student?> getStudent(String id) async {
  final row = await sb.from("students").select().eq("id", id).maybeSingle();
  return row == null ? null : Student.fromJson(row);
}

Future<Student> addStudent({
  required String name,
  required String country,
  required String boardId,
  required String boardName,
  required String grade,
  required StudentLanguages languages,
  required String timezone,
  required int ayStartMonth,
  required List<String> subjects,
}) async {
  final uid = sb.auth.currentUser!.id;

  // The ONE write that used to go straight at the database, with no tolerance
  // for a column the schema has not got. Every other write drops an unknown
  // column and carries on; this one threw — and it is the very first thing a
  // new family does, so a database a migration behind made the app unusable at
  // step six of six, after they had typed everything in.
  //
  // Dropping a column here costs a default, not the child: timezone falls back
  // to the server's, ay_start_month to April. Both are mended in Settings.
  final payload = <String, dynamic>{
    "owner_id": uid,
    "name": name,
    "country": country,
    "board_id": boardId,
    "board": boardName,
    "grade": grade,
    "class_label": grade,          // legacy column kept in step
    "languages": languages.toJson(),
    "timezone": timezone,
    "ay_start_month": ayStartMonth,
  };

  Map<String, dynamic>? row;
  for (var attempt = 0; attempt < 6; attempt++) {
    try {
      row = await sb.from("students").insert(payload).select().single();
      break;
    } on PostgrestException catch (e) {
      final missing = _missingColumn.firstMatch(e.message)?.group(1);
      // Only a missing column, and only one the app actually sent. Anything
      // else — a broken policy, no network, a duplicate — is a real failure
      // and must still be shown rather than retried into silence.
      if (missing == null || !payload.containsKey(missing)) rethrow;
      // "name" or "owner_id" missing is not a schema that is merely behind;
      // it is not this app's schema at all, and a child with no name is worse
      // than an error message.
      if (missing == "owner_id" || missing == "name") rethrow;
      schemaGaps.add("students.$missing");
      payload.remove(missing);
    }
  }
  row ??= await sb.from("students").insert(payload).select().single();

  final student = Student.fromJson(row);
  final list = subjects.isEmpty ? defaultSubjects(languages) : subjects;
  await sb.from("plans").insert({
    "student_id": student.id,
    "subjects": list,
    "timetable": spreadTimetable(list),
    "morning_on": false,
    "morning": emptyWeek(),
    "week_off": ["Sun"],
    "chapters": {}, "exams": [], "comps": [], "off_days": [],
  });
  return student;
}

Future<void> updateStudent(String id, Map<String, dynamic> patch) async {
  if (patch["grade"] != null) patch["class_label"] = patch["grade"];
  await _tolerant("students", (row) async {
    if (row.isEmpty) return;              // nothing left the database knows
    await sb.from("students").update(row).eq("id", id);
  }, patch);
}

Future<void> recordConsent() async {
  final uid = sb.auth.currentUser!.id;
  await sb.from("accounts").upsert({"id": uid});
  await sb.from("accounts").update({
    "consent_given_at": DateTime.now().toUtc().toIso8601String(),
    "consent_version": "2026-09",
  }).eq("id", uid);
}

// --------------------------------------------------------------------- plan
Future<Plan> getPlan(String studentId) async {
  final row = await sb.from("plans").select().eq("student_id", studentId).maybeSingle();
  if (row != null) {
    final p = Plan.fromJson(row);
    if (p.subjects.isEmpty) p.subjects = defaultSubjects(null);
    return p;
  }
  final subjects = defaultSubjects(null);
  final fresh = Plan(
    studentId: studentId, subjects: subjects, timetable: spreadTimetable(subjects),
    morningOn: false, morning: emptyWeek(), weekOff: ["Sun"],
    chapters: {}, exams: [], comps: [], offDays: [],
  );
  await sb.from("plans").insert({"student_id": studentId, ...fresh.toJson()});
  return fresh;
}

Future<void> savePlan(Plan plan) async {
  await _tolerant("plans", (row) async {
    await sb.from("plans").update(row).eq("student_id", plan.studentId);
  }, {
    ...plan.toJson(),
    "updated_at": DateTime.now().toUtc().toIso8601String(),
  });
}

// ---------------------------------------------------------------------- day
Future<Day> getDay(String studentId, String date) async {
  final row = await sb.from("days").select()
      .eq("student_id", studentId).eq("date", date).maybeSingle();
  if (row != null) return Day.fromJson(row);
  final fresh = Day(studentId: studentId, date: date, badges: []);
  await sb.from("days").insert(fresh.toJson());
  return fresh;
}

Future<void> saveDay(Day day) async {
  await _tolerant("days", (row) async {
    await sb.from("days").update(row)
        .eq("student_id", day.studentId).eq("date", day.date);
  }, day.toJson());
}

// -------------------------------------------------------------------- tasks
Future<List<Task>> getTasks(String studentId, String date) async {
  final rows = await sb.from("tasks").select()
      .eq("student_id", studentId).eq("date", date).order("created_at");
  return (rows as List).map((r) => Task.fromJson(r as Map<String, dynamic>)).toList();
}

Future<void> addTask(String studentId, String date, String subject, String task,
    {String? due, String? mode}) {
  // The diary often has no due date, and the tutor sends back "" for it.
  // Postgres refuses "" for a date column, so an empty one becomes null here —
  // at the one place that writes it, rather than in every caller.
  final when = (due ?? "").trim();
  // Her homework must land even if the database has no "mode" column yet —
  // losing the whole list because one field is new is exactly what used to
  // happen.
  return _tolerant("tasks", (row) async {
    await sb.from("tasks").insert(row);
  }, {
    "student_id": studentId, "date": date, "subject": subject, "task": task,
    "due": when.isEmpty ? null : when,
    if ((mode ?? "").trim().isNotEmpty) "mode": mode!.trim().toLowerCase(),
  });
}

/// The diary's shorthand is not always readable — "S.(I)" could be Science or
/// Social. When the tutor guesses wrong, this puts it right.
Future<void> setTaskSubject(String id, String subject) =>
    sb.from("tasks").update({"subject": subject}).eq("id", id);

Future<void> setTaskDone(String id, bool done, String by) =>
    sb.from("tasks").update({"done": done, "checked_by": done ? by : null}).eq("id", id);

/// Re-reading the diary replaces what the last reading produced. Only the
/// unfinished ones go — anything already checked by the tutor is her work and
/// stays.
Future<void> removeUndoneTasks(String studentId, String date) =>
    sb.from("tasks").delete().eq("student_id", studentId).eq("date", date).eq("done", false);

Future<void> removeTask(String id) => sb.from("tasks").delete().eq("id", id);

// ----------------------------------------------------------------- practice
/// Every practice row since [from] — how the term has actually gone, rather
/// than only today.
Future<List<PracticeRow>> getPracticeSince(String studentId, String from) async {
  final rows = await sb.from("practice").select().eq("student_id", studentId).gte("date", from);
  return (rows as List).map((r) => PracticeRow.fromJson(r as Map<String, dynamic>)).toList();
}

Future<List<PracticeRow>> getPractice(String studentId, String date) async {
  final rows = await sb.from("practice").select().eq("student_id", studentId).eq("date", date);
  return (rows as List).map((r) => PracticeRow.fromJson(r as Map<String, dynamic>)).toList();
}

Future<void> setPractice(String studentId, String date, String item, bool done, String? score) =>
    sb.from("practice").upsert({
      "student_id": studentId, "date": date, "item": item, "done": done, "score": score,
    }, onConflict: "student_id,date,item");

// ------------------------------------------------------------------ lessons
Future<List<Lesson>> getLessons(String studentId) async {
  final rows = await sb.from("lessons").select().eq("student_id", studentId);
  return (rows as List).map((r) => Lesson.fromJson(r as Map<String, dynamic>)).toList();
}

/// The transcription is the expensive part — a page photographed, uploaded and
/// read. It must survive a database that has not caught up with the app.
Future<void> saveLesson(String studentId, Lesson l) => _tolerant("lessons",
    (row) async {
      await sb.from("lessons").upsert(row, onConflict: "student_id,ref");
    }, {
      "student_id": studentId, "ref": l.ref, "subject": l.subject, "name": l.name,
      "text": l.text, "pages": l.pages,
      "keep": l.keep,
      if (l.savedOn.isNotEmpty) "saved_on": l.savedOn,
      "updated_at": DateTime.now().toUtc().toIso8601String(),
    });

/// Put a lesson away for good. Her pages in storage are left alone — those
/// cost nothing and a parent may want them back.
Future<void> removeLesson(String studentId, String ref) =>
    sb.from("lessons").delete().eq("student_id", studentId).eq("ref", ref);

/// File a lesson under a different subject — the pages were read correctly,
/// the subject was picked wrongly, and re-photographing a chapter over a
/// dropdown mistake would be absurd.
Future<void> setLessonSubject(String studentId, String ref, String subject) =>
    _tolerant("lessons", (row) async {
      if (row.isEmpty) return;
      await sb.from("lessons").update(row)
          .eq("student_id", studentId).eq("ref", ref);
    }, {"subject": subject});

/// Change how long a lesson is kept, without re-reading the pages.
Future<void> setLessonKeep(String studentId, String ref, String keep) =>
    _tolerant("lessons", (row) async {
      if (row.isEmpty) return;            // the column isn't there to set
      await sb.from("lessons").update(row)
          .eq("student_id", studentId).eq("ref", ref);
    }, {"keep": keep});

/// A new book has started: put the old chapters away in one go.
///
/// They are marked, not deleted. A parent who clears the wrong subject, or
/// finds the school is still using last term's book after all, can bring any
/// of them back — and nothing a child worked through is destroyed by a tap.
Future<void> archiveLessons(String studentId, List<String> refs) async {
  if (refs.isEmpty) return;
  await sb.from("lessons").update({"keep": "archived"})
      .eq("student_id", studentId).inFilter("ref", refs);
}

// ----------------------------------------------------------------- messages
Future<List<Msg>> getMessages(String studentId, String date) async {
  final rows = await sb.from("messages").select()
      .eq("student_id", studentId).eq("date", date).order("created_at");
  return (rows as List).map((r) => Msg.fromJson(r as Map<String, dynamic>)).toList();
}

Future<void> addMessage(String studentId, String date, Msg m) =>
    sb.from("messages").insert({
      "student_id": studentId, "date": date, "role": m.role,
      "content": m.content, "hidden": m.hidden,
    });

Future<void> sendNudge(String studentId, String fromName, String text) =>
    sb.from("nudges").insert({"student_id": studentId, "from_name": fromName, "text": text});

/// The notes from home she has not read yet. Oldest first, so a morning note
/// is still above an afternoon one.
Future<List<Nudge>> unseenNudges(String studentId) async {
  final rows = await sb.from("nudges").select()
      .eq("student_id", studentId).eq("seen", false).order("created_at");
  return (rows as List).map((r) => Nudge.fromJson(r as Map<String, dynamic>)).toList();
}

/// She has seen them, so they do not greet her again tomorrow.
Future<void> markNudgesSeen(List<String> ids) async {
  if (ids.isEmpty) return;
  await sb.from("nudges").update({"seen": true}).inFilter("id", ids);
}

/// Standing instructions from her parents to the tutor.
Future<void> setParentNote(String studentId, String note) =>
    updateStudent(studentId, {"parent_note": note.isEmpty ? null : note});

// ------------------------------------------------------------------- skills
/// Everything the tutor has noticed about what she finds hard, newest first.
Future<List<SkillNote>> getSkills(String studentId) async {
  final rows = await sb
      .from("skills")
      .select()
      .eq("student_id", studentId)
      .order("last_seen", ascending: false);
  return (rows as List).map((r) => SkillNote.fromJson(r as Map<String, dynamic>)).toList();
}

/// The tutor saw it again — or for the first time. Counting how often it comes
/// up is what separates a slip from a habit.
Future<void> noteWeakness(String studentId, String subject, String skill, String note) async {
  final key = skill.toLowerCase().trim();
  final today = DateTime.now().toUtc().toIso8601String().split("T").first;

  final existing = await sb
      .from("skills")
      .select()
      .eq("student_id", studentId)
      .eq("subject", subject)
      .eq("skill_key", key)
      .maybeSingle();

  if (existing == null) {
    await sb.from("skills").insert({
      "student_id": studentId, "subject": subject, "skill": skill, "skill_key": key,
      "status": "weak", "seen": 1, "note": note.isEmpty ? null : note,
      "first_seen": today, "last_seen": today,
    });
    return;
  }

  await sb.from("skills").update({
    "seen": ((existing["seen"] as int?) ?? 1) + 1,
    "status": "weak",                       // it is back, whatever it was
    "last_seen": today,
    if (note.isNotEmpty) "note": note,
    "updated_at": DateTime.now().toUtc().toIso8601String(),
  }).eq("id", existing["id"] as String);
}

/// She has it now. The row stays — how long something took to click is worth
/// knowing later.
Future<void> markSkillFixed(String studentId, String subject, String skill) async {
  final today = DateTime.now().toUtc().toIso8601String().split("T").first;
  await sb
      .from("skills")
      .update({"status": "fixed", "last_seen": today,
               "updated_at": DateTime.now().toUtc().toIso8601String()})
      .eq("student_id", studentId)
      .eq("subject", subject)
      .eq("skill_key", skill.toLowerCase().trim());
}

// ------------------------------------------------------------------- photos
/// Keeping a copy of the page is a convenience; reading it is the point. So
/// this gives up after half a minute rather than hanging on a stalled upload
/// and leaving a child staring at "Saving pages…" for ever.
Future<String> uploadPhoto(String studentId, String date, Uint8List bytes) async {
  final path = "$studentId/$date/${DateTime.now().microsecondsSinceEpoch}.jpg";
  await sb.storage
      .from("photos")
      .uploadBinary(
        path, bytes, fileOptions: const FileOptions(contentType: "image/jpeg"),
      )
      .timeout(const Duration(seconds: 30));
  return path;
}

/// Storage is private, so a short-lived signed link is made on demand.
Future<String?> photoUrl(String? path) async {
  if (path == null || path.isEmpty) return null;
  try {
    return await sb.storage.from("photos").createSignedUrl(path, 3600);
  } catch (_) {
    return null;
  }
}
