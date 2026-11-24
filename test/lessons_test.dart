// Choosing which chapters travel with a question. Over a term the book grows
// to dozens of chapters and only a few fit in one turn, so the right ones have
// to be picked — not simply the first ones she ever photographed.
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/models.dart";
import "package:study_desk/rules.dart";

Lesson lesson(String subject, String ref, {String name = "", String text = "some text"}) =>
    Lesson(ref: ref, subject: subject, name: name.isEmpty ? "Chapter $ref" : name,
           text: text, pages: const []);

Plan planWith(Map<String, List<Chapter>> chapters) => Plan(
      studentId: "x",
      subjects: const ["Maths", "English", "Science"],
      timetable: spreadTimetable(const ["Maths", "English", "Science"]),
      morningOn: false,
      morning: emptyWeek(),
      weekOff: const ["Sun"],
      chapters: chapters,
      exams: <Exam>[],
      comps: <Comp>[],
      offDays: <OffDay>[],
    );

Chapter ch(String id, String name, String status) => Chapter(id: id, name: name, status: status);

void main() {
  examTests();
  photoTests();
  timezoneTests();
  zonePickerTests();

  group("a term's worth of chapters", () {
    final plan = planWith({
      "Maths": [
        ch("m1", "Numbers", "done"),
        ch("m2", "Addition", "done"),
        ch("m3", "Fractions", "learning"),
        ch("m4", "Shapes", "todo"),
      ],
      "English": [
        ch("e1", "The Kite", "done"),
        ch("e2", "Adjectives", "learning"),
      ],
    });

    final everything = [
      lesson("Maths", "m1", name: "Numbers"),
      lesson("Maths", "m2", name: "Addition"),
      lesson("Maths", "m3", name: "Fractions"),
      lesson("Maths", "m4", name: "Shapes"),
      lesson("English", "e1", name: "The Kite"),
      lesson("English", "e2", name: "Adjectives"),
    ];

    test("the chapter she is on beats the chapter she started the year with", () {
      final picked = lessonsForTurn(everything, plan, max: 3);
      final refs = picked.map((l) => l.ref).toList();

      expect(refs, contains("m3"), reason: "Fractions is the current Maths chapter");
      expect(refs, contains("e2"), reason: "Adjectives is the current English chapter");
      expect(refs, isNot(contains("m1")), reason: "chapter 1 is finished and old");
    });

    test("the subject she just named is pulled in", () {
      final picked = lessonsForTurn(everything, plan, asking: "help me with English", max: 2);
      expect(picked.first.subject, "English");
    });

    test("naming the chapter itself wins", () {
      final picked =
          lessonsForTurn(everything, plan, asking: "I don't understand Shapes", max: 1);
      expect(picked.single.ref, "m4");
    });

    test("today's subjects are preferred over ones not studied today", () {
      final picked = lessonsForTurn(
        [lesson("Science", "s1"), lesson("Maths", "m4", name: "Shapes")],
        plan,
        todaysSubjects: const ["Science"],
        max: 1,
      );
      expect(picked.single.subject, "Science");
    });

    test("never more than asked for, however big the book gets", () {
      final huge = [for (var i = 0; i < 60; i++) lesson("Maths", "m$i")];
      expect(lessonsForTurn(huge, plan, max: 3), hasLength(3));
      expect(lessonsForTurn(huge, plan, max: 1), hasLength(1));
    });

    test("chapters with no text yet are left out", () {
      final picked = lessonsForTurn([
        lesson("Maths", "m3", text: ""),
        lesson("Maths", "m4", text: "   "),
        lesson("English", "e2", text: "real content"),
      ], plan, max: 3);

      expect(picked, hasLength(1));
      expect(picked.single.ref, "e2");
    });

    test("with nothing uploaded it simply returns nothing", () {
      expect(lessonsForTurn(const [], plan), isEmpty);
    });

    test("equal candidates keep the order they were saved in", () {
      final plain = planWith({});
      final picked = lessonsForTurn(
        [lesson("Maths", "a"), lesson("Maths", "b"), lesson("Maths", "c")],
        plain,
        max: 2,
      );
      expect(picked.map((l) => l.ref), ["a", "b"]);
    });
  });
}

// ---------------------------------------------------------------- exams
void examTests() {
  Exam exam(String subject, String date, {String what = "", String id = ""}) =>
      Exam(id: id.isEmpty ? "$subject-$date" : id, subject: subject, what: what, date: date);

  group("saving an exam timetable", () {
    test("new papers are added and kept in date order", () {
      final merged = mergeExams(
        [exam("Maths", "2026-11-10")],
        [exam("English", "2026-11-05"), exam("Science", "2026-11-12")],
      );
      expect(merged.map((e) => e.subject), ["English", "Maths", "Science"]);
    });

    test("photographing the same sheet twice doesn't double the papers", () {
      final first = mergeExams([], [exam("Maths", "2026-11-10", what: "Ch 3, 4")]);
      final again = mergeExams(first, [exam("Maths", "2026-11-10", what: "Ch 3, 4")]);
      expect(again, hasLength(1));
    });

    test("a clearer photo corrects the portions, keeping the saved paper", () {
      final saved = [exam("Maths", "2026-11-10", what: "Ch 3", id: "keep-me")];
      final merged = mergeExams(saved, [exam("Maths", "2026-11-10", what: "Chapters 3 and 4")]);

      expect(merged, hasLength(1));
      expect(merged.single.what, "Chapters 3 and 4");
      expect(merged.single.id, "keep-me", reason: "the row itself must survive");
    });

    test("blank portions never wipe out portions already saved", () {
      final saved = [exam("Maths", "2026-11-10", what: "Chapters 3 and 4")];
      final merged = mergeExams(saved, [exam("Maths", "2026-11-10", what: "  ")]);
      expect(merged.single.what, "Chapters 3 and 4");
    });

    test("the same subject on a different date is a different paper", () {
      final merged = mergeExams(
        [exam("Maths", "2026-11-10")],
        [exam("Maths", "2026-12-01")],
      );
      expect(merged, hasLength(2));
    });

    test("rows with no date or no subject are dropped", () {
      final merged = mergeExams([], [
        exam("Maths", ""),
        exam("", "2026-11-10"),
        exam("Science", "2026-11-11"),
      ]);
      expect(merged.map((e) => e.subject), ["Science"]);
    });
  });

  group("what is still ahead", () {
    Plan withExams(List<Exam> exams) => Plan(
          studentId: "x",
          subjects: const ["Maths"],
          timetable: spreadTimetable(const ["Maths"]),
          morningOn: false,
          morning: emptyWeek(),
          weekOff: const ["Sun"],
          chapters: <String, List<Chapter>>{},
          exams: exams,
          comps: <Comp>[],
          offDays: <OffDay>[],
        );

    test("today's paper still counts, yesterday's doesn't", () {
      final plan = withExams([
        exam("Maths", "2026-09-24"),
        exam("English", "2026-09-23"),
        exam("Science", "2026-09-30"),
      ]);
      expect(examsAhead(plan, "2026-09-24").map((e) => e.subject), ["Maths", "Science"]);
    });
  });
}

// ------------------------------------------------------- photos from a phone
void photoTests() {
  group("photos a browser can't open", () {
    test("iPhone HEIC and HEIF are refused before anything is uploaded", () {
      expect(isPhotoUsable("IMG_4821.HEIC"), isFalse);
      expect(isPhotoUsable("img_4821.heic"), isFalse);
      expect(isPhotoUsable("scan.heif"), isFalse);
    });

    test("the ordinary formats are fine", () {
      for (final name in ["diary.jpg", "diary.JPEG", "page.png", "shot.webp"]) {
        expect(isPhotoUsable(name), isTrue, reason: name);
      }
    });

    test("the advice names both the phone setting and the Mac fix", () {
      expect(kHeicAdvice, contains("Most Compatible"));
      expect(kHeicAdvice, contains("Preview"));
    });
  });
}

// ------------------------------------------------------------- the clock
void timezoneTests() {
  group("which day it is, where the child is", () {
    test("the device's offset picks a sensible zone name", () {
      expect(zoneForOffset(const Duration(hours: 5, minutes: 30)), "Asia/Kolkata");
      expect(zoneForOffset(const Duration(hours: 0)), "Europe/London");
      expect(zoneForOffset(const Duration(hours: -5)), "America/New_York");
      expect(zoneForOffset(const Duration(hours: 9)), "Asia/Tokyo");
    });

    test("an unusual offset still finds its own zone", () {
      expect(zoneForOffset(const Duration(hours: 5, minutes: 45)), "Asia/Kathmandu");
      expect(zoneForOffset(const Duration(hours: 12)), "Pacific/Auckland");
    });

    test("an offset nobody uses falls back to UTC rather than guessing", () {
      expect(zoneForOffset(const Duration(hours: 17)), "UTC");
    });

    test("the date rolls over at midnight where she is, not in London", () {
      // 23:30 in London on the 24th is already the 25th in India.
      final when = DateTime.utc(2026, 9, 24, 23, 30);
      expect(todayId("Europe/London", now: when), "2026-09-24");
      expect(todayId("Asia/Kolkata", now: when), "2026-09-25");
    });

    test("morning revision follows her own clock", () {
      final when = DateTime.utc(2026, 9, 24, 2, 0);   // 07:30 in India
      expect(isMorning("Asia/Kolkata", now: when), isTrue);
      expect(isMorning("America/New_York", now: when), isFalse);  // 21:00 the night before
    });
  });
}

// ------------------------------------------------ the timezone question
void zonePickerTests() {
  group("choosing where the clock is set", () {
    test("each country offers its schools' own zone", () {
      expect(zoneForCountry("IN"), "Asia/Kolkata");
      expect(zoneForCountry("AE"), "Asia/Dubai");
      expect(zoneForCountry("GB"), "Europe/London");
      expect(zoneForCountry("NZ"), "Pacific/Auckland");
    });

    test("a country we don't list falls back to this device", () {
      expect(zoneForCountry("XX"), deviceZone());
    });

    test("the label shows the offset, so a parent can recognise it", () {
      expect(zoneLabel("Asia/Kolkata"), "Asia/Kolkata · UTC+5:30");
      expect(zoneLabel("Europe/London"), "Europe/London · UTC+0");
      expect(zoneLabel("America/New_York"), "America/New_York · UTC-5");
      expect(zoneLabel("Asia/Kathmandu"), "Asia/Kathmandu · UTC+5:45");
    });

    test("the list runs west to east and holds every zone the app knows", () {
      final list = kZonesByOffset;
      expect(list, hasLength(kZoneOffsets.length));
      for (var i = 1; i < list.length; i++) {
        expect(kZoneOffsets[list[i]]! >= kZoneOffsets[list[i - 1]]!, isTrue,
            reason: "${list[i]} came before ${list[i - 1]}");
      }
    });

    test("every country in the picker offers a zone the app can use", () {
      for (final entry in kCountryZone.entries) {
        expect(kZoneOffsets.containsKey(entry.value), isTrue,
            reason: "${entry.key} points at an unknown zone ${entry.value}");
      }
    });
  });
}
