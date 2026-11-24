// The shared pieces every screen is built from. These have no database and no
// network behind them, so they are the cheapest things in the suite to check.
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/theme.dart";
import "package:study_desk/ui/mascot.dart";

void main() {
  group("the page column", () {
    testWidgets("a wide screen gets one centred column, not stretched text",
        (tester) async {
      tester.view.physicalSize = const Size(2400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Bounded(maxWidth: 760, child: Container(key: const Key("inner"))),
        ),
      ));

      expect(tester.getSize(find.byKey(const Key("inner"))).width, lessThanOrEqualTo(760));
    });

    testWidgets("a phone screen is left alone", (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Bounded(child: Container(key: const Key("inner"))),
        ),
      ));

      expect(tester.getSize(find.byKey(const Key("inner"))).width, 390);
    });
  });

  group("the big choice card", () {
    testWidgets("shows what it offers and answers a tap", (tester) async {
      var tapped = 0;
      await tester.pumpWidget(MaterialApp(
        theme: studyTheme(Brightness.light),
        home: Scaffold(
          body: BigChoice(
            emoji: "🧩",
            title: "Explain it with pictures",
            subtitle: "I'll draw it and you try it",
            onTap: () => tapped++,
          ),
        ),
      ));

      expect(find.text("Explain it with pictures"), findsOneWidget);
      expect(find.text("I'll draw it and you try it"), findsOneWidget);

      await tester.tap(find.byType(BigChoice));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets("a card with no action can't be tapped", (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: studyTheme(Brightness.light),
        home: const Scaffold(body: BigChoice(emoji: "🎒", title: "Waiting", onTap: null)),
      ));
      await tester.tap(find.byType(BigChoice));
      await tester.pump();     // nothing to assert but that it doesn't throw
      expect(find.text("Waiting"), findsOneWidget);
    });
  });

  group("Chinnu", () {
    testWidgets("draws in every mood without complaint", (tester) async {
      for (final mood in Mood.values) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: Center(child: Mascot(mood: mood, size: 80))),
        ));
        await tester.pump();
        expect(find.byType(Mascot), findsOneWidget, reason: "$mood");
      }
    });
  });

  group("light and dark", () {
    test("both themes build, and the dark one really is darker", () {
      final light = studyTheme(Brightness.light);
      final dark = studyTheme(Brightness.dark);

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(dark.scaffoldBackgroundColor.computeLuminance(),
          lessThan(light.scaffoldBackgroundColor.computeLuminance()));
    });
  });
}
