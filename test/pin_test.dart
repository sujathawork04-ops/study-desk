// Setting a PIN, changing it and turning it off. The dialog is told how to
// check a password rather than reaching for the database, so all of this runs
// with no network.
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/rules.dart";
import "package:study_desk/screens/pin_dialog.dart";
import "package:study_desk/theme.dart";

Future<void> open(
  WidgetTester tester, {
  required bool needCurrent,
  required bool needNew,
  String? currentHash,
  Future<bool> Function(String)? checkPassword,
}) async {
  var opened = false;

  await tester.pumpWidget(MaterialApp(
    theme: studyTheme(Brightness.light),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () async {
              opened = true;
              await showDialog<String>(
                context: context,
                builder: (_) => PinDialog(
                  title: "PIN",
                  needCurrent: needCurrent,
                  needNew: needNew,
                  currentHash: currentHash,
                  email: "parent@example.com",
                  checkPassword: checkPassword,
                ),
              );
            },
            child: const Text("open"),
          ),
        ),
      ),
    ),
  ));

  await tester.tap(find.text("open"));
  await tester.pumpAndSettle();
  expect(opened, isTrue);
}

void main() {
  group("choosing a PIN", () {
    testWidgets("four to six digits, repeated, and it is accepted", (tester) async {
      await open(tester, needCurrent: false, needNew: true);

      await tester.enterText(find.byType(TextField).at(0), "2468");
      await tester.enterText(find.byType(TextField).at(1), "2468");
      await tester.tap(find.text("Save"));
      await tester.pumpAndSettle();

      expect(find.byType(PinDialog), findsNothing, reason: "it should have closed");
    });

    testWidgets("too short is refused, and the window stays open", (tester) async {
      await open(tester, needCurrent: false, needNew: true);

      await tester.enterText(find.byType(TextField).at(0), "12");
      await tester.enterText(find.byType(TextField).at(1), "12");
      await tester.tap(find.text("Save"));
      await tester.pumpAndSettle();

      expect(find.text("A PIN is 4 to 6 digits."), findsOneWidget);
      expect(find.byType(PinDialog), findsOneWidget);
    });

    testWidgets("a mismatch is caught before anything is saved", (tester) async {
      await open(tester, needCurrent: false, needNew: true);

      await tester.enterText(find.byType(TextField).at(0), "1234");
      await tester.enterText(find.byType(TextField).at(1), "1243");
      await tester.tap(find.text("Save"));
      await tester.pumpAndSettle();

      expect(find.text("The two PINs don't match."), findsOneWidget);
    });

    testWidgets("letters can't be typed at all", (tester) async {
      await open(tester, needCurrent: false, needNew: true);

      await tester.enterText(find.byType(TextField).at(0), "ab12cd");
      await tester.pump();

      expect(find.text("12"), findsOneWidget, reason: "only the digits survive");
    });

    testWidgets("the digits can be shown when she wants to check them",
        (tester) async {
      await open(tester, needCurrent: false, needNew: true);
      expect(find.text("Show the digits"), findsOneWidget);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    });
  });

  group("turning it off", () {
    testWidgets("the current PIN opens it", (tester) async {
      await open(tester,
          needCurrent: true, needNew: false, currentHash: pinHash("4321"));

      await tester.enterText(find.byType(TextField).first, "4321");
      await tester.tap(find.text("Save"));
      await tester.pumpAndSettle();

      expect(find.byType(PinDialog), findsNothing);
    });

    testWidgets("a wrong PIN says so and changes nothing", (tester) async {
      await open(tester,
          needCurrent: true, needNew: false, currentHash: pinHash("4321"));

      await tester.enterText(find.byType(TextField).first, "1111");
      await tester.tap(find.text("Save"));
      await tester.pumpAndSettle();

      expect(find.text("That's not your current PIN."), findsOneWidget);
      expect(find.byType(PinDialog), findsOneWidget);
    });

    testWidgets("a forgotten PIN falls back to the account password",
        (tester) async {
      await open(tester,
          needCurrent: true,
          needNew: false,
          currentHash: pinHash("4321"),
          checkPassword: (p) async => p == "correct-horse");

      await tester.tap(find.text("I forgot the PIN"));
      await tester.pumpAndSettle();
      expect(find.text("for parent@example.com"), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, "wrong");
      await tester.tap(find.text("Save"));
      await tester.pumpAndSettle();
      expect(find.text("That password doesn't match this account."), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, "correct-horse");
      await tester.tap(find.text("Save"));
      await tester.pumpAndSettle();
      expect(find.byType(PinDialog), findsNothing);
    });

    testWidgets("no way back in is offered when there is no password to check",
        (tester) async {
      await open(tester,
          needCurrent: true, needNew: false, currentHash: pinHash("4321"));
      expect(find.text("I forgot the PIN"), findsNothing);
    });

    testWidgets("cancelling leaves the PIN alone", (tester) async {
      await open(tester,
          needCurrent: true, needNew: false, currentHash: pinHash("4321"));

      await tester.tap(find.text("Cancel"));
      await tester.pumpAndSettle();
      expect(find.byType(PinDialog), findsNothing);
    });
  });

  group("changing it", () {
    testWidgets("the old one is proved before the new one is taken",
        (tester) async {
      await open(tester,
          needCurrent: true, needNew: true, currentHash: pinHash("1111"));

      // Current PIN, then the new pair.
      await tester.enterText(find.byType(TextField).at(0), "9999");
      await tester.enterText(find.byType(TextField).at(1), "2222");
      await tester.enterText(find.byType(TextField).at(2), "2222");
      await tester.tap(find.text("Save"));
      await tester.pumpAndSettle();

      expect(find.text("That's not your current PIN."), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), "1111");
      await tester.tap(find.text("Save"));
      await tester.pumpAndSettle();

      expect(find.byType(PinDialog), findsNothing);
    });
  });
}
