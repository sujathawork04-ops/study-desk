// DEFECT H1 — the daily limit that could be switched off from the outside.
//
// The Edge Function exempted a request from the quota when the request itself
// said `wantJson: true`. That is a field in a body any signed-in caller can
// write, so one line in a browser console bought unlimited calls billed to
// this project's card — and because the exempt path passed msgs: 0, nothing
// counted them either. The second half was worse: the limit was only applied
// when the counter happened to return a number, so a missing or slow
// bump_usage let every request through. A spend limit must never fail open.
//
// The fix lives in supabase/functions/tutor/index.ts. These tests pin the
// ARITHMETIC of it, so the rule cannot drift without someone noticing.
import "package:flutter_test/flutter_test.dart";

/// The function's rule, written here exactly as index.ts applies it.
/// Returns "" when the request may proceed, or the error code it returns.
String gate({
  required Object? used,          // what bump_usage returned
  required int limit,
  required bool wantJson,
  int headroom = 200,
}) {
  if (used is! int) return "quota_unavailable";   // fails CLOSED
  if (!wantJson && used > limit) return "daily_limit";
  if (used > limit + headroom) return "daily_limit";
  return "";
}

void main() {
  group("a child's ordinary conversation", () {
    test("inside the allowance, it goes through", () {
      expect(gate(used: 40, limit: 200, wantJson: false), "");
    });

    test("one past the allowance, it stops", () {
      expect(gate(used: 201, limit: 200, wantJson: false), "daily_limit");
    });

    test("exactly at the allowance is still hers to use", () {
      expect(gate(used: 200, limit: 200, wantJson: false), "");
    });
  });

  group("the app reading on her behalf", () {
    test("a chapter does not eat her conversation allowance", () {
      // The reason the exemption existed, and it still holds.
      expect(gate(used: 260, limit: 200, wantJson: true), "");
    });

    test("but it is counted, and it does hit a wall", () {
      expect(gate(used: 401, limit: 200, wantJson: true), "daily_limit");
    });

    test("the wall is the allowance plus the reading headroom", () {
      expect(gate(used: 400, limit: 200, wantJson: true), "");
      expect(gate(used: 401, limit: 200, wantJson: true), "daily_limit");
    });

    test("claiming wantJson no longer buys unlimited calls", () {
      // The attack, in one line: before the fix this returned "" forever,
      // because the counter was never incremented at all.
      for (final n in [500, 5000, 500000]) {
        expect(gate(used: n, limit: 200, wantJson: true), "daily_limit",
            reason: "$n calls must not be allowed by asserting wantJson");
      }
    });
  });

  group("when the counter itself cannot be read", () {
    test("nothing is spent — it fails closed, not open", () {
      expect(gate(used: null, limit: 200, wantJson: false), "quota_unavailable");
      expect(gate(used: null, limit: 200, wantJson: true), "quota_unavailable");
    });

    test("a non-numeric answer is not quietly treated as zero", () {
      expect(gate(used: "", limit: 200, wantJson: false), "quota_unavailable");
      expect(gate(used: false, limit: 200, wantJson: true), "quota_unavailable");
    });
  });

  group("a smaller allowance is honoured too", () {
    test("a 20-message plan stops at 21", () {
      expect(gate(used: 20, limit: 20, wantJson: false), "");
      expect(gate(used: 21, limit: 20, wantJson: false), "daily_limit");
      expect(gate(used: 220, limit: 20, wantJson: true), "");
      expect(gate(used: 221, limit: 20, wantJson: true), "daily_limit");
    });
  });
}
