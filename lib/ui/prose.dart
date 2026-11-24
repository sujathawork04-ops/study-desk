// The tutor's reply, laid out as writing rather than as one block of text.
//
// Before this, a long explanation arrived as an undifferentiated wall at a
// single size, with the tutor's own **emphasis** showing as asterisks. The
// shape of an explanation — this is a step, this is the important bit, this is
// a new section — is half of how a child reads it.
import "package:flutter/material.dart";
import "../rules.dart";
import "../theme.dart";

class Prose extends StatelessWidget {
  const Prose(this.text, {super.key, this.color, this.size = 15.5});
  final String text;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final blocks = markdownBlocks(text);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = color ?? (dark ? C.dInk : C.ink);

    // Nothing the parser recognised: show the text exactly as it came.
    if (blocks.isEmpty) {
      return Text(text, style: TextStyle(color: ink, fontSize: size, height: 1.45));
    }

    final kids = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (i > 0) kids.add(SizedBox(height: _gapBefore(b)));
      kids.add(switch (b.kind) {
        MdKind.rule => Divider(
            height: 1,
            thickness: 1,
            color: (dark ? C.dLine : C.line).withValues(alpha: .9),
          ),
        MdKind.heading => _line(b.text, ink,
            size: b.level <= 1 ? size + 3 : size + 1, weight: FontWeight.w800),
        MdKind.bullet => _hung("•", b.text, ink),
        MdKind.number => _hung(b.marker, b.text, ink),
        MdKind.para => _line(b.text, ink),
      });
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: kids);
  }

  double _gapBefore(MdBlock b) => switch (b.kind) {
        MdKind.rule => 14,
        MdKind.heading => 14,
        // Steps in a list belong together; paragraphs need air between them.
        MdKind.bullet || MdKind.number => 5,
        MdKind.para => 10,
      };

  Widget _line(String text, Color ink,
          {double? size, FontWeight weight = FontWeight.w400}) =>
      Text.rich(
        TextSpan(children: _spans(text, ink, weight)),
        style: TextStyle(color: ink, fontSize: size ?? this.size, height: 1.45),
      );

  /// A bullet or number sitting in its own column, so wrapped lines line up
  /// under the words and not under the marker.
  Widget _hung(String marker, String text, Color ink) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: marker.length > 2 ? 30 : 20,
            child: Text(marker,
                style: TextStyle(
                    color: ink.withValues(alpha: .75),
                    fontSize: size,
                    height: 1.45,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(child: _line(text, ink)),
        ]),
      );

  List<InlineSpan> _spans(String text, Color ink, FontWeight base) => [
        for (final s in markdownSpans(text))
          TextSpan(
            text: s.text,
            style: TextStyle(
              fontWeight: s.bold ? FontWeight.w800 : base,
              fontStyle: s.italic ? FontStyle.italic : null,
              fontFamily: s.code ? "monospace" : null,
              // Emphasis the tutor asked for should read as emphasis, not as a
              // different voice: same colour, heavier weight.
              color: ink,
            ),
          ),
      ];
}
