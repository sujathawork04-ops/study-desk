// Talks to the Supabase Edge Function. The Anthropic key lives there, never on
// the phone. Replies stream in word by word, the same as the web app.
import "dart:async";
import "dart:convert";
import "package:http/http.dart" as http;
import "package:supabase_flutter/supabase_flutter.dart";
import "../config.dart";

class TutorError implements Exception {
  TutorError(this.code, [this.limit, this.detail = ""]);
  final String code;
  final int? limit;

  /// What the far end actually said. The Edge Function already sends this and
  /// the app used to throw it away — so a parent got "ask a grown-up to fix
  /// it" with nothing whatsoever to act on, and no way to tell a dead API key
  /// from a function that was never deployed.
  final String detail;

  @override
  String toString() => code;
}

/// Written for a nine-year-old sitting alone with the app. Every message says
/// what SHE can do next; a grown-up is named only when one is genuinely
/// needed, and nothing ever sounds like her fault.
String friendlyError(String code, {int? limit, String detail = ""}) {
  final child = _childError(code, limit);
  final note = grownUpNote(code, detail);
  return note.isEmpty ? child : "$child\n\n$note";
}

/// The second line, and ONLY ever the second line: a child is never made to
/// read this, and never made to feel the breakage is hers to understand.
/// It exists so the parent standing behind her knows which of five possible
/// things is actually wrong without opening a dashboard to guess.
String grownUpNote(String code, String detail) {
  String trimmed() {
    final one = detail.replaceAll(RegExp(r"\s+"), " ").trim();
    if (one.isEmpty) return "";
    return one.length <= 160 ? one : "${one.substring(0, 157)}\u2026";
  }

  return switch (code) {
    "bad_api_key" =>
      "For the grown-up: Claude refused the API key. Make a new one at "
          "platform.claude.com \u2192 API keys, then replace ANTHROPIC_API_KEY "
          "in Supabase \u2192 Edge Functions \u2192 Secrets.",
    "server_not_configured" =>
      "For the grown-up: ANTHROPIC_API_KEY isn't set in Supabase \u2192 "
          "Edge Functions \u2192 Secrets.",
    "function_not_deployed" =>
      "For the grown-up: the tutor function isn't deployed. In the project "
          "folder run: supabase functions deploy tutor",
    // The rest are either the child's own doing (she has chatted a lot today)
    // or plainly temporary, and a technical line would only alarm.
    "daily_limit" || "rate_limited" || "offline" || "slow" ||
    "not_signed_in" || "not_your_student" || "too_long" ||
    "invalid_json" || "subscription_required" => "",
    _ => trimmed().isEmpty ? "" : "For the grown-up: ${trimmed()}",
  };
}

String _childError(String code, int? limit) => switch (code) {
      "not_signed_in" => "The app needs signing in again — ask a grown-up when they're free. "
          "Nothing you've done is lost.",
      "not_your_student" => "This is the wrong child's desk. Tap 👧 at the top to pick yours.",
      "subscription_required" => "The plan needs renewing before Teacher can carry on. "
          "Show this to a grown-up — nothing is lost.",
      "daily_limit" => "You've done a lot with Teacher today (${limit ?? ""} messages) — "
          "that's a full day's work! Teacher will be here again tomorrow. 🌙",
      "rate_limited" => "Teacher needs a minute to catch up. Have a drink of water "
          "and press send again in two or three minutes.",
      "bad_api_key" => "Teacher can't be reached — this one's for a grown-up to fix, not you. "
          "Your work is saved.",
      "too_long" => "That page has a lot on it — more than Teacher could write "
          "down in one go. Try sending fewer pages at a time, or just the part "
          "you're learning now.",
      "invalid_json" => "That photo came out hard to read. Try again from straight above, "
          "in good light, with the page flat.",
      "server_not_configured" => "Teacher isn't switched on yet — a grown-up needs to finish "
          "setting the app up. Nothing is wrong with your work.",
      "function_not_deployed" => "Teacher isn't switched on yet — a grown-up needs to finish "
          "setting the app up. Nothing is wrong with your work.",
      "offline" => "No internet just now. Check the wifi, then press send again — "
          "your message is still here.",
      "slow" => "That's taking longer than it should. Press send again — a photo taken "
          "close, flat and in good light is read fastest.",
      _ => "Something went wrong at Teacher's end, not yours. Press send again, "
          "and if it keeps happening, show a grown-up.",
    };

String _token() {
  final s = Supabase.instance.client.auth.currentSession;
  if (s == null) throw TutorError("not_signed_in");
  return s.accessToken;
}

Map<String, String> _headers() => {
      "content-type": "application/json",
      "authorization": "Bearer ${_token()}",
    };

/// A reply that arrives a few words at a time. [onDelta] receives the whole
/// answer so far, so the screen can simply show it.
Future<String> askTutorStream({
  required String studentId,
  required List<Map<String, String>> messages,
  List<String> images = const [],
  String tier = "default",
  required void Function(String whole) onDelta,
}) async {
  final req = http.Request("POST", Uri.parse("${Config.functionsBase}/tutor"))
    ..headers.addAll(_headers())
    ..body = jsonEncode({
      "studentId": studentId, "messages": messages, "images": images,
      "tier": tier, "stream": true,
    });

  http.StreamedResponse res;
  try {
    res = await req.send();
  } catch (_) {
    throw TutorError("offline");
  }

  if (res.statusCode == 404) throw TutorError("function_not_deployed");
  if (res.statusCode >= 400) {
    final body = await res.stream.bytesToString();
    final j = _tryJson(body);
    throw TutorError((j?["error"] as String?) ?? "upstream_error",
        j?["limit"] as int?, (j?["detail"] as String?) ?? "");
  }

  var whole = "";
  var buffer = "";
  await for (final chunk in res.stream.transform(utf8.decoder)) {
    buffer += chunk;
    final parts = buffer.split("\n\n");
    buffer = parts.removeLast();
    for (final p in parts) {
      final line = p.split("\n").firstWhere((l) => l.startsWith("data: "), orElse: () => "");
      if (line.isEmpty) continue;
      final ev = _tryJson(line.substring(6));
      if (ev == null) continue;
      switch (ev["type"]) {
        case "delta":
          whole += (ev["text"] as String?) ?? "";
          onDelta(whole);
        case "done":
          whole = (ev["text"] as String?) ?? whole;
        case "error":
          throw TutorError((ev["error"] as String?) ?? "upstream_error");
      }
    }
  }
  return whole;
}

/// A reply the app parses rather than shows: reading the diary, transcribing a
/// lesson, building a 🎧 talk.
Future<Map<String, dynamic>> askTutorJson({
  required String studentId,
  required String prompt,
  List<String> images = const [],
  String tier = "quick",
  /// How much room the answer needs. A diary is a short list; a textbook page
  /// transcribed in full is not, and asking for too little returns an answer
  /// cut off mid-sentence that no parser can rescue.
  int maxTokens = 1400,
}) async {
  http.Response res;
  try {
    res = await http
        .post(
          Uri.parse("${Config.functionsBase}/tutor"),
          headers: _headers(),
          body: jsonEncode({
            "studentId": studentId,
            "messages": [{"role": "user", "content": prompt}],
            "images": images, "wantJson": true, "tier": tier,
            "maxTokens": maxTokens,
          }),
        )
        // Reading a page takes 10–30 seconds. Past 90 something has gone
        // wrong, and a child should be told rather than left watching a
        // message that never changes.
        .timeout(const Duration(seconds: 90));
  } on TimeoutException {
    throw TutorError("slow");
  } catch (_) {
    throw TutorError("offline");
  }
  if (res.statusCode == 404) throw TutorError("function_not_deployed");
  final j = _tryJson(res.body);
  if (res.statusCode >= 400) {
    throw TutorError((j?["error"] as String?) ?? "upstream_error",
        j?["limit"] as int?, (j?["detail"] as String?) ?? "");
  }
  return (j?["data"] as Map<String, dynamic>?) ?? const {};
}

Map<String, dynamic>? _tryJson(String s) {
  try {
    return jsonDecode(s) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}
