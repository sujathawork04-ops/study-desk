// Asking for a PIN, in one small window: prove it's you, choose a new one, or
// both. It knows nothing about the database — whoever opens it says how to
// check the password — so it can be tested on its own.
import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../rules.dart";
import "../theme.dart";

/// Pops with:
///   null  — she backed out
///   ""    — she proved who she is and no new PIN was asked for (turning it off)
///   "1234"— the new PIN, already checked for length and repeated correctly
class PinDialog extends StatefulWidget {
  const PinDialog({
    super.key,
    required this.title,
    required this.needCurrent,
    required this.needNew,
    this.note = "",
    this.currentHash,
    this.email = "",
    this.checkPassword,
    this.confirmLabel = "Save",
  });

  final String title;
  final String note;
  final bool needCurrent;              // ask for the PIN she already set
  final bool needNew;                  // ask her to choose one
  final String? currentHash;
  final String email;
  final Future<bool> Function(String password)? checkPassword;
  final String confirmLabel;

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  final now = TextEditingController();
  final fresh = TextEditingController();
  final again = TextEditingController();
  final password = TextEditingController();
  bool forgot = false, busy = false, show = false;
  String err = "";

  @override
  void dispose() {
    now.dispose(); fresh.dispose(); again.dispose(); password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (mounted) {
      setState(() { busy = true; err = ""; });
    }
    try {
      if (widget.needCurrent) {
        if (forgot) {
          final check = widget.checkPassword;
          if (check == null || password.text.isEmpty) {
            if (mounted) {
              setState(() => err = "Type your account password.");
            }
            return;
          }
          if (!await check(password.text)) {
            if (mounted) {
              setState(() => err = "That password doesn't match this account.");
            }
            return;
          }
        } else if (pinHash(now.text) != widget.currentHash) {
          if (mounted) {
            setState(() => err = "That's not your current PIN.");
          }
          return;
        }
      }
      if (!widget.needNew) {
        if (mounted) Navigator.of(context).pop("");
        return;
      }
      if (!RegExp(r"^\d{4,6}$").hasMatch(fresh.text)) {
        if (mounted) {
          setState(() => err = "A PIN is 4 to 6 digits.");
        }
        return;
      }
      if (fresh.text != again.text) {
        if (mounted) {
          setState(() => err = "The two PINs don't match.");
        }
        return;
      }
      if (mounted) Navigator.of(context).pop(fresh.text);
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Widget _digits(TextEditingController c, String label, {bool autofocus = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          autofocus: autofocus,
          obscureText: !show,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          style: const TextStyle(fontSize: 19, letterSpacing: 8, fontWeight: FontWeight.w700),
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: label,
            counterText: "",
            // The label sits above the box, so the digits stay centred in it.
            floatingLabelBehavior: FloatingLabelBehavior.always,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (widget.note.isNotEmpty) ...[
            Text(widget.note, style: t.bodySmall),
            const SizedBox(height: 14),
          ],
          if (widget.needCurrent && !forgot) _digits(now, "Current PIN", autofocus: true),
          if (widget.needCurrent && forgot)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: password,
                obscureText: true,
                autofocus: true,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: "Password",
                  helperText: widget.email.isEmpty ? null : "for ${widget.email}",
                ),
              ),
            ),
          if (widget.needCurrent && widget.checkPassword != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: busy ? null : () => setState(() { forgot = !forgot; err = ""; }),
                child: Text(forgot ? "Use the PIN instead" : "I forgot the PIN"),
              ),
            ),
          if (widget.needNew) ...[
            if (widget.needCurrent) const Divider(height: 22),
            _digits(fresh, widget.needCurrent ? "New PIN" : "Choose a PIN",
                autofocus: !widget.needCurrent),
            _digits(again, "Repeat it"),
            Row(children: [
              Checkbox(
                value: show,
                onChanged: (v) => setState(() => show = v ?? false),
              ),
              Text("Show the digits", style: t.bodySmall),
            ]),
          ],
          if (err.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(err, style: const TextStyle(color: C.warn)),
            ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        FilledButton(
          onPressed: busy ? null : _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
