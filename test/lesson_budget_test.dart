// How much of her book travels with each message.
//
// The cap used to be 6,000 characters per lesson — about a fifth of a Class 4
// chapter. She photographed twenty-eight pages of Maths, the tutor was handed
// the opening and taught from that, and the DMAS rule sat in the four-fifths
// that never arrived. Nothing said a word about it, which is the part that
// matters: a silent cut is indistinguishable from a book that simply doesn't
// mention the thing.
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/rules.dart";

({String name, String text}) lesson(String name, int chars) =>
    (name: name, text: List.filled(chars, "x").join());

void main() {
  group("the budget", () {
    test("a whole Class 4 chapter now fits, uncut", () {
      // ~5,900 words is roughly 33,000 characters — the chapter she uploaded.
      final out = lessonsForPrompt([lesson("Maths Ch 4", 33000)]);
      expect(out.single.trimmed, isFalse, reason: "this is the bug: it was cut at 6,000");
      expect(out.single.text.length, 33000);
    });

    test("the old cap would have dropped four-fifths of it", () {
      // Kept as a reminder of the size of the mistake.
      const chapter = 33000;
      expect(6000 / chapter, lessThan(0.2));
    });

    test("one chapter on its own is never cut for no reason", () {
      // It was: 33,000 characters arriving trimmed with nothing competing.
      final out = lessonsForPrompt([lesson("Alone", 39000)]);
      expect(out.single.trimmed, isFalse);
    });

    test("the chapter she is asking about comes first and gets the room", () {
      final out = lessonsForPrompt([
        lesson("The one she asked about", 28000),
        lesson("Background A", 20000),
        lesson("Background B", 20000),
      ]);
      expect(out.first.name, "The one she asked about");
      expect(out.first.trimmed, isFalse);
    });

    test("the total never runs away with itself", () {
      final out = lessonsForPrompt([
        lesson("A", 90000), lesson("B", 90000), lesson("C", 90000),
      ]);
      final total = out.fold<int>(0, (n, l) => n + l.text.length);
      expect(total, lessThanOrEqualTo(kLessonBudget));
    });
  });

  group("a cut is never silent", () {
    test("anything shortened says so", () {
      final out = lessonsForPrompt([lesson("Enormous", 90000)]);
      expect(out.single.trimmed, isTrue);
    });

    test("anything complete does not claim to be cut", () {
      final out = lessonsForPrompt([lesson("Small", 500)]);
      expect(out.single.trimmed, isFalse);
    });
  });

  group("the awkward cases", () {
    test("no lessons at all", () {
      expect(lessonsForPrompt([]), isEmpty);
    });

    test("an empty chapter does not break the sharing out", () {
      final out = lessonsForPrompt([lesson("Empty", 0), lesson("Real", 1000)]);
      expect(out.length, 2);
      expect(out.last.text.length, 1000);
    });

    test("a tiny budget still returns something usable", () {
      final out = lessonsForPrompt([lesson("A", 5000)], budget: 100, reserve: 0);
      expect(out.single.text.length, 100);
      expect(out.single.trimmed, isTrue);
    });

    test("later chapters are not starved to nothing by the first", () {
      final out = lessonsForPrompt([
        lesson("First", 100000), lesson("Second", 5000),
      ]);
      expect(out.length, 2, reason: "the second must still arrive");
      expect(out.last.text.isNotEmpty, isTrue);
    });
  });
}
