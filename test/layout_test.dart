// How the desk arranges itself. The phone layout is the one that works; these
// rules only decide when there is enough room to stop pretending to be a phone.
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/rules.dart";

void main() {
  group("when to stop being a phone", () {
    test("every phone, held either way, keeps the bottom bar", () {
      for (final w in [320.0, 375.0, 390.0, 414.0, 430.0]) {
        expect(wideLayout(w), isFalse, reason: "${w}px portrait");
      }
      // A phone on its side, and a small tablet, are still bottom-bar country.
      expect(wideLayout(844), isFalse);
      expect(wideLayout(899), isFalse);
    });

    test("a laptop or a browser window gets the side rail", () {
      for (final w in [900.0, 1024.0, 1440.0, 2560.0]) {
        expect(wideLayout(w), isTrue, reason: "${w}px");
      }
    });
  });

  group("how wide the words are allowed to get", () {
    test("a phone is never squeezed by the cap", () {
      expect(contentWidth(390, cards: false), 760);
      expect(contentWidth(390, cards: true), 760);
    });

    test("reading never runs the full width of a big screen", () {
      // The window is 2560 wide; the sentence is not.
      expect(contentWidth(2560, cards: false), lessThan(900));
    });

    test("tiles may take more room than prose", () {
      expect(contentWidth(1440, cards: true),
          greaterThan(contentWidth(1440, cards: false)));
    });
  });

  group("how many tiles across", () {
    test("a phone column is always one", () {
      expect(cardColumns(390 - 32), 1);
      expect(cardColumns(358), 1);
    });

    test("two when both still have room to breathe", () {
      expect(cardColumns(1060), 2);
      expect(cardColumns(760), 2);
    });

    test("never three, however wide the screen", () {
      for (final w in [1060.0, 1920.0, 3840.0]) {
        expect(cardColumns(w), lessThanOrEqualTo(2), reason: "${w}px");
      }
    });

    test("the switch happens exactly when two tiles fit, not before", () {
      const min = 340.0, gap = 12.0;
      expect(cardColumns(min * 2 + gap - 1, minTile: min, gap: gap), 1);
      expect(cardColumns(min * 2 + gap, minTile: min, gap: gap), 2);
    });
  });
}
