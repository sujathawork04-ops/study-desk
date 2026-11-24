// Sorting into groups — the one interactive that works in every subject and
// every script, which is why it matters that it never hands her a card with
// nowhere right to put it.
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/blocks.dart";
import "package:study_desk/rules.dart";

const _living = 'WIDGET: {"type":"sort","groups":["Living","Non-living"],'
    '"items":[{"it":"dog","group":"Living"},{"it":"rock","group":"Non-living"},'
    '{"it":"fern","group":"Living"}],"ask":"Sort these"}';

void main() {
  group("marking it", () {
    test("all in the right place is right", () {
      final w = WidgetSpec.parse(_living)!;
      expect(
          w.isRight({"dog": "Living", "rock": "Non-living", "fern": "Living"}), isTrue);
    });

    test("one in the wrong place is wrong", () {
      final w = WidgetSpec.parse(_living)!;
      expect(w.isRight({"dog": "Living", "rock": "Living", "fern": "Living"}), isFalse);
    });

    test("leaving one out is not finished", () {
      final w = WidgetSpec.parse(_living)!;
      expect(w.isRight({"dog": "Living", "rock": "Non-living"}), isFalse);
      expect(w.isRight(<String, String>{}), isFalse);
    });

    test("a sort is never left to the tutor to mark — it carries its own answer", () {
      final w = WidgetSpec.parse(_living)!;
      expect(w.isRight({"dog": "Living", "rock": "Non-living", "fern": "Living"}), isNotNull);
    });
  });

  group("which ones she got wrong", () {
    const correct = [
      (it: "dog", group: "Living"),
      (it: "rock", group: "Non-living"),
      (it: "fern", group: "Living"),
    ];

    test("nothing wrong means an empty list", () {
      expect(
          sortMistakes(correct,
              {"dog": "Living", "rock": "Non-living", "fern": "Living"}),
          isEmpty);
    });

    test("misplaced and unplaced both count as not yet right", () {
      expect(sortMistakes(correct, {"dog": "Non-living", "rock": "Non-living"}),
          ["dog", "fern"]);
    });

    test("they come back in the tutor's order, so feedback reads the same twice", () {
      final a = sortMistakes(correct, {"fern": "Non-living", "dog": "Non-living"});
      final b = sortMistakes(correct, {"dog": "Non-living", "fern": "Non-living"});
      expect(a, b);
      expect(a, ["dog", "rock", "fern"]);
    });
  });

  group("the columns on screen", () {
    test("the tutor's own order is kept", () {
      expect(
          sortGroups(const ["Solid", "Liquid", "Gas"], const [
            (it: "ice", group: "Solid"),
            (it: "steam", group: "Gas"),
          ]),
          ["Solid", "Liquid", "Gas"]);
    });

    test("an empty column stays — she has to notice it is empty", () {
      final g = sortGroups(const ["Metal", "Non-metal"],
          const [(it: "iron", group: "Metal")]);
      expect(g, contains("Non-metal"));
    });

    test("a group named only by an item still gets a column", () {
      expect(
          sortGroups(const ["Noun"], const [
            (it: "run", group: "Verb"),
            (it: "cat", group: "Noun"),
          ]),
          ["Noun", "Verb"]);
    });
  });

  group("what the tutor cannot send", () {
    test("an item belonging to a group that has no column is refused", () {
      // Otherwise she is handed a card with nowhere right to put it, taps every
      // column, and is told no each time.
      expect(
          WidgetSpec.parse('WIDGET: {"type":"sort","groups":["Living"],'
              '"items":[{"it":"dog","group":"Living"},{"it":"rock","group":"Non-living"},'
              '{"it":"fern","group":"Living"}],"ask":"x"}'),
          isNull);
    });

    test("one group is not a sort, and five is too many to hold", () {
      expect(
          WidgetSpec.parse('WIDGET: {"type":"sort","groups":["A"],'
              '"items":[{"it":"x","group":"A"},{"it":"y","group":"A"},'
              '{"it":"z","group":"A"}],"ask":"x"}'),
          isNull);
      expect(
          WidgetSpec.parse('WIDGET: {"type":"sort","groups":["A","B","C","D","E"],'
              '"items":[{"it":"x","group":"A"},{"it":"y","group":"B"},'
              '{"it":"z","group":"C"}],"ask":"x"}'),
          isNull);
    });

    test("too few or too many cards is refused", () {
      expect(
          WidgetSpec.parse('WIDGET: {"type":"sort","groups":["A","B"],'
              '"items":[{"it":"x","group":"A"},{"it":"y","group":"B"}],"ask":"x"}'),
          isNull);
      final many = List.generate(11, (i) => '{"it":"i$i","group":"A"}').join(",");
      expect(
          WidgetSpec.parse(
              'WIDGET: {"type":"sort","groups":["A","B"],"items":[$many],"ask":"x"}'),
          isNull);
    });

    test("a blank card is refused", () {
      expect(
          WidgetSpec.parse('WIDGET: {"type":"sort","groups":["A","B"],'
              '"items":[{"it":"  ","group":"A"},{"it":"y","group":"B"},'
              '{"it":"z","group":"A"}],"ask":"x"}'),
          isNull);
    });
  });

  group("it works in her other languages", () {
    test("Tamil words sort as readily as English ones", () {
      final w = WidgetSpec.parse('WIDGET: {"type":"sort",'
          '"groups":["உயிரினம்","உயிரற்றது"],'
          '"items":[{"it":"நாய்","group":"உயிரினம்"},'
          '{"it":"கல்","group":"உயிரற்றது"},'
          '{"it":"மரம்","group":"உயிரினம்"}],"ask":"பிரித்து வைக்கவும்"}');
      expect(w, isNotNull);
      expect(
          w!.isRight({
            "நாய்": "உயிரினம்",
            "கல்": "உயிரற்றது",
            "மரம்": "உயிரினம்",
          }),
          isTrue);
    });
  });

  group("what reaches the tutor", () {
    test("every card and where she put it, so the tutor can see the pattern", () {
      final w = WidgetSpec.parse(_living)!;
      final said = w.describe({"dog": "Living", "rock": "Living", "fern": "Living"});
      expect(said, contains("dog → Living"));
      expect(said, contains("rock → Living"));
      expect(said, contains("rock"), reason: "the doubt must be named");
    });

    test("an unplaced card is said to be unplaced, not silently dropped", () {
      final w = WidgetSpec.parse(_living)!;
      expect(w.describe({"dog": "Living"}), contains("not placed"));
    });
  });
}
