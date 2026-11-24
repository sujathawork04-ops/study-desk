// Chinnu — the study companion. Painted rather than shipped as an image, so it
// stays sharp at any size and costs nothing to load.
import "dart:math" as math;
import "package:flutter/material.dart";

enum Mood { hello, cheer, think, rest }

class Mascot extends StatelessWidget {
  const Mascot({super.key, this.mood = Mood.hello, this.size = 62});
  final Mood mood;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size, height: size,
        child: CustomPaint(painter: _MascotPainter(mood)),
      );
}

class _MascotPainter extends CustomPainter {
  _MascotPainter(this.mood);
  final Mood mood;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;   // the drawing is designed on a 100×100 grid
    Offset p(double x, double y) => Offset(x * s, y * s);

    final ink = Paint()..color = const Color(0xFF1B2A5E);
    final tuft = Paint()..color = const Color(0xFFFFE45C);

    // tuft on top
    final star = Path()
      ..moveTo(50 * s, 8 * s)
      ..cubicTo(54 * s, 16 * s, 58 * s, 18 * s, 62 * s, 19 * s)
      ..cubicTo(56 * s, 22 * s, 52 * s, 26 * s, 50 * s, 32 * s)
      ..cubicTo(48 * s, 26 * s, 44 * s, 22 * s, 38 * s, 19 * s)
      ..cubicTo(42 * s, 18 * s, 46 * s, 16 * s, 50 * s, 8 * s)
      ..close();
    canvas.drawPath(star, tuft);

    // body
    canvas.drawCircle(p(50, 56), 34 * s, Paint()..color = Colors.white.withValues(alpha: .96));
    canvas.drawCircle(p(50, 56), 34 * s,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 2 * s
          ..color = const Color(0xFF1B2A5E).withValues(alpha: .12));

    // cheeks
    final cheek = Paint()..color = const Color(0xFFFFB3C7).withValues(alpha: .75);
    canvas.drawCircle(p(26, 58), 6 * s, cheek);
    canvas.drawCircle(p(74, 58), 6 * s, cheek);

    // eyes
    if (mood == Mood.rest) {
      final lid = Paint()
        ..style = PaintingStyle.stroke..strokeWidth = 3.4 * s
        ..strokeCap = StrokeCap.round..color = const Color(0xFF1B2A5E);
      canvas.drawArc(Rect.fromLTWH(30 * s, 38 * s, 12 * s, 9 * s), 0, math.pi, false, lid);
      canvas.drawArc(Rect.fromLTWH(58 * s, 38 * s, 12 * s, 9 * s), 0, math.pi, false, lid);
    } else {
      canvas.drawCircle(p(36, 43), 5 * s, ink);
      canvas.drawCircle(p(64, 43), 5 * s, ink);
    }

    // mouth
    if (mood == Mood.cheer) {
      final smile = Path()
        ..moveTo(38 * s, 62 * s)
        ..quadraticBezierTo(50 * s, 76 * s, 62 * s, 62 * s)
        ..quadraticBezierTo(50 * s, 68 * s, 38 * s, 62 * s)
        ..close();
      canvas.drawPath(smile, ink);
    } else {
      final line = Paint()
        ..style = PaintingStyle.stroke..strokeWidth = 3.4 * s
        ..strokeCap = StrokeCap.round..color = const Color(0xFF1B2A5E);
      final m = Path()..moveTo(40 * s, mood == Mood.think ? 66 * s : 63 * s);
      if (mood == Mood.think) {
        m.quadraticBezierTo(48 * s, 62 * s, 58 * s, 67 * s);
      } else {
        m.quadraticBezierTo(50 * s, 72 * s, 60 * s, 63 * s);
      }
      canvas.drawPath(m, line);
    }

    if (mood == Mood.cheer) {
      _spark(canvas, p(13, 33), 8 * s, tuft);
      _spark(canvas, p(88, 36), 6 * s, tuft);
    }
  }

  void _spark(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final rr = i.isEven ? r : r * .38;
      final pt = Offset(c.dx + rr * math.cos(a), c.dy + rr * math.sin(a));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path..close(), paint);
  }

  @override
  bool shouldRepaint(_MascotPainter old) => old.mood != mood;
}

/// The ring of "how much of today is finished" that sits around the mascot.
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.pct, this.size = 80});
  final int pct;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size, height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: pct / 100),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => CustomPaint(painter: _RingPainter(v)),
        ),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 3;
    final bg = Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 6
      ..color = Colors.white.withValues(alpha: .25);
    final fg = Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 6
      ..strokeCap = StrokeCap.round..color = const Color(0xFFFFE45C);
    canvas.drawCircle(c, r, bg);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * t, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t;
}

/// A gentle up-and-down, switched off when the system asks for less motion.
class Bob extends StatefulWidget {
  const Bob({super.key, required this.child});
  final Widget child;
  @override
  State<Bob> createState() => _BobState();
}

class _BobState extends State<Bob> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3400))..repeat(reverse: true);

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, -5 * Curves.easeInOut.transform(_c.value)),
        child: child,
      ),
      child: widget.child,
    );
  }
}
