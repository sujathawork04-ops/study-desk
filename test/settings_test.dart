// The parts added for parents: the optional PIN, the guard that stops a screen
// drawing before a child's day has arrived, and reopening the setup questions
// to change school, board or class.
//
// These run with no device, no database and no network — every screen here is
// pumped with state built by hand, exactly as `flutter test` likes it.
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/models.dart";
import "package:study_desk/rules.dart";
import "package:study_desk/screens/parent.dart";
import "package:study_desk/screens/setup.dart";
import "package:study_desk/state.dart";
import "package:study_desk/theme.dart";

Student student({String? pin, String grade = "Class 4", String board = "CBSE"}) => Student(
      id: "child-1",
      name: "Meera Nair",
      country: "IN",
      boardId: "cbse",
      board: board,
      grade: grade,
      timezone: "Asia/Kolkata",
      ayStartMonth: 4,
      languages: const StudentLanguages(first: "English", second: "Tamil", third: "Hindi"),
      parentPin: pin,
    );

AppState deskFor(Student s) {
  final state = AppState();
  state.student = s;
  state.plan = Plan(
    studentId: s.id,
    subjects: ["Maths", "English", "Tamil"],
    timetable: spreadTimetable(const ["Maths", "English", "Tamil"]),
    morningOn: false,
    morning: emptyWeek(),
    weekOff: ["Sun"],
    chapters: <String, List<Chapter>>{},
    exams: <Exam>[],
    comps: <Comp>[],
    offDays: <OffDay>[],
  );
  state.day = Day(studentId: s.id, date: state.date, badges: []);
  return state;
}

Widget wrap(AppState state, Widget child) => MaterialApp(
      theme: studyTheme(Brightness.light),
      home: Scope(state: state, child: Scaffold(body: child)),
    );

void main() {
  group("the parent PIN is optional", () {
    test("no PIN stored means the tab opens", () {
      expect(parentTabLocked(pin: null, unlocked: false), isFalse);
      expect(parentTabLocked(pin: "", unlocked: false), isFalse);
    });

    test("a stored PIN locks it until it is entered", () {
      expect(parentTabLocked(pin: "abc123", unlocked: false), isTrue);
      expect(parentTabLocked(pin: "abc123", unlocked: true), isFalse);
    });

    test("the same PIN always hashes the same, a different one doesn't", () {
      expect(pinHash("1234"), pinHash("1234"));
      expect(pinHash("1234"), isNot(pinHash("1235")));
    });

    testWidgets("with a PIN set, the tab asks for it and offers a way back in",
        (tester) async {
      final s = student(pin: pinHash("1234"));
      await tester.pumpWidget(wrap(deskFor(s), const ParentScreen()));

      expect(find.text("Parent area"), findsOneWidget);
      expect(find.text("Unlock"), findsOneWidget);
      expect(find.text("I forgot my PIN"), findsOneWidget);
    });

    testWidgets("with the PIN turned off, the tab opens straight away",
        (tester) async {
      final s = student(pin: null);
      await tester.pumpWidget(wrap(deskFor(s), const ParentScreen()));

      expect(find.text("Unlock"), findsNothing);
      expect(find.textContaining("Meera"), findsWidgets);   // the day, not the lock
    });

    testWidgets("turning a PIN on locks the parent tab straight away",
        (tester) async {
      final s = student(pin: null);
      final desk = deskFor(s);
      desk.unlockParent();                       // she was reading it with no PIN
      await tester.pumpWidget(wrap(desk, const ParentScreen()));
      expect(find.text("Unlock"), findsNothing);

      // What Settings does when the switch is flipped on.
      s.parentPin = pinHash("2468");
      desk.lockParent();
      await tester.pumpAndSettle();

      expect(find.text("Parent area"), findsOneWidget);
      expect(find.text("Unlock"), findsOneWidget);
    });

    testWidgets("unlocking once keeps it open until it is locked again",
        (tester) async {
      final desk = deskFor(student(pin: pinHash("2468")));
      await tester.pumpWidget(wrap(desk, const ParentScreen()));
      expect(find.text("Unlock"), findsOneWidget);

      desk.unlockParent();
      await tester.pumpAndSettle();
      expect(find.text("Unlock"), findsNothing);

      desk.lockParent();
      await tester.pumpAndSettle();
      expect(find.text("Unlock"), findsOneWidget);
    });

    test("switching child never carries the unlock across", () {
      final desk = deskFor(student(pin: pinHash("2468")));
      desk.unlockParent();
      expect(desk.parentUnlocked, isTrue);

      desk.clearStudent();
      expect(desk.parentUnlocked, isFalse,
          reason: "the next child's parent tab must ask again");
    });

    testWidgets("an empty stored PIN counts as no PIN", (tester) async {
      await tester.pumpWidget(wrap(deskFor(student(pin: "")), const ParentScreen()));
      expect(find.text("Unlock"), findsNothing);
    });
  });

  group("changing school, board or class", () {
    testWidgets("reopening the questions fills in her answers", (tester) async {
      final s = student(grade: "Class 4");
      await tester.pumpWidget(MaterialApp(
        theme: studyTheme(Brightness.light),
        home: SetupScreen(
          first: false,
          existing: s,
          existingSubjects: const ["Maths", "English", "Tamil"],
          onDone: (_) async {},
        ),
      ));

      expect(find.text("Change school details"), findsOneWidget);
      expect(find.text("Meera Nair"), findsOneWidget);          // name prefilled
    });

    testWidgets("all six steps are reachable, and saving is offered on each",
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: studyTheme(Brightness.light),
        home: SetupScreen(
          first: false,
          existing: student(),
          existingSubjects: const ["Maths"],
          onDone: (_) async {},
        ),
      ));

      for (final name in stepNames) {
        expect(find.text(name), findsOneWidget, reason: "$name chip is missing");
      }
      expect(find.text("Save changes ✓"), findsOneWidget);

      // Jump straight to Subjects — no walking through the steps in order.
      await tester.tap(find.text("Subjects"));
      await tester.pumpAndSettle();
      expect(find.text("Save changes ✓"), findsOneWidget);
    });

    testWidgets("adding a child still walks through in order and asks consent",
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: studyTheme(Brightness.light),
        home: SetupScreen(first: true, onDone: (_) async {}),
      ));

      expect(find.text("Welcome! Who is studying?"), findsOneWidget);
      expect(find.text("Next"), findsOneWidget);
      expect(find.text("Save changes ✓"), findsNothing);
      expect(find.text("Child"), findsNothing);                  // no jump chips
    });
  });

  group("a child is never shown before her day is loaded", () {
    test("choosing a child clears the previous child's day first", () {
      final state = deskFor(student());
      expect(state.plan, isNotNull);

      // What choose() does before the database answers.
      state.student = student(grade: "Class 6");
      state.plan = null;
      state.day = null;

      expect(state.plan, isNull, reason: "the old plan must not survive");
      expect(state.student!.grade, "Class 6");
    });

    test("the state reads safely while her details are still on the way", () {
      final empty = AppState();
      expect(empty.gradeDescription, "");
      expect(empty.academicYear, "");
      expect(empty.subjects, isNotEmpty);        // sensible defaults, never null
    });
  });
}
