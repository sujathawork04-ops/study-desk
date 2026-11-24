// What a picked file really is. A photo renamed from .heic to .jpg is still
// HEIC, and only its first bytes say so — the name is a label, not evidence.
import "dart:typed_data";

import "package:flutter_test/flutter_test.dart";
import "package:study_desk/data/photos.dart";
import "package:study_desk/rules.dart";

/// A file's first bytes, padded to a realistic length.
List<int> head(List<int> signature) =>
    [...signature, ...List<int>.filled(40, 0)];

/// "....ftyp<brand>" — how every HEIC, HEIF and MP4-family file begins.
List<int> ftyp(String brand) => head([
      0, 0, 0, 0x18,
      ...("ftyp$brand").codeUnits,
    ]);

void main() {
  group("what the file really is", () {
    test("a real JPEG", () {
      expect(photoKind(head([0xFF, 0xD8, 0xFF, 0xE0])), "jpeg");
      expect(photoKind(head([0xFF, 0xD8, 0xFF, 0xE1])), "jpeg", reason: "with EXIF");
    });

    test("PNG, GIF and WebP", () {
      expect(photoKind(head([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])), "png");
      expect(photoKind(head([0x47, 0x49, 0x46, 0x38, 0x39, 0x61])), "gif");
      expect(photoKind(head([...("RIFF").codeUnits, 0, 0, 0, 0, ...("WEBP").codeUnits])), "webp");
    });

    test("an iPhone photo, whatever it has been renamed to", () {
      for (final brand in ["heic", "heix", "mif1", "msf1", "hevc", "avif"]) {
        expect(photoKind(ftyp(brand)), "heic", reason: "brand $brand");
      }
    });

    test("the name is not evidence — this is the bug that bit", () {
      // Renaming a .heic to .jpg passes the name check and then fails deep in
      // the browser with "Failed to retrieve track metadata".
      expect(isPhotoUsable("diary.jpg"), isTrue, reason: "the label says jpg");
      expect(isPhotoBytesUsable(ftyp("heic")), isFalse, reason: "the bytes say otherwise");
      expect(photoProblem(ftyp("heic")), kHeicAdvice);
      expect(photoProblem(ftyp("heic")), contains("Renaming it to"));
    });

    test("something that is not an image at all", () {
      expect(photoKind(head([0x25, 0x50, 0x44, 0x46])), "", reason: "a PDF");
      expect(photoKind(head([0x50, 0x4B, 0x03, 0x04])), "", reason: "a zip");
      expect(photoProblem(head([0x25, 0x50, 0x44, 0x46])), kOddFileAdvice);
    });

    test("an empty or truncated file is refused, not crashed on", () {
      expect(photoKind(const []), "");
      expect(photoKind(const [0xFF, 0xD8]), "");
      expect(isPhotoBytesUsable(const []), isFalse);
      expect(photoProblem(const []), kOddFileAdvice);
    });

    test("an ordinary MP4 is not mistaken for a photo", () {
      expect(photoKind(ftyp("isom")), "");
      expect(photoKind(ftyp("mp42")), "");
    });
  });

  group("what we tell the tutor it is", () {
    test("the media type comes from the bytes, not the file name", () {
      expect(photoMime(head([0x89, 0x50, 0x4E, 0x47])), "image/png");
      expect(photoMime(head([0xFF, 0xD8, 0xFF])), "image/jpeg");
      expect(photoMime(head([...("RIFF").codeUnits, 0, 0, 0, 0, ...("WEBP").codeUnits])),
          "image/webp");
    });

    test("a usable photo always has a media type the tutor accepts", () {
      const accepted = {"image/jpeg", "image/png", "image/gif", "image/webp"};
      for (final b in [
        head([0xFF, 0xD8, 0xFF]),
        head([0x89, 0x50, 0x4E, 0x47]),
        head([0x47, 0x49, 0x46, 0x38]),
        head([...("RIFF").codeUnits, 0, 0, 0, 0, ...("WEBP").codeUnits]),
      ]) {
        expect(isPhotoBytesUsable(b), isTrue);
        expect(accepted.contains(photoMime(b)), isTrue);
      }
    });
  });

  group("the advice a parent reads", () {
    test("the HEIC message says renaming is not converting", () {
      expect(kHeicAdvice, contains("Renaming"));
      expect(kHeicAdvice, contains("Export"));
      expect(kHeicAdvice, contains("Most Compatible"));
    });

    test("a good photo produces no message at all", () {
      expect(photoProblem(head([0xFF, 0xD8, 0xFF])), "");
    });
  });

  group("the gate every picked photo goes through", () {
    test("a good photo passes straight through, unchanged", () async {
      final jpeg = head([0xFF, 0xD8, 0xFF, 0xE0]);
      final r = await readyPhoto(Uint8List.fromList(jpeg));
      expect(r.problem, "");
      expect(r.converted, isFalse);
      expect(r.bytes, jpeg);
    });

    test("something that is not an image is refused with plain advice", () async {
      final r = await readyPhoto(Uint8List.fromList(head([0x25, 0x50, 0x44, 0x46])));
      expect(r.problem, kOddFileAdvice);
      expect(r.converted, isFalse);
    });

    test("with no decoder on this platform, a HEIC gets the how-to", () async {
      // Off the browser there is nothing to decode with, so the parent is told
      // how to convert it rather than left with a silent failure.
      final r = await readyPhoto(Uint8List.fromList(ftyp("heic")));
      expect(r.problem, kHeicAdvice);
      expect(r.converted, isFalse);
      expect(r.bytes.isNotEmpty, isTrue, reason: "her photo is never thrown away");
    });

    test("the waiting message says what is happening, in her words", () {
      expect(kConvertingPhoto, contains("iPhone"));
      expect(kConvertingPhoto.length, lessThan(70), reason: "it sits under a button");
    });
  });
}
