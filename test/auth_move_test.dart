// Why the app seemed to restart itself in the middle of a lesson.
//
// Supabase renews the sign-in token roughly hourly and announces it on the
// same stream as signing in and out. The desk treated every announcement as a
// new sign-in, threw away its children list and rebuilt from scratch — so the
// screen blanked, the chat was destroyed with whatever Teacher had just
// written, and she was dropped back on Today.
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/rules.dart";

void main() {
  group("an hourly token renewal must change nothing", () {
    test("the same person with a new token is left alone", () {
      expect(authMove("parent-1", "parent-1"), AuthMove.carryOn);
    });

    test("this is judged by who, not by what the event is called", () {
      // Event names differ between web, Android and Supabase versions.
      // A user id does not, which is why the decision hangs on that.
      for (final id in ["a", "b", "00000000-0000-0000-0000-000000000001"]) {
        expect(authMove(id, id), AuthMove.carryOn, reason: id);
      }
    });
  });

  group("a real change still rebuilds", () {
    test("signing out goes back to the sign-in screen", () {
      expect(authMove("parent-1", null), AuthMove.signedOut);
    });

    test("signing out when nobody was signed in is still signed out", () {
      expect(authMove(null, null), AuthMove.signedOut);
    });

    test("a first sign-in loads that account's children", () {
      expect(authMove(null, "parent-1"), AuthMove.reload);
    });

    test("a different parent on the same device loads THEIR children", () {
      // The one case where keeping the old list would be a real problem: one
      // parent must never see another parent's children.
      expect(authMove("parent-1", "parent-2"), AuthMove.reload);
    });
  });
}
