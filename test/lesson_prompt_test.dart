// What the tutor is told when it is handed photographs of a chapter.
//
// A real 21-page scan came back with the large intestine before the stomach,
// the molars before the incisors, and two pages of the book's own "Lesson
// Structure" front matter transcribed as if they were the lesson — which also
// made the chapter's title "Lesson Structure". Nothing in the request had said
// the pages were a sequence, or that a page might not belong to the chapter.
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/prompt.dart";

void main() {
  group("the pages are a sequence, and it says so", () {
    test("the batch's own page numbers are named", () {
      final p = lessonPrompt("Science", "Class 4", from: 7, to: 8);
      expect(p, contains("page 7"));
      expect(p, contains("8"));
    });

    test("reordering is refused in words, not merely implied", () {
      final p = lessonPrompt("Science", "Class 4", from: 3, to: 4);
      expect(p, contains("ORDER:"));
      expect(p.toLowerCase(), contains("never start with a later page"));
      expect(p.toLowerCase(), contains("reads better"));
    });

    test("a single page still gets a number", () {
      final p = lessonPrompt("Maths", "Class 4", from: 12, to: 12);
      expect(p, contains("page 12"));
    });
  });

  group("pages that are not the chapter", () {
    test("front matter is named as something to skip, not transcribe", () {
      final p = lessonPrompt("Science", "Class 4", from: 1, to: 2);
      expect(p.toLowerCase(), contains("lesson structure"));
      expect(p.toLowerCase(), contains("contents page"));
      expect(p.toLowerCase(), contains("previous chapter"));
    });

    test("a batch of nothing but front matter may come back empty", () {
      expect(lessonPrompt("Science", "Class 4", from: 1, to: 2),
          contains('reply {"title": "", "text": ""}'));
    });
  });

  group("the title comes from the chapter, not from a page", () {
    test("a section name is ruled out explicitly", () {
      final p = lessonPrompt("Science", "Class 4", from: 1, to: 2);
      expect(p, contains("TITLE:"));
      expect(p.toLowerCase(), contains("opening page"));
      expect(p.toLowerCase(), contains("never the name of a section"));
    });
  });

  group("a word the camera cut off is not invented", () {
    test("the tutor is told to mark it rather than guess", () {
      final p = lessonPrompt("Science", "Class 4", from: 4, to: 5);
      expect(p, contains("[...]"));
      expect(p.toLowerCase(), contains("rather than guessing"));
    });
  });

  group("what was already right stays right", () {
    test("the subject and the child's class are still named", () {
      final p = lessonPrompt("Tamil", "Class 4", from: 1, to: 2);
      expect(p, contains("Tamil"));
      expect(p, contains("Class 4"));
    });

    test("exercise questions are kept, answers are not asked for", () {
      final p = lessonPrompt("Science", "Class 4", from: 1, to: 2);
      expect(p, contains("questions only"));
    });

    test("every language keeps its own script", () {
      expect(lessonPrompt("Hindi", "Class 4", from: 1, to: 2),
          contains("own script"));
    });
  });
}
