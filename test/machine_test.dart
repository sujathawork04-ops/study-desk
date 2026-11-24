// The simple machines she can move. The arithmetic matters more than the
// drawing: a machine that quietly created force out of nothing would teach her
// the opposite of what her Science chapter is for.
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/blocks.dart";
import "package:study_desk/rules.dart";

void main() {
  group("the three machines her book covers", () {
    test("each has an icon, her book's name and what it trades", () {
      expect(kMachines.keys.toSet(), {"pulley", "lever", "ramp"});
      for (final e in kMachines.entries) {
        expect(e.value.$1.isNotEmpty, isTrue);
        expect(e.value.$2.isNotEmpty, isTrue);
        expect(e.value.$3.length, greaterThan(20), reason: e.key);
      }
    });

    test("it is called an inclined plane, as CBSE calls it", () {
      expect(kMachines["ramp"]!.$2, "Inclined plane");
    });

    test("every range is small enough to slide through and find the pattern", () {
      for (final k in kMachines.keys) {
        final r = machineRange(k);
        expect(r.min, greaterThanOrEqualTo(1));
        expect(r.max - r.min, inInclusiveRange(3, 8), reason: k);
        expect(r.label.isNotEmpty, isTrue, reason: k);
      }
    });
  });

  group("no free lunch — the work is conserved", () {
    test("a pulley: effort times rope pulled equals the load lifted", () {
      for (var ropes = 1; ropes <= 4; ropes++) {
        final e = machineEffort("pulley", 100, ropes).effort;
        expect(e * ropes, closeTo(100, 0.0001), reason: "$ropes ropes");
      }
    });

    test("an inclined plane: effort times slope equals load times height", () {
      for (var len = 1; len <= 5; len++) {
        for (var h = 1; h <= 3; h++) {
          final e = machineEffort("ramp", 60, len, height: h).effort;
          expect(e * len, closeTo(60 * h, 0.0001), reason: "slope $len, height $h");
        }
      }
    });

    test("a lever: effort times its arm equals load times its arm", () {
      for (var f = 1; f <= 9; f++) {
        final e = machineEffort("lever", 100, f).effort;
        expect(e * (10 - f), closeTo(100 * f, 0.0001), reason: "fulcrum at $f");
      }
    });
  });

  group("what she discovers by moving it", () {
    test("more ropes means less to pull", () {
      final one = machineEffort("pulley", 100, 1).effort;
      final four = machineEffort("pulley", 100, 4).effort;
      expect(one, 100);
      expect(four, 25);
      expect(four, lessThan(one));
    });

    test("one fixed pulley is honest about helping with nothing", () {
      expect(machineHelps("pulley", 100, 1), isFalse);
      expect(machineEffort("pulley", 100, 1).how.toLowerCase(), contains("direction"));
    });

    test("a longer slope is gentler", () {
      expect(machineEffort("ramp", 100, 5).effort, lessThan(machineEffort("ramp", 100, 2).effort));
    });

    test("a fulcrum near the load helps; near her hands it fights her", () {
      expect(machineHelps("lever", 100, 1), isTrue);
      expect(machineHelps("lever", 100, 9), isFalse);
      expect(machineEffort("lever", 100, 9).effort, greaterThan(100));
    });

    test("a fulcrum dead centre gains nothing, and says so", () {
      expect(machineEffort("lever", 100, 5).effort, 100);
      expect(machineHelps("lever", 100, 5), isFalse);
      expect(machineEffort("lever", 100, 5).how.toLowerCase(), contains("middle"));
    });

    test("the cost is always named, never only the saving", () {
      expect(machineEffort("pulley", 100, 4).how.toLowerCase(), contains("rope"));
      expect(machineEffort("ramp", 100, 4).how.toLowerCase(), contains("times as far"));
    });
  });

  group("it cannot be made to crash or divide by zero", () {
    test("a fulcrum past the end of the bar is pulled back into range", () {
      expect(machineEffort("lever", 100, 10).effort,
          machineEffort("lever", 100, 9).effort);
      expect(machineEffort("lever", 100, 99).effort.isFinite, isTrue);
    });

    test("zero or negative settings are pulled back too", () {
      expect(machineEffort("pulley", 100, 0).effort, 100);
      expect(machineEffort("pulley", 100, -5).effort, 100);
    });

    test("no load means no effort, not a NaN", () {
      for (final k in kMachines.keys) {
        final e = machineEffort(k, 0, 2).effort;
        expect(e, 0);
        expect(e.isNaN, isFalse, reason: k);
      }
      expect(machineEffort("pulley", -10, 2).effort, 0);
    });

    test("an unknown machine behaves like a pulley rather than breaking", () {
      expect(machineEffort("catapult", 100, 2).effort, 50);
    });
  });

  group("reading what she set", () {
    test("the effort is rounded to something a nine-year-old reads", () {
      expect(prettyEffort(25.0), "25");
      expect(prettyEffort(33.3333), "33.3");
      expect(prettyEffort(11.1111), "11.1");
      expect(prettyEffort(100.0), "100");
      expect(prettyEffort(49.999), "50");
    });

    test("what is sent to the tutor carries the effort she found, not just the setting", () {
      final w = WidgetSpec.parse(
          'WIDGET: {"type":"machine","machine":"pulley","load":100,"ask":"Try it","answer":4}')!;
      final said = w.describe(4);
      expect(said, contains("4"));
      expect(said, contains("25"), reason: "the tutor must see what she discovered");
      expect(said, contains("100"));
    });
  });

  group("the tutor cannot send something she can't use", () {
    test("a machine that is not in her book is refused", () {
      expect(
          WidgetSpec.parse(
              'WIDGET: {"type":"machine","machine":"jetpack","load":100,"ask":"x"}'),
          isNull);
    });

    test("a missing or silly load is refused", () {
      expect(WidgetSpec.parse('WIDGET: {"type":"machine","machine":"lever","ask":"x"}'), isNull);
      expect(
          WidgetSpec.parse('WIDGET: {"type":"machine","machine":"lever","load":0,"ask":"x"}'),
          isNull);
      expect(
          WidgetSpec.parse('WIDGET: {"type":"machine","machine":"lever","load":99999,"ask":"x"}'),
          isNull);
    });

    test("a good one is accepted", () {
      final w = WidgetSpec.parse(
          'WIDGET: {"type":"machine","machine":"ramp","load":50,"height":2,"ask":"Push it up","answer":4}');
      expect(w, isNotNull);
      expect(w!.type, "machine");
      expect(w.isRight(4), isTrue);
      expect(w.isRight(3), isFalse);
    });

    test('"find any setting that helps" accepts every setting that really helps', () {
      final w = WidgetSpec.parse(
          'WIDGET: {"type":"machine","machine":"lever","load":100,"mustHelp":true,"ask":"Make it easier"}')!;
      expect(w.isRight(1), isTrue);
      expect(w.isRight(4), isTrue);
      expect(w.isRight(5), isFalse, reason: "dead centre gains nothing");
      expect(w.isRight(7), isFalse);
    });

    test("with no answer and no mustHelp, the tutor judges it, not the app", () {
      final w = WidgetSpec.parse(
          'WIDGET: {"type":"machine","machine":"pulley","load":100,"ask":"Have a play"}')!;
      expect(w.isRight(3), isNull);
    });
  });
}
