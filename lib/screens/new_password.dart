// The one screen a reset link exists to reach.
//
// Supabase's link signs her in and stops there. Without this, "Forgot
// password" quietly becomes "sign in once" — and the next time she is signed
// out she is locked out exactly as before, having used up her one link.
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../data/db.dart" as db;
import "../rules.dart";
import "../theme.dart";
import "../ui/mascot.dart";

class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final first = TextEditingController();
  final second = TextEditingController();
  bool show = false, busy = false;
  String err = "";

  @override
  void dispose() {
    first.dispose();
    second.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final problem = newPasswordProblem(first.text, second.text);
    if (problem.isNotEmpty) {
      setState(() => err = problem);
      return;
    }
    setState(() { busy = true; err = ""; });
    try {
      await db.sb.auth.updateUser(UserAttributes(password: first.text));
      if (mounted) widget.onDone();
    } on AuthException catch (e) {
      if (mounted) {
        setState(() { err = friendlySignIn(e.message); busy = false; });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          err = "Couldn't save it. Check your internet and try again.";
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Bounded(
          maxWidth: 460,
          child: AutofillGroup(
            child: ListView(padding: const EdgeInsets.all(20), children: [
              const SizedBox(height: 28),
              const Center(child: Mascot(size: 76)),
              const SizedBox(height: 14),
              Center(child: Text("Choose a new password", style: t.headlineSmall)),
              const SizedBox(height: 8),
              Text(
                "This is the one chance the link gives you. Pick something you "
                "will remember — you will need it next time you sign in.",
                textAlign: TextAlign.center,
                style: t.bodySmall,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                decoration: BoxDecoration(
                  color: dark ? C.dPaper : C.paper,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: dark ? C.dLine : C.line),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  ..._field("New password", first, autofocus: true),
                  ..._field("Type it once more", second, last: true),
                  FilledButton(
                    onPressed: busy ? null : _save,
                    child: Text(busy ? "Saving…" : "Save my new password"),
                  ),
                  if (err.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text("⚠️ "),
                        Expanded(
                          child: Text(err,
                              style: const TextStyle(
                                  color: C.warn, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 14),
              Text("At least $kMinPassword characters.",
                  textAlign: TextAlign.center, style: t.bodySmall),
            ]),
          ),
        ),
      ),
    );
  }

  List<Widget> _field(String label, TextEditingController c,
          {bool autofocus = false, bool last = false}) =>
      [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        TextField(
          controller: c,
          obscureText: !show,
          autofocus: autofocus,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: last ? TextInputAction.done : TextInputAction.next,
          onSubmitted: (_) {
            if (last) {
              _save();
            } else {
              FocusScope.of(context).nextFocus();
            }
          },
          decoration: InputDecoration(
            suffixIcon: IconButton(
              tooltip: show ? "Hide" : "Show",
              icon: Icon(show ? Icons.visibility_off : Icons.visibility, size: 20),
              onPressed: () => setState(() => show = !show),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ];
}
