// DEFECT C3 — the settings door.
//
// The parent tab asked for a PIN. Settings, reachable from the ⚙️ on every
// single tab, did not — and behind it were the children, the setup, Sign out,
// the account's email address and its password. A child could point the login
// email at an address she controlled, reset the password from there, and own
// the account. These pin the rule: one lock, both doors.
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/rules.dart";

void main() {
  group("settings is locked exactly when the parent tab is", () {
    test("a PIN is set and nobody has unlocked: locked", () {
      expect(settingsLocked(pin: "a1b2c3d4", unlocked: false), isTrue);
    });

    test("a PIN is set and she has unlocked this session: open", () {
      expect(settingsLocked(pin: "a1b2c3d4", unlocked: true), isFalse);
    });

    test("no PIN at all: open, as the parent tab is", () {
      expect(settingsLocked(pin: null, unlocked: false), isFalse);
      expect(settingsLocked(pin: "", unlocked: false), isFalse);
    });

    test("it never disagrees with the parent tab, in any combination", () {
      for (final pin in [null, "", "a1b2c3d4"]) {
        for (final unlocked in [true, false]) {
          expect(
            settingsLocked(pin: pin, unlocked: unlocked),
            parentTabLocked(pin: pin, unlocked: unlocked),
            reason: "pin=$pin unlocked=$unlocked — the two doors must agree",
          );
        }
      }
    });
  });

  group("what the lock is and is not", () {
    test("the PIN keeps a child out; it is not a stranger's barrier", () {
      // Documented honestly rather than overstated: the hash is small and the
      // comparison is on the device. Supabase's row-level security is what
      // actually protects the data; this stops the child at the desk.
      expect(pinHash("1234"), isNot(pinHash("4321")));
      expect(pinHash("1234"), pinHash("1234"));
    });

    test("an empty PIN is no PIN, not a PIN of zero length to check", () {
      expect(settingsLocked(pin: "", unlocked: false), isFalse);
    });
  });
}
