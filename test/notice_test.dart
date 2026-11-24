// The line the app says to a child when something is happening, or has gone
// wrong. It used to be bare coloured text under a button, which is why a
// failure read like terminal output — "PostgrestException(message: …)" in
// orange, floating. A child studying alone deserves it to look deliberate.
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/theme.dart";

Widget wrap(Widget child, {Brightness brightness = Brightness.light}) => MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: child),
    );

void main() {
  group("a notice", () {
    testWidgets("says what it was given", (tester) async {
      await tester.pumpWidget(wrap(const Note("Saving pages… 7s")));
      expect(find.text("Saving pages… 7s"), findsOneWidget);
    });

    testWidgets("nothing to say takes no room at all", (tester) async {
      await tester.pumpWidget(wrap(const Note("")));
      expect(find.byType(Row), findsNothing, reason: "an empty notice must not leave a gap");
    });

    testWidgets("each tone carries its own mark", (tester) async {
      await tester.pumpWidget(wrap(const Note("working", tone: NoteTone.working)));
      expect(find.text("⏳"), findsOneWidget);

      await tester.pumpWidget(wrap(const Note("good", tone: NoteTone.good)));
      expect(find.text("✓"), findsOneWidget);

      await tester.pumpWidget(wrap(const Note("problem", tone: NoteTone.problem)));
      expect(find.text("!"), findsOneWidget);
    });

    testWidgets("a long message wraps instead of being cut off", (tester) async {
      // Real failures are long sentences. They must not vanish off the edge.
      const long = "That's an iPhone HEIC photo, which a browser can't open. "
          "Renaming it to .jpg doesn't help — that changes the name, not what's "
          "inside. To convert it properly: open it in Preview on the Mac.";
      await tester.pumpWidget(wrap(const SizedBox(width: 360, child: Note(long))));
      expect(find.text(long), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("it works in the dark theme the evening study uses", (tester) async {
      await tester.pumpWidget(
          wrap(const Note("Teacher is reading your diary… 4s"), brightness: Brightness.dark));
      expect(find.text("Teacher is reading your diary… 4s"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
