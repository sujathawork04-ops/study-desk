// Reading the tutor's markdown. The rule that matters most: never lose a
// character — above all not a multiplication sign in a maths lesson.
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/rules.dart";

String _all(String src) =>
    markdownBlocks(src).map((b) => markdownSpans(b.text).map((s) => s.text).join()).join("\n");

void main() {
  group("nothing is ever lost", () {
    test("a multiplication sign with spaces survives exactly", () {
      expect(markdownSpans("3 * 4 = 12"), const [MdSpan("3 * 4 = 12")]);
    });

    test("a multiplication sign without spaces survives exactly", () {
      expect(markdownSpans("2*3*4 = 24"), const [MdSpan("2*3*4 = 24")]);
    });

    test("a lone asterisk is shown, not swallowed", () {
      expect(markdownSpans("look at the * above"), const [MdSpan("look at the * above")]);
      expect(markdownSpans("*"), const [MdSpan("*")]);
      expect(markdownSpans("**"), const [MdSpan("**")]);
    });

    test("an unclosed bold is left as written rather than eaten", () {
      expect(markdownSpans("**start but never end"),
          const [MdSpan("**start but never end")]);
    });

    test("every character of a long reply comes back", () {
      const src = "**Step 1.** Work out 6 * 7 first.\n\n"
          "Then `divide` by 3, and *check* it.\n\n"
          "---\n\n"
          "1. Divide\n2. Multiply\n\n- brackets first\n- then DMAS";
      final out = _all(src);
      for (final must in ["Step 1.", "6 * 7", "divide", "check", "Divide", "Multiply", "brackets first", "then DMAS"]) {
        expect(out, contains(must), reason: must);
      }
    });
  });

  group("emphasis the tutor meant", () {
    test("bold is bold and the stars are gone", () {
      expect(markdownSpans("That was **my error**, not yours."), const [
        MdSpan("That was "),
        MdSpan("my error", bold: true),
        MdSpan(", not yours."),
      ]);
    });

    test("italic needs to hug its words", () {
      expect(markdownSpans("say *this* now"), const [
        MdSpan("say "),
        MdSpan("this", italic: true),
        MdSpan(" now"),
      ]);
    });

    test("code keeps its own run", () {
      expect(markdownSpans("type `DMAS` here"), const [
        MdSpan("type "),
        MdSpan("DMAS", code: true),
        MdSpan(" here"),
      ]);
    });

    test("two bold runs on one line stay two runs", () {
      // This is the bug that greedy optionals caused: the first ** paired with
      // the LAST **, and everything between became one bold run with the stars
      // left inside it.
      expect(markdownSpans("**one** and **two**"), const [
        MdSpan("one", bold: true),
        MdSpan(" and "),
        MdSpan("two", bold: true),
      ]);
      expect(markdownSpans("*one* and *two*"), const [
        MdSpan("one", italic: true),
        MdSpan(" and "),
        MdSpan("two", italic: true),
      ]);
    });

    test("a single star inside bold is kept", () {
      expect(markdownSpans("**a*b**"), const [MdSpan("a*b", bold: true)]);
    });

    test("a row of stars is never emphasis", () {
      for (final s in ["*", "**", "***", "****"]) {
        expect(markdownSpans(s), [MdSpan(s)], reason: s);
      }
    });

    test("plain runs either side are joined, not left in pieces", () {
      final out = markdownSpans("a **b** c **d** e");
      expect(out.length, 5);
      expect(out.first.text, "a ");
      expect(out.last.text, " e");
    });
  });

  group("the shape of a reply", () {
    test("a line of dashes becomes a rule, not three dashes", () {
      final b = markdownBlocks("one\n\n---\n\ntwo");
      expect(b.map((e) => e.kind).toList(), [MdKind.para, MdKind.rule, MdKind.para]);
      expect(b[1].text, "");
    });

    test("blank lines separate paragraphs; single newlines do not", () {
      final b = markdownBlocks("line one\nstill one\n\nline two");
      expect(b.length, 2);
      expect(b.first.text, "line one still one");
    });

    test("numbered steps keep the tutor's own numbers", () {
      final b = markdownBlocks("1. first\n2. second\n7) seventh");
      expect(b.map((e) => e.kind).toSet(), {MdKind.number});
      expect(b.map((e) => e.marker).toList(), ["1.", "2.", "7)"]);
      expect(b.last.text, "seventh");
    });

    test("bullets are recognised however the tutor types them", () {
      for (final src in ["- a", "* a", "• a"]) {
        final b = markdownBlocks(src);
        expect(b.single.kind, MdKind.bullet, reason: src);
        expect(b.single.text, "a", reason: src);
      }
    });

    test("headings carry their depth", () {
      final b = markdownBlocks("# Big\n### Small");
      expect(b.first.level, 1);
      expect(b.last.level, 3);
      expect(b.first.text, "Big");
    });

    test("a bulleted line starting with a star is a bullet, not italic", () {
      expect(markdownBlocks("* brackets first").single.kind, MdKind.bullet);
    });

    test("empty and whitespace-only text give nothing to draw", () {
      expect(markdownBlocks(""), isEmpty);
      expect(markdownBlocks("\n\n   \n"), isEmpty);
    });

    test("plain text with no marks is one paragraph", () {
      final b = markdownBlocks("Just a normal sentence.");
      expect(b.single.kind, MdKind.para);
      expect(b.single.text, "Just a normal sentence.");
    });
  });

  group("reading it aloud", () {
    test("the marks are not spoken", () {
      final said = plainWords("**Well done!** You got it `right`.\n\n---\n\nNext: *try this*.");
      expect(said, isNot(contains("*")));
      expect(said, isNot(contains("`")));
      expect(said, isNot(contains("-")), reason: "the dividing line is not read out");
      expect(said, contains("Well done!"));
      expect(said, contains("try this"));
    });

    test("a multiplication sign is kept, because it is part of the sum", () {
      // It is not a mark, so it stays. Reading "6 star 7" aloud is a separate
      // problem and a worse one to guess at than to leave alone.
      expect(plainWords("Work out 6 * 7."), contains("6 * 7"));
    });

    test("a reply with no marks is read as it stands", () {
      expect(plainWords("Good morning."), "Good morning.");
    });
  });
}
