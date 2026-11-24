// What a parent is told when signing in goes wrong.
//
// Supabase wraps a dead connection in the same AuthException as a wrong
// password, so the raw text used to be printed straight onto the screen —
// including the project's address.
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/rules.dart";

void main() {
  group("a dead connection", () {
    test("the exact message from the browser is not shown to her", () {
      const raw = "ClientException: Failed to fetch, "
          "uri=https://example-project.supabase.co/auth/v1/token?grant_type=password";
      final said = friendlySignIn(raw);
      expect(said, isNot(contains("supabase.co")), reason: "no project address on screen");
      expect(said, isNot(contains("ClientException")));
      expect(said, isNot(contains("uri=")));
      expect(said.toLowerCase(), contains("internet"));
      expect(said.toLowerCase(), contains("restore"),
          reason: "a sleeping free-tier project is the likeliest cause, so say so");
    });

    test("every shape a dead connection arrives in is caught", () {
      for (final raw in [
        "ClientException: Failed to fetch, uri=https://x.supabase.co/auth/v1/token",
        "SocketException: Failed host lookup: 'x.supabase.co'",
        "Connection refused",
        "Connection closed before full header was received",
        "Connection timed out",
        "Network is unreachable",
        "TimeoutException after 0:00:30.000000",
        "XMLHttpRequest error.",
        "HandshakeException: Connection terminated during handshake",
      ]) {
        final said = friendlySignIn(raw);
        expect(said.toLowerCase(), contains("couldn't reach the server"), reason: raw);
      }
    });
  });

  group("the ordinary mistakes still read plainly", () {
    test("a wrong password says so, and points at Create account", () {
      final said = friendlySignIn("Invalid login credentials");
      expect(said, contains("don't match"));
      expect(said, contains("Create account"));
    });

    test("an email already in use", () {
      expect(friendlySignIn("User already registered"), contains("sign in instead"));
    });

    test("too many emails says what actually helps, not 'wait a minute'", () {
      for (final raw in [
        "For security purposes, you can only request this after 46 seconds",
        "email rate limit exceeded",
      ]) {
        final said = friendlySignIn(raw);
        expect(said, contains("couple of emails an hour"), reason: raw);
        expect(said.toLowerCase(), contains("password instead"), reason: raw);
        // The old wording sent people round in circles: the cap is hourly and
        // project-wide, so waiting a minute never once helped.
        expect(said.toLowerCase(), isNot(contains("wait a minute")), reason: raw);
      }
    });

    test("a short password", () {
      expect(friendlySignIn("Password should be at least 6 characters"),
          contains("at least 6 characters"));
    });

    test("an unconfirmed email", () {
      expect(friendlySignIn("Email not confirmed"), contains("confirmation link"));
    });

    test("the server having a bad day", () {
      expect(friendlySignIn("503 Service Unavailable"), contains("isn't answering"));
    });
  });

  group("a Study Desk that is closed to new accounts", () {
    test("Supabase's own wording is replaced with what to actually do", () {
      final said = friendlySignIn("Signups not allowed for this instance");
      expect(said, isNot(contains("instance")), reason: "nobody knows what an instance is");
      expect(said.toLowerCase(), contains("ask them to add you"));
      expect(said.toLowerCase(), contains("sign in"));
    });

    test("the screen can tell this apart from an ordinary mistake", () {
      expect(signUpsAreClosed("Signups not allowed for this instance"), isTrue);
      expect(signUpsAreClosed("Signup is disabled"), isTrue);
      expect(signUpsAreClosed("Signups are disabled"), isTrue);
    });

    test("a wrong password is not mistaken for a closed desk", () {
      expect(signUpsAreClosed("Invalid login credentials"), isFalse);
      expect(signUpsAreClosed("Failed to fetch"), isFalse);
      expect(signUpsAreClosed(""), isFalse);
    });
  });

  group("the email provider is not working", () {
    test("raw JSON never reaches a parent", () {
      const raw = '{"code":"unexpected_failure","message":"Error sending recovery email"}';
      final said = friendlySignIn(raw);
      expect(said, isNot(contains("{")));
      expect(said, isNot(contains("unexpected_failure")));
      expect(said, isNot(contains("\"code\"")));
    });

    test("it says what to do instead of naming the machinery", () {
      for (final raw in [
        '{"code":"unexpected_failure","message":"Error sending recovery email"}',
        "Error sending invite email",
        "Error sending confirmation email",
        "Error sending magic link email",
      ]) {
        final said = friendlySignIn(raw);
        expect(said.toLowerCase(), contains("couldn't send the email"), reason: raw);
        expect(said.toLowerCase(), contains("password"), reason: raw);
      }
    });

    test("any JSON-shaped message is replaced, even one with no known words", () {
      expect(friendlySignIn('{"weird":"thing"}'), isNot(contains("weird")));
      expect(friendlySignIn('  [1,2,3]'), isNot(contains("[1")));
    });
  });

  group("nothing technical reaches the screen, whatever arrives", () {
    test("a URL is never shown, even in a message with no known pattern", () {
      final said = friendlySignIn("Weird failure at https://secret.example.com/v1/thing");
      expect(said, isNot(contains("https://")));
      expect(said, isNot(contains("secret.example.com")));
    });

    test("an exception class name is never shown", () {
      expect(friendlySignIn("PostgrestException: something odd"),
          isNot(contains("PostgrestException")));
      expect(friendlySignIn("StateError: bad state"), isNot(contains("StateError")));
    });

    test("a stack frame is never shown", () {
      expect(friendlySignIn("#0  main (package:study_desk/main.dart:1)"),
          isNot(contains("package:")));
    });

    test("an empty message still says something", () {
      expect(friendlySignIn("").isNotEmpty, isTrue);
      expect(friendlySignIn("   ").isNotEmpty, isTrue);
    });

    test("a plain sentence Supabase wrote is passed through as it is", () {
      // Not every unknown message is technical; a readable one is better than
      // a vague one. The example used to be "Signups not allowed for this
      // instance" — which this file now has a rule for, so it was testing the
      // opposite of what it says. Pick one nothing maps.
      expect(friendlySignIn("This email domain is not allowed"),
          "This email domain is not allowed");
      expect(friendlySignIn("Password is too weak"), "Password is too weak");
    });
  });
}
