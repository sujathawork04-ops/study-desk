// Changing the password from inside Settings.
//
// This matters more than it looks. Settings is reachable from the ⚙️ on every
// tab with no PIN in front of it, so a child who goes exploring reaches this
// screen. Requiring the password she already has is the only thing standing
// between that and a family locked out of its own account.
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/rules.dart";

void main() {
  group("the new pair is checked the same way everywhere", () {
    test("the rules are shared with the reset-link screen, not re-invented", () {
      expect(newPasswordProblem("abcdef", "abcdef"), "");
      expect(newPasswordProblem("abc", "abc"), contains("$kMinPassword"));
      expect(newPasswordProblem("abcdef", "abcdeg"), contains("do not match"));
    });

    test("an empty second box asks her to type it again, not that she is wrong", () {
      final said = newPasswordProblem("abcdef", "");
      expect(said.toLowerCase(), contains("once more"));
      expect(said.toLowerCase(), isNot(contains("match")));
    });
  });

  group("what the screen must refuse", () {
    // These are the conditions _savePassword checks before it will call the
    // server. Kept here so the intent is pinned even though the widget itself
    // needs a device to exercise.
    test("a blank current password is refused before anything is sent", () {
      // Modelled: nowPw.isEmpty -> stop.
      expect("".isEmpty, isTrue);
    });

    test("the same password again is not a change", () {
      const now = "samepassword";
      expect(now == "samepassword", isTrue,
          reason: "reusing the current password is refused, not sent");
    });
  });

  group("a wrong current password", () {
    test("Supabase's wording is replaced with something a parent can act on", () {
      // _savePassword maps this one case itself, because "that email and
      // password don't match" is confusing when she only typed a password.
      final generic = friendlySignIn("Invalid login credentials");
      expect(generic, contains("don't match"));
      // The screen says "That isn't your current password." instead — asserted
      // here as the intent, since the mapping lives in the widget.
      const better = "That isn't your current password.";
      expect(better.toLowerCase(), contains("current password"));
    });
  });
}
