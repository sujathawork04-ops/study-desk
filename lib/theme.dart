import "package:flutter/material.dart";

import "rules.dart";

/// Light, dark, or follow the device — changed from Settings ⚙️.
final ValueNotifier<ThemeMode> appTheme = ValueNotifier(ThemeMode.system);

ThemeMode themeModeFrom(String? s) => switch (s) {
      "light" => ThemeMode.light,
      "dark" => ThemeMode.dark,
      _ => ThemeMode.system,
    };

String themeModeName(ThemeMode m) => switch (m) {
      ThemeMode.light => "light",
      ThemeMode.dark => "dark",
      ThemeMode.system => "system",
    };

/// The same palette as the web app, so the two feel like one product.
class C {
  static const blue = Color(0xFF2A4DB3);
  static const blueSoft = Color(0xFFE3EAFC);
  static const sky = Color(0xFF38A3F1);
  static const ink = Color(0xFF1B2A5E);
  static const inkSoft = Color(0xFF4F5E8A);
  static const ground = Color(0xFFEEF3FB);
  static const paper = Color(0xFFFFFFFF);
  static const line = Color(0xFFD3DCEF);
  static const done = Color(0xFF1F8A5B);
  static const doneSoft = Color(0xFFDCF3E8);
  static const warn = Color(0xFFC2410C);
  static const warnSoft = Color(0xFFFDEBDF);
  static const hi = Color(0xFFFFE45C);
  static const hiInk = Color(0xFF5A4700);
  static const sun = Color(0xFFFFB020);

  // dark
  static const dInk = Color(0xFFE4E9FF);
  static const dInkSoft = Color(0xFFB0BBE0);
  static const dGround = Color(0xFF12162A);
  static const dPaper = Color(0xFF1B2136);
  static const dLine = Color(0xFF2C3556);
  static const dBlue = Color(0xFF8EA8FF);
  static const dBlueSoft = Color(0xFF243058);
}

ThemeData studyTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: C.blue,
    brightness: b,
    primary: dark ? C.dBlue : C.blue,
    surface: dark ? C.dPaper : C.paper,
  );
  final onSurface = dark ? C.dInk : C.ink;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? C.dGround : C.ground,
    // Baloo 2 and Atkinson Hyperlegible if you add them to assets; the system
    // font is used otherwise so the app runs with no downloads.
    fontFamily: null,
    textTheme: TextTheme(
      headlineSmall: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: onSurface),
      titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: onSurface),
      titleMedium: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: onSurface),
      bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: onSurface),
      bodyMedium: TextStyle(fontSize: 15, height: 1.45, color: onSurface),
      bodySmall: TextStyle(fontSize: 13.5, color: dark ? C.dInkSoft : C.inkSoft),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? C.dPaper : C.paper,
      // Without this, Flutter's default padding makes every box tall enough to
      // look like a text area rather than a single line.
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      floatingLabelStyle: TextStyle(color: dark ? C.dBlue : C.blue, fontWeight: FontWeight.w700),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: dark ? C.dLine : C.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: dark ? C.dLine : C.line),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: dark ? C.dPaper : C.paper,
      indicatorColor: dark ? C.dBlueSoft : C.blueSoft,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.all(TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: dark ? C.dInkSoft : C.inkSoft,
      )),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: dark ? C.dPaper : C.paper,
      selectedColor: dark ? C.dBlueSoft : C.blueSoft,
      side: BorderSide(color: dark ? C.dLine : C.line),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14.5,
        color: dark ? C.dInk : C.ink,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      shape: const StadiumBorder(),
      showCheckmark: false,
    ),
  );
}

/// Keeps a page readable on a wide screen: one centred column instead of
/// text stretched across a whole laptop monitor. A no-op on a phone.
class Bounded extends StatelessWidget {
  const Bounded({super.key, required this.child, this.maxWidth = 760, this.alignment = Alignment.topCenter});
  final Widget child;
  final double maxWidth;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => Align(
        alignment: alignment,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}

/// A big, friendly, tappable card — the child-facing equivalent of a button.
class BigChoice extends StatelessWidget {
  const BigChoice({super.key, required this.emoji, required this.title, this.subtitle, required this.onTap});
  final String emoji;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? C.dPaper : C.paper,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(children: [
            Container(
              width: 40, height: 40, alignment: Alignment.center,
              decoration: BoxDecoration(
                color: dark ? C.dBlueSoft : C.blueSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (subtitle != null)
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: dark ? C.dInkSoft : C.inkSoft),
          ]),
        ),
      ),
    );
  }
}

/// The white rounded card every screen is built from.
class Sheet extends StatelessWidget {
  const Sheet({super.key, required this.child, this.tint});
  final Widget child;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint ?? (dark ? C.dPaper : C.paper),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .35 : .08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A card with a numbered or emoji bullet and a title — "1 · Today's diary".
class StepCard extends StatelessWidget {
  const StepCard({super.key, required this.badge, required this.title, this.trailing, required this.children, this.done = false});
  final String badge;
  final String title;
  final Widget? trailing;
  final List<Widget> children;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Sheet(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 28, height: 28, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done ? C.doneSoft : (dark ? C.dBlueSoft : C.blueSoft),
              shape: BoxShape.circle,
            ),
            child: Text(badge, style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 13,
              color: done ? C.done : (dark ? C.dBlue : C.blue))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          if (trailing != null) trailing!,
        ]),
        const SizedBox(height: 10),
        ...children,
      ]),
    );
  }
}

/// The little status pill: "Posted ✓", "2/3".
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.tone = PillTone.mid});
  final String text;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PillTone.ok => (C.doneSoft, C.done),
      PillTone.no => (C.warnSoft, C.warn),
      PillTone.mid => (C.blueSoft, C.blue),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}

enum PillTone { ok, no, mid }

/// A line the app says to the child: what it is doing, what went wrong, what
/// went well.
///
/// These used to be bare coloured text, which is why a failure read like
/// something out of a terminal — "Couldn't finish saving the pages.
/// PostgrestException(message: …)" in orange, floating under a button. A
/// nine-year-old studying alone deserves the app to look like it meant to say
/// that. Same shape as [Pill], one size up, with room for a sentence.
class Note extends StatelessWidget {
  const Note(this.text, {super.key, this.tone = NoteTone.working});
  final String text;
  final NoteTone tone;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;

    final (bg, fg, mark) = switch (tone) {
      NoteTone.working => (dark ? C.dBlueSoft : C.blueSoft, dark ? C.dBlue : C.blue, "⏳"),
      NoteTone.good => (C.doneSoft, C.done, "✓"),
      NoteTone.problem => (C.warnSoft, C.warn, "!"),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(mark, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(width: 9),
        Expanded(
          child: Text(text,
              style: TextStyle(color: fg, fontSize: 14, height: 1.35)),
        ),
      ]),
    );
  }
}

enum NoteTone { working, good, problem }


/// Lays its children in one column, or two when there is honestly room for
/// both — so four practice subjects fill a laptop screen instead of becoming a
/// tall stack with a scrollbar and empty space either side.
class TwoUp extends StatelessWidget {
  const TwoUp({
    super.key,
    required this.children,
    this.minTile = 340,
    this.gap = 12,
    this.runGap,
  });
  final List<Widget> children;
  final double minTile, gap;

  /// Vertical spacing. Defaults to [gap]; pass 0 when the tiles already carry
  /// their own bottom margin, or the rows drift apart.
  final double? runGap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth.isFinite
            ? cardColumns(c.maxWidth, minTile: minTile, gap: gap)
            : 1;
        if (cols < 2 || children.length < 2) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: runGap ?? gap),
                children[i],
              ],
            ],
          );
        }
        final w = (c.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: runGap ?? gap,
          children: [for (final k in children) SizedBox(width: w, child: k)],
        );
      });
}
