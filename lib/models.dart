// The shapes stored in Supabase. Same tables as the web app — one database
// serves both, so a family can use the phone and the browser together.

class StudentLanguages {
  const StudentLanguages({required this.first, this.second, this.third});
  final String first;
  final String? second;
  final String? third;

  factory StudentLanguages.fromJson(Map<String, dynamic>? j) => StudentLanguages(
        first: (j?["first"] as String?) ?? "English",
        second: j?["second"] as String?,
        third: j?["third"] as String?,
      );

  Map<String, dynamic> toJson() => {"first": first, "second": second, "third": third};
  List<String> get all => [first, if (second != null) second!, if (third != null) third!];
}

class Student {
  Student({
    required this.id, required this.name, required this.country, required this.boardId,
    required this.board, required this.grade, required this.timezone,
    required this.ayStartMonth, required this.languages, this.parentPin,
    this.parentMobile, this.themeMode, this.readAloud = false, this.parentNote,
    this.strictness,
  });

  final String id;
  final String name;
  final String country;
  final String boardId;
  final String board;
  final String grade;
  final String timezone;
  final int ayStartMonth;
  final StudentLanguages languages;
  String? parentPin;
  String? parentMobile;
  String? themeMode;          // system | light | dark
  bool readAloud;             // she prefers Teacher's replies spoken

  /// Standing instructions from her parents to the tutor — "go slowly with
  /// tables", "she reads Tamil better than she writes it". The child never
  /// sees it; the tutor is told it before every conversation.
  String? parentNote;

  /// How demanding Teacher should be: gentle | firm | exacting.
  String? strictness;

  String get firstName => name.split(" ").first;

  factory Student.fromJson(Map<String, dynamic> j) => Student(
        id: j["id"] as String,
        name: (j["name"] as String?) ?? "",
        country: (j["country"] as String?) ?? "IN",
        boardId: (j["board_id"] as String?) ?? "cbse",
        board: (j["board"] as String?) ?? "",
        grade: (j["grade"] as String?) ?? (j["class_label"] as String?) ?? "",
        timezone: (j["timezone"] as String?) ?? "Asia/Kolkata",
        ayStartMonth: (j["ay_start_month"] as int?) ?? 4,
        languages: StudentLanguages.fromJson(j["languages"] as Map<String, dynamic>?),
        parentPin: j["parent_pin"] as String?,
        parentMobile: j["parent_mobile"] as String?,
        themeMode: j["theme_mode"] as String?,
        readAloud: (j["read_aloud"] as bool?) ?? false,
        parentNote: j["parent_note"] as String?,
        strictness: j["strictness"] as String?,
      );
}

class Chapter {
  Chapter({required this.id, required this.name, required this.status});
  final String id;
  String name;
  String status; // todo | learning | done

  factory Chapter.fromJson(Map<String, dynamic> j) =>
      Chapter(id: j["id"] as String, name: j["name"] as String, status: j["status"] as String);
  Map<String, dynamic> toJson() => {"id": id, "name": name, "status": status};
}

class Exam {
  Exam({required this.id, required this.subject, required this.what, required this.date});
  final String id;
  String subject, what, date;
  factory Exam.fromJson(Map<String, dynamic> j) => Exam(
      id: j["id"] as String, subject: j["subject"] as String,
      what: j["what"] as String, date: (j["date"] as String?) ?? "");
  Map<String, dynamic> toJson() => {"id": id, "subject": subject, "what": what, "date": date};
}

class Comp {
  Comp({required this.id, required this.name, required this.type, required this.language,
        required this.date, required this.prepDays, required this.details});
  final String id;
  String name, type, language, date, details;
  int prepDays;
  factory Comp.fromJson(Map<String, dynamic> j) => Comp(
      id: j["id"] as String, name: j["name"] as String, type: j["type"] as String,
      language: (j["language"] as String?) ?? "English", date: (j["date"] as String?) ?? "",
      prepDays: (j["prepDays"] as int?) ?? 10, details: (j["details"] as String?) ?? "");
  Map<String, dynamic> toJson() => {
      "id": id, "name": name, "type": type, "language": language,
      "date": date, "prepDays": prepDays, "details": details};
}

class OffDay {
  OffDay({required this.id, required this.type, required this.from, required this.to, required this.note});
  final String id;
  String type, from, to, note;
  factory OffDay.fromJson(Map<String, dynamic> j) => OffDay(
      id: j["id"] as String, type: j["type"] as String,
      from: (j["from"] as String?) ?? "", to: (j["to"] as String?) ?? "", note: (j["note"] as String?) ?? "");
  Map<String, dynamic> toJson() => {"id": id, "type": type, "from": from, "to": to, "note": note};
}

class Plan {
  Plan({
    required this.studentId, required this.subjects, required this.timetable,
    required this.morningOn, required this.morning, required this.weekOff,
    required this.chapters, required this.exams, required this.comps, required this.offDays,
  });

  final String studentId;
  List<String> subjects;
  Map<String, List<String>> timetable;   // after school
  bool morningOn;
  Map<String, List<String>> morning;     // before school
  List<String> weekOff;
  Map<String, List<Chapter>> chapters;
  List<Exam> exams;
  List<Comp> comps;
  List<OffDay> offDays;

  static Map<String, List<String>> _week(dynamic raw) {
    final out = {for (final d in kWeek) d: <String>[]};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is List) out[k as String] = v.map((e) => e.toString()).toList();
      });
    }
    return out;
  }

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
        studentId: j["student_id"] as String,
        subjects: ((j["subjects"] as List?) ?? []).map((e) => e.toString()).toList(),
        timetable: _week(j["timetable"]),
        morningOn: (j["morning_on"] as bool?) ?? false,
        morning: _week(j["morning"]),
        weekOff: ((j["week_off"] as List?) ?? ["Sun"]).map((e) => e.toString()).toList(),
        chapters: ((j["chapters"] as Map?) ?? {}).map((k, v) => MapEntry(
            k as String,
            ((v as List?) ?? []).map((e) => Chapter.fromJson(e as Map<String, dynamic>)).toList())),
        exams: ((j["exams"] as List?) ?? []).map((e) => Exam.fromJson(e as Map<String, dynamic>)).toList(),
        comps: ((j["comps"] as List?) ?? []).map((e) => Comp.fromJson(e as Map<String, dynamic>)).toList(),
        offDays: ((j["off_days"] as List?) ?? []).map((e) => OffDay.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Map<String, dynamic> toJson() => {
        "subjects": subjects,
        "timetable": timetable,
        "morning_on": morningOn,
        "morning": morning,
        "week_off": weekOff,
        "chapters": chapters.map((k, v) => MapEntry(k, v.map((c) => c.toJson()).toList())),
        "exams": exams.map((e) => e.toJson()).toList(),
        "comps": comps.map((c) => c.toJson()).toList(),
        "off_days": offDays.map((o) => o.toJson()).toList(),
      };
}

class Day {
  Day({required this.studentId, required this.date, this.dayType, this.dayTypeBy,
       this.diaryPhoto, this.diaryPostedAt, this.teacherNote, this.parentNote,
       required this.badges});
  final String studentId;
  final String date;
  String? dayType, dayTypeBy, diaryPhoto, diaryPostedAt, teacherNote;

  /// Just for today, from her parents to the tutor — "she has a cold, keep it
  /// short", "no homework today, they went to a wedding". It is wiped by
  /// tomorrow because it lives on the day, not on the child.
  String? parentNote;
  List<String> badges;

  factory Day.fromJson(Map<String, dynamic> j) => Day(
        studentId: j["student_id"] as String,
        date: j["date"] as String,
        dayType: j["day_type"] as String?,
        dayTypeBy: j["day_type_by"] as String?,
        diaryPhoto: j["diary_photo"] as String?,
        diaryPostedAt: j["diary_posted_at"] as String?,
        teacherNote: j["teacher_note"] as String?,
        parentNote: j["parent_note"] as String?,
        badges: ((j["badges"] as List?) ?? []).map((e) => e.toString()).toList(),
      );

  Map<String, dynamic> toJson() => {
        "student_id": studentId, "date": date, "day_type": dayType, "day_type_by": dayTypeBy,
        "diary_photo": diaryPhoto, "diary_posted_at": diaryPostedAt,
        "teacher_note": teacherNote, "parent_note": parentNote, "badges": badges,
      };
}

class Task {
  Task({required this.id, required this.subject, required this.task, this.due,
        required this.done, this.checkedBy, this.mode});
  final String id;
  final String subject, task;
  final String? due;

  /// How the school wants it done: oral | written | read | practice. It comes
  /// from the row the line was written on, which is better evidence than the
  /// words — "learn Q&A" on an Oral row will be asked, not collected.
  final String? mode;
  bool done;
  String? checkedBy;

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j["id"] as String, subject: j["subject"] as String, task: j["task"] as String,
        due: j["due"] as String?, done: (j["done"] as bool?) ?? false,
        checkedBy: j["checked_by"] as String?,
        mode: j["mode"] as String?,
      );
}

class PracticeRow {
  PracticeRow({required this.item, required this.done, this.score});
  final String item;
  final bool done;
  final String? score;
  factory PracticeRow.fromJson(Map<String, dynamic> j) => PracticeRow(
      item: j["item"] as String, done: (j["done"] as bool?) ?? false, score: j["score"] as String?);
}

/// One thing she finds hard — written by the tutor, about the work and never
/// about the child, and closed when she has it.
class SkillNote {
  SkillNote({
    required this.subject, required this.skill, required this.status,
    required this.seen, this.note, this.lastSeen = "", this.firstSeen = "",
  });

  final String subject, skill, status;
  final int seen;
  final String? note;
  final String lastSeen, firstSeen;

  bool get open => status != "fixed";

  factory SkillNote.fromJson(Map<String, dynamic> j) => SkillNote(
        subject: (j["subject"] as String?) ?? "",
        skill: (j["skill"] as String?) ?? "",
        status: (j["status"] as String?) ?? "weak",
        seen: (j["seen"] as int?) ?? 1,
        note: j["note"] as String?,
        lastSeen: (j["last_seen"] as String?) ?? "",
        firstSeen: (j["first_seen"] as String?) ?? "",
      );
}

/// A short note typed in the parent area for the child herself — praise, a
/// reminder, "back by six". It is shown once, on her Today page.
class Nudge {
  Nudge({required this.id, required this.from, required this.text});
  final String id, from, text;
  factory Nudge.fromJson(Map<String, dynamic> j) => Nudge(
        id: j["id"] as String,
        from: (j["from_name"] as String?) ?? "Home",
        text: (j["text"] as String?) ?? "",
      );
}

class Lesson {
  Lesson({required this.ref, required this.subject, required this.name,
          required this.text, required this.pages,
          this.keep = "year", this.savedOn = ""});
  final String ref;
  final String subject, name, text;
  final List<String> pages;

  /// How long the family wants it taught from: day | term | year. A borrowed
  /// worksheet and her own textbook chapter do not deserve the same shelf life.
  final String keep;

  /// The day it was saved — the other half of working out when it expires.
  final String savedOn;

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        ref: j["ref"] as String, subject: (j["subject"] as String?) ?? "",
        name: (j["name"] as String?) ?? "", text: (j["text"] as String?) ?? "",
        pages: ((j["pages"] as List?) ?? []).map((e) => e.toString()).toList(),
        keep: (j["keep"] as String?) ?? "year",
        savedOn: (j["saved_on"] as String?)?.split("T").first ?? "",
      );
}

class Msg {
  Msg({required this.role, required this.content, this.hidden});
  final String role;     // user | assistant
  final String content;
  final String? hidden;  // SPELL: / WIDGET: / EXPLAIN: lines, never shown
  factory Msg.fromJson(Map<String, dynamic> j) => Msg(
      role: j["role"] as String, content: (j["content"] as String?) ?? "",
      hidden: j["hidden"] as String?);
}

const kWeek = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

const kDayTypes = {
  "school": ("🏫", "School day"),
  "nobag": ("🎒", "No-bag day"),
  "holiday": ("🏖️", "Holiday"),
  "leave": ("🤒", "On leave"),
};

const kCompTypes = {
  "speech": "🎤 Speech / Elocution", "recitation": "📜 Recitation", "spelling": "🐝 Spelling bee",
  "quiz": "❓ Quiz / GK", "olympiad": "🧮 Olympiad", "story": "📖 Storytelling",
  "essay": "✍️ Essay writing", "handwriting": "🖋️ Handwriting", "drawing": "🎨 Drawing / Craft",
  "other": "🏆 Other",
};
