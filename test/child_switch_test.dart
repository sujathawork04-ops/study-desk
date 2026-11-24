// Two sisters sharing one account, and one of them switching while the other's
// homework is still on its way.
//
// Loading a child's day fetches seven things at once and assigns them into one
// shared place. Nothing checked, on the way out, that the child on screen was
// still the child the load began for — so the slower load landed last and
// landed on the wrong girl.
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/rules.dart";

void main() {
  group("whose homework may be shown", () {
    test("the only load running, same child — show it", () {
      expect(loadIsStale(startedAt: 1, now: 1, sameChild: true), isFalse);
    });

    test("a newer load has started — throw this one away", () {
      // Asha's load began first and finishes last. Mira is on screen now.
      expect(loadIsStale(startedAt: 1, now: 2, sameChild: false), isTrue);
    });

    test("overtaken even when the child looks the same", () {
      // Switched away and back: the counter is the only thing that knows.
      expect(loadIsStale(startedAt: 1, now: 2, sameChild: true), isTrue);
    });

    test("the child changed even though no newer load started", () {
      // Cleared to the child picker mid-flight.
      expect(loadIsStale(startedAt: 3, now: 3, sameChild: false), isTrue);
    });

    test("three loads in a row: only the last one may paint", () {
      const latest = 3;
      expect(loadIsStale(startedAt: 1, now: latest, sameChild: true), isTrue);
      expect(loadIsStale(startedAt: 2, now: latest, sameChild: true), isTrue);
      expect(loadIsStale(startedAt: 3, now: latest, sameChild: true), isFalse);
    });

    test("a counter that has wrapped past the start is still just 'different'", () {
      expect(loadIsStale(startedAt: 9, now: 1, sameChild: true), isTrue);
    });
  });
}
