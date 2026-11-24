// What happens when a reading lands on a chapter that already holds text.
//
// The old code always appended, so re-photographing a blurry chapter stored it
// twice — and the success message counted only the new part, so nothing said
// so. That text travels with every question, so the cost grew with each retry.
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/rules.dart";

void main() {
  group("when she is asked at all", () {
    test("a chapter nobody has read yet is saved without a question", () {
      expect(readNeedsAsking(matchedExisting: true, oldText: ""), isFalse);
      expect(readNeedsAsking(matchedExisting: true, oldText: "   \n "), isFalse);
    });

    test("a brand new chapter is saved without a question", () {
      expect(readNeedsAsking(matchedExisting: false, oldText: ""), isFalse);
      expect(readNeedsAsking(matchedExisting: false, oldText: "anything"), isFalse);
    });

    test("she is asked only when there is something to lose", () {
      expect(readNeedsAsking(matchedExisting: true, oldText: "Chapter 5…"), isTrue);
    });

    test("loading a whole book is not ninety dialogs", () {
      // Every chapter of a fresh book is new, so none of them asks.
      for (var i = 0; i < 90; i++) {
        expect(readNeedsAsking(matchedExisting: false, oldText: ""), isFalse);
      }
    });
  });

  group("more pages of the same chapter", () {
    test("both halves are kept, in order", () {
      final out = applyRead(ReadAction.addPages,
          oldText: "first half", oldPages: ["a.jpg"],
          newText: "second half", newPages: ["b.jpg"]);
      expect(out.text, "first half\n\nsecond half");
      expect(out.pages, ["a.jpg", "b.jpg"]);
    });

    test("the same photograph is not stored twice", () {
      final out = applyRead(ReadAction.addPages,
          oldText: "a", oldPages: ["p1.jpg", "p2.jpg"],
          newText: "b", newPages: ["p2.jpg", "p3.jpg"]);
      expect(out.pages, ["p1.jpg", "p2.jpg", "p3.jpg"]);
    });

    test("text already contained is not repeated", () {
      final out = applyRead(ReadAction.addPages,
          oldText: "the whole chapter", oldPages: const [],
          newText: "whole chapter", newPages: const []);
      expect(out.text, "the whole chapter");
    });
  });

  group("a better scan replaces — it does not add", () {
    test("the old text is gone, not appended", () {
      final out = applyRead(ReadAction.replace,
          oldText: "blurry first attempt", oldPages: ["bad.jpg"],
          newText: "clear second attempt", newPages: ["good.jpg"]);
      expect(out.text, "clear second attempt");
      expect(out.text, isNot(contains("blurry")));
    });

    test("the old pages go too — keeping them is how the bug looked inside", () {
      final out = applyRead(ReadAction.replace,
          oldText: "x", oldPages: ["bad1.jpg", "bad2.jpg"],
          newText: "y", newPages: ["good.jpg"]);
      expect(out.pages, ["good.jpg"]);
    });

    test("three bad attempts do not leave three copies", () {
      var text = "", pages = <String>[];
      for (final attempt in ["try one", "try two", "try three"]) {
        final out = applyRead(ReadAction.replace,
            oldText: text, oldPages: pages,
            newText: attempt, newPages: ["$attempt.jpg"]);
        text = out.text;
        pages = out.pages;
      }
      expect(text, "try three");
      expect(pages, ["try three.jpg"]);
    });
  });

  group("the titles only looked alike", () {
    test("the new chapter carries only its own pages and words", () {
      final out = applyRead(ReadAction.separateChapter,
          oldText: "Shapes and Patterns", oldPages: ["shapes.jpg"],
          newText: "Shapes of Solids", newPages: ["solids.jpg"]);
      expect(out.text, "Shapes of Solids");
      expect(out.pages, ["solids.jpg"]);
    });
  });

  group("the matching that decides whether she is asked at all", () {
    test("numbered chapters never collide, so a book loads straight through", () {
      for (var i = 1; i <= 15; i++) {
        for (var j = 1; j <= 15; j++) {
          expect(sameLesson("Chapter $i", "Chapter $j"), i == j,
              reason: "Chapter $i vs Chapter $j");
        }
      }
    });

    test("one shared word is not enough — these stay separate chapters", () {
      // I had this backwards and told Sujatha to expect these to merge. The
      // "two words is too thin to bet on" guard in sameLesson already stops
      // every one of them.
      expect(sameLesson("Shapes", "Shapes and Patterns"), isFalse);
      expect(sameLesson("Fractions", "Fractions and Decimals"), isFalse);
      expect(sameLesson("Addition and Subtraction", "Subtraction"), isFalse);
      expect(sameLesson("Multiplication", "Division"), isFalse);
    });

    test("shared filler words do not merge two real chapters", () {
      expect(sameLesson("Plants Around Us", "Animals Around Us"), isFalse);
    });

    test("one chapter under two fuller names DOES collide — the case it exists for", () {
      // Every word of the shorter title inside the longer one, two or more of
      // them. This is the real shape: the same chapter photographed in two
      // goes comes back named differently each time.
      expect(sameLesson("Shapes and Patterns", "Shapes and Patterns Around Us"), isTrue);
      expect(
          sameLesson("The Northern Plains and Islands",
              "Northern Plains Islands of India"),
          isTrue);
    });

    test("a number beats the words, in both directions", () {
      expect(sameLesson("Lesson 5 Shapes", "Chapter 5 Shapes and Patterns"), isTrue);
      expect(sameLesson("Lesson 4 Shapes", "Chapter 5 Shapes"), isFalse);
    });
  });
}
