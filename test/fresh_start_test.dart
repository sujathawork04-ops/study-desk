// Drawing a line under a conversation.
//
// The whole day was one thread, so an hour spent on islands kept colouring the
// answers to Maths questions afterwards. A fresh start cuts the tutor's view
// of the day — and deletes nothing, because her work is not the app's to throw
// away.
import "package:flutter_test/flutter_test.dart";
import "package:study_desk/models.dart";
import "package:study_desk/rules.dart";

Msg said(String who, String what) => Msg(role: who, content: what);
Msg theLine() => Msg(role: "user", content: "", hidden: kFreshStart);

/// The same rule the chat screen applies when it loads the day.
List<Msg> sinceFreshStart(List<Msg> all) {
  for (var i = all.length - 1; i >= 0; i--) {
    if (all[i].hidden == kFreshStart) return all.sublist(i + 1);
  }
  return all;
}

void main() {
  group("a fresh start", () {
    test("only what came after it is carried on with", () {
      final day = [
        said("user", "what is an oasis"),
        said("assistant", "water under the sand…"),
        theLine(),
        said("user", "test: maths"),
      ];
      final out = sinceFreshStart(day);
      expect(out.length, 1);
      expect(out.single.content, "test: maths");
    });

    test("with no line drawn, the whole day carries on as before", () {
      final day = [said("user", "hello"), said("assistant", "hello!")];
      expect(sinceFreshStart(day).length, 2);
    });

    test("the most recent line is the one that counts", () {
      final day = [
        said("user", "islands"),
        theLine(),
        said("user", "maths"),
        theLine(),
        said("user", "spelling"),
      ];
      expect(sinceFreshStart(day).single.content, "spelling");
    });

    test("a line drawn and nothing said since leaves an empty screen", () {
      expect(sinceFreshStart([said("user", "islands"), theLine()]), isEmpty);
    });

    test("an empty day is handled without fuss", () {
      expect(sinceFreshStart([]), isEmpty);
    });

    test("the line itself is never shown to her", () {
      final out = sinceFreshStart([theLine(), said("user", "maths")]);
      expect(out.any((m) => m.hidden == kFreshStart), isFalse);
    });

    test("nothing is deleted — the earlier messages still exist", () {
      final day = [said("user", "islands"), theLine(), said("user", "maths")];
      expect(day.length, 3, reason: "her day stays whole; only the view is cut");
      expect(sinceFreshStart(day).length, 1);
    });
  });
}
