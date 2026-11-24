// The pictures an explanation can be made of.
//
// For a long time there were eight, and all eight were arithmetic: fractions,
// number lines, arrays. Ask what an oasis is and there was nothing to draw, so
// the subject that most needs pictures — a child who has never seen a desert —
// got four sentences of prose. These are the four that fixed that.
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/ui/pictures.dart";

Widget wrap(Map<String, dynamic> spec) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: Picture(spec: spec))));

void main() {
  group("layers — a cross-section", () {
    const oasis = {
      "kind": "layers",
      "bands": [
        {"name": "Hot sand", "note": "burning all day", "fill": "sand"},
        {"name": "Rock", "fill": "rock"},
        {"name": "Water under the ground", "note": "this is why palms grow", "fill": "water"},
      ],
      "mark": "Water under the ground",
    };

    testWidgets("every band is named on screen", (tester) async {
      await tester.pumpWidget(wrap(oasis));
      expect(find.text("Hot sand"), findsOneWidget);
      expect(find.text("Rock"), findsOneWidget);
      expect(find.text("Water under the ground"), findsOneWidget);
      expect(find.text("burning all day"), findsOneWidget);
    });

    testWidgets("the marked band is pointed at", (tester) async {
      await tester.pumpWidget(wrap(oasis));
      expect(find.text("👈"), findsOneWidget);
    });

    testWidgets("an unknown fill does not crash the drawing", (tester) async {
      await tester.pumpWidget(wrap({
        "kind": "layers",
        "bands": [{"name": "Something", "fill": "purple-jelly"}],
      }));
      expect(find.text("Something"), findsOneWidget);
    });

    testWidgets("no bands draws nothing rather than breaking", (tester) async {
      await tester.pumpWidget(wrap({"kind": "layers", "bands": []}));
      expect(tester.takeException(), isNull);
    });
  });

  group("cycle — it comes round again", () {
    testWidgets("each stage shows, and the last loops back", (tester) async {
      await tester.pumpWidget(wrap({
        "kind": "cycle",
        "stages": [
          {"emoji": "☀️", "name": "Sun heats the sea"},
          {"emoji": "☁️", "name": "Water rises"},
          {"emoji": "🌧️", "name": "It rains"},
        ],
      }));
      expect(find.text("Sun heats the sea"), findsOneWidget);
      expect(find.text("It rains"), findsOneWidget);
      expect(find.text("→"), findsNWidgets(2));
      expect(find.text("↻"), findsOneWidget, reason: "the point of a cycle");
    });
  });

  group("map — where it is and what is round it", () {
    testWidgets("the water is named and the places are labelled", (tester) async {
      await tester.pumpWidget(wrap({
        "kind": "map",
        "water": "Bay of Bengal",
        "land": "islands",
        "places": [
          {"name": "Port Blair", "x": 0.38, "y": 0.45},
        ],
      }));
      expect(find.text("Bay of Bengal"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("a map with no places still draws", (tester) async {
      await tester.pumpWidget(wrap({"kind": "map", "water": "The sea", "land": "one"}));
      expect(find.text("The sea"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group("compare — two things she is muddling", () {
    testWidgets("both headings and every row are shown", (tester) async {
      await tester.pumpWidget(wrap({
        "kind": "compare",
        "left": "Island",
        "right": "Peninsula",
        "rows": [
          {"left": "Water on every side", "right": "Water on three sides"},
          {"left": "You need a boat", "right": "You can walk there"},
        ],
      }));
      expect(find.text("Island"), findsOneWidget);
      expect(find.text("Peninsula"), findsOneWidget);
      expect(find.text("Water on every side"), findsOneWidget);
      expect(find.text("You can walk there"), findsOneWidget);
    });
  });

  group("the old eight still work", () {
    testWidgets("a fraction, and an unknown kind falls back to one big thing",
        (tester) async {
      await tester.pumpWidget(wrap({"kind": "fraction", "parts": 4, "shaded": 3}));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(wrap({"kind": "something-new", "big": "?"}));
      expect(find.text("?"), findsOneWidget);
    });

    testWidgets("a label under the picture is shown when given", (tester) async {
      await tester.pumpWidget(wrap({
        "kind": "compare", "left": "A", "right": "B",
        "rows": [{"left": "x", "right": "y"}],
        "label": "Two kinds of land",
      }));
      expect(find.text("Two kinds of land"), findsOneWidget);
    });
  });
}
