// How demanding Teacher is — and, more to the point, what "demanding" means
// here: teach it clearly, then find out whether she actually understood,
// rather than asking "do you understand?" and believing the answer.
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/models.dart";
import "package:study_desk/prompt.dart";
import "package:study_desk/rules.dart";

DayContext ctx(String level) => DayContext(
      studentName: "Meera Nair",
      subjects: const ["Maths"],
      gradeDescription: "Class 4 (CBSE, India)",
      academicYear: "2026–27 — second term",
      approxAge: 9,
      languages: const StudentLanguages(first: "English"),
      prettyDate: "Wednesday, 30 September",
      explainLang: "first",
      dayType: "school",
      tasks: const [], practice: const [], morning: const [],
      lessons: const [], badges: const [], lock: "",
      strictness: level,
    );

void main() {
  group("the three levels", () {
    test("every level has an icon, a name and a plain explanation", () {
      expect(kStrictness.keys.toSet(), {"gentle", "firm", "exacting"});
      for (final e in kStrictness.entries) {
        expect(e.value.$1.isNotEmpty, isTrue);
        expect(e.value.$2.isNotEmpty, isTrue);
        expect(e.value.$3.length, greaterThan(20), reason: "a parent must be able to choose");
      }
    });

    test("each one produces its own rules", () {
      final g = strictnessBlock("gentle");
      final f = strictnessBlock("firm");
      final x = strictnessBlock("exacting");
      expect(g == f, isFalse);
      expect(f == x, isFalse);
    });

    test("an unknown level falls back to the middle, never to nothing", () {
      expect(strictnessBlock("ferocious"), strictnessBlock("firm"));
      expect(strictnessBlock(""), strictnessBlock("firm"));
    });
  });

  group("strict means teach clearly, then check", () {
    test("the demanding levels insist on teaching properly first", () {
      for (final level in ["firm", "exacting"]) {
        final b = strictnessBlock(level).toLowerCase();
        expect(b, contains("clearly"), reason: level);
        expect(b, contains("picture"), reason: "$level — show, do not pile on words");
      }
    });

    test('"do you understand?" is explicitly forbidden', () {
      for (final level in ["firm", "exacting"]) {
        expect(strictnessBlock(level).toLowerCase(), contains("do you understand"),
            reason: "$level must name the question it bans");
        expect(strictnessBlock(level).toLowerCase(), contains("explain it back"),
            reason: "$level must say what to do instead");
      }
    });

    test("a right answer is not accepted without the working", () {
      for (final level in ["firm", "exacting"]) {
        expect(strictnessBlock(level).toLowerCase(), contains("working"), reason: level);
      }
    });

    test("it tests whether she has the idea, not the example", () {
      for (final level in ["firm", "exacting"]) {
        expect(strictnessBlock(level).toLowerCase(), contains("change the numbers"),
            reason: level);
      }
    });
  });

  group("demanding is never unkind", () {
    test("every level forbids mockery and comparison", () {
      for (final level in kStrictness.keys) {
        final b = strictnessBlock(level).toLowerCase();
        expect(b, contains("never mock"), reason: level);
        expect(b, contains("compare her"), reason: level);
        expect(b, contains("careless"), reason: "$level must forbid the word, not use it");
      }
    });

    test("no level allows a tick she has not earned", () {
      for (final level in kStrictness.keys) {
        expect(strictnessBlock(level).toLowerCase(),
            contains("never call something right when it is not"),
            reason: level);
      }
    });
  });

  group("what reaches the tutor", () {
    test("the chosen level's rules are in the turn", () {
      expect(buildSystemTurn(ctx("exacting")), contains("Exam standard"));
      expect(buildSystemTurn(ctx("gentle")), contains("Keep the pace easy"));
    });

    test("the bar sits with the teaching rules, before the day's detail", () {
      final turn = buildSystemTurn(ctx("firm"));
      // Anchor on the day's actual date, not on a bare "TODAY:" — that string
      // also appears inside the fixed teaching rules ("- TODAY: no teaching",
      // the competition-day line), so the bare marker was matching a sentence
      // far above the day's facts and said nothing about the real order.
      expect(turn.indexOf("HOW HIGH THE BAR IS"),
          lessThan(turn.indexOf("TODAY: Wednesday, 30 September")));
      expect(turn.indexOf("TODAY: Wednesday, 30 September"), greaterThan(-1),
          reason: "the day's date must be in the turn at all");
    });

    test("a child with no level set is taught thoroughly, not gently", () {
      final s = Student.fromJson({"id": "1", "name": "Meera"});
      expect(s.strictness, isNull);
      expect(strictnessBlock(s.strictness ?? "firm"), strictnessBlock("firm"));
    });
  });
}
