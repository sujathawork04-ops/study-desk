// What the tutor knows about how she is getting on: how often each subject was
// practised, how the scoring went, how far through the book she is — and which
// subject therefore deserves today's time.
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/blocks.dart";
import "package:study_desk/curricula.dart";
import "package:study_desk/data/tutor.dart";
import "package:study_desk/models.dart";
import "package:study_desk/prompt.dart";
import "package:study_desk/rules.dart";
import "package:study_desk/state.dart";

PracticeRow row(String item, {bool done = true, String? score}) =>
    PracticeRow(item: item, done: done, score: score);

Plan planWith(Map<String, List<Chapter>> chapters, {List<String>? subjects}) => Plan(
      studentId: "x",
      subjects: subjects ?? const ["Maths", "English", "Science"],
      timetable: spreadTimetable(subjects ?? const ["Maths", "English", "Science"]),
      morningOn: false,
      morning: emptyWeek(),
      weekOff: const ["Sun"],
      chapters: chapters,
      exams: <Exam>[],
      comps: <Comp>[],
      offDays: <OffDay>[],
    );

Chapter ch(String id, String name, String status) => Chapter(id: id, name: name, status: status);

void main() {
  skillNoteTests();
  boardTests();
  readingTests();
  homeworkListTests();
  duplicateTaskTests();
  taskModeTests();
  independenceTests();
  dayRolloverTests();

  group("reading a score the tutor wrote", () {
    test("the shapes a tutor actually writes all mean the same thing", () {
      expect(readScore("7/10"), closeTo(0.7, 0.001));
      expect(readScore("70%"), closeTo(0.7, 0.001));
      expect(readScore("7"), closeTo(0.7, 0.001));
      expect(readScore("0.7"), closeTo(0.7, 0.001));
      expect(readScore("9 / 10"), closeTo(0.9, 0.001));
    });

    test("nothing, nonsense and a zero denominator are simply unknown", () {
      expect(readScore(null), isNull);
      expect(readScore(""), isNull);
      expect(readScore("good try!"), isNull);
      expect(readScore("5/0"), isNull);
    });
  });

  group("which subject a practice row belongs to", () {
    test("tests, competitions and morning slots all count towards the subject", () {
      expect(subjectOf("Maths"), "Maths");
      expect(subjectOf("Test: Maths"), "Maths");
      expect(subjectOf("Morning: Tamil"), "Tamil");
      expect(subjectOf("Competition: Elocution"), "Elocution");
    });
  });

  group("three weeks of practice, per subject", () {
    final plan = planWith({
      "Maths": [ch("m1", "Numbers", "done"), ch("m2", "Fractions", "learning")],
      "English": [ch("e1", "The Kite", "learning")],
    });

    test("sessions, scores and the book are counted together", () {
      final p = subjectProgress(plan, [
        row("Maths", score: "9/10"),
        row("Test: Maths", score: "8/10"),
        row("Maths", score: "10/10"),
        row("English", score: "4/10"),
      ], const ["Maths", "English", "Science"]);

      final maths = p.firstWhere((r) => r.subject == "Maths");
      expect(maths.sessions, 3);
      expect(maths.scored, 3);
      expect(maths.average, closeTo(0.9, 0.01));
      expect(maths.chaptersDone, 1);
      expect(maths.chaptersTotal, 2);
      expect(maths.current, "Fractions");

      final science = p.firstWhere((r) => r.subject == "Science");
      expect(science.sessions, 0);
      expect(science.average, isNull);
    });

    test("practice she started but didn't finish isn't counted as done", () {
      final p = subjectProgress(
          plan, [row("Maths", done: false, score: "3/10")], const ["Maths"]);
      expect(p.single.sessions, 0);
    });
  });

  group("choosing where the time goes", () {
    List<SubjectProgress> given(List<PracticeRow> rows, List<String> subjects) =>
        subjectProgress(planWith({}, subjects: subjects), rows, subjects);

    test("the lowest scores come first", () {
      final rows = given([
        row("Maths", score: "9/10"),
        row("Maths", score: "9/10"),
        row("English", score: "4/10"),
        row("English", score: "5/10"),
        row("Science", score: "7/10"),
        row("Science", score: "7/10"),
      ], const ["Maths", "English", "Science"]);

      expect(needsWork(rows, take: 1), ["English"]);
    });

    test("a subject nobody has touched outranks a merely weak one", () {
      final rows = given([
        row("English", score: "4/10"),
      ], const ["Maths", "English"]);

      expect(needsWork(rows, take: 1), ["Maths"], reason: "never practised at all");
    });

    test("praise is only offered where it is earned", () {
      final rows = given([
        row("Maths", score: "9/10"),
        row("Maths", score: "8/10"),
        row("English", score: "5/10"),
        row("English", score: "6/10"),
      ], const ["Maths", "English"]);

      expect(doingWell(rows), ["Maths"]);
    });

    test("one good day isn't a strength yet", () {
      final rows = given([row("Maths", score: "10/10")], const ["Maths"]);
      expect(doingWell(rows), isEmpty);
    });
  });

  group("what the tutor is actually told", () {
    DayContext ctxWith(List<SubjectProgress> progress) => DayContext(
          studentName: "Meera Nair",
          subjects: const ["Maths", "English"],
          gradeDescription: "Class 4 (CBSE, India)",
          academicYear: "2026–27 — second term",
          approxAge: 9,
          languages: const StudentLanguages(first: "English", second: "Tamil"),
          prettyDate: "Friday, 25 September",
          explainLang: "first",
          dayType: "school",
          tasks: const [],
          practice: const [],
          morning: const [],
          lessons: const [],
          badges: const [],
          lock: "",
          progress: progress,
        );

    test("each subject's record reaches the prompt", () {
      final turn = buildSystemTurn(ctxWith([
        (subject: "Maths", sessions: 3, scored: 3, average: 0.9,
         chaptersDone: 1, chaptersTotal: 2, current: "Fractions"),
        (subject: "English", sessions: 0, scored: 0, average: null,
         chaptersDone: 0, chaptersTotal: 0, current: null),
      ]));

      expect(turn, contains("HOW SHE IS DOING"));
      expect(turn, contains("Maths: 3 session(s), average 90%"));
      expect(turn, contains("on Fractions"));
      expect(turn, contains("English: 0 session(s), not practised yet"));
    });

    test("the tutor is told to plan with it, not to recite it", () {
      final turn = buildSystemTurn(ctxWith(const []));
      expect(turn, contains("KNOWING HER"));
      expect(turn, contains("never read the list out"));
      expect(turn, contains("NEVER tell her she is bad at a subject"));
    });

    test("a brand new child gets no such heading at all", () {
      expect(buildSystemTurn(ctxWith(const [])), isNot(contains("HOW SHE IS DOING (last 3 weeks")));
    });
  });
}

// ------------------------------------------------- what she finds hard
void skillNoteTests() {
  group("the tutor's notes on what she finds hard", () {
    test("a weakness is read with its subject, skill and what she does", () {
      final lines = readTutorLines(
        "Good try! Look at the tens column again.\n"
        "WEAK: Maths | regrouping in subtraction | drops the carried ten",
      );

      expect(lines.weak, hasLength(1));
      expect(lines.weak.single.subject, "Maths");
      expect(lines.weak.single.skill, "regrouping in subtraction");
      expect(lines.weak.single.note, "drops the carried ten");
    });

    test("the note is optional", () {
      final lines = readTutorLines("WEAK: English | silent letters");
      expect(lines.weak.single.skill, "silent letters");
      expect(lines.weak.single.note, "");
    });

    test("a cracked skill is read too", () {
      final lines = readTutorLines("FIXED: Maths | regrouping in subtraction");
      expect(lines.fixed, hasLength(1));
      expect(lines.fixed.single.subject, "Maths");
      expect(lines.fixed.single.skill, "regrouping in subtraction");
    });

    test("none of it is ever shown to the child", () {
      final lines = readTutorLines(
        "That's it exactly — you carried the ten this time. 🌟\n"
        "WEAK: Maths | regrouping in subtraction | drops the carried ten\n"
        "FIXED: English | capital letters\n"
        "BADGE: Careful carrier",
      );

      expect(lines.visible, "That's it exactly — you carried the ten this time. 🌟");
      expect(lines.visible, isNot(contains("WEAK")));
      expect(lines.visible, isNot(contains("FIXED")));
    });

    test("a half-written line is ignored rather than saved as nonsense", () {
      expect(readTutorLines("WEAK: Maths").weak, isEmpty);
      expect(readTutorLines("WEAK: | something").weak, isEmpty);
      expect(readTutorLines("FIXED: Maths").fixed, isEmpty);
    });

    test("several notes in one reply all come through", () {
      final lines = readTutorLines(
        "WEAK: Maths | place value | reads 405 as 45\n"
        "WEAK: Tamil | உயிர்மெய் letters | mixes ஔ and ஒள",
      );
      expect(lines.weak, hasLength(2));
      expect(lines.weak.last.subject, "Tamil");
    });
  });

  group("what the tutor is told about its own notes", () {
    DayContext withSkills(
      List<({String subject, String skill, String note, int seen, bool open, String lastSeen})> skills,
    ) =>
        DayContext(
          studentName: "Meera Nair",
          subjects: const ["Maths"],
          gradeDescription: "Class 4 (CBSE, India)",
          academicYear: "2026–27 — second term",
          approxAge: 9,
          languages: const StudentLanguages(first: "English"),
          prettyDate: "Friday, 25 September",
          explainLang: "first",
          dayType: "school",
          tasks: const [],
          practice: const [],
          morning: const [],
          lessons: const [],
          badges: const [],
          lock: "",
          skills: skills,
        );

    test("open notes reach the tutor with how often they have come up", () {
      final turn = withSkills([
        (subject: "Maths", skill: "regrouping in subtraction",
         note: "drops the carried ten", seen: 3, open: true, lastSeen: "2026-09-24"),
      ]);
      final text = buildSystemTurn(turn);

      expect(text, contains("YOUR NOTES ON WHAT SHE FINDS HARD"));
      expect(text, contains("regrouping in subtraction"));
      expect(text, contains("seen 3×"));
    });

    test("a cracked one is flagged as cracked, not as a weakness", () {
      final text = buildSystemTurn(withSkills([
        (subject: "English", skill: "capital letters", note: "", seen: 4,
         open: false, lastSeen: "2026-09-20"),
      ]));
      expect(text, contains("CRACKED: English: capital letters"));
    });

    test("the rules say how to write one, and forbid writing about the child", () {
      final text = buildSystemTurn(withSkills(const []));
      expect(text, contains("WEAK: <subject>"));
      expect(text, contains("about the WORK, never about her"));
      expect(text, contains("Never read the list to her"));
    });

    test("a child with no notes gets no heading", () {
      expect(buildSystemTurn(withSkills(const [])),
          isNot(contains("YOUR NOTES ON WHAT SHE FINDS HARD")));
    });
  });
}

// ------------------------------------------------------------- the board
void boardTests() {
  group("teaching to the school's own board", () {
    test("the board is described the way a school would write it", () {
      expect(describeBoard("IN", "cbse"), contains("CBSE"));
      expect(describeBoard("IN", "cbse"), contains("India"));
      expect(describeBoard("IN", "icse"), contains("CISCE"));
    });

    test("a board with a note passes the note along", () {
      final ib = describeBoard("XX", "ib");
      expect(ib.isNotEmpty, isTrue);
    });

    test("an unknown board degrades to its id rather than throwing", () {
      expect(describeBoard("IN", "no-such-board"), isNotEmpty);
    });

    test("the tutor is told to follow that board, and to ask when unsure", () {
      final turn = buildSystemTurn(DayContext(
        studentName: "Meera Nair",
        subjects: const ["Maths"],
        gradeDescription: "Class 4 (CBSE, India)",
        board: "CBSE, India",
        academicYear: "2026–27 — second term",
        approxAge: 9,
        languages: const StudentLanguages(first: "English"),
        prettyDate: "Friday, 25 September",
        explainLang: "first",
        dayType: "school",
        tasks: const [],
        practice: const [],
        morning: const [],
        lessons: const [],
        badges: const [],
        lock: "",
      ));

      expect(turn, contains("BOARD: CBSE, India"));
      expect(turn, contains("its sequence"));
      expect(turn, contains("ask for a photo of the textbook page"));
      expect(turn, contains("OUTRANKS anything you remember about the board"));
    });
  });
}

// -------------------------------------------- reading and learn-by-heart
void readingTests() {
  group("homework done with the voice, not the pen", () {
    test("reading and learning are spoken homework", () {
      expect(isReadingTask("Read lesson 4"), isTrue);
      expect(isReadingTask("Read Ln 6 and prepare well"), isTrue);
      expect(isReadingTask("Learn the poem"), isTrue);
      expect(isReadingTask("Tables of 7"), isTrue);
      expect(isReadingTask("Spellings page 12"), isTrue);
      expect(isReadingTask("Recitation practice"), isTrue);
      expect(isReadingTask("Learn by heart Q1-3"), isTrue);
    });

    test("anything with a pen in it is written homework", () {
      expect(isReadingTask("Write the answers for Ln 6"), isFalse);
      expect(isReadingTask("Exercise 5.2 Q1-5"), isFalse);
      expect(isReadingTask("Workbook page 34"), isFalse);
      expect(isReadingTask("Maths sums 1 to 10"), isFalse);
    });

    test("read AND write is written homework — the pen wins", () {
      expect(isReadingTask("Read lesson 4 and write the new words"), isFalse,
          reason: "there is a notebook to photograph");
    });

    test("the tutor is told how to check reading, and never to ask for a photo", () {
      final turn = buildSystemTurn(DayContext(
        studentName: "Meera Nair",
        subjects: const ["English"],
        gradeDescription: "Class 4 (CBSE, India)",
        academicYear: "2026–27 — second term",
        approxAge: 9,
        languages: const StudentLanguages(first: "English"),
        prettyDate: "Friday, 25 September",
        explainLang: "first",
        dayType: "school",
        tasks: const [(subject: "English", task: "Read lesson 4", done: false, mode: "read")],
        practice: const [],
        morning: const [],
        lessons: const [],
        badges: const [],
        lock: "",
      ));

      expect(turn, contains("READING AND LEARN-BY-HEART HOMEWORK"));
      expect(turn, contains("NEVER ask for one"));
      expect(turn, contains("Here is my reading"));
      expect(turn, contains("an accent is not a mistake"));
      expect(turn, contains("Do not mark it done because she says she read it"));
    });
  });
}

// ------------------------------------------------- the homework list itself
void homeworkListTests() {
  Task job(String subject, String task, {bool done = false}) =>
      Task(id: "$subject-$task", subject: subject, task: task, done: done);

  group("grouping the day's homework", () {
    test("two tasks in one subject are one heading, not two", () {
      final groups = tasksBySubject([
        job("Social", "Learn Q&A (1 to 3) Ls-5"),
        job("Social", "Learn Q5A (Q+3) Ls-5"),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.subject, "Social");
      expect(groups.single.tasks, hasLength(2));
    });

    test("subjects keep the order the diary listed them in", () {
      final groups = tasksBySubject([
        job("Maths", "Ls-5"),
        job("Social", "Q&A"),
        job("Maths", "Tables"),
        job("English", "Read Ln 4"),
      ]);

      expect(groups.map((g) => g.subject), ["Maths", "Social", "English"]);
      expect(groups.first.tasks, hasLength(2), reason: "both Maths tasks together");
    });

    test("a blank subject is shown as Other rather than an empty chip", () {
      final groups = tasksBySubject([job("", "Vivid facts"), job("   ", "Bring water bottle")]);
      expect(groups.single.subject, "Other");
      expect(groups.single.tasks, hasLength(2));
    });

    test("nothing in, nothing out", () {
      expect(tasksBySubject(const []), isEmpty);
    });
  });

  group("reading a school's shorthand", () {
    test("the diary reader is told how the abbreviations map", () {
      final p = diaryPrompt("2026-09-25", "Class 4 (CBSE, India)",
          const ["Maths", "English", "Tamil", "Social", "Science"]);

      expect(p, contains("Soc / S.St / SST"));
      expect(p, contains("a row under \"Math (Practice)\" is Maths"));
      expect(p, contains("Guessing the closest subject from her list is better than \"Other\""));
    });
  });
}

// ------------------------------------------ reading the same page twice
void duplicateTaskTests() {
  group("the same homework line, read twice", () {
    test("punctuation and spacing don't make it a different task", () {
      expect(sameTask("Learn Q&A (1 to 3) Ls-5", "Learn Q&A(1to3) Ls-5"), isTrue);
      expect(sameTask("Ls-5 prepare well", "Ls 5 prepare well."), isTrue);
      expect(sameTask("Read Ln 6", "read ln6"), isTrue);
    });

    test("genuinely different homework stays different", () {
      expect(sameTask("Learn Q&A Ls-5", "Learn Q&A Ls-6"), isFalse);
      expect(sameTask("Read lesson 4", "Read lesson 5"), isFalse);
      expect(sameTask("Maths sums 1-10", "Maths sums 11-20"), isFalse);
    });

    test("an empty line matches nothing, not everything", () {
      expect(sameTask("", ""), isFalse);
      expect(sameTask("", "Read lesson 4"), isFalse);
      expect(sameTask("...", "Read lesson 4"), isFalse);
    });

    test("the key keeps only what the words are made of", () {
      expect(taskKey("Learn Q&A (1 to 3) Ls-5"), "learnqa1to3ls5");
      expect(taskKey("  READ   ln 6!  "), "readln6");
    });
  });
}

// ------------------------------------------- oral homework vs written work
void taskModeTests() {
  group("how the school wants it done", () {
    test("the diary's own row label decides", () {
      expect(taskMode("Learn Q&A (1 to 3) Ls-5", mode: "oral"), "say");
      expect(taskMode("Exercise 5.2", mode: "written"), "show");
      expect(taskMode("Read lesson 4", mode: "read"), "say");
    });

    test("the row label beats the words in the line", () {
      // "Write" in an oral row: the teacher still asks her.
      expect(taskMode("Write and learn Q1-3", mode: "oral"), "say");
      // "Learn" in a written row: there is a notebook to hand in.
      expect(taskMode("Learn and write the answers", mode: "written"), "show");
    });

    test("with no label it falls back to reading the words", () {
      expect(taskMode("Read lesson 4"), "say");
      expect(taskMode("Exercise 5.2 Q1-5"), "show");
      expect(taskMode("Learn the poem"), "say");
    });

    test("prepare-for-a-test follows the words", () {
      expect(taskMode("Ls-5 prepare well for Chapter Check", mode: "practice"), "show");
      expect(taskMode("Learn tables of 7", mode: "practice"), "say");
    });
  });

  group("what the tutor is told to do with oral homework", () {
    test("the method is understanding first, keywords, then being asked", () {
      final turn = buildSystemTurn(DayContext(
        studentName: "Meera Nair",
        subjects: const ["Social"],
        gradeDescription: "Class 4 (CBSE, India)",
        academicYear: "2026–27 — second term",
        approxAge: 9,
        languages: const StudentLanguages(first: "English"),
        prettyDate: "Friday, 25 September",
        explainLang: "first",
        dayType: "school",
        tasks: const [
          (subject: "Social", task: "Learn Q&A (1 to 3) Ls-5", done: false, mode: "oral"),
        ],
        practice: const [],
        morning: const [],
        lessons: const [],
        badges: const [],
        lock: "",
      ));

      expect(turn, contains("LEARN-THE-ANSWERS HOMEWORK"));
      expect(turn, contains("Understanding first, memory second"));
      expect(turn, contains("KEYWORDS, NOT SENTENCES"));
      expect(turn, contains("Word-perfect is not the goal"));
      expect(turn, contains("Never invent answers for her book's questions"));
      expect(turn, contains("Do not turn oral homework into written work"));
      expect(turn, contains("(the school wrote this on the ORAL row)"));
    });

    test("the diary reader is asked for the row it came from", () {
      final p = diaryPrompt("2026-09-25", "Class 4 (CBSE, India)", const ["Social"]);
      expect(p, contains('"mode"'));
      expect(p, contains("The teacher will ASK her tomorrow"));
    });
  });
}

// -------------------------------------------- a nine-year-old on her own
void independenceTests() {
  group("what she is told when something goes wrong", () {
    test("nothing blames her, and her work is never described as lost", () {
      for (final code in [
        "not_signed_in", "subscription_required", "rate_limited", "bad_api_key",
        "offline", "server_not_configured", "function_not_deployed", "anything_else",
      ]) {
        final msg = friendlyError(code);
        expect(msg, isNot(contains("Error")), reason: code);
        expect(msg.toLowerCase(), isNot(contains("failed")), reason: code);
        expect(msg.length, greaterThan(20), reason: "$code says too little");
      }
    });

    test("a grown-up is named only where one is truly needed", () {
      // Things she can act on herself.
      expect(friendlyError("offline").toLowerCase(), isNot(contains("grown-up")));
      expect(friendlyError("rate_limited").toLowerCase(), isNot(contains("grown-up")));
      expect(friendlyError("invalid_json").toLowerCase(), isNot(contains("grown-up")));

      // Things she genuinely cannot fix at nine.
      expect(friendlyError("bad_api_key").toLowerCase(), contains("grown-up"));
      expect(friendlyError("server_not_configured").toLowerCase(), contains("grown-up"));
    });

    test("a day's limit is framed as a full day's work, not a punishment", () {
      final msg = friendlyError("daily_limit", limit: 40);
      expect(msg, contains("40"));
      expect(msg.toLowerCase(), contains("tomorrow"));
    });
  });

  group("the tutor knows she is alone", () {
    test("it must not send her off to find an adult over schoolwork", () {
      final turn = buildSystemTurn(DayContext(
        studentName: "Meera Nair",
        subjects: const ["Maths"],
        gradeDescription: "Class 4 (CBSE, India)",
        academicYear: "2026–27 — second term",
        approxAge: 9,
        languages: const StudentLanguages(first: "English"),
        prettyDate: "Friday, 25 September",
        explainLang: "first",
        dayType: "school",
        tasks: const [],
        practice: const [],
        morning: const [],
        lessons: const [],
        badges: const [],
        lock: "",
      ));

      expect(turn, contains("SHE IS ON HER OWN"));
      expect(turn, contains("NEVER send her to fetch a grown-up for ordinary study trouble"));
      expect(turn, contains("at most 3 or 4 short lines"));
      expect(turn, contains("she does not have"));
      expect(turn, contains("it is fine to stop and come back"));
      expect(turn, contains("her mother said you could give the answer"));
    });
  });
}

// ------------------------------------------------- midnight, where she is
void dayRolloverTests() {
  Student child({String timezone = "Asia/Kolkata"}) => Student(
        id: "child-1", name: "Meera Nair", country: "IN", boardId: "cbse",
        board: "CBSE", grade: "Class 4", timezone: timezone, ayStartMonth: 4,
        languages: const StudentLanguages(first: "English"),
      );

  group("the app left open overnight", () {
    test("a day loaded yesterday is noticed as stale", () {
      final state = AppState()..student = child();
      state.loadedDate = shiftDate(state.date, -1);
      expect(state.dayHasRolledOver, isTrue);
    });

    test("a day loaded today is left alone", () {
      final state = AppState()..student = child();
      state.loadedDate = state.date;
      expect(state.dayHasRolledOver, isFalse);
    });

    test("nothing loaded yet is not a rollover", () {
      final state = AppState()..student = child();
      expect(state.loadedDate, "");
      expect(state.dayHasRolledOver, isFalse, reason: "the first load isn't a rollover");
    });

    test("the day that counts is hers, not the server's", () {
      // 23:00 UTC on the 24th: still the 24th in London, already the 25th in India.
      final when = DateTime.utc(2026, 9, 24, 23, 0);
      expect(todayId("Asia/Kolkata", now: when), "2026-09-25");
      expect(todayId("Europe/London", now: when), "2026-09-24");
      expect(todayId("America/New_York", now: when), "2026-09-24");
    });

    test("a wrongly stored timezone is what makes a day look stuck", () {
      // The same instant, read with the wrong zone, gives the wrong date —
      // which is exactly what "it still shows yesterday" looks like.
      final when = DateTime.utc(2026, 9, 25, 1, 0);   // 06:30 in India
      expect(todayId("Asia/Kolkata", now: when), "2026-09-25");
      expect(todayId("UTC", now: when), "2026-09-25");

      final evening = DateTime.utc(2026, 9, 24, 19, 0);  // 00:30 on the 25th in India
      expect(todayId("Asia/Kolkata", now: evening), "2026-09-25");
      expect(todayId("UTC", now: evening), "2026-09-24", reason: "a day behind");
    });
  });
}
