// Coaching a competition: which stage the days left put her in, how each kind
// of competition is coached, and that the tutor is actually told about it.
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/models.dart";
import "package:study_desk/prompt.dart";
import "package:study_desk/rules.dart";

DayContext contextWith(
  List<({String name, String type, String language, String date, int daysLeft, String stage, String details})> comps,
) =>
    DayContext(
      studentName: "Meera Nair",
      subjects: const ["Maths", "English", "Tamil"],
      gradeDescription: "Class 4 (CBSE, India)",
      academicYear: "2026–27 — second term",
      approxAge: 9,
      languages: const StudentLanguages(first: "English", second: "Tamil"),
      prettyDate: "Thursday, 24 September",
      explainLang: "first",
      dayType: "school",
      tasks: const [],
      practice: const [],
      morning: const [],
      lessons: const [],
      badges: const [],
      lock: "",
      comps: comps,
    );

void main() {
  group("how long is left decides what she does today", () {
    test("far off means building the material", () {
      expect(compStage(10, prepDays: 14), "build");
      expect(compStage(8, prepDays: 10), "build");
    });

    test("halfway means learning it", () {
      expect(compStage(5, prepDays: 10), "learn");
      expect(compStage(4, prepDays: 10), "learn");
    });

    test("the last few days are rehearsal", () {
      expect(compStage(3, prepDays: 10), "rehearse");
      expect(compStage(2, prepDays: 10), "rehearse");
    });

    test("the day before is calm, the day itself is confidence", () {
      expect(compStage(1, prepDays: 10), "eve");
      expect(compStage(0, prepDays: 10), "today");
    });

    test("a short run-up skips straight to the sharp end", () {
      expect(compStage(2, prepDays: 3), "rehearse");
      expect(compStage(3, prepDays: 3), "rehearse");
    });

    test("every stage has something to show the child", () {
      for (final s in ["build", "learn", "rehearse", "eve", "today"]) {
        expect(kCompStages[s], isNotNull, reason: "$s has no label");
        expect(kCompStages[s]!.$2, isNotEmpty);
        expect(kCompStages[s]!.$3, isNotEmpty);
      }
    });
  });

  group("each kind of competition is coached its own way", () {
    test("anything performed out loud is spoken", () {
      expect(compKind("Speech"), "spoken");
      expect(compKind("English elocution"), "spoken");
      expect(compKind("Story telling"), "spoken");
      expect(compKind("Fancy dress"), "spoken");
    });

    test("poems are recitation, not speech", () {
      expect(compKind("Tamil recitation"), "recitation");
      expect(compKind("Thirukkural"), "recitation");
    });

    test("the rest land on their own kind", () {
      expect(compKind("Spelling bee"), "spelling");
      expect(compKind("Science Olympiad"), "quiz");
      expect(compKind("Essay writing"), "writing");
      expect(compKind("Drawing"), "art");
      expect(compKind("Singing"), "performance");
      expect(compKind("Chess"), "other");
    });
  });

  group("the tutor is told what it is coaching", () {
    test("an upcoming competition reaches the prompt with its stage", () {
      final turn = buildSystemTurn(contextWith([
        (
          name: "Class 4 English elocution",
          type: "Elocution",
          language: "English",
          date: "2026-10-01",
          daysLeft: 7,
          stage: "build",
          details: "2 minutes, topic given by school: My favourite festival",
        ),
      ]));

      expect(turn, contains("COMPETITIONS COMING UP — coach her through these"));
      expect(turn, contains("Class 4 English elocution"));
      expect(turn, contains("in 7 days"));
      expect(turn, contains("STAGE: BUILD"));
      expect(turn, contains("My favourite festival"));
    });

    test("tomorrow and today are said in words, not just numbers", () {
      final eve = buildSystemTurn(contextWith([
        (name: "Speech", type: "Speech", language: "English", date: "2026-09-25",
         daysLeft: 1, stage: "eve", details: ""),
      ]));
      expect(eve, contains("TOMORROW"));

      final now = buildSystemTurn(contextWith([
        (name: "Speech", type: "Speech", language: "English", date: "2026-09-24",
         daysLeft: 0, stage: "today", details: ""),
      ]));
      expect(now, contains("TODAY"));
    });

    test("with nothing coming up, the tutor isn't given an empty heading", () {
      // The phrase also appears in the coaching rules, so match the heading
      // the renderer writes, not the rulebook's mention of it.
      expect(buildSystemTurn(contextWith([])),
          isNot(contains("COMPETITIONS COMING UP — coach her through these")));
    });

    test("the coaching rules tell it to lead, rehearse and never dump a script", () {
      final turn = buildSystemTurn(contextWith([]));
      expect(turn, contains("COMPETITION COACHING"));
      expect(turn, contains("Here is my rehearsal"));
      expect(turn, contains("REHEARSE"));
    });
  });

  group("which competitions are close enough to work on", () {
    Plan planWithComp({required String date, int prepDays = 10}) => Plan(
          studentId: "x",
          subjects: const ["Maths"],
          timetable: spreadTimetable(const ["Maths"]),
          morningOn: false,
          morning: emptyWeek(),
          weekOff: const ["Sun"],
          chapters: <String, List<Chapter>>{},
          exams: <Exam>[],
          comps: [
            Comp(id: "1", name: "Elocution", type: "Speech", language: "English",
                 date: date, prepDays: prepDays, details: ""),
          ],
          offDays: <OffDay>[],
        );

    test("inside the run-up it appears in today's practice", () {
      final plan = planWithComp(date: "2026-10-01");
      expect(activeComps(plan, "2026-09-24"), hasLength(1));
      expect(practiceItems(plan, "2026-09-24"), contains("Competition: Elocution"));
    });

    test("too far off, it waits its turn", () {
      final plan = planWithComp(date: "2026-12-01");
      expect(activeComps(plan, "2026-09-24"), isEmpty);
    });

    test("once it is past, it is gone", () {
      final plan = planWithComp(date: "2026-09-20");
      expect(activeComps(plan, "2026-09-24"), isEmpty);
    });
  });
}
