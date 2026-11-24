// Sign in or create an account. Password by default because it sends no email
// and so is never rate-limited; a 6-digit code is offered for installations
// that have their own SMTP sender set up in Supabase.
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../rules.dart";
import "../theme.dart";
import "../ui/mascot.dart";

enum Stage { password, signup, email, code }

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final password2 = TextEditingController();
  final code = TextEditingController();
  Stage stage = Stage.password;
  bool busy = false;
  /// Typing a password blind on a phone keyboard is where sign-ins go wrong.
  bool showPassword = false;

  /// This Study Desk is closed to new sign-ups. Learned from the server the
  /// first time someone tries, and then not offered again — a button that
  /// cannot work is worse than no button.
  bool noNewAccounts = false;
  String err = "", note = "";

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final last = p.getString("lastEmail");
      if (last != null && mounted) setState(() => email.text = last);
    });
  }

  @override
  void dispose() {
    email.dispose(); password.dispose(); password2.dispose(); code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (mounted) {
      setState(() { busy = true; err = ""; note = ""; });
    }
    try {
      await action();
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          err = friendlySignIn(e.message);
          if (signUpsAreClosed(e.message)) {
            noNewAccounts = true;
            stage = Stage.password;      // nothing to do on the other tab
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => err = "Couldn't reach the server. Check your internet.");
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> _remember() async {
    final p = await SharedPreferences.getInstance();
    await p.setString("lastEmail", email.text.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Bounded(
          maxWidth: 460,
          // One autofill group around the whole form, so a password manager
          // sees an email box and a password box that belong together. Without
          // it the browser and the phone's keychain offer nothing, and she
          // types her password by hand every single time.
          child: AutofillGroup(
            child: ListView(padding: const EdgeInsets.all(20), children: [
              const SizedBox(height: 24),
              const Center(child: Bob(child: Mascot(size: 92))),
              const SizedBox(height: 12),
              Center(child: Text("Study Desk", style: t.headlineSmall)),
              const SizedBox(height: 8),
              Text(
                "A patient tutor for your child: homework checked (never answered), "
                "daily practice, test and competition prep.",
                textAlign: TextAlign.center,
                style: t.bodySmall,
              ),
              const SizedBox(height: 18),

              // The form sits on its own surface. Floating on the page
              // background, the boxes and the blurb had equal weight and
              // nothing said where to start.
              Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                decoration: BoxDecoration(
                  color: dark ? C.dPaper : C.paper,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: dark ? C.dLine : C.line),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? .34 : .06),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (stage == Stage.password || stage == Stage.signup) ...[
                    // Two halves of one control, not two loose buttons sitting
                    // off to the left of a centred page.
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: dark ? C.dGround : C.ground,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: _tab("Sign in", stage == Stage.password,
                              () => setState(() { stage = Stage.password; err = ""; })),
                        ),
                        if (!noNewAccounts)
                          Expanded(
                            child: _tab("Create account", stage == Stage.signup,
                                () => setState(() { stage = Stage.signup; err = ""; })),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (stage == Stage.password) ..._password(),
                  if (stage == Stage.signup) ..._signup(),
                  if (stage == Stage.email) ..._askEmail(),
                  if (stage == Stage.code) ..._askCode(),

                  if (note.isNotEmpty && err.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(note, style: TextStyle(color: dark ? C.dBlue : C.blue)),
                    ),
                  if (err.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text("⚠️ "),
                        Expanded(
                            child: Text(err,
                                style: const TextStyle(
                                    color: C.warn, fontWeight: FontWeight.w600))),
                      ]),
                    ),
                ]),
              ),

              const SizedBox(height: 16),
              Text(
                "Parent or teacher account. Children study inside the app — they don't "
                "need one of their own.",
                textAlign: TextAlign.center,
                style: t.bodySmall,
              ),
              const SizedBox(height: 14),
              // Quieter than the rest: it has to be there, it is not what she
              // is here to read.
              Text(
                "By signing in you agree to the terms and privacy policy, and you confirm "
                "you are the parent or guardian of the children you add.",
                textAlign: TextAlign.center,
                style: t.bodySmall?.copyWith(
                  fontSize: 11.5,
                  color: (dark ? C.dInkSoft : C.inkSoft).withValues(alpha: .8),
                ),
              ),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tab(String label, bool on, VoidCallback onTap) => Material(
        color: on ? C.blue : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: on ? Colors.white : C.inkSoft,
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
          ),
        ),
      );

  List<Widget> _field(
    String label,
    TextEditingController c, {
    bool secret = false,
    TextInputType? type,
    bool last = false,
    bool autofocus = false,
    String? hint,
    List<String>? autofill,
  }) =>
      [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        TextField(
          controller: c,
          obscureText: secret && !showPassword,
          keyboardType: type,
          autofocus: autofocus,
          autofillHints: autofill,
          // A password is not a word: no autocorrect, no capitals, no
          // suggestions from the keyboard trying to be helpful.
          autocorrect: !secret,
          enableSuggestions: !secret,
          textCapitalization: TextCapitalization.none,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: secret
                ? IconButton(
                    tooltip: showPassword ? "Hide password" : "Show password",
                    icon: Icon(
                        showPassword ? Icons.visibility_off : Icons.visibility,
                        size: 20),
                    onPressed: () => setState(() => showPassword = !showPassword),
                  )
                : null,
          ),
          // Enter moves on, and from the last box it signs in — nobody should
          // have to reach for the mouse to finish typing a password.
          textInputAction: last ? TextInputAction.done : TextInputAction.next,
          onSubmitted: (_) {
            if (last) {
              _go();
            } else {
              FocusScope.of(context).nextFocus();
            }
          },
        ),
        const SizedBox(height: 12),
      ];

  /// What the Enter key does on the stage that is showing.
  void _go() {
    if (busy) return;
    switch (stage) {
      case Stage.password:
        _signIn();
      case Stage.signup:
        _createAccount();
      case Stage.email:
        _sendCode();
      case Stage.code:
        _checkCode();
    }
  }

  void _signIn() => _run(() async {
        await _remember();
        await Supabase.instance.client.auth.signInWithPassword(
            email: email.text.trim().toLowerCase(), password: password.text);
        // Closes the autofill session, which is what prompts the browser or
        // the keychain to offer to save the password it just watched her type.
        TextInput.finishAutofillContext();
      });

  void _createAccount() => _run(() async {
        if (password.text.length < 6) {
          throw const AuthException("Please use a password of at least 6 characters.");
        }
        if (password.text != password2.text) {
          throw const AuthException("The two passwords don't match.");
        }
        await _remember();
        final res = await Supabase.instance.client.auth
            .signUp(email: email.text.trim().toLowerCase(), password: password.text);
        TextInput.finishAutofillContext();
        if (res.session == null) {
          if (mounted) {
            setState(() {
              stage = Stage.password;
              note = "Account made. Check your email for the confirmation link, then sign in here.";
            });
          }
        }
      });

  void _sendCode() => _run(() async {
        await _remember();
        await Supabase.instance.client.auth.signInWithOtp(email: email.text.trim().toLowerCase());
        if (mounted) {
          setState(() { stage = Stage.code; note = "Code sent. It's good for one hour."; });
        }
      });

  void _checkCode() => _run(() async {
        await Supabase.instance.client.auth.verifyOTP(
          email: email.text.trim().toLowerCase(),
          token: code.text.replaceAll(RegExp(r"\D"), ""),
          type: OtpType.email,
        );
      });

  List<Widget> _password() => [
        ..._field("Your email", email,
            type: TextInputType.emailAddress,
            hint: "you@example.com",
            autofocus: email.text.isEmpty,
            autofill: const [AutofillHints.username, AutofillHints.email]),
        ..._field("Password", password,
            secret: true, last: true, autofill: const [AutofillHints.password]),
        FilledButton(
          onPressed: busy ? null : _signIn,
          child: Text(busy ? "Signing in…" : "Sign in"),
        ),
        const SizedBox(height: 4),
        // The real alternative gets a button; the recovery link is small and
        // quiet underneath it. Before, both were plain blue links of the same
        // size and nothing said which was the ordinary path.
        OutlinedButton(
          onPressed: busy ? null : () => setState(() { stage = Stage.email; err = ""; }),
          child: const Text("Email me a code instead"),
        ),
        Center(
          child: TextButton(
            onPressed: busy
                ? null
                : () => _run(() async {
                      if (email.text.trim().isEmpty) {
                        throw const AuthException("Type your email first.");
                      }
                      await Supabase.instance.client.auth
                          .resetPasswordForEmail(email.text.trim().toLowerCase());
                      if (mounted) {
                        setState(() =>
                            note = "If that email has an account, a reset link is on its way.");
                      }
                    }),
            child: Text("Forgot password",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: C.blue, fontWeight: FontWeight.w600)),
          ),
        ),
      ];

  List<Widget> _signup() => [
        ..._field("Your email", email,
            type: TextInputType.emailAddress,
            hint: "you@example.com",
            autofocus: email.text.isEmpty,
            autofill: const [AutofillHints.username, AutofillHints.email]),
        ..._field("Choose a password", password,
            secret: true, autofill: const [AutofillHints.newPassword]),
        ..._field("Type it once more", password2,
            secret: true, last: true, autofill: const [AutofillHints.newPassword]),
        FilledButton(
          onPressed: busy ? null : _createAccount,
          child: Text(busy ? "Creating…" : "Create my account"),
        ),
        const SizedBox(height: 10),
        Text("Six characters or more. You set up your child on the next screen — it takes a minute.",
            style: Theme.of(context).textTheme.bodySmall),
      ];

  List<Widget> _askEmail() => [
        ..._field("Your email", email,
            type: TextInputType.emailAddress,
            hint: "you@example.com",
            last: true,
            autofocus: email.text.isEmpty,
            autofill: const [AutofillHints.username, AutofillHints.email]),
        FilledButton(
          onPressed: busy ? null : _sendCode,
          child: Text(busy ? "Sending…" : "Send me a code"),
        ),
        TextButton(
          onPressed: () => setState(() { stage = Stage.password; err = ""; }),
          child: const Text("Sign in with a password instead"),
        ),
        const SizedBox(height: 6),
        Text("Codes by email need your own email sender set up in Supabase. Until then, use the password.",
            style: Theme.of(context).textTheme.bodySmall),
      ];

  List<Widget> _askCode() => [
        Text("We sent a 6-digit code to ${email.text}.", style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 10),
        TextField(
          controller: code,
          keyboardType: TextInputType.number,
          maxLength: 8,
          // So the phone offers the code straight from the notification.
          autofillHints: const [AutofillHints.oneTimeCode],
          textAlign: TextAlign.center,
          autofocus: true,
          style: const TextStyle(fontSize: 24, letterSpacing: 6),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _go(),
          decoration: const InputDecoration(hintText: "123456"),
        ),
        FilledButton(
          onPressed: busy ? null : _checkCode,
          child: Text(busy ? "Checking…" : "Sign in"),
        ),
        TextButton(
          onPressed: () => setState(() { stage = Stage.email; code.clear(); }),
          child: const Text("Change email"),
        ),
      ];
}
