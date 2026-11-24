// What happens when the app is ahead of the database.
//
// The app is rebuilt by running one command; the database is updated by
// pasting a SQL file into a browser. They drift, always the same way, and the
// symptom has been identical every time: work destroyed and a
// PostgrestException shown to a nine-year-old.
import "package:flutter_test/flutter_test.dart";

/// The same expression the data layer uses to read Postgres's complaint.
final missingColumn = RegExp(r"Could not find the '([^']+)' column");

void main() {
  group("reading what Postgres actually said", () {
    test("it names the column, and we find it", () {
      const real = "Could not find the 'keep' column of 'lessons' in the schema cache";
      expect(missingColumn.firstMatch(real)?.group(1), "keep");
    });

    test("every one of these has bitten in real life", () {
      const seen = {
        "Could not find the 'mode' column of 'tasks' in the schema cache": "mode",
        "Could not find the 'morning' column of 'plans' in the schema cache": "morning",
        "Could not find the 'keep' column of 'lessons' in the schema cache": "keep",
        "Could not find the 'parent_note' column of 'students' in the schema cache":
            "parent_note",
      };
      seen.forEach((message, column) {
        expect(missingColumn.firstMatch(message)?.group(1), column);
      });
    });

    test("a different failure is not mistaken for a missing column", () {
      // Only one kind of error may be handled by dropping a field. Anything
      // else — a broken policy, a bad value, no network — must be raised.
      for (final other in [
        "new row violates row-level security policy for table \"lessons\"",
        "invalid input syntax for type date: \"\"",
        "duplicate key value violates unique constraint",
        "",
      ]) {
        expect(missingColumn.firstMatch(other), isNull, reason: other);
      }
    });
  });

  group("dropping the unknown field", () {
    /// The loop the data layer runs: drop what the database does not know,
    /// keep everything else, and remember what was dropped.
    ({Map<String, dynamic> sent, Set<String> gaps}) send(
      Map<String, dynamic> row,
      Set<String> unknownToTheDatabase,
    ) {
      final payload = {...row};
      final gaps = <String>{};
      for (var attempt = 0; attempt < 4; attempt++) {
        final offending = payload.keys.where(unknownToTheDatabase.contains).toList();
        if (offending.isEmpty) return (sent: payload, gaps: gaps);
        gaps.add(offending.first);
        payload.remove(offending.first);
      }
      return (sent: payload, gaps: gaps);
    }

    test("a lesson still saves when 'keep' does not exist", () {
      final out = send({
        "ref": "r1", "subject": "Maths", "name": "Lesson 4",
        "text": "the transcription", "keep": "book", "saved_on": "2026-09-30",
      }, {"keep", "saved_on"});

      expect(out.sent.containsKey("text"), isTrue,
          reason: "the expensive part — a page photographed, read and transcribed");
      expect(out.sent["text"], "the transcription");
      expect(out.sent.containsKey("keep"), isFalse);
      expect(out.gaps, {"keep", "saved_on"});
    });

    test("homework lands even without the 'mode' column", () {
      final out = send({
        "student_id": "s", "date": "2026-09-30", "subject": "Social",
        "task": "Learn Q&A 1 to 3", "mode": "oral",
      }, {"mode"});
      expect(out.sent["task"], "Learn Q&A 1 to 3");
      expect(out.gaps, {"mode"});
    });

    test("an up-to-date database changes nothing at all", () {
      final row = {"ref": "r1", "text": "t", "keep": "book"};
      final out = send(row, <String>{});
      expect(out.sent, row);
      expect(out.gaps, isEmpty);
    });

    test("it gives up rather than looping for ever", () {
      final out = send({"a": 1, "b": 2, "c": 3, "d": 4, "e": 5, "f": 6},
          {"a", "b", "c", "d", "e", "f"});
      expect(out.gaps.length, lessThanOrEqualTo(4),
          reason: "four attempts, then stop guessing");
    });
  });
}
