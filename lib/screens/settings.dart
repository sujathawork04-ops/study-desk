// Settings ⚙️ — everything a parent changes once in a while, in one place:
// how the app looks, who studies here, the parent PIN (which is optional),
// and the account's email and mobile number.
import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart" show AuthException, UserAttributes;

import "../config.dart";
import "../data/db.dart" as db;
import "../models.dart";
import "../rules.dart";
import "../state.dart";
import "../theme.dart";
import "pin_dialog.dart";
import "setup.dart";

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<Student>? children;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadChildren());
  }

  Future<void> _loadChildren() async {
    final list = await db.listStudents();
    if (mounted) {
      setState(() => children = list);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Scope.of(context);
    final student = state.student;
    if (student == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: Bounded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
            _SchoolCard(student: student, state: state, onChanged: _loadChildren),
            const SizedBox(height: 12),
            _ThemeCard(student: student, state: state),
            const SizedBox(height: 14),
            _StrictnessCard(student: student, state: state),
            const SizedBox(height: 12),
            _ChildrenCard(children: children, state: state, onChanged: _loadChildren),
            const SizedBox(height: 12),
            _PinCard(student: student, state: state),
            const SizedBox(height: 12),
            _ContactCard(student: student, state: state, children: children),
            const SizedBox(height: 18),
            Center(
              child: TextButton(
                onPressed: () => db.sb.auth.signOut(),
                child: const Text("Sign out"),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text("Study Desk · build ${Config.build}",
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ]),
        ),
      ),
    );
  }
}

// ------------------------------------------------------- school and subjects
class _SchoolCard extends StatelessWidget {
  const _SchoolCard({required this.student, required this.state, required this.onChanged});
  final Student student;
  final AppState state;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) => Sheet(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("🏫 School & subjects", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text("${student.grade} · ${student.board} · ${student.languages.all.join(", ")}",
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await navigator.push(MaterialPageRoute(
                builder: (routeContext) => SetupScreen(
                  first: false,
                  existing: student,
                  existingSubjects: state.subjects,
                  onDone: (s) async {
                    await state.choose(s);
                    if (routeContext.mounted) Navigator.of(routeContext).pop();
                  },
                ),
              ));
              await onChanged();
            },
            child: const Text("✏️ Change school, board or class"),
          ),
          const SizedBox(height: 8),
          Text("Reopens the setup questions with her answers filled in. Homework, "
              "chapters and progress are kept.",
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}

// ------------------------------------------------------------------- theme
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.student, required this.state});
  final Student student;
  final AppState state;

  @override
  Widget build(BuildContext context) => Sheet(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("🎨 How it looks", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text("Dark is easier on the eyes for evening study.",
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: appTheme,
            builder: (_, mode, __) => Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (m, label) in const [
                (ThemeMode.system, "📱 Match my device"),
                (ThemeMode.light, "☀️ Light"),
                (ThemeMode.dark, "🌙 Dark"),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: mode == m,
                  onSelected: (_) async {
                    appTheme.value = m;
                    student.themeMode = themeModeName(m);
                    try {
                      await db.updateStudent(student.id, {"theme_mode": themeModeName(m)});
                    } catch (_) {
                      // The column only exists after schema_v8.sql — the app
                      // still works, it just won't remember on the next start.
                    }
                  },
                ),
            ]),
          ),
        ]),
      );
}

// -------------------------------------------------------------- strictness
/// How demanding Teacher is — about standards, never about warmth.
class _StrictnessCard extends StatefulWidget {
  const _StrictnessCard({required this.student, required this.state});
  final Student student;
  final AppState state;
  @override
  State<_StrictnessCard> createState() => _StrictnessCardState();
}

class _StrictnessCardState extends State<_StrictnessCard> {
  @override
  Widget build(BuildContext context) {
    final level = widget.student.strictness ?? "firm";
    return Sheet(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("🎯 How demanding Teacher is",
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text("This changes what counts as finished and how much is accepted as "
            "an answer. It never changes how kindly Teacher speaks to her.",
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in kStrictness.entries)
            ChoiceChip(
              label: Text("${e.value.$1} ${e.value.$2}"),
              selected: level == e.key,
              onSelected: (_) async {
                widget.student.strictness = e.key;
                if (mounted) {
                  setState(() {});
                }
                widget.state.studentChanged();
                try {
                  await db.updateStudent(widget.student.id, {"strictness": e.key});
                } catch (_) {
                  // The column arrives with schema_v13.sql. Until then the
                  // choice holds for this session and the parent tab says so.
                }
              },
            ),
        ]),
        const SizedBox(height: 8),
        Text(kStrictness[level]?.$3 ?? "",
            style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}

// ---------------------------------------------------------------- children
class _ChildrenCard extends StatelessWidget {
  const _ChildrenCard({required this.children, required this.state, required this.onChanged});
  final List<Student>? children;
  final AppState state;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) => Sheet(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("👨‍👩‍👧‍👦 Children", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text("Each child has her own homework, plan and progress.",
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          if (children == null)
            const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator())
          else
            for (final c in children!)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: BigChoice(
                  emoji: c.id == state.student?.id ? "⭐" : "🎒",
                  title: c.firstName,
                  subtitle: c.id == state.student?.id
                      ? "Studying now · ${c.grade} · tap to change her details"
                      : "${c.grade} · tap to switch to her and edit",
                  // Tapping a child opens her setup answers — name, place of
                  // education, board, class, school year, languages, subjects.
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    if (c.id != state.student?.id) await state.choose(c);
                    await navigator.push(MaterialPageRoute(
                      builder: (routeContext) => SetupScreen(
                        first: false,
                        existing: c,
                        existingSubjects: state.subjects,
                        onDone: (s) async {
                          await state.choose(s);
                          if (routeContext.mounted) Navigator.of(routeContext).pop();
                        },
                      ),
                    ));
                    await onChanged();
                  },
                ),
              ),
          const SizedBox(height: 2),
          OutlinedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await navigator.push(MaterialPageRoute(
                builder: (routeContext) => SetupScreen(
                  first: false,
                  onDone: (s) async {
                    await state.choose(s);
                    if (routeContext.mounted) Navigator.of(routeContext).pop();
                  },
                ),
              ));
              await onChanged();
            },
            child: const Text("➕ Add a brother or sister"),
          ),
        ]),
      );
}

// --------------------------------------------------------------------- PIN
class _PinCard extends StatefulWidget {
  const _PinCard({required this.student, required this.state});
  final Student student;
  final AppState state;
  @override
  State<_PinCard> createState() => _PinCardState();
}

class _PinCardState extends State<_PinCard> {
  bool busy = false;
  String msg = "";
  bool ok = false;

  bool get has => (widget.student.parentPin ?? "").isNotEmpty;
  String get email => db.sb.auth.currentUser?.email ?? "";

  Future<bool> _password(String password) async {
    try {
      await db.sb.auth.signInWithPassword(email: email, password: password);
      return true;
    } on AuthException {
      return false;
    }
  }

  /// Saves the PIN — or clears it when [value] is null — then re-reads the
  /// child's row, because signing in for the forgotten-PIN route reloads the
  /// children and would otherwise bring the old PIN back.
  Future<void> _store(String? value, String said) async {
    if (mounted) {
      setState(() { busy = true; msg = ""; });
    }
    try {
      await db.updateStudent(widget.student.id, {"parent_pin": value});
      widget.student.parentPin = value;
      await widget.state.refreshStudent();
      widget.state.studentChanged();
      if (mounted) {
        setState(() { ok = true; msg = said; });
      }
    } catch (e) {
      if (mounted) {
        setState(() { ok = false; msg = "Couldn't save it: $e"; });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> _turnOn() async {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const PinDialog(
        title: "Choose a PIN",
        note: "Four to six digits. The parent tab will ask for it, so pick "
            "something you'll remember and your child won't guess.",
        needCurrent: false,
        needNew: true,
        confirmLabel: "Turn PIN on",
      ),
    );
    if (pin == null || pin.isEmpty) return;
    await _store(pinHash(pin), "PIN on. The parent tab will ask for it from now on.");
    // It should start protecting straight away, not at the next restart.
    widget.state.lockParent();
  }

  Future<void> _turnOff() async {
    final done = await showDialog<String>(
      context: context,
      builder: (_) => PinDialog(
        title: "Turn the PIN off",
        note: "The parent tab will then open straight away — handy if you're "
            "the only one using this phone.",
        needCurrent: true,
        needNew: false,
        currentHash: widget.student.parentPin,
        email: email,
        checkPassword: _password,
        confirmLabel: "Turn PIN off",
      ),
    );
    if (done == null) return;
    await _store(null, "PIN off. The parent tab opens straight away.");
  }

  Future<void> _change() async {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => PinDialog(
        title: "Change the PIN",
        needCurrent: true,
        needNew: true,
        currentHash: widget.student.parentPin,
        email: email,
        checkPassword: _password,
        confirmLabel: "Save new PIN",
      ),
    );
    if (pin == null || pin.isEmpty) return;
    await _store(pinHash(pin), "PIN changed.");
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Sheet(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text("🔒 Parent PIN", style: t.titleMedium)),
          if (busy)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Switch(
              value: has,
              onChanged: (want) => want ? _turnOn() : _turnOff(),
            ),
        ]),
        const SizedBox(height: 2),
        Text(
          has
              ? "On — the parent tab asks for your PIN."
              : "Off — the parent tab opens straight away.",
          style: t.bodySmall,
        ),
        const SizedBox(height: 6),
        Text(
          has
              ? "Forgotten it? Turning it off or changing it also accepts your account password."
              : "Turn it on if you'd rather your child couldn't change her own homework.",
          style: t.bodySmall,
        ),
        if (has) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: busy ? null : _change,
            child: const Text("Change PIN"),
          ),
        ],
        if (msg.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(msg, style: TextStyle(color: ok ? C.done : C.warn)),
          ),
      ]),
    );
  }
}

// --------------------------------------------------------- email and mobile
class _ContactCard extends StatefulWidget {
  const _ContactCard({required this.student, required this.state, required this.children});
  final Student student;
  final AppState state;
  final List<Student>? children;
  @override
  State<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<_ContactCard> {
  late final email = TextEditingController(text: db.sb.auth.currentUser?.email ?? "");
  late final mobile = TextEditingController(text: widget.student.parentMobile ?? "");
  final nowPw = TextEditingController();
  final newPw = TextEditingController();
  final newPw2 = TextEditingController();
  bool busy = false, ok = false, showPw = false;
  String msg = "";

  @override
  void dispose() {
    email.dispose(); mobile.dispose();
    nowPw.dispose(); newPw.dispose(); newPw2.dispose();
    super.dispose();
  }

  /// Change the account password from inside the app.
  ///
  /// THE CURRENT PASSWORD IS REQUIRED, and that is not ceremony. This screen
  /// is reachable from the ⚙️ on every tab with no PIN in front of it, so
  /// without this check any child who went exploring could change her parent's
  /// password and lock the family out of its own account. Proving the old one
  /// first is what makes it safe to put this here at all.
  Future<void> _savePassword() async {
    final addr = db.sb.auth.currentUser?.email ?? "";
    if (addr.isEmpty) {
      if (mounted) {
        setState(() { ok = false; msg = "Sign in again first."; });
      }
      return;
    }
    if (nowPw.text.isEmpty) {
      if (mounted) {
        setState(() { ok = false; msg = "Type your current password first."; });
      }
      return;
    }
    final problem = newPasswordProblem(newPw.text, newPw2.text);
    if (problem.isNotEmpty) {
      if (mounted) {
        setState(() { ok = false; msg = problem; });
      }
      return;
    }
    if (newPw.text == nowPw.text) {
      if (mounted) {
        setState(() { ok = false; msg = "That is the password you already have."; });
      }
      return;
    }

    if (mounted) {
      setState(() { busy = true; msg = ""; });
    }
    try {
      // Prove it is the parent. Throws if the old password is wrong.
      await db.sb.auth.signInWithPassword(email: addr, password: nowPw.text);
      await db.sb.auth.updateUser(UserAttributes(password: newPw.text));
      nowPw.clear(); newPw.clear(); newPw2.clear();
      if (mounted) {
        setState(() {
          ok = true;
          msg = "Password changed. Use the new one next time you sign in.";
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          ok = false;
          msg = RegExp("invalid login credentials", caseSensitive: false)
                  .hasMatch(e.message)
              ? "That isn't your current password."
              : friendlySignIn(e.message);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          ok = false;
          msg = "Couldn't change it. Check your internet and try again.";
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Widget _pwField(String label, TextEditingController c, {bool last = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
          obscureText: !showPw,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          textInputAction: last ? TextInputAction.done : TextInputAction.next,
          onSubmitted: (_) {
            if (last) {
              if (!busy) _savePassword();
            } else {
              FocusScope.of(context).nextFocus();
            }
          },
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: IconButton(
              tooltip: showPw ? "Hide" : "Show",
              icon: Icon(showPw ? Icons.visibility_off : Icons.visibility, size: 20),
              onPressed: () => setState(() => showPw = !showPw),
            ),
          ),
        ),
      );

  Future<void> _saveEmail() async {
    final wanted = email.text.trim();
    final current = db.sb.auth.currentUser?.email ?? "";
    if (wanted.isEmpty || !wanted.contains("@")) {
      if (mounted) {
        setState(() { msg = "That doesn't look like an email address."; ok = false; });
      }
      return;
    }
    if (wanted.toLowerCase() == current.toLowerCase()) {
      if (mounted) {
        setState(() { msg = "That's already your email."; ok = false; });
      }
      return;
    }
    if (mounted) {
      setState(() { busy = true; msg = ""; });
    }
    try {
      await db.sb.auth.updateUser(UserAttributes(email: wanted));
      if (mounted) {
        setState(() {
          ok = true;
          msg = "Check $wanted for a confirmation link. The change happens once you tap it — "
              "keep signing in with $current until then.";
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() { ok = false; msg = e.message; });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> _saveMobile() async {
    if (mounted) {
      setState(() { busy = true; msg = ""; });
    }
    final value = mobile.text.trim();
    try {
      // Saved against every child on this account — it's the parent's number.
      for (final c in widget.children ?? [widget.student]) {
        await db.updateStudent(c.id, {"parent_mobile": value.isEmpty ? null : value});
        c.parentMobile = value.isEmpty ? null : value;
      }
      widget.student.parentMobile = value.isEmpty ? null : value;
      widget.state.studentChanged();
      if (mounted) {
        setState(() { ok = true; msg = "Mobile number saved."; });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          ok = false;
          msg = "Couldn't save it. Run schema_v8.sql in Supabase once, then try again.";
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Sheet(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("✉️ Your details", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text("The email you sign in with, and a number for reminders later.",
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: "Email"),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: busy ? null : _saveEmail,
              child: const Text("Change email"),
            ),
          ),
          const Divider(height: 26),
          TextField(
            controller: mobile,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: "Mobile number", hintText: "+91…"),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: busy ? null : _saveMobile,
              child: const Text("Save mobile"),
            ),
          ),
          const Divider(height: 26),
          Text("Password", style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            "Change it here any time. You need the one you use now — so nobody "
            "who finds this screen open can change it on you.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          _pwField("Password you use now", nowPw),
          _pwField("New password", newPw),
          _pwField("Type the new one again", newPw2, last: true),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: busy ? null : _savePassword,
              child: Text(busy ? "Saving…" : "Change password"),
            ),
          ),
          if (msg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(msg, style: TextStyle(color: ok ? C.done : C.warn)),
            ),
        ]),
      );
}
