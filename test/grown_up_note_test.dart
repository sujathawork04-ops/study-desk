// What a parent is told when the breakage is not the child's to fix.
//
// The app used to say "this one's for a grown-up to fix" and stop there —
// which is true, and useless: a dead API key, a function that was never
// deployed, and a secret that was never set all produced the same sentence.
// The Edge Function was already sending its own reason; the app threw it away.
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/data/tutor.dart";

void main() {
  group("the child's line never changes", () {
    test("she is still told it isn't hers to fix, and that her work is safe",
        () {
      final m = friendlyError("bad_api_key", detail: "invalid x-api-key");
      expect(m, startsWith("Teacher can't be reached"));
      expect(m, contains("Your work is saved"));
    });

    test("the grown-up's line is separate, never the opening words", () {
      final m = friendlyError("bad_api_key");
      expect(m.split("\n\n").first, isNot(contains("For the grown-up")));
      expect(m.split("\n\n").length, 2);
    });
  });

  group("the grown-up is told which of the look-alikes it is", () {
    test("a refused key names the two places to go", () {
      final n = grownUpNote("bad_api_key", "");
      expect(n, contains("API key"));
      expect(n, contains("ANTHROPIC_API_KEY"));
      expect(n.toLowerCase(), contains("secrets"));
    });

    test("a missing secret is not confused with a refused one", () {
      expect(grownUpNote("server_not_configured", ""),
          isNot(equals(grownUpNote("bad_api_key", ""))));
      expect(grownUpNote("server_not_configured", ""), contains("isn't set"));
    });

    test("an undeployed function gives the command that deploys it", () {
      expect(grownUpNote("function_not_deployed", ""),
          contains("supabase functions deploy tutor"));
    });

    test("anything else passes the far end's own words through", () {
      expect(grownUpNote("upstream_error", "overloaded_error: try later"),
          contains("overloaded_error"));
    });
  });

  group("a child is never alarmed by something ordinary", () {
    test("her own day's limit carries no technical line", () {
      expect(friendlyError("daily_limit", limit: 60), isNot(contains("\n\n")));
    });

    test("nor does being offline, even if a detail arrives", () {
      expect(friendlyError("offline", detail: "ECONNRESET"),
          isNot(contains("ECONNRESET")));
    });

    test("nor a quiet minute, a slow page, or a long one", () {
      for (final c in ["rate_limited", "slow", "too_long", "invalid_json"]) {
        expect(grownUpNote(c, "some noisy technical thing"), "",
            reason: "$c should stay child-only");
      }
    });
  });

  group("the passed-through words are kept readable", () {
    test("a wall of JSON is cut, not pasted whole", () {
      final n = grownUpNote("upstream_error", "x" * 500);
      expect(n.length, lessThan(200));
      expect(n, endsWith("…"));
    });

    test("newlines in the far end's reply do not break the line", () {
      expect(grownUpNote("upstream_error", "line one\n\n  line two"),
          contains("line one line two"));
    });

    test("nothing is added when there is nothing to say", () {
      expect(grownUpNote("upstream_error", "   "), "");
      expect(friendlyError("upstream_error"), isNot(contains("\n\n")));
    });
  });
}
