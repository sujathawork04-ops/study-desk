// Choosing a new password after a reset link.
//
// Supabase's link signs her in and stops. Without this screen, "Forgot
// password" quietly becomes "sign in once", and the one link is spent.
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/rules.dart";

void main() {
  group("what she is told is wrong", () {
    test("nothing typed", () {
      expect(newPasswordProblem("", ""), contains("Choose a password"));
    });

    test("too short says how short, not just 'too short'", () {
      final said = newPasswordProblem("abc", "abc");
      expect(said, contains("$kMinPassword"));
    });

    test("the second box empty is its own message, not 'they do not match'", () {
      // "They don't match" when she simply has not typed the second one yet
      // reads as an accusation and sends her back to re-check the first.
      final said = newPasswordProblem("longenough", "");
      expect(said.toLowerCase(), contains("once more"));
      expect(said.toLowerCase(), isNot(contains("match")));
    });

    test("a genuine mismatch", () {
      expect(newPasswordProblem("longenough", "longenouch"), contains("do not match"));
    });
  });

  group("what passes", () {
    test("two matching passwords of the minimum length", () {
      expect(newPasswordProblem("abcdef", "abcdef"), "");
    });

    test("spaces are allowed — a passphrase is a good password", () {
      expect(newPasswordProblem("meera loves maths", "meera loves maths"), "");
    });

    test("length is counted before the match, so the message is the useful one", () {
      // Both wrong: she is told the fixable thing first.
      expect(newPasswordProblem("abc", "xyz"), contains("$kMinPassword"));
    });

    test("exactly at the boundary", () {
      expect(newPasswordProblem("a" * kMinPassword, "a" * kMinPassword), "");
      expect(newPasswordProblem("a" * (kMinPassword - 1), "a" * (kMinPassword - 1)),
          isNot(""));
    });
  });
}
