// Reading a whole chapter, not the first five pages of one.
//
// Two faults sat together here. Only five pages were ever read, silently. And
// the same lesson photographed twice came back under a slightly different
// name each time, so exact matching made three chapters out of one book and
// split her pages between them — which is what 23 pages turning into "2 pages
// read" and three chapters actually was.
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/models.dart";
import "package:study_desk/rules.dart";

void main() {
  group("the same lesson, written differently", () {
    test("the three names one chapter actually came back as", () {
      const a = "The Northern Plains and Islands";
      const b = "The Northern Plains, Islands of India, and Himalayan Range";
      const c = "Lesson on Northern Plains and Islands of India";

      expect(sameLesson(a, b), isTrue);
      expect(sameLesson(b, c), isTrue);
      expect(sameLesson(a, c), isTrue);
      expect(sameLesson(c, a), isTrue, reason: "order must not matter");
    });

    test("noise words carry no weight", () {
      expect(lessonWords("Lesson 4 — The Water Cycle"), {"4", "water", "cycle"});
      expect(lessonWords("Chapter: our class notes"), isEmpty);
    });

    test("different lessons stay different", () {
      expect(sameLesson("The Water Cycle", "The Northern Plains"), isFalse);
      expect(sameLesson("Fractions", "Multiplication"), isFalse);
      expect(sameLesson("Plants Around Us", "Animals Around Us"), isFalse);
    });

    test("a numbered chapter settles it either way", () {
      expect(sameLesson("Lesson 4 — Our Neighbourhood", "Lesson 4"), isTrue);
      expect(sameLesson("Lesson 4 — Our Neighbourhood", "Lesson 5 — Our Neighbourhood"),
          isFalse, reason: "same words, different chapter — never merge these");
      expect(sameLesson("Chapter 12: Water", "Ch. 12 Water and Us"), isTrue);
    });

    test("two words alone are too thin to merge on", () {
      // "Water" inside "Water Cycle" is not enough to call them one lesson.
      expect(sameLesson("Water", "Water Cycle"), isFalse);
    });

    test("an empty title never matches anything", () {
      expect(sameLesson("", "The Water Cycle"), isFalse);
      expect(sameLesson("The Water Cycle", ""), isFalse);
      expect(sameLesson("Lesson", "Chapter"), isFalse, reason: "all noise, no lesson");
    });

    test("it finds the existing chapter rather than making a fourth", () {
      final list = [
        Chapter(id: "1", name: "The Northern Plains and Islands", status: "learning"),
        Chapter(id: "2", name: "The Water Cycle", status: "done"),
      ];
      final match = list
          .where((c) => sameLesson(c.name, "Lesson on Northern Plains and Islands of India"))
          .toList();
      expect(match.length, 1);
      expect(match.first.id, "1");
    });
  });

  group("how many pages get read", () {
    test("the limits are generous and finite", () {
      expect(kMaxLessonPages, greaterThanOrEqualTo(20),
          reason: "a chapter runs to twenty-odd pages");
      expect(kPagesPerRead, greaterThanOrEqualTo(1));
      expect(kPagesPerRead, lessThan(kMaxLessonPages));
    });

    test("23 pages is read as batches covering every one of them", () {
      // The arithmetic the screen does: no page may be skipped.
      const total = 23;
      final covered = <int>[];
      for (var i = 0; i < total; i += kPagesPerRead) {
        final upto = (i + kPagesPerRead < total) ? i + kPagesPerRead : total;
        covered.addAll([for (var p = i; p < upto; p++) p]);
      }
      expect(covered.length, total);
      expect(covered.toSet().length, total, reason: "no page read twice");
      expect(covered.first, 0);
      expect(covered.last, total - 1, reason: "the last page must not be dropped");
    });

    test("a single page still works", () {
      const total = 1;
      final covered = <int>[];
      for (var i = 0; i < total; i += kPagesPerRead) {
        final upto = (i + kPagesPerRead < total) ? i + kPagesPerRead : total;
        covered.addAll([for (var p = i; p < upto; p++) p]);
      }
      expect(covered, [0]);
    });
  });

  group("showing what was actually read", () {
    Lesson withText(String text, {int pages = 0}) => Lesson(
          ref: "r", subject: "Social", name: "The Northern Plains",
          text: text, pages: List.filled(pages, "p"), keep: "book",
          savedOn: "2026-09-30",
        );

    test("counting words", () {
      expect(wordCount(""), 0);
      expect(wordCount("   "), 0);
      expect(wordCount("one two three"), 3);
      expect(wordCount("line one\nline two"), 4, reason: "newlines separate words too");
    });

    test("one page and twenty-three pages must not look alike", () {
      final thin = withText(List.filled(600, "word").join(" "), pages: 1);
      final full = withText(List.filled(7400, "word").join(" "), pages: 23);

      expect(lessonSize(thin), "1 page · about 600 words");
      expect(lessonSize(full), "23 pages · about 7,400 words");
      expect(lessonSize(thin) == lessonSize(full), isFalse,
          reason: "the whole point — a parent can tell at a glance");
    });

    test("a lesson whose pages failed to store still reports its words", () {
      // Storing the photo is a nicety and is allowed to fail; the
      // transcription is the thing that matters and must still be visible.
      final l = withText(List.filled(900, "word").join(" "));
      expect(lessonSize(l), "about 900 words");
    });

    test("an empty transcription says so rather than looking fine", () {
      expect(lessonSize(withText("")), "");
      expect(lessonSize(withText("", pages: 3)), "3 pages");
    });
  });

  group("putting a lesson under the right subject", () {
    Plan planWith(Map<String, List<Chapter>> chapters) => Plan(
          studentId: "x", subjects: const ["Maths", "Social"],
          timetable: spreadTimetable(const ["Maths", "Social"]),
          morningOn: false, morning: emptyWeek(), weekOff: const ["Sun"],
          chapters: chapters, exams: <Exam>[], comps: <Comp>[], offDays: <OffDay>[],
        );

    test("the chapter leaves one subject and arrives in the other", () {
      final plan = planWith({
        "Maths": [Chapter(id: "c1", name: "Andaman and Nicobar", status: "learning")],
        "Social": <Chapter>[],
      });

      expect(moveChapter(plan, "c1", "Maths", "Social"), isTrue);
      expect(plan.chapters["Maths"], isEmpty, reason: "it must not be left behind");
      expect(plan.chapters["Social"]!.single.id, "c1");
      expect(plan.chapters["Social"]!.single.name, "Andaman and Nicobar");
    });

    test("its id survives, because the transcription points at it", () {
      final plan = planWith({
        "Maths": [Chapter(id: "c1", name: "Andaman", status: "learning")],
      });
      moveChapter(plan, "c1", "Maths", "Social");
      expect(plan.chapters["Social"]!.single.id, "c1",
          reason: "lesson.ref is this id — change it and the words are orphaned");
    });

    test("arriving as the current chapter steps the old one back", () {
      final plan = planWith({
        "Maths": [Chapter(id: "c1", name: "Andaman", status: "learning")],
        "Social": [Chapter(id: "c9", name: "The Water Cycle", status: "learning")],
      });
      moveChapter(plan, "c1", "Maths", "Social");

      final social = plan.chapters["Social"]!;
      expect(social.where((c) => c.status == "learning").length, 1,
          reason: "only one chapter at a time is the one she is on");
      expect(social.firstWhere((c) => c.id == "c1").status, "learning");
      expect(social.firstWhere((c) => c.id == "c9").status, "todo");
    });

    test("a finished chapter moving does not disturb the current one", () {
      final plan = planWith({
        "Maths": [Chapter(id: "c1", name: "Andaman", status: "done")],
        "Social": [Chapter(id: "c9", name: "The Water Cycle", status: "learning")],
      });
      moveChapter(plan, "c1", "Maths", "Social");
      expect(plan.chapters["Social"]!.firstWhere((c) => c.id == "c9").status, "learning");
    });

    test("a subject with no chapters yet is created on arrival", () {
      final plan = planWith({
        "Maths": [Chapter(id: "c1", name: "Andaman", status: "learning")],
      });
      expect(moveChapter(plan, "c1", "Maths", "Social"), isTrue);
      expect(plan.chapters["Social"]!.single.id, "c1");
    });

    test("nonsense moves change nothing", () {
      final plan = planWith({
        "Maths": [Chapter(id: "c1", name: "Andaman", status: "learning")],
      });
      expect(moveChapter(plan, "c1", "Maths", "Maths"), isFalse, reason: "same subject");
      expect(moveChapter(plan, "nope", "Maths", "Social"), isFalse, reason: "no such chapter");
      expect(moveChapter(plan, "c1", "Science", "Social"), isFalse, reason: "not in Science");
      expect(plan.chapters["Maths"]!.single.id, "c1", reason: "still where it was");
    });
  });

  group("two rows for one chapter", () {
    Lesson lesson(String ref, String name, String text,
            {String subject = "Social", List<String> pages = const []}) =>
        Lesson(ref: ref, subject: subject, name: name, text: text,
            pages: pages, keep: "book", savedOn: "2026-09-30");

    test("the same pages read twice do not double the words", () {
      // This is the case that actually happened: the chapter photographed
      // under Maths and again under Social, identical both times.
      const body = "The Andaman and Nicobar Islands lie in the Bay of Bengal.";
      expect(mergeLessonText(body, body), body,
          reason: "one clean copy, not the same paragraph twice");
    });

    test("a second reading that covers more is kept in full", () {
      const first = "Page one. Page two.";
      const second = "Page one. Page two. Page three.";
      expect(mergeLessonText(first, second), second);
      expect(mergeLessonText(second, first), second, reason: "either way round");
    });

    test("genuinely different pages are joined on", () {
      expect(mergeLessonText("Pages 1 to 5.", "Pages 6 to 10."),
          "Pages 1 to 5.\n\nPages 6 to 10.");
    });

    test("an empty side contributes nothing and breaks nothing", () {
      expect(mergeLessonText("", "words"), "words");
      expect(mergeLessonText("words", ""), "words");
      expect(mergeLessonText("", ""), "");
    });

    test("a page stored twice is listed once", () {
      expect(mergePages(["a", "b"], ["b", "c"]), ["a", "b", "c"]);
      expect(mergePages(["a"], ["a"]), ["a"]);
      expect(mergePages([], ["a"]), ["a"]);
    });

    test("the twin is found — same chapter, same subject, different row", () {
      final mine = lesson("r1", "Andaman and Nicobar Islands and Lakshadweep", "one");
      final all = [
        mine,
        lesson("r2", "Lesson on Andaman and Nicobar Islands, Lakshadweep", "two"),
        lesson("r3", "The Water Cycle", "three"),
      ];
      expect(twinOf(mine, all)?.ref, "r2");
    });

    test("itself is never its own twin", () {
      final mine = lesson("r1", "Andaman and Nicobar", "one");
      expect(twinOf(mine, [mine]), isNull);
    });

    test("a copy in another subject is not offered here", () {
      final mine = lesson("r1", "Andaman and Nicobar", "one");
      final other = lesson("r2", "Andaman and Nicobar", "two", subject: "Maths");
      expect(twinOf(mine, [mine, other]), isNull, reason: "different subject");
      expect(twinOf(mine, [mine, other], inSubject: "Maths")?.ref, "r2",
          reason: "but it IS the one to join when moving there");
    });

    test("a lesson put away is not dragged back in", () {
      final mine = lesson("r1", "Andaman and Nicobar", "one");
      final away = Lesson(ref: "r2", subject: "Social", name: "Andaman and Nicobar",
          text: "two", pages: const [], keep: kArchived, savedOn: "2026-09-01");
      expect(twinOf(mine, [mine, away]), isNull);
    });

    test("a different chapter is never treated as a duplicate", () {
      final mine = lesson("r1", "The Water Cycle", "one");
      final other = lesson("r2", "The Northern Plains", "two");
      expect(twinOf(mine, [mine, other]), isNull);
    });
  });

  group("taking a chapter out of the plan", () {
    test("it goes, and only it", () {
      final plan = Plan(
        studentId: "x", subjects: const ["Social"],
        timetable: spreadTimetable(const ["Social"]),
        morningOn: false, morning: emptyWeek(), weekOff: const ["Sun"],
        chapters: {
          "Social": [
            Chapter(id: "c1", name: "Andaman", status: "learning"),
            Chapter(id: "c2", name: "Water Cycle", status: "todo"),
          ],
        },
        exams: <Exam>[], comps: <Comp>[], offDays: <OffDay>[],
      );
      expect(removeChapter(plan, "c1", "Social"), isTrue);
      expect(plan.chapters["Social"]!.single.id, "c2");
      expect(removeChapter(plan, "c1", "Social"), isFalse, reason: "already gone");
      expect(removeChapter(plan, "c2", "Maths"), isFalse, reason: "wrong subject");
    });
  });
}
