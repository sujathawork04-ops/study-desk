// Taking the archive out of the app.
//
// The transcriptions are the only part of a reading that is ever read back,
// about 1% of the storage the photographs take, and until now the only part
// with no copy anywhere outside one free-tier database. A term's scanning is
// hours of work and real money; it should not live in one place.
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/models.dart";
import "package:study_desk/rules.dart";

Lesson _l(String subject, String name, String text,
        {String keep = "book", List<String> pages = const ["p.jpg"], String on = "2026-10-14"}) =>
    Lesson(
      ref: "ref-${name.hashCode}",
      subject: subject,
      name: name,
      text: text,
      pages: pages,
      keep: keep,
      savedOn: on,
    );

String _out(List<Lesson> ls) => lessonArchive(ls,
    studentName: "Meera Nair", grade: "Class 4 (CBSE, India)", onDate: "2026-10-14");

void main() {
  group("nothing is left behind", () {
    test("every chapter's words are in the file, in full", () {
      final ls = [
        _l("Maths", "Chapter 5 Fractions", "A fraction is a part of a whole."),
        _l("Social", "Chapter 2 Islands", "An island is land with water all round."),
        _l("Science", "Chapter 7 Simple Machines", "A pulley changes the direction you pull."),
      ];
      final out = _out(ls);
      for (final l in ls) {
        expect(out, contains(l.text), reason: l.name);
        expect(out, contains(l.name), reason: l.name);
      }
    });

    test("put-away chapters are kept too — they are the older book", () {
      final out = _out([
        _l("Maths", "Chapter 1 Numbers", "first term work", keep: kArchived),
        _l("Maths", "Chapter 9 Decimals", "second term work"),
      ]);
      expect(out, contains("first term work"));
      expect(out, contains("second term work"));
      expect(out, contains("put away"));
    });

    test("a chapter that read as nothing is still listed, and says so", () {
      final out = _out([_l("Hindi", "Chapter 3", "")]);
      expect(out, contains("Chapter 3"));
      expect(out, contains("nothing was read"));
    });

    test("an empty archive still produces a readable file", () {
      final out = _out(const []);
      expect(out, contains("Meera Nair"));
      expect(out, contains("0 chapters"));
    });
  });

  group("it is readable, and it says what it is for", () {
    test("the child, the class and the date are at the top", () {
      final out = _out([_l("Maths", "Chapter 1", "x")]);
      expect(out, startsWith("# Meera Nair — lessons"));
      expect(out, contains("Class 4 (CBSE, India)"));
      expect(out, contains("2026-10-14"));
    });

    test("it says to keep the file somewhere else", () {
      expect(_out([_l("Maths", "Chapter 1", "x")]).toLowerCase(),
          contains("not the app"));
    });

    test("subjects are grouped, and in a steady order", () {
      final a = _out([
        _l("Social", "Chapter 1", "s"),
        _l("Maths", "Chapter 1", "m"),
        _l("English", "Chapter 1", "e"),
      ]);
      expect(a.indexOf("## English"), lessThan(a.indexOf("## Maths")));
      expect(a.indexOf("## Maths"), lessThan(a.indexOf("## Social")));
    });

    test("the same archive twice is the same file — safe to diff", () {
      final ls = [_l("Maths", "Chapter 5", "a"), _l("Social", "Chapter 2", "b")];
      expect(_out(ls), _out(ls));
    });

    test("each chapter carries its page and word counts, so a bad read shows", () {
      final out = _out([
        _l("Maths", "Chapter 5", "one two three", pages: ["a.jpg", "b.jpg", "c.jpg"])
      ]);
      expect(out, contains("3 words"));
      expect(out, contains("3 pages"));
      expect(out, contains("read 2026-10-14"));
    });
  });

  group("it can be read back in", () {
    test("every chapter carries its ref, subject and keep as a marker", () {
      final out = _out([_l("Maths", "Chapter 5 Fractions", "x", keep: "book")]);
      expect(out, contains("subject:Maths"));
      expect(out, contains("keep:book"));
      expect(out, matches(RegExp(r"<!-- ref:\S+ subject:Maths keep:book -->")));
    });

    test("one marker per chapter, no more", () {
      final out = _out([
        _l("Maths", "Chapter 1", "a"),
        _l("Maths", "Chapter 2", "b"),
        _l("Social", "Chapter 1", "c"),
      ]);
      expect(RegExp(r"<!-- ref:").allMatches(out).length, 3);
    });
  });

  group("the file it is saved as", () {
    test("names the child and sorts by date", () {
      expect(archiveFileName("Meera Nair", "2026-10-14"), "meera-nair-lessons-2026-10-14.md");
    });

    test("a name with punctuation or spaces is still a safe filename", () {
      expect(archiveFileName("O'Brien  Jr.", "2026-01-02"), "o-brien-jr-lessons-2026-01-02.md");
      expect(archiveFileName("", "2026-01-02"), "lessons-lessons-2026-01-02.md");
    });

    test("a name in another script does not produce an empty filename", () {
      final n = archiveFileName("சாய்", "2026-01-02");
      expect(n.endsWith("-lessons-2026-01-02.md"), isTrue);
      expect(n.startsWith("-"), isFalse);
    });
  });
}
