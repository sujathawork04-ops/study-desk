// A scanned chapter arrives as one PDF, not as twelve photographs. These pin
// the two decisions that stand between that PDF and Teacher reading it: what
// counts as a PDF at all, and what happens to the pages past the cap.
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/rules.dart";

List<int> bytesOf(String s) => s.codeUnits;

void main() {
  group("knowing a PDF when it sees one", () {
    test("a real PDF starts with the marker", () {
      expect(isPdfBytes(bytesOf("%PDF-1.7\nstuff")), isTrue);
    });

    test("a scanner's few bytes before the marker are forgiven", () {
      // Some scanner apps write a byte-order mark or a stray newline first.
      // The file opens perfectly well in Preview, so it must open here.
      expect(isPdfBytes(bytesOf("\n\n%PDF-1.4 rest")), isTrue);
    });

    test("a JPEG is not a PDF, whatever it is called", () {
      expect(isPdfBytes(const [0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0]), isFalse);
    });

    test("a PNG is not a PDF", () {
      expect(isPdfBytes(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
          isFalse);
    });

    test("the word PDF deep inside a photo is not the marker", () {
      // 2000 bytes of photo, then the text. Past the window on purpose: a
      // JPEG that happens to contain '%PDF-' in its metadata is still a JPEG.
      final photo = <int>[0xFF, 0xD8, 0xFF, ...List.filled(2000, 0x20)]
        ..addAll(bytesOf("%PDF-"));
      expect(isPdfBytes(photo), isFalse);
    });

    test("an empty or tiny file is not a PDF", () {
      expect(isPdfBytes(const []), isFalse);
      expect(isPdfBytes(bytesOf("%PD")), isFalse);
    });
  });

  group("how many pages get read", () {
    test("a short chapter is read whole, with nothing to explain", () {
      final r = pagesToRead(12);
      expect(r.take, 12);
      expect(r.note, "");
    });

    test("exactly the cap is still read whole", () {
      final r = pagesToRead(kMaxLessonPages);
      expect(r.take, kMaxLessonPages);
      expect(r.note, "");
    });

    test("a whole scanned book is cut — and SAYS so", () {
      final r = pagesToRead(200);
      expect(r.take, kMaxLessonPages);
      expect(r.note, contains("200"));
      expect(r.note, contains("$kMaxLessonPages"));
      // The parent must be told what to do about the rest, not just that
      // something was dropped.
      expect(r.note.toLowerCase(), contains("add the rest"));
    });

    test("nothing offered, nothing taken", () {
      expect(pagesToRead(0).take, 0);
      expect(pagesToRead(0).note, "");
    });
  });

  group("what a parent is told when a PDF cannot be used", () {
    test("the phone sends her to the browser rather than failing silently", () {
      expect(kPdfOnPhoneAdvice.toLowerCase(), contains("browser"));
      expect(kPdfOnPhoneAdvice.toLowerCase(), contains("pdf"));
    });

    test("an unopenable PDF suggests the two things that actually fix it", () {
      expect(kPdfUnreadableAdvice.toLowerCase(), contains("password"));
      expect(kPdfUnreadableAdvice.toLowerCase(), contains("again"));
    });
  });
}
