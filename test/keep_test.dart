// How long a lesson is taught from. A page borrowed for one afternoon and her
// own textbook chapter should not have the same shelf life, and the date maths
// has to hold across a school year that does not start in January.
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/models.dart";
import "package:study_desk/rules.dart";

Lesson lesson(String keep, String savedOn, {String name = "Lesson 4", String text = "body"}) =>
    Lesson(ref: "r1", subject: "Social", name: name, text: text,
        pages: const [], keep: keep, savedOn: savedOn);

void main() {
  group("when the school year began", () {
    test("an April year, seen from either side of April", () {
      expect(academicYearStart(4, "2026-09-29"), "2026-04-01");
      expect(academicYearStart(4, "2027-02-14"), "2026-04-01", reason: "February is still 2026–27");
      expect(academicYearStart(4, "2026-04-01"), "2026-04-01", reason: "the first day itself");
      expect(academicYearStart(4, "2026-03-31"), "2025-04-01", reason: "the day before is last year");
    });

    test("a September year and a January year", () {
      expect(academicYearStart(9, "2026-09-29"), "2026-09-01");
      expect(academicYearStart(9, "2026-08-31"), "2025-09-01");
      expect(academicYearStart(1, "2026-09-29"), "2026-01-01");
    });
  });

  group("the day a lesson runs out", () {
    test("just today means today", () {
      expect(keepUntil("day", "2026-09-29", 4), "2026-09-29");
    });

    test("all year runs to the day before the next year starts", () {
      expect(keepUntil("year", "2026-09-29", 4), "2027-03-31");
      expect(keepUntil("year", "2027-02-14", 4), "2027-03-31", reason: "same year, same end");
      expect(keepUntil("year", "2026-09-29", 9), "2027-08-31", reason: "a September school");
    });

    test("a term is half a year, and which half depends on when it was saved", () {
      // April start: first term April–September, second October–March.
      expect(keepUntil("term", "2026-05-10", 4), "2026-09-30", reason: "saved in the first term");
      expect(keepUntil("term", "2026-11-10", 4), "2027-03-31", reason: "saved in the second");
      expect(keepUntil("term", "2026-09-30", 4), "2026-09-30", reason: "the last day of term 1");
      expect(keepUntil("term", "2026-10-01", 4), "2027-03-31", reason: "the first day of term 2");
    });

    test("an unknown choice is kept, never quietly thrown away", () {
      expect(keepUntil("forever", "2026-09-29", 4), "");
      expect(keepUntil("", "2026-09-29", 4), "");
    });

    test("a lesson with no saved date is kept", () {
      // Every lesson saved before this feature existed. They must not vanish.
      expect(keepUntil("year", "", 4), "");
      expect(lessonIsCurrent(lesson("year", ""), today: "2030-01-01", ayStartMonth: 4), isTrue);
    });

    test("a nonsense date is kept rather than crashing", () {
      expect(keepUntil("year", "not-a-date", 4), "");
    });
  });

  group("is it still taught from", () {
    test("today's page is current today and gone tomorrow", () {
      final l = lesson("day", "2026-09-29");
      expect(lessonIsCurrent(l, today: "2026-09-29", ayStartMonth: 4), isTrue);
      expect(lessonIsCurrent(l, today: "2026-09-30", ayStartMonth: 4), isFalse);
    });

    test("a term lesson survives the term and not the one after", () {
      final l = lesson("term", "2026-05-10");
      expect(lessonIsCurrent(l, today: "2026-09-30", ayStartMonth: 4), isTrue);
      expect(lessonIsCurrent(l, today: "2026-10-01", ayStartMonth: 4), isFalse);
    });

    test("a year lesson lasts the year", () {
      final l = lesson("year", "2026-06-01");
      expect(lessonIsCurrent(l, today: "2027-03-31", ayStartMonth: 4), isTrue);
      expect(lessonIsCurrent(l, today: "2027-04-01", ayStartMonth: 4), isFalse);
    });
  });

  group("what the tutor is handed", () {
    Plan plan() => Plan(
          studentId: "x", subjects: const ["Social"],
          timetable: spreadTimetable(const ["Social"]),
          morningOn: false, morning: emptyWeek(), weekOff: const ["Sun"],
          chapters: const {}, exams: <Exam>[], comps: <Comp>[], offDays: <OffDay>[],
        );

    test("a lesson that has been put away is not taught from", () {
      final all = [
        lesson("day", "2026-09-28", name: "Yesterday's worksheet"),
        lesson("year", "2026-09-28", name: "Lesson 4"),
      ];
      final out = lessonsForTurn(all, plan(), today: "2026-09-29", ayStartMonth: 4);
      expect(out.length, 1);
      expect(out.first.name, "Lesson 4");
    });

    test("with no date given, nothing is filtered — old callers still work", () {
      final all = [lesson("day", "2020-01-01", name: "Ancient")];
      expect(lessonsForTurn(all, plan()).length, 1);
    });
  });

  group("what a parent reads on screen", () {
    test("the label names the day it runs out", () {
      expect(keepLabel(lesson("year", "2026-09-29"), 4), "Kept until 2027-03-31");
      expect(keepLabel(lesson("day", "2026-09-29"), 4), "Kept until 2026-09-29");
    });

    test("a lesson with no end says so plainly", () {
      expect(keepLabel(lesson("year", ""), 4), "Kept until you put it away");
    });

    test("the kept-until-the-next-book label makes no promise about dates", () {
      final label = keepLabel(lesson("book", "2026-09-29"), 4);
      expect(label, "Kept until you start a new book");
      expect(label.contains("2027"), isFalse, reason: "no date anyone has to trust");
    });

    test("every choice has an icon, a name and an explanation", () {
      expect(kKeepChoices.keys.toSet(), {"day", "book"},
          reason: "no calendar guessing — nobody knows when term ends");
      for (final e in kKeepChoices.entries) {
        expect(e.value.$1.isNotEmpty, isTrue);
        expect(e.value.$2.isNotEmpty, isTrue);
        expect(e.value.$3.isNotEmpty, isTrue);
      }
    });
  });

  group("what is stored", () {
    test("a lesson saved before this feature defaults to the year", () {
      final old = Lesson.fromJson({"ref": "r", "subject": "Social", "name": "L4", "text": "t"});
      expect(old.keep, "year");
      expect(old.savedOn, "");
    });

    test("a timestamp from the database is read as a plain day", () {
      final l = Lesson.fromJson({
        "ref": "r", "subject": "Social", "name": "L4", "text": "t",
        "keep": "term", "saved_on": "2026-09-29T00:00:00+00:00",
      });
      expect(l.keep, "term");
      expect(l.savedOn, "2026-09-29");
    });
  });

  group("starting a new book", () {
    test("a lesson kept until the next book never expires on its own", () {
      final l = lesson("book", "2026-04-02");
      expect(lessonIsCurrent(l, today: "2029-01-01", ayStartMonth: 4), isTrue,
          reason: "three years on, still hers until someone says otherwise");
    });

    test("once put away it is out, whatever the date says", () {
      final l = lesson(kArchived, "2026-09-29");
      expect(lessonIsCurrent(l, today: "2026-09-29", ayStartMonth: 4), isFalse,
          reason: "even on the day it was saved");
      expect(keepLabel(l, 4), "Put away — from an older book");
    });

    test("bringing it back is the same one field, nothing rebuilt", () {
      final away = lesson(kArchived, "2026-09-29");
      final back = Lesson(
        ref: away.ref, subject: away.subject, name: away.name,
        text: away.text, pages: away.pages, keep: "book", savedOn: away.savedOn,
      );
      expect(lessonIsCurrent(back, today: "2027-06-01", ayStartMonth: 4), isTrue);
      expect(back.text, away.text, reason: "her pages are untouched");
    });

    test("the clear-out list offers this subject's live lessons, oldest first", () {
      final all = [
        lesson("book", "2026-07-01", name: "Lesson 6"),
        lesson("book", "2026-04-10", name: "Lesson 1"),
        lesson(kArchived, "2026-04-01", name: "Last year's Lesson 9"),
      ];
      final out = lessonsToClear(all, "Social");
      expect(out.map((l) => l.name).toList(), ["Lesson 1", "Lesson 6"]);
    });

    test("another subject's book is never swept up with this one", () {
      final all = [
        lesson("book", "2026-04-10", name: "Social 1"),
        Lesson(ref: "m1", subject: "Maths", name: "Maths 1", text: "t",
            pages: const [], keep: "book", savedOn: "2026-04-10"),
      ];
      expect(lessonsToClear(all, "Social").map((l) => l.name).toList(), ["Social 1"]);
    });

    test("an empty lesson is not offered — there is nothing to put away", () {
      final all = [lesson("book", "2026-04-10", name: "Blank", text: "  ")];
      expect(lessonsToClear(all, "Social"), isEmpty);
    });

    test("a put-away lesson is not handed to the tutor", () {
      final all = [
        lesson(kArchived, "2026-04-10", name: "Old book"),
        lesson("book", "2026-09-01", name: "New book"),
      ];
      final plan = Plan(
        studentId: "x", subjects: const ["Social"],
        timetable: spreadTimetable(const ["Social"]),
        morningOn: false, morning: emptyWeek(), weekOff: const ["Sun"],
        chapters: const {}, exams: <Exam>[], comps: <Comp>[], offDays: <OffDay>[],
      );
      final out = lessonsForTurn(all, plan, today: "2026-09-29", ayStartMonth: 4);
      expect(out.map((l) => l.name).toList(), ["New book"]);
    });
  });
}
