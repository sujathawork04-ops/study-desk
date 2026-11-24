// The pictures an explanation is made of. Eight kinds, all painted, all
// readable at phone width — the Dart twin of screens/Picture.tsx.
import "dart:math" as math;
import "package:flutter/material.dart";
import "../theme.dart";

class Picture extends StatelessWidget {
  const Picture({super.key, required this.spec});
  final Map<String, dynamic> spec;

  int _i(String k, int d) => spec[k] is num ? (spec[k] as num).toInt() : d;
  double _d(String k, double d) => spec[k] is num ? (spec[k] as num).toDouble() : d;
  String _s(String k, String d) => (spec[k] as String?) ?? d;

  @override
  Widget build(BuildContext context) {
    final label = spec["label"] as String?;
    final body = switch (spec["kind"]) {
      "fraction" => SizedBox(
          height: _s("shape", "bar") == "circle" ? 150 : 62,
          child: CustomPaint(
            size: Size.infinite,
            painter: _Fraction(_i("parts", 4), _i("shaded", 0), _s("shape", "bar") == "circle"),
          )),
      "objects" => _Objects(emoji: _s("emoji", "🔵"), count: _i("count", 6), groups: _i("groups", 0)),
      "numberline" => SizedBox(
          height: (spec["jumps"] is List && (spec["jumps"] as List).isNotEmpty) ? 100 : 76,
          child: CustomPaint(size: Size.infinite, painter: _NumberLine(spec))),
      "array" => _Array(rows: _i("rows", 1), cols: _i("cols", 1)),
      "steps" => _Steps(
          lines: ((spec["lines"] as List?) ?? const []).map((e) => e.toString()).toList(),
          highlight: _i("highlight", -1), note: spec["note"] as String?),
      "shape" => SizedBox(
          height: 150,
          child: CustomPaint(size: Size.infinite,
              painter: _Shape(_s("shape", "rectangle"), _d("a", 6), _d("b", 4), _d("deg", 45)))),
      "bars" => SizedBox(
          height: 150,
          child: CustomPaint(size: Size.infinite,
              painter: _Bars(((spec["data"] as List?) ?? const [])
                  .map((e) => (name: (e["name"] ?? "").toString(),
                               value: (e["value"] is num) ? (e["value"] as num).toDouble() : 0.0))
                  .toList()))),
      // The four below exist because the first eight were all arithmetic. Ask
      // what an oasis is, or where the Andaman Islands are, and there was
      // nothing to draw — so a subject that lives on pictures got paragraphs.
      "layers" => _Layers(
          bands: ((spec["bands"] as List?) ?? const [])
              .map((e) => (
                    name: (e["name"] ?? "").toString(),
                    note: (e["note"] ?? "").toString(),
                    fill: (e["fill"] ?? "").toString(),
                  ))
              .toList(),
          mark: spec["mark"] as String?),
      "cycle" => _Cycle(
          stages: ((spec["stages"] as List?) ?? const [])
              .map((e) => (
                    name: (e["name"] ?? "").toString(),
                    emoji: (e["emoji"] ?? "").toString(),
                  ))
              .toList()),
      "map" => _Map(
          water: _s("water", "around"),
          land: _s("land", "island"),
          places: ((spec["places"] as List?) ?? const [])
              .map((e) => (
                    name: (e["name"] ?? "").toString(),
                    x: (e["x"] is num) ? (e["x"] as num).toDouble() : 0.5,
                    y: (e["y"] is num) ? (e["y"] as num).toDouble() : 0.5,
                  ))
              .toList()),
      "compare" => _Compare(
          left: _s("left", ""),
          right: _s("right", ""),
          rows: ((spec["rows"] as List?) ?? const [])
              .map((e) => (
                    left: (e["left"] ?? "").toString(),
                    right: (e["right"] ?? "").toString(),
                  ))
              .toList()),
      _ => _Big(text: _s("big", "?"), note: spec["note"] as String?),
    };

    return Column(children: [
      body,
      if (label != null) ...[
        const SizedBox(height: 6),
        Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
      ],
    ]);
  }
}

// ------------------------------------------------------------------ fraction
class _Fraction extends CustomPainter {
  _Fraction(this.parts, this.shaded, this.circle);
  final int parts, shaded;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    final on = Paint()..color = C.blue;
    final off = Paint()..color = C.blueSoft;
    final edge = Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.white;

    if (circle) {
      final c = Offset(size.width / 2, size.height / 2);
      final r = math.min(size.width, size.height) / 2 - 6;
      for (var i = 0; i < parts; i++) {
        final a0 = i / parts * 2 * math.pi - math.pi / 2;
        final sweep = 2 * math.pi / parts;
        final rect = Rect.fromCircle(center: c, radius: r);
        canvas.drawArc(rect, a0, sweep, true, i < shaded ? on : off);
        canvas.drawArc(rect, a0, sweep, true, edge);
      }
      return;
    }

    const gap = 3.0;
    final w = (size.width - gap * (parts - 1)) / parts;
    for (var i = 0; i < parts; i++) {
      final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(i * (w + gap), 4, w, size.height - 10), const Radius.circular(6));
      canvas.drawRRect(r, i < shaded ? on : off);
      canvas.drawRRect(r, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = C.line);
    }
  }

  @override
  bool shouldRepaint(_Fraction o) => o.parts != parts || o.shaded != shaded || o.circle != circle;
}

// ------------------------------------------------------------------- objects
class _Objects extends StatelessWidget {
  const _Objects({required this.emoji, required this.count, required this.groups});
  final String emoji;
  final int count, groups;

  @override
  Widget build(BuildContext context) {
    final n = count.clamp(1, 40);
    final g = (groups > 1 && groups <= n) ? groups : 0;
    final per = g > 0 ? (n / g).ceil() : n;
    final chunks = g > 0
        ? [for (var i = 0; i < g; i++) math.max(0, math.min(per, n - i * per))]
        : [n];

    return Wrap(
      spacing: 10, runSpacing: 10, alignment: WrapAlignment.center,
      children: [
        for (final c in chunks)
          Container(
            constraints: const BoxConstraints(maxWidth: 150),
            padding: EdgeInsets.all(g > 0 ? 8 : 0),
            decoration: g > 0
                ? BoxDecoration(
                    border: Border.all(color: C.line, width: 2, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(12))
                : null,
            child: Wrap(
              spacing: 4, runSpacing: 2, alignment: WrapAlignment.center,
              children: [for (var i = 0; i < c; i++) Text(emoji, style: const TextStyle(fontSize: 24))],
            ),
          ),
      ],
    );
  }
}

// --------------------------------------------------------------- number line
class _NumberLine extends CustomPainter {
  _NumberLine(this.spec);
  final Map<String, dynamic> spec;

  double _n(String k, double d) => spec[k] is num ? (spec[k] as num).toDouble() : d;

  @override
  void paint(Canvas canvas, Size size) {
    final from = _n("from", 0), to = _n("to", 10), step = _n("step", 1);
    final steps = math.max(1, ((to - from) / step).round()).clamp(1, 60);
    final baseY = size.height - 28;
    double x(double v) => 20 + (v - from) / (to - from) * (size.width - 40);

    final grey = Paint()..color = C.line..strokeWidth = 3..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(20, baseY), Offset(size.width - 20, baseY), grey);

    final every = math.max(1, (steps / 10).round());
    for (var i = 0; i <= steps; i++) {
      final v = from + i * step;
      canvas.drawLine(Offset(x(v), baseY - 6), Offset(x(v), baseY + 6),
          Paint()..color = C.line..strokeWidth = 2);
      if (i % every == 0) _text(canvas, _label(v), Offset(x(v), baseY + 10), C.inkSoft, 11);
    }

    for (final j in (spec["jumps"] as List?) ?? const []) {
      final a = (j["from"] as num).toDouble(), b = (j["to"] as num).toDouble();
      final x1 = x(a), x2 = x(b), r = (x2 - x1).abs() / 2;
      final rect = Rect.fromLTRB(math.min(x1, x2), baseY - math.min(r, 26), math.max(x1, x2), baseY + math.min(r, 26));
      canvas.drawArc(rect, math.pi, math.pi, false,
          Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..color = C.warn);
      _text(canvas, (j["label"] as String?) ?? "+${_label(b - a)}",
          Offset((x1 + x2) / 2, baseY - math.min(r, 26) - 16), C.warn, 11, bold: true);
    }

    if (spec["mark"] is num) {
      final v = (spec["mark"] as num).toDouble();
      canvas.drawCircle(Offset(x(v), baseY), 9, Paint()..color = C.blue);
      _text(canvas, _label(v), Offset(x(v), baseY - 30), C.blue, 12, bold: true);
    }
  }

  String _label(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2);

  void _text(Canvas canvas, String s, Offset at, Color color, double size, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: color, fontSize: size,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(at.dx - tp.width / 2, at.dy));
  }

  @override
  bool shouldRepaint(_NumberLine o) => true;
}

// --------------------------------------------------------------------- array
class _Array extends StatelessWidget {
  const _Array({required this.rows, required this.cols});
  final int rows, cols;

  @override
  Widget build(BuildContext context) {
    final r = rows.clamp(1, 12), c = cols.clamp(1, 12);
    return Column(children: [
      for (var i = 0; i < r; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var j = 0; j < c; j++)
              Container(width: 16, height: 16, margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: const BoxDecoration(color: C.blue, shape: BoxShape.circle)),
          ]),
        ),
      const SizedBox(height: 6),
      Text("$r × $c = ${r * c}", style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

// --------------------------------------------------- a written method, lit up
class _Steps extends StatelessWidget {
  const _Steps({required this.lines, required this.highlight, this.note});
  final List<String> lines;
  final int highlight;
  final String? note;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines.length && i < 8; i++)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: i == highlight ? C.hi : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(lines[i], style: TextStyle(
                fontFamily: "monospace", fontSize: 16,
                fontWeight: i == highlight ? FontWeight.w700 : FontWeight.w400,
                color: i == highlight ? C.hiInk : null)),
            ),
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(note!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      );
}

// --------------------------------------------------------------------- shape
class _Shape extends CustomPainter {
  _Shape(this.kind, this.a, this.b, this.deg);
  final String kind;
  final double a, b, deg;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = C.blueSoft;
    final edge = Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = C.blue;
    final mark = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..color = C.warn;

    switch (kind) {
      case "angle":
        final d = deg.clamp(1, 179) * math.pi / 180;
        final o = Offset(30, size.height - 25);
        canvas.drawLine(o, Offset(size.width - 25, o.dy),
            Paint()..color = C.ink..strokeWidth = 3);
        canvas.drawLine(o, Offset(o.dx + 150 * math.cos(-d), o.dy + 150 * math.sin(-d)), edge);
        canvas.drawArc(Rect.fromCircle(center: o, radius: 40), -d, d, false, mark);
        _label(canvas, "${deg.round()}°", Offset(o.dx + 52, o.dy - 26), C.warn);
      case "circle":
        final c = size.center(Offset.zero);
        canvas.drawCircle(c, 60, fill);
        canvas.drawCircle(c, 60, edge);
        canvas.drawLine(c, Offset(c.dx + 60, c.dy), mark);
        _label(canvas, "r", Offset(c.dx + 26, c.dy - 20), C.warn);
      case "triangle":
        final p = Path()
          ..moveTo(25, size.height - 25)
          ..lineTo(size.width - 25, size.height - 25)
          ..lineTo(size.width / 2, 25)
          ..close();
        canvas.drawPath(p, fill);
        canvas.drawPath(p, edge);
        _label(canvas, _n(a), Offset(size.width / 2 - 6, size.height - 22), C.ink);
      default:
        final w = size.width - 50;
        final h = math.max(48.0, size.height - 60);
        final r = Rect.fromLTWH(25, 10, w, h);
        canvas.drawRect(r, fill);
        canvas.drawRect(r, edge);
        _label(canvas, _n(a), Offset(25 + w / 2 - 6, h + 16), C.ink);
        _label(canvas, _n(kind == "square" ? a : b), Offset(6, 10 + h / 2), C.ink);
    }
  }

  String _n(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  void _label(Canvas canvas, String s, Offset at, Color color) {
    TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout()..paint(canvas, at);
  }

  @override
  bool shouldRepaint(_Shape o) => o.kind != kind || o.a != a || o.b != b || o.deg != deg;
}

// ---------------------------------------------------------------------- bars
class _Bars extends CustomPainter {
  _Bars(this.data);
  final List<({String name, double value})> data;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final rows = data.take(7).toList();
    final maxV = rows.map((d) => d.value).reduce(math.max).clamp(1, double.infinity);
    final w = (size.width - 28) / rows.length;
    final baseY = size.height - 30;

    canvas.drawLine(Offset(14, baseY), Offset(size.width - 14, baseY),
        Paint()..color = C.line..strokeWidth = 2);

    for (var i = 0; i < rows.length; i++) {
      final h = rows[i].value / maxV * (baseY - 24);
      final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(16 + i * w + w * .15, baseY - h, w * .7, h), const Radius.circular(4));
      canvas.drawRRect(r, Paint()..color = i.isEven ? C.blue : C.done);
      _t(canvas, rows[i].value.toStringAsFixed(rows[i].value == rows[i].value.roundToDouble() ? 0 : 1),
          Offset(16 + i * w + w / 2, baseY - h - 16), C.ink, bold: true);
      _t(canvas, rows[i].name, Offset(16 + i * w + w / 2, baseY + 6), C.inkSoft);
    }
  }

  void _t(Canvas canvas, String s, Offset at, Color color, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: color, fontSize: 11,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(at.dx - tp.width / 2, at.dy));
  }

  @override
  bool shouldRepaint(_Bars o) => true;
}

// ---------------------------------------------------------- one big thing
class _Big extends StatelessWidget {
  const _Big({required this.text, this.note});
  final String text;
  final String? note;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(text, style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: C.blue)),
        if (note != null) Text(note!, style: Theme.of(context).textTheme.bodySmall),
      ]);
}


// ============================================================ layers
/// Horizontal bands, top to bottom, each named. A cross-section — which is how
/// a child is shown an oasis (sand, rock, water underneath), the layers of the
/// soil, the zones of the sea, the air above her.
class _Layers extends StatelessWidget {
  const _Layers({required this.bands, this.mark});
  final List<({String name, String note, String fill})> bands;
  final String? mark;

  static const _fills = <String, (Color, Color)>{
    "sand":  (Color(0xFFF3DFA8), Color(0xFF6B5418)),
    "water": (Color(0xFFBFE3FA), Color(0xFF12496E)),
    "rock":  (Color(0xFFCFD5E2), Color(0xFF2B3348)),
    "soil":  (Color(0xFFD9C3A5), Color(0xFF4A3520)),
    "grass": (Color(0xFFCDEBC0), Color(0xFF1F5B22)),
    "air":   (Color(0xFFE8F1FE), Color(0xFF2A4DB3)),
    "hot":   (Color(0xFFFBD9C4), Color(0xFF8A3310)),
  };

  @override
  Widget build(BuildContext context) {
    if (bands.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      for (var i = 0; i < bands.length; i++)
        Builder(builder: (_) {
          final b = bands[i];
          final pair = _fills[b.fill.toLowerCase()] ?? (C.blueSoft, C.ink);
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: pair.$1,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(i == 0 ? 12 : 0),
                bottom: Radius.circular(i == bands.length - 1 ? 12 : 0),
              ),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.name,
                      style: TextStyle(color: pair.$2, fontWeight: FontWeight.w700, fontSize: 14.5)),
                  if (b.note.isNotEmpty)
                    Text(b.note, style: TextStyle(color: pair.$2, fontSize: 12.5)),
                ]),
              ),
              if (mark != null && mark == b.name)
                Text("👈", style: TextStyle(color: pair.$2, fontSize: 16)),
            ]),
          );
        }),
    ]);
  }
}

// ============================================================ cycle
/// Stages that come round again — the water cycle, a seed becoming a plant,
/// day and night. Drawn as a ring of steps with arrows, so "it starts again"
/// is something she sees rather than something she is told.
class _Cycle extends StatelessWidget {
  const _Cycle({required this.stages});
  final List<({String name, String emoji})> stages;

  @override
  Widget build(BuildContext context) {
    if (stages.isEmpty) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 8,
      children: [
        for (var i = 0; i < stages.length; i++) ...[
          Container(
            constraints: const BoxConstraints(minWidth: 82, maxWidth: 132),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: dark ? C.dBlueSoft : C.blueSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (stages[i].emoji.isNotEmpty)
                Text(stages[i].emoji, style: const TextStyle(fontSize: 21)),
              Text(stages[i].name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: dark ? C.dInk : C.ink,
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          ),
          Text(i == stages.length - 1 ? "↻" : "→",
              style: TextStyle(fontSize: 19, color: dark ? C.dBlue : C.blue)),
        ],
      ],
    );
  }
}

// ============================================================ map
/// Not a real map — a sketch. Water, a piece of land in it, and named dots
/// where things are. Enough to answer "where is it, and what is round it",
/// which is what an island or a harbour or a desert town actually needs.
class _Map extends StatelessWidget {
  const _Map({required this.water, required this.land, required this.places});
  final String water, land;
  final List<({String name, double x, double y})> places;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 190,
        child: CustomPaint(
          size: Size.infinite,
          painter: _MapPainter(land: land, places: places),
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(water,
                  style: const TextStyle(
                      color: Color(0xFF12496E), fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      );
}

class _MapPainter extends CustomPainter {
  _MapPainter({required this.land, required this.places});
  final String land;
  final List<({String name, double x, double y})> places;

  @override
  void paint(Canvas c, Size s) {
    final sea = Paint()..color = const Color(0xFFBFE3FA);
    c.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(12)), sea);

    // A soft blob of land. Islands get two, a coast gets one big one.
    final ground = Paint()..color = const Color(0xFFCDEBC0);
    final edge = Paint()
      ..color = const Color(0xFF1F5B22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    void blob(double cx, double cy, double rx, double ry) {
      final path = Path()
        ..addOval(Rect.fromCenter(
            center: Offset(cx * s.width, cy * s.height),
            width: rx * s.width, height: ry * s.height));
      c.drawPath(path, ground);
      c.drawPath(path, edge);
    }

    switch (land) {
      case "islands":
        blob(0.36, 0.42, 0.30, 0.42);
        blob(0.66, 0.68, 0.20, 0.26);
      case "coast":
        blob(0.15, 0.5, 0.72, 1.3);
      default:
        blob(0.5, 0.5, 0.52, 0.66);
    }

    for (final p in places) {
      final at = Offset(p.x * s.width, p.y * s.height);
      c.drawCircle(at, 5, Paint()..color = const Color(0xFFC2410C));
      final tp = TextPainter(
        text: TextSpan(
            text: p.name,
            style: const TextStyle(
                color: Color(0xFF1B2A5E), fontSize: 11.5, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: s.width * 0.5);
      // Keep the label inside the picture even for a dot near the right edge.
      final dx = (at.dx + 9 + tp.width > s.width) ? at.dx - 9 - tp.width : at.dx + 9;
      tp.paint(c, Offset(dx, at.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) =>
      old.land != land || old.places.length != places.length;
}

// ============================================================ compare
/// Two things side by side, one row per difference. An island against a
/// peninsula, a village against a city, a desert against a forest — the shape
/// most Social questions actually have.
class _Compare extends StatelessWidget {
  const _Compare({required this.left, required this.right, required this.rows});
  final String left, right;
  final List<({String left, String right})> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final head = TextStyle(
        fontWeight: FontWeight.w700, fontSize: 14, color: dark ? C.dBlue : C.blue);
    final cell = TextStyle(fontSize: 13, color: dark ? C.dInk : C.ink);

    return Container(
      decoration: BoxDecoration(
        color: dark ? C.dPaper : C.paper,
        border: Border.all(color: dark ? C.dLine : C.line),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(left, style: head)),
          const SizedBox(width: 10),
          Expanded(child: Text(right, style: head)),
        ]),
        const SizedBox(height: 6),
        for (final r in rows) ...[
          Divider(height: 12, color: dark ? C.dLine : C.line),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(r.left, style: cell)),
            const SizedBox(width: 10),
            Expanded(child: Text(r.right, style: cell)),
          ]),
        ],
      ]),
    );
  }
}
