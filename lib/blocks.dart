// The hidden lines the tutor puts at the end of a reply, and the pictures they
// describe. Identical wire format to the web app — lib/widgets.ts and
// lib/explain.ts — so the same tutor prompt drives both.
import "dart:convert";
import "rules.dart";

// ---------------------------------------------------------------- one widget
const kWidgetKinds = {
  "fraction", "numberline", "array", "placevalue", "clock", "order", "balance",
  "machine", "sort"
};

final _widgetLine = RegExp(r"^\s*\**\s*WIDGET:\s*(\{.*\})\s*\**\s*$", multiLine: true, caseSensitive: false);
final _explainLine = RegExp(r"^\s*\**\s*EXPLAIN:\s*(\{.*\})\s*\**\s*$", multiLine: true, caseSensitive: false);
final _controlLine = RegExp(r"^\s*\**\s*(BADGE|DONE|PRACTICED|MASTERED|SPELL|WIDGET|EXPLAIN|WEAK|FIXED)\s*:", caseSensitive: false);

class WidgetSpec {
  WidgetSpec(this.type, this.json);
  final String type;
  final Map<String, dynamic> json;

  String get ask => (json["ask"] as String?) ?? "";
  num? get answerNum => json["answer"] is num ? json["answer"] as num : null;
  String? get answerText => json["answer"] is String ? json["answer"] as String : null;
  List<String>? get answerList =>
      json["answer"] is List ? (json["answer"] as List).map((e) => e.toString()).toList() : null;

  int i(String k, int fallback) => json[k] is num ? (json[k] as num).toInt() : fallback;
  double d(String k, double fallback) => json[k] is num ? (json[k] as num).toDouble() : fallback;
  String s(String k, String fallback) => (json[k] as String?) ?? fallback;
  List<String> list(String k) =>
      ((json[k] as List?) ?? const []).map((e) => e.toString()).toList();

  static WidgetSpec? parse(String reply) {
    final m = _widgetLine.firstMatch(reply);
    if (m == null) return null;
    try {
      final j = jsonDecode(m.group(1)!) as Map<String, dynamic>;
      final t = j["type"] as String?;
      if (t == null || !kWidgetKinds.contains(t)) return null;
      if (!_sane(t, j)) return null;
      return WidgetSpec(t, j);
    } catch (_) {
      return null;
    }
  }

  /// Only draw what we know how to draw, and keep the numbers child-sized.
  static bool _sane(String t, Map<String, dynamic> j) {
    num? n(String k) => j[k] is num ? j[k] as num : null;
    switch (t) {
      case "fraction":
        return (n("parts") ?? 0) >= 2 && (n("parts") ?? 0) <= 12;
      case "numberline":
        final f = n("from"), to = n("to"), st = n("step");
        return f != null && to != null && st != null && to > f && st > 0;
      case "array":
        final r = n("rows") ?? 0, c = n("cols") ?? 0;
        return r >= 1 && r <= 12 && c >= 1 && c <= 12;
      case "order":
        final items = j["items"];
        return items is List && items.length >= 2 && items.length <= 8;
      case "balance":
        return j["right"] is String;
      case "machine":
        // Only the three her book covers, and a load she can hold in her head.
        if (!kMachines.containsKey(j["machine"])) return false;
        final load = n("load");
        if (load == null || load <= 0 || load > 1000) return false;
        final h = n("height");
        return h == null || (h >= 1 && h <= 5);
      case "sort":
        final groups = j["groups"], items = j["items"];
        if (groups is! List || groups.length < 2 || groups.length > 4) return false;
        if (items is! List || items.length < 3 || items.length > 10) return false;
        final names = groups.map((e) => e.toString()).toSet();
        for (final it in items) {
          // Every item must say which group it belongs to, and that group must
          // be one of the columns on screen — otherwise she is given a card
          // with nowhere right to put it and can never finish.
          if (it is! Map) return false;
          if (it["it"] is! String || (it["it"] as String).trim().isEmpty) return false;
          if (!names.contains("${it["group"]}")) return false;
        }
        return true;
      default:
        return true;   // placevalue, clock
    }
  }

  /// What gets written into the chat after she presses Check.
  String describe(Object? value) => switch (type) {
        "fraction" => "I shaded $value out of ${i("parts", 4)}.",
        "numberline" => "I put the marker on $value.",
        "array" => "I made ${i("rows", 0)} rows of ${i("cols", 0)} — that's $value in all.",
        "placevalue" => "I built the number $value.",
        "clock" => "I set the clock to $value.",
        "order" => "I put them in this order: ${(value as List).join(" → ")}.",
        "machine" => _describeMachine(value as int),
        "sort" => _describeSort((value as Map).cast<String, String>()),
        _ => "I put $value on the left pan.",
      };

  String _describeMachine(int setting) {
    final m = s("machine", "pulley");
    final load = i("load", 0);
    final r = machineEffort(m, load, setting, height: i("height", 1));
    // Send the effort as well as the setting. The tutor can then talk about
    // what she FOUND, not just what she moved.
    return "On the ${kMachines[m]?.$2 ?? m} I set "
        "${machineRange(m).label.toLowerCase()} to $setting. "
        "The load is $load and I had to pull ${prettyEffort(r.effort)}.";
  }

  String _describeSort(Map<String, String> placed) {
    final correct = sortItems;
    final wrong = sortMistakes(correct, placed);
    final lines = correct.map((c) => "${c.it} → ${placed[c.it] ?? "not placed"}").join(", ");
    return wrong.isEmpty
        ? "I sorted them all: $lines."
        : "I sorted them like this: $lines. (I am not sure about ${wrong.join(", ")}.)";
  }

  /// The items of a "sort", each with the group it really belongs in.
  List<({String it, String group})> get sortItems =>
      ((json["items"] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => (it: "${m["it"]}", group: "${m["group"]}"))
          .toList();

  /// null when the tutor gave no answer — then the tutor judges, not the app.
  bool? isRight(Object? value) {
    if (type == "sort") {
      // A sort always carries its own answer — every item names its group — so
      // this one is never left to the tutor to judge.
      return sortMistakes(sortItems, (value as Map).cast<String, String>()).isEmpty;
    }
    if (type == "machine") {
      final a = answerNum;
      if (a != null) return (value as int) == a.toInt();
      // No target setting given: she was asked to make the machine HELP, which
      // is a real question with more than one right answer.
      return json["mustHelp"] == true
          ? machineHelps(s("machine", "pulley"), i("load", 0), value as int,
              height: i("height", 1))
          : null;
    }
    if (type == "order") {
      final a = answerList;
      if (a == null) return null;
      return jsonEncode(value) == jsonEncode(a);
    }
    if (type == "clock") {
      final a = answerText;
      return a == null ? null : "$value" == a;
    }
    final a = answerNum;
    return a == null ? null : (value as num?) == a;
  }
}

// ------------------------------------------------- an illustrated explanation
const kPictureKinds = {
  "fraction", "objects", "numberline", "array", "steps", "shape", "bars", "text"
};

class ExplainStep {
  ExplainStep({required this.say, this.show, this.ask, this.doIt});
  final String say;
  final Map<String, dynamic>? show;
  final String? ask;
  final WidgetSpec? doIt;
}

class Explainer {
  Explainer(this.title, this.steps);
  final String title;
  final List<ExplainStep> steps;

  static Explainer? parse(String reply) {
    final m = _explainLine.firstMatch(reply);
    if (m == null) return null;
    try {
      final j = jsonDecode(m.group(1)!) as Map<String, dynamic>;
      final title = j["title"] as String?;
      final raw = j["steps"];
      if (title == null || raw is! List) return null;

      final steps = <ExplainStep>[];
      for (final e in raw) {
        if (e is! Map) continue;
        final say = (e["say"] as String?)?.trim();
        if (say == null || say.isEmpty) continue;
        final show = e["show"] is Map ? Map<String, dynamic>.from(e["show"] as Map) : null;
        final okShow = show != null && kPictureKinds.contains(show["kind"]);
        WidgetSpec? doIt;
        if (e["do"] is Map) {
          final d = Map<String, dynamic>.from(e["do"] as Map);
          final t = d["type"] as String?;
          if (t != null && kWidgetKinds.contains(t) && WidgetSpec._sane(t, d)) {
            doIt = WidgetSpec(t, d);
          }
        }
        steps.add(ExplainStep(say: say, show: okShow ? show : null, ask: e["ask"] as String?, doIt: doIt));
        if (steps.length == 10) break;   // a runaway explanation is not an explanation
      }
      return steps.length >= 2 ? Explainer(title, steps) : null;
    } catch (_) {
      return null;
    }
  }
}

// --------------------------------------------------------- reading the reply
class TutorLines {
  TutorLines({required this.visible, required this.badges, required this.doneNumbers,
              required this.practiced, required this.mastered, required this.spell,
              required this.widgetLine, required this.explainLine,
              this.weak = const [], this.fixed = const []});
  final String visible;
  final List<String> badges;
  final List<int> doneNumbers;
  final List<(String, String)> practiced;   // (item, score)
  final List<String> mastered;
  final List<String> spell;
  final String widgetLine;
  final String explainLine;

  /// Something she found hard, and something she has since got the hang of —
  /// the tutor's own notes on what to come back to.
  final List<({String subject, String skill, String note})> weak;
  final List<({String subject, String skill})> fixed;
}

TutorLines readTutorLines(String reply) {
  final badges = <String>[];
  final done = <int>[];
  final practiced = <(String, String)>[];
  final mastered = <String>[];
  final spell = <String>[];
  final weak = <({String subject, String skill, String note})>[];
  final fixed = <({String subject, String skill})>[];

  for (final l in reply.split("\n")) {
    final badge = RegExp(r"^\s*\**\s*BADGE:\s*(.+)$", caseSensitive: false).firstMatch(l);
    if (badge != null) badges.add(badge.group(1)!.trim());

    final d = RegExp(r"^\s*\**\s*DONE:\s*(\d+)", caseSensitive: false).firstMatch(l);
    if (d != null) done.add(int.parse(d.group(1)!));

    final p = RegExp(r"^\s*\**\s*PRACTICED:\s*([^|]+?)\s*(?:\|\s*(.+?))?\s*\**\s*$", caseSensitive: false).firstMatch(l);
    if (p != null) practiced.add((p.group(1)!.trim(), (p.group(2) ?? "").trim()));

    final m = RegExp(r"^\s*\**\s*MASTERED:\s*(.+)$", caseSensitive: false).firstMatch(l);
    if (m != null) mastered.add(m.group(1)!.trim());

    final sp = RegExp(r"^\s*\**\s*SPELL:\s*(.+?)\s*\**\s*$", caseSensitive: false).firstMatch(l);
    if (sp != null) spell.add(sp.group(1)!.trim());

    // WEAK: Maths | regrouping in subtraction | forgets to carry the ten
    final w = RegExp(
            r"^\s*\**\s*WEAK:\s*([^|]+?)\s*\|\s*([^|]+?)\s*(?:\|\s*(.*?))?\s*\**\s*$",
            caseSensitive: false)
        .firstMatch(l);
    if (w != null && w.group(1)!.trim().isNotEmpty && w.group(2)!.trim().isNotEmpty) {
      weak.add((
        subject: w.group(1)!.trim(),
        skill: w.group(2)!.trim(),
        note: (w.group(3) ?? "").trim(),
      ));
    }

    // FIXED: Maths | regrouping in subtraction
    final fx = RegExp(r"^\s*\**\s*FIXED:\s*([^|]+?)\s*\|\s*(.+?)\s*\**\s*$",
            caseSensitive: false)
        .firstMatch(l);
    if (fx != null) {
      fixed.add((subject: fx.group(1)!.trim(), skill: fx.group(2)!.trim()));
    }
  }

  final visible = reply
      .split("\n")
      .where((l) => !_controlLine.hasMatch(l))
      .join("\n")
      .trim();

  return TutorLines(
    visible: visible, badges: badges, doneNumbers: done, practiced: practiced,
    mastered: mastered, spell: spell,
    widgetLine: _widgetLine.firstMatch(reply)?.group(0)?.trim() ?? "",
    explainLine: _explainLine.firstMatch(reply)?.group(0)?.trim() ?? "",
    weak: weak, fixed: fixed,
  );
}
