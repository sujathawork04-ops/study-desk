// The rules that decide a day. Pure Dart, so `flutter test` runs them with no
// device, no database and no network.
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/blocks.dart";
import "package:study_desk/curricula.dart";
import "package:study_desk/models.dart";
import "package:study_desk/rules.dart";

Plan planWith({
  bool morningOn = false,
  Map<String, List<String>>? morning,
  List<String>? weekOff,
  List<Exam> exams = const [],
}) =>
    Plan(
      studentId: "x",
      subjects: const ["Maths", "English", "Tamil"],
      timetable: spreadTimetable(const ["Maths", "English", "Tamil"]),
      morningOn: morningOn,
      morning: morning ?? (emptyWeek()..["Mon"] = ["Tamil"]),
      weekOff: weekOff ?? ["Sun"],
      chapters: {}, exams: exams, comps: [], offDays: [],
    );

const monday = "2026-09-21";

void main() {
  group("the school day", () {
    test("a weekly off day is a holiday without anyone marking it", () {
      final plan = planWith(weekOff: ["Sun"]);
      final sunday = Day(studentId: "x", date: "2026-09-20", badges: []);
      expect(dayTypeOf(sunday, plan).type, "holiday");
    });

    test("what the child marked wins over the plan", () {
      final plan = planWith(weekOff: ["Mon"]);
      final day = Day(studentId: "x", date: monday, badges: [], dayType: "school");
      expect(dayTypeOf(day, plan).type, "school");
    });

    test("practice stays locked until the diary is in", () {
      final plan = planWith();
      final day = Day(studentId: "x", date: monday, badges: []);
      expect(homeworkLock(day, plan, []), contains("snap your diary"));
    });

    test("and until every piece of homework is checked", () {
      final plan = planWith();
      final day = Day(studentId: "x", date: monday, badges: [])
        ..diaryPostedAt = "2026-09-21T10:00:00Z";
      final tasks = [
        Task(id: "1", subject: "Maths", task: "Ex 5.2", done: true),
        Task(id: "2", subject: "English", task: "5 sentences", done: false),
      ];
      expect(homeworkLock(day, plan, tasks), contains("1 left"));
      tasks[1].done = true;
      expect(homeworkLock(day, plan, tasks), "");
    });
  });

  group("morning study", () {
    test("is off unless the parent turns it on", () {
      expect(morningItems(planWith(), monday), isEmpty);
    });

    test("has its own subjects when on", () {
      expect(morningItems(planWith(morningOn: true), monday), ["Morning: Tamil"]);
    });

    test("never collides with the after-school list", () {
      final plan = planWith(morningOn: true);
      final after = practiceItems(plan, monday);
      for (final m in morningItems(plan, monday)) {
        expect(after.contains(m), isFalse);
        expect(m.startsWith("Morning: "), isTrue);
      }
    });
  });

  group("subjects", () {
    test("the first guess follows the languages chosen at setup", () {
      expect(
        defaultSubjects(const StudentLanguages(first: "English", second: "Tamil", third: "Hindi")),
        ["Maths", "English", "Tamil", "Hindi", "Science", "Social", "Computer", "General Knowledge"],
      );
    });

    test("the weekly timetable spreads every subject, nothing dropped", () {
      const subjects = ["Maths", "English", "Tamil", "Hindi", "Science", "Social", "Computer", "GK"];
      final t = spreadTimetable(subjects);
      final placed = ["Mon", "Tue", "Wed", "Thu", "Fri"].expand((d) => t[d]!).toList()..sort();
      expect(placed, ([...subjects]..sort()));
      expect(t["Sat"], ["Weekly revision"]);
      expect(t["Sun"], isEmpty);
    });
  });

  group("the tutor's hidden lines", () {
    test("a widget is read and kept out of the child's view", () {
      const reply = 'Have a look at this.\n\nWIDGET: {"type":"fraction","parts":4,"ask":"Shade three quarters","answer":3}';
      final w = WidgetSpec.parse(reply)!;
      expect(w.type, "fraction");
      expect(w.i("parts", 0), 4);
      expect(readTutorLines(reply).visible, "Have a look at this.");
    });

    test("nonsense is refused rather than drawn", () {
      expect(WidgetSpec.parse('WIDGET: {"type":"rocket","ask":"go"}'), isNull);
      expect(WidgetSpec.parse('WIDGET: {"type":"fraction","parts":99,"ask":"too many"}'), isNull);
      expect(WidgetSpec.parse("WIDGET: {not json}"), isNull);
    });

    test("the app only judges when the tutor gave an answer", () {
      final withAnswer = WidgetSpec.parse('WIDGET: {"type":"fraction","parts":4,"ask":"a","answer":3}')!;
      expect(withAnswer.isRight(3), isTrue);
      expect(withAnswer.isRight(2), isFalse);
      final without = WidgetSpec.parse('WIDGET: {"type":"fraction","parts":4,"ask":"a"}')!;
      expect(without.isRight(3), isNull);
    });

    test("a walk-through keeps its steps in order and is capped", () {
      const reply = 'EXPLAIN: {"title":"What a fraction is","steps":['
          '{"say":"Amma makes one dosa.","show":{"kind":"fraction","parts":1,"shaded":1}},'
          '{"say":"She cuts it into 4.","show":{"kind":"fraction","parts":4,"shaded":0}},'
          '{"say":"You take 3.","ask":"How many of four?"}]}';
      final e = Explainer.parse(reply)!;
      expect(e.title, "What a fraction is");
      expect(e.steps.length, 3);
      expect(e.steps.first.say, contains("dosa"));
      expect(e.steps.last.ask, "How many of four?");
      expect(Explainer.parse('EXPLAIN: {"title":"t","steps":[{"say":"only one"}]}'), isNull);
    });

    test("badges, ticks and scores are picked out", () {
      const reply = "Well done!\nBADGE: 🧠 Super Thinker\nDONE: 2\nPRACTICED: Maths | 4/5";
      final lines = readTutorLines(reply);
      expect(lines.badges, ["🧠 Super Thinker"]);
      expect(lines.doneNumbers, [2]);
      expect(lines.practiced.first.$1, "Maths");
      expect(lines.practiced.first.$2, "4/5");
      expect(lines.visible, "Well done!");
    });
  });

  group("boards and the school year", () {
    test("every country offers a board, and every board has grades", () {
      for (final c in countries) {
        expect(c.boards, isNotEmpty, reason: c.name);
        for (final b in c.boards) {
          expect(b.grades, isNotEmpty, reason: "${c.name} / ${b.name}");
        }
      }
    });

    test("India's April–March year is labelled the way schools write it", () {
      expect(academicYearLabel(4, today: DateTime(2026, 9, 20)), "2026–27");
      expect(academicYearLabel(4, today: DateTime(2027, 2, 10)), "2026–27");
      expect(academicYearLabel(1, today: DateTime(2026, 9, 20)), "2026");
    });

    test("the grade is described the way the tutor should read it", () {
      expect(describeGrade("IN", "cbse", "Class 4"), "Class 4 (CBSE, India)");
    });
  });
}
