// What the tutor knows on the night before a paper.
//
// A parent types the portions into Parent → Exams and reasonably assumes the
// tutor revises those. It did not: a "Test: Social" row carried only whichever
// chapter she happened to be on, so on the one night when precision matters
// most, the revision was general.
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/models.dart";
import "package:study_desk/prompt.dart";
import "package:study_desk/rules.dart";

Plan planWith(List<Exam> exams) => Plan(
      studentId: "x", subjects: const ["Social", "Maths"],
      timetable: spreadTimetable(const ["Social", "Maths"]),
      morningOn: false, morning: emptyWeek(), weekOff: const ["Sun"],
      chapters: const {}, exams: exams, comps: <Comp>[], offDays: <OffDay>[],
    );

Exam exam(String subject, String date, {String what = ""}) =>
    Exam(id: "e1", subject: subject, what: what, date: date);

void main() {
  subjectSwitchRules();

  group("what the tutor is told about the paper", () {
    test("tomorrow's paper says TOMORROW, and names the portions", () {
      final plan = planWith([exam("Social", "2026-10-01", what: "Lessons 4, 5 and 6")]);
      final out = testDetail(plan, "Social", "2026-09-30");

      expect(out, contains("TOMORROW"));
      expect(out, contains("Lessons 4, 5 and 6"));
      expect(out, contains("2026-10-01"));
    });

    test("today's paper says TODAY", () {
      final plan = planWith([exam("Social", "2026-09-30", what: "Lesson 4")]);
      expect(testDetail(plan, "Social", "2026-09-30"), contains("TODAY"));
    });

    test("a paper further off counts the days", () {
      final plan = planWith([exam("Maths", "2026-10-04", what: "Tables to 12")]);
      expect(testDetail(plan, "Maths", "2026-09-30"), contains("in 4 days"));
    });

    test("no portions given tells the tutor to ask her", () {
      final plan = planWith([exam("Social", "2026-10-01")]);
      final out = testDetail(plan, "Social", "2026-09-30");
      expect(out, contains("TOMORROW"));
      expect(out, contains("ask her what the test covers"),
          reason: "better than revising the wrong chapter in silence");
    });

    test("the soonest paper wins when a subject has two", () {
      final plan = planWith([
        exam("Social", "2026-10-09", what: "The whole book"),
        exam("Social", "2026-10-01", what: "Lessons 4 and 5"),
      ]);
      expect(testDetail(plan, "Social", "2026-09-30"), contains("Lessons 4 and 5"));
    });

    test("another subject's paper is never described here", () {
      final plan = planWith([exam("Maths", "2026-10-01", what: "Tables")]);
      expect(testDetail(plan, "Social", "2026-09-30"), "");
    });

    test("a paper already sat is not revised for", () {
      final plan = planWith([exam("Social", "2026-09-28", what: "Lesson 3")]);
      expect(testDetail(plan, "Social", "2026-09-30"), "");
    });

    test("a subject written in another case still matches", () {
      final plan = planWith([exam("social", "2026-10-01", what: "Lesson 4")]);
      expect(testDetail(plan, "Social", "2026-09-30"), contains("Lesson 4"));
    });

    test("no exams at all says nothing rather than guessing", () {
      expect(testDetail(planWith([]), "Social", "2026-09-30"), "");
    });
  });
}

// The rules that stop one topic bleeding into the next. A child types
// "test:math" and gets a Social answer about islands, because the tutor was
// mid-explanation and two words did not read like a new subject to it.
void subjectSwitchRules() {
  group("changing the subject", () {
    final turn = buildSystemTurn(DayContext(
      studentName: "Meera Nair",
      subjects: const ["Maths", "Social"],
      gradeDescription: "Class 4 (CBSE, India)",
      academicYear: "2026–27 — second term",
      approxAge: 9,
      languages: const StudentLanguages(first: "English"),
      prettyDate: "Wednesday, 30 September",
      explainLang: "first",
      dayType: "school",
      tasks: const [], practice: const [], morning: const [],
      lessons: const [], badges: const [], lock: "",
    ));

    test("shorthand is named outright, punctuation and all", () {
      expect(turn, contains('"test: math"'),
          reason: "the exact thing she typed must be recognised");
      expect(turn, contains("quiz me science"));
      expect(turn, contains("maths now"));
    });

    test("the old topic must be dropped, not blended in", () {
      expect(turn.toLowerCase(), contains("drop the previous topic"));
      expect(turn.toLowerCase(), contains("never carry its examples"));
    });

    test("an unclear subject is asked about, never guessed", () {
      expect(turn.toLowerCase(), contains("do not guess"));
    });
  });

  group("a whole paper, when she asks for one", () {
    final turn = buildSystemTurn(DayContext(
      studentName: "Meera Nair",
      subjects: const ["Maths"],
      gradeDescription: "Class 4 (CBSE, India)",
      academicYear: "2026–27 — second term",
      approxAge: 9,
      languages: const StudentLanguages(first: "English"),
      prettyDate: "Wednesday, 30 September",
      explainLang: "first",
      dayType: "school",
      tasks: const [], practice: const [], morning: const [],
      lessons: const [], badges: const [], lock: "",
    ));

    test("one-at-a-time is explicitly not a reason to refuse a paper", () {
      // The tutor told a parent "that's not how I work with Meera" and
      // refused. Practice and a mock test are different things.
      expect(turn.toLowerCase(), contains("wrong for a mock test"));
      expect(turn.toLowerCase(), contains("not a good enough reason"));
    });

    test("the whole paper comes at once, laid out like her school's", () {
      expect(turn.toLowerCase(), contains("whole paper at once"));
      expect(turn.toLowerCase(), contains("marks beside each question"));
    });

    test("no hints and no answers inside the paper itself", () {
      expect(turn.toLowerCase(), contains("no hints"));
      expect(turn.toLowerCase(), contains("a paper with hints in it is not a paper"));
    });

    test("she writes it, photographs it, and it is marked honestly", () {
      expect(turn.toLowerCase(), contains("send a photo of every"));
      expect(turn.toLowerCase(), contains("the true score"));
    });

    test("the answers are still not handed over on request", () {
      expect(turn.toLowerCase(), contains("asks for the answers before she has written it"));
    });
  });
}
