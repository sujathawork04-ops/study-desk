// The things she can move. She acts, presses Check, and what she did is sent
// to the tutor as her next message — the Dart twin of screens/Widget.tsx.
import "dart:math" as math;
import "package:flutter/material.dart";
import "../blocks.dart";
import "../rules.dart";
import "../theme.dart";

class Manipulative extends StatefulWidget {
  const Manipulative({super.key, required this.spec, required this.onSend, this.disabled = false});
  final WidgetSpec spec;
  final void Function(String text) onSend;
  final bool disabled;

  @override
  State<Manipulative> createState() => _ManipulativeState();
}

class _ManipulativeState extends State<Manipulative> {
  late Object? value = _initial();
  bool? checked;
  int tries = 0;

  Object? _initial() => switch (widget.spec.type) {
        "fraction" => 0,
        "numberline" => widget.spec.d("from", 0),
        "array" => (r: 0, c: 0),
        "placevalue" => widget.spec.i("start", 0),
        "clock" => (h: widget.spec.i("hour", 12), m: widget.spec.i("minute", 0)),
        "order" => (widget.spec.list("items")..shuffle(math.Random())),
        // Start the machine at its least helpful setting, so the discovery that
        // moving it helps is hers to make rather than handed over.
        "machine" => machineRange(widget.spec.s("machine", "pulley")).min,
        "sort" => <String, String>{},
        _ => 0,
      };

  void _touch(Object? v) => setState(() { value = v; checked = null; });

  void _check() {
    final flat = switch (widget.spec.type) {
      "sort" => value,
      "machine" => value,
      "array" => (value as ({int r, int c})).r * (value as ({int r, int c})).c,
      "clock" => "${(value as ({int h, int m})).h}:${(value as ({int h, int m})).m.toString().padLeft(2, "0")}",
      _ => value,
    };
    final right = widget.spec.isRight(flat);
    setState(() { checked = right; tries++; });
    // Right, or unknown, or tried twice — either way the tutor takes it from here.
    if (right != false || tries >= 2) widget.onSend(widget.spec.describe(flat));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? C.dGround : C.ground,
        border: Border.all(color: dark ? C.dLine : C.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.spec.ask, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        _stage(),
        const SizedBox(height: 10),
        Row(children: [
          FilledButton(onPressed: widget.disabled ? null : _check, child: const Text("Check ✓")),
          const SizedBox(width: 10),
          if (checked != null)
            Expanded(
              child: Text(
                checked!
                    ? "Yes! That's it 🌟"
                    : tries >= 2
                        ? "Not yet — let's look at it together."
                        : "Not quite. Try moving it once more 🙂",
                style: TextStyle(fontWeight: FontWeight.w700, color: checked! ? C.done : C.warn),
              ),
            ),
        ]),
      ]),
    );
  }

  Widget _stage() => switch (widget.spec.type) {
        "fraction" => _FractionTap(spec: widget.spec, shaded: value as int, onTap: _touch),
        "numberline" => _NumberLinePick(spec: widget.spec, value: value as double, onPick: _touch),
        "array" => _ArrayBuild(spec: widget.spec, rc: value as ({int r, int c}), onPick: _touch),
        "placevalue" => _PlaceValue(spec: widget.spec, value: value as int, onChange: _touch),
        "clock" => _ClockSet(hm: value as ({int h, int m}), onChange: _touch),
        "order" => _Order(items: (value as List).cast<String>(), onChange: _touch),
        "machine" => _MachineTry(spec: widget.spec, setting: value as int, onChange: _touch),
        "sort" => _SortCards(
            spec: widget.spec,
            placed: (value as Map).cast<String, String>(),
            onChange: _touch),
        _ => _Balance(spec: widget.spec, value: value as int, onChange: _touch),
      };
}

// ------------------------------------------------------------------ fraction
class _FractionTap extends StatelessWidget {
  const _FractionTap({required this.spec, required this.shaded, required this.onTap});
  final WidgetSpec spec;
  final int shaded;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final n = spec.i("parts", 4);
    return Row(
      children: [
        for (var i = 0; i < n; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => onTap(i + 1 == shaded ? i : i + 1),
              child: Container(
                height: 48,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: i < shaded ? C.blue : C.blueSoft,
                  border: Border.all(color: C.line),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// --------------------------------------------------------------- number line
class _NumberLinePick extends StatelessWidget {
  const _NumberLinePick({required this.spec, required this.value, required this.onPick});
  final WidgetSpec spec;
  final double value;
  final void Function(double) onPick;

  @override
  Widget build(BuildContext context) {
    final from = spec.d("from", 0), to = spec.d("to", 10), step = spec.d("step", 1);
    final steps = ((to - from) / step).round().clamp(1, 200);
    return Column(children: [
      Text(value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(2),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: C.blue)),
      Slider(
        value: ((value - from) / step).clamp(0, steps.toDouble()),
        min: 0, max: steps.toDouble(), divisions: steps,
        label: value.toString(),
        onChanged: (v) => onPick(double.parse((from + v * step).toStringAsFixed(4))),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(from.toStringAsFixed(0), style: Theme.of(context).textTheme.bodySmall),
        Text(to.toStringAsFixed(0), style: Theme.of(context).textTheme.bodySmall),
      ]),
    ]);
  }
}

// --------------------------------------------------------------------- array
class _ArrayBuild extends StatelessWidget {
  const _ArrayBuild({required this.spec, required this.rc, required this.onPick});
  final WidgetSpec spec;
  final ({int r, int c}) rc;
  final void Function(({int r, int c})) onPick;

  @override
  Widget build(BuildContext context) {
    final rows = spec.i("rows", 4), cols = spec.i("cols", 3);
    return Column(children: [
      for (var r = 0; r < rows; r++)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var c = 0; c < cols; c++)
            GestureDetector(
              onTap: () => onPick((r: r + 1, c: c + 1)),
              child: Container(
                width: 22, height: 22, margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: (r < rc.r && c < rc.c) ? C.blue : C.blueSoft,
                  border: Border.all(color: C.line),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ]),
      const SizedBox(height: 6),
      Text("${rc.r} rows × ${rc.c} in each = ${rc.r * rc.c}",
          style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

// --------------------------------------------------------------- place value
class _PlaceValue extends StatelessWidget {
  const _PlaceValue({required this.spec, required this.value, required this.onChange});
  final WidgetSpec spec;
  final int value;
  final void Function(int) onChange;

  static const _places = [(1000, "Thousands"), (100, "Hundreds"), (10, "Tens"), (1, "Ones")];

  @override
  Widget build(BuildContext context) {
    final max = spec.i("max", 9999);
    final s = value.clamp(0, max).toString().padLeft(4, "0");
    final digits = {1000: int.parse(s[0]), 100: int.parse(s[1]), 10: int.parse(s[2]), 1: int.parse(s[3])};

    return Column(children: [
      Row(children: [
        for (final (v, name) in _places.where((p) => p.$1 <= max))
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(color: C.line), borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Text(name, maxLines: 1, overflow: TextOverflow.clip,
                    style: const TextStyle(fontSize: 10, color: C.inkSoft)),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _tap("−", () { if (digits[v]! > 0) onChange(value - v); }),
                  Text("${digits[v]}", style: const TextStyle(fontWeight: FontWeight.w700)),
                  _tap("+", () { if (digits[v]! < 9 && value + v <= max) onChange(value + v); }),
                ]),
              ]),
            ),
          ),
      ]),
      const SizedBox(height: 8),
      Text("$value", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
    ]);
  }

  Widget _tap(String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(label, style: const TextStyle(fontSize: 15, color: C.blue)),
        ),
      );
}

// --------------------------------------------------------------------- clock
class _ClockSet extends StatelessWidget {
  const _ClockSet({required this.hm, required this.onChange});
  final ({int h, int m}) hm;
  final void Function(({int h, int m})) onChange;

  @override
  Widget build(BuildContext context) => Column(children: [
        SizedBox(width: 170, height: 170, child: CustomPaint(painter: _ClockFace(hm.h, hm.m))),
        Text("${hm.h}:${hm.m.toString().padLeft(2, "0")}",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        Text("Hour hand", style: Theme.of(context).textTheme.bodySmall),
        Slider(value: hm.h.toDouble(), min: 1, max: 12, divisions: 11,
            onChanged: (v) => onChange((h: v.round(), m: hm.m))),
        Text("Minute hand", style: Theme.of(context).textTheme.bodySmall),
        Slider(value: hm.m.toDouble(), min: 0, max: 55, divisions: 11,
            onChanged: (v) => onChange((h: hm.h, m: v.round()))),
      ]);
}

class _ClockFace extends CustomPainter {
  _ClockFace(this.h, this.m);
  final int h, m;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 6;
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = C.line);

    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6 - math.pi / 2;
      final p = Offset(c.dx + (r - 18) * math.cos(a), c.dy + (r - 18) * math.sin(a));
      final tp = TextPainter(
        text: TextSpan(text: "${i == 0 ? 12 : i}",
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.inkSoft)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }

    final hA = ((h % 12) + m / 60) * math.pi / 6 - math.pi / 2;
    final mA = m * math.pi / 30 - math.pi / 2;
    canvas.drawLine(c, Offset(c.dx + r * .5 * math.cos(hA), c.dy + r * .5 * math.sin(hA)),
        Paint()..color = C.blue..strokeWidth = 7..strokeCap = StrokeCap.round);
    canvas.drawLine(c, Offset(c.dx + r * .78 * math.cos(mA), c.dy + r * .78 * math.sin(mA)),
        Paint()..color = C.warn..strokeWidth = 4..strokeCap = StrokeCap.round);
    canvas.drawCircle(c, 5, Paint()..color = C.ink);
  }

  @override
  bool shouldRepaint(_ClockFace o) => o.h != h || o.m != m;
}

// --------------------------------------------------------------------- order
class _Order extends StatelessWidget {
  const _Order({required this.items, required this.onChange});
  final List<String> items;
  final void Function(List<String>) onChange;

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < items.length; i++)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: C.line), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              SizedBox(width: 20, child: Text("${i + 1}", style: Theme.of(context).textTheme.bodySmall)),
              Expanded(child: Text(items[i])),
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 18),
                onPressed: i == 0 ? null : () => onChange(_swap(i, i - 1)),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward, size: 18),
                onPressed: i == items.length - 1 ? null : () => onChange(_swap(i, i + 1)),
              ),
            ]),
          ),
      ]);

  List<String> _swap(int a, int b) {
    final x = [...items];
    final t = x[a]; x[a] = x[b]; x[b] = t;
    return x;
  }
}

// ------------------------------------------------------------------- balance
class _Balance extends StatelessWidget {
  const _Balance({required this.spec, required this.value, required this.onChange});
  final WidgetSpec spec;
  final int value;
  final void Function(int) onChange;

  @override
  Widget build(BuildContext context) {
    final target = spec.answerNum?.toInt() ?? spec.i("left", 0);
    final tilt = ((value - target) * 4).clamp(-12, 12).toDouble();
    return Column(children: [
      SizedBox(
        height: 120,
        child: CustomPaint(size: Size.infinite,
            painter: _Scale(tilt, "$value", spec.s("right", "?"))),
      ),
      Text(tilt == 0 ? "balanced ⚖️" : tilt < 0 ? "left side too light" : "left side too heavy",
          style: Theme.of(context).textTheme.bodySmall),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        OutlinedButton(onPressed: () => onChange(math.max(0, value - 1)), child: const Text("−1")),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text("$value", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
        OutlinedButton(onPressed: () => onChange(value + 1), child: const Text("+1")),
      ]),
    ]);
  }
}

class _Scale extends CustomPainter {
  _Scale(this.tilt, this.left, this.right);
  final double tilt;
  final String left, right;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.width / 2;
    canvas.save();
    canvas.translate(mid, 40);
    canvas.rotate(tilt * math.pi / 180);
    canvas.translate(-mid, -40);

    canvas.drawLine(Offset(mid - 110, 40), Offset(mid + 110, 40),
        Paint()..color = C.line..strokeWidth = 6..strokeCap = StrokeCap.round);
    _pan(canvas, Offset(mid - 110, 44), left);
    _pan(canvas, Offset(mid + 40, 44), right);
    canvas.restore();

    canvas.drawLine(Offset(mid, 40), Offset(mid, 105), Paint()..color = C.line..strokeWidth = 6);
    canvas.drawLine(Offset(mid - 38, 107), Offset(mid + 38, 107),
        Paint()..color = C.line..strokeWidth = 6..strokeCap = StrokeCap.round);
  }

  void _pan(Canvas canvas, Offset at, String text) {
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(at.dx, at.dy, 70, 34), const Radius.circular(8));
    canvas.drawRRect(r, Paint()..color = C.blueSoft);
    canvas.drawRRect(r, Paint()..style = PaintingStyle.stroke..color = C.line);
    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: C.blue, fontSize: 15, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 66);
    tp.paint(canvas, Offset(at.dx + 35 - tp.width / 2, at.dy + 8));
  }

  @override
  bool shouldRepaint(_Scale o) => o.tilt != tilt || o.left != left || o.right != right;
}

// ------------------------------------------------------------- simple machines
/// A machine she sets, with the effort shown as she moves it.
///
/// The readout is the whole point. She is not told "a pulley reduces effort" —
/// she slides it and watches 100 become 50 become 25, and the line underneath
/// tells her what she just paid for that in rope.
class _MachineTry extends StatelessWidget {
  const _MachineTry({required this.spec, required this.setting, required this.onChange});
  final WidgetSpec spec;
  final int setting;
  final void Function(int) onChange;

  @override
  Widget build(BuildContext context) {
    final kind = spec.s("machine", "pulley");
    final load = spec.i("load", 100);
    final height = spec.i("height", 1);
    final r = machineRange(kind);
    final out = machineEffort(kind, load, setting, height: height);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final helps = out.effort < load;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 150,
        child: CustomPaint(
          size: Size.infinite,
          painter: _MachinePaint(kind, setting, load, height, dark),
        ),
      ),
      const SizedBox(height: 6),
      // Load and effort side by side, because the comparison IS the lesson.
      Row(children: [
        _Readout(label: "Load", value: "$load", tone: C.inkSoft),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text("→", style: TextStyle(fontSize: 18)),
        ),
        _Readout(
          label: "You pull",
          value: prettyEffort(out.effort),
          tone: helps ? C.done : C.warn,
        ),
      ]),
      const SizedBox(height: 8),
      Text(r.label, style: Theme.of(context).textTheme.bodySmall),
      Row(children: [
        OutlinedButton(
          onPressed: setting <= r.min ? null : () => onChange(setting - 1),
          child: const Text("−"),
        ),
        Expanded(
          child: Slider(
            value: setting.clamp(r.min, r.max).toDouble(),
            min: r.min.toDouble(),
            max: r.max.toDouble(),
            divisions: r.max - r.min,
            label: "$setting",
            onChanged: (v) => onChange(v.round()),
          ),
        ),
        OutlinedButton(
          onPressed: setting >= r.max ? null : () => onChange(setting + 1),
          child: const Text("+"),
        ),
      ]),
      Text(out.how, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _Readout extends StatelessWidget {
  const _Readout({required this.label, required this.value, required this.tone});
  final String label, value;
  final Color tone;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: tone)),
        ],
      );
}

class _MachinePaint extends CustomPainter {
  _MachinePaint(this.kind, this.setting, this.load, this.height, this.dark);
  final String kind;
  final int setting, load, height;
  final bool dark;

  Color get _line => dark ? C.dLine : C.line;
  Color get _ink => dark ? C.dInk : C.ink;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case "lever":
        _lever(canvas, size);
      case "ramp":
        _ramp(canvas, size);
      default:
        _pulley(canvas, size);
    }
  }

  Paint get _stroke => Paint()
    ..color = _line
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;

  void _label(Canvas canvas, String text, Offset at, {Color? color, double sz = 12}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color ?? _ink, fontSize: sz, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(at.dx - tp.width / 2, at.dy));
  }

  // One wheel per rope holding the load, so she can count the strands herself.
  void _pulley(Canvas canvas, Size size) {
    final mid = size.width / 2;
    canvas.drawLine(Offset(mid - 90, 14), Offset(mid + 90, 14), _stroke);
    for (var k = 0; k < setting; k++) {
      final x = mid - (setting - 1) * 14 + k * 28;
      canvas.drawCircle(Offset(x, 34), 11, Paint()..color = C.blueSoft);
      canvas.drawCircle(Offset(x, 34), 11, _stroke..style = PaintingStyle.stroke);
      canvas.drawLine(Offset(x, 45), Offset(x, 96),
          Paint()..color = C.sky..strokeWidth = 3);
      canvas.drawLine(Offset(x, 14), Offset(x, 23),
          Paint()..color = _line..strokeWidth = 3);
    }
    final box = Rect.fromCenter(center: Offset(mid, 112), width: 74, height: 32);
    canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(6)),
        Paint()..color = C.blueSoft);
    canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(6)),
        Paint()..style = PaintingStyle.stroke..color = _line..strokeWidth = 3);
    _label(canvas, "$load", Offset(mid, 103), color: C.blue, sz: 15);
    _label(canvas, setting == 1 ? "1 rope" : "$setting ropes", Offset(mid, 133));
  }

  // The fulcrum slides; the bar tips the way the arms say it should.
  void _lever(Canvas canvas, Size size) {
    final left = size.width * 0.12, right = size.width * 0.88;
    final span = right - left;
    final fx = left + span * (setting / 10);
    final effortArm = 10 - setting;
    // Down on the heavy side. When the effort arm is the longer one the load
    // end rises, so the bar leans the way the arms say it should. The arms
    // differ by at most 8 steps; 1.4 degrees each keeps the lean visible
    // without the bar standing on end.
    final tip = ((effortArm - setting) * 1.4).clamp(-11.0, 11.0).toDouble();

    canvas.save();
    canvas.translate(fx, 70);
    canvas.rotate(-tip * math.pi / 180);
    canvas.translate(-fx, -70);
    canvas.drawLine(Offset(left, 70), Offset(right, 70), _stroke);
    final box = Rect.fromCenter(center: Offset(left + 8, 56), width: 44, height: 24);
    canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(5)),
        Paint()..color = C.blueSoft);
    _label(canvas, "$load", Offset(left + 8, 48), color: C.blue);
    _label(canvas, "push", Offset(right - 10, 48), color: C.done);
    canvas.restore();

    // The fulcrum: a triangle, which is how her book draws it.
    final tri = Path()
      ..moveTo(fx, 72)
      ..lineTo(fx - 13, 100)
      ..lineTo(fx + 13, 100)
      ..close();
    canvas.drawPath(tri, Paint()..color = C.hi);
    canvas.drawPath(tri, Paint()..style = PaintingStyle.stroke..color = _line..strokeWidth = 3);
    _label(canvas, "fulcrum", Offset(fx, 104));
    _label(canvas, "$setting", Offset(left + span * setting / 20, 118), color: C.inkSoft);
    _label(canvas, "$effortArm",
        Offset(fx + (right - fx) / 2, 118), color: C.inkSoft);
  }

  // A right triangle whose slope lengthens with the setting.
  void _ramp(Canvas canvas, Size size) {
    final baseY = 118.0;
    final x0 = size.width * 0.1;
    final h = 20.0 * height;
    final len = math.min(size.width * 0.78, 34.0 * setting + 34);
    final tri = Path()
      ..moveTo(x0, baseY)
      ..lineTo(x0 + len, baseY)
      ..lineTo(x0 + len, baseY - h)
      ..close();
    canvas.drawPath(tri, Paint()..color = C.blueSoft);
    canvas.drawPath(tri, Paint()..style = PaintingStyle.stroke..color = _line..strokeWidth = 3);

    // The load sits a third of the way up the slope.
    final t = 0.34;
    final at = Offset(x0 + len * t, baseY - h * t);
    canvas.drawCircle(at, 13, Paint()..color = C.sun);
    canvas.drawCircle(at, 13, Paint()..style = PaintingStyle.stroke..color = _line..strokeWidth = 3);
    _label(canvas, "$load", Offset(at.dx, at.dy - 6), color: C.hiInk, sz: 11);
    _label(canvas, "slope $setting long", Offset(x0 + len / 2, baseY + 6));
    _label(canvas, "height $height", Offset(x0 + len + 2, baseY - h - 16));
  }

  @override
  bool shouldRepaint(_MachinePaint o) =>
      o.setting != setting || o.load != load || o.kind != kind ||
      o.height != height || o.dark != dark;
}

// ------------------------------------------------------------ sort into groups
/// Tap a card, then tap the group it belongs in. Works in any language, because
/// nothing here is drawn — the words are whatever the tutor sent.
class _SortCards extends StatefulWidget {
  const _SortCards({required this.spec, required this.placed, required this.onChange});
  final WidgetSpec spec;
  final Map<String, String> placed;
  final void Function(Map<String, String>) onChange;

  @override
  State<_SortCards> createState() => _SortCardsState();
}

class _SortCardsState extends State<_SortCards> {
  String? holding;

  @override
  Widget build(BuildContext context) {
    final items = widget.spec.sortItems;
    final groups = sortGroups(widget.spec.list("groups"), items);
    final waiting = items.where((i) => !widget.placed.containsKey(i.it)).toList();
    final dark = Theme.of(context).brightness == Brightness.dark;

    void put(String group) {
      final held = holding;
      if (held == null) return;
      widget.onChange({...widget.placed, held: group});
      setState(() => holding = null);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (waiting.isNotEmpty)
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final i in waiting)
            _Card(
              text: i.it,
              held: holding == i.it,
              dark: dark,
              onTap: () => setState(() => holding = holding == i.it ? null : i.it),
            ),
        ]),
      if (waiting.isNotEmpty) const SizedBox(height: 4),
      Text(
        holding == null
            ? "Tap a word, then tap the group it belongs to."
            : "Now tap where “$holding” goes.",
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      for (final g in groups)
        GestureDetector(
          onTap: () => put(g),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: holding == null
                  ? null
                  : (dark ? C.dBlueSoft : C.blueSoft).withValues(alpha: 0.5),
              border: Border.all(
                  color: holding == null ? (dark ? C.dLine : C.line) : C.sky, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final e in widget.placed.entries.where((e) => e.value == g))
                  _Card(
                    text: e.key,
                    held: false,
                    dark: dark,
                    // Tapping a placed card takes it back out, so a mistake is
                    // fixable without starting the whole thing again.
                    onTap: () {
                      final next = {...widget.placed}..remove(e.key);
                      widget.onChange(next);
                    },
                  ),
              ]),
            ]),
          ),
        ),
    ]);
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.text, required this.held, required this.dark, required this.onTap});
  final String text;
  final bool held, dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: held ? C.hi : (dark ? C.dPaper : C.paper),
            border: Border.all(color: held ? C.sun : (dark ? C.dLine : C.line), width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(text,
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: held ? C.hiInk : null)),
        ),
      );
}
