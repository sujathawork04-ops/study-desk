import "dart:async";

import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "config.dart";
import "data/db.dart" as db;
import "models.dart";
import "screens/home.dart";
import "screens/new_password.dart";
import "screens/setup.dart";
import "screens/sign_in.dart";
import "rules.dart";
import "state.dart";
import "theme.dart";
import "ui/mascot.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A readable failure instead of a blank red rectangle: whatever broke, and
  // the first lines of where, so a screenshot is enough to fix it.
  ErrorWidget.builder = (FlutterErrorDetails d) => Material(
        color: const Color(0xFFFDEBDF),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Something broke on this screen",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF7A2E0E))),
            const SizedBox(height: 10),
            SelectableText("${d.exception}",
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF7A2E0E))),
            const SizedBox(height: 12),
            SelectableText(
              (d.stack?.toString() ?? "no stack")
                  .split("\n")
                  .where((l) => l.trim().isNotEmpty)
                  .take(14)
                  .join("\n"),
              style: const TextStyle(fontSize: 11, fontFamily: "monospace", color: Color(0xFF7A2E0E)),
            ),
          ]),
        ),
      );
  if (Config.ok) {
    // publishableKey is the current name for what Supabase used to call the
    // anon key — the same value, and the one that is safe in a browser. The
    // secret / service_role key must never appear in this app.
    await Supabase.initialize(
        url: Config.supabaseUrl, publishableKey: Config.supabaseAnonKey);
  }
  runApp(const StudyDeskApp());
}

class StudyDeskApp extends StatelessWidget {
  const StudyDeskApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
        valueListenable: appTheme,
        builder: (_, mode, __) => MaterialApp(
          title: "Study Desk",
          debugShowCheckedModeBanner: false,
          theme: studyTheme(Brightness.light),
          darkTheme: studyTheme(Brightness.dark),
          themeMode: mode,
          home: Config.ok ? const Gate() : const SetupNeeded(),
        ),
      );
}

/// Shown instead of a blank screen when the build has no Supabase details.
class SetupNeeded extends StatelessWidget {
  const SetupNeeded({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Bounded(
            maxWidth: 620,
            child: Padding(
            padding: const EdgeInsets.all(20),
            child: Sheet(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Almost there — two values to pass in",
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                const Text("Build the app with your Supabase address and key:"),
                const SizedBox(height: 10),
                const SelectableText(
                  "flutter run \\\n"
                  "  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \\\n"
                  "  --dart-define=SUPABASE_ANON_KEY=<your-anon-publishable-key> \\\n"
                  "  --dart-define=FREE_MODE=true",
                  style: TextStyle(fontFamily: "monospace", fontSize: 13),
                ),
                const SizedBox(height: 10),
                const Text("Both are in Supabase under Project Settings → API: the Project URL, "
                    "and the key marked anon / publishable — never the secret one."),
              ]),
            ),
          ),
          ),
        ),
      );
}

/// Signed out → sign in. Signed in with no child → setup. Otherwise the desk.
class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  final state = AppState();
  Session? session;
  List<Student>? students;
  bool busy = true;
  StreamSubscription<AuthState>? _auth;

  /// She arrived through a reset link. Until a new password is set, this is
  /// the only screen she sees — the link is the one chance to set one, and
  /// letting her straight into the app wastes it.
  bool mustSetPassword = false;

  /// When the chosen child changes — or is cleared by "Children" — this screen
  /// has to rebuild too, or the desk keeps asking for a child that isn't there.
  void _onState() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    _auth?.cancel();
    state.removeListener(_onState);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    state.addListener(_onState);
    session = db.sb.auth.currentSession;
    _auth = db.sb.auth.onAuthStateChange.listen((e) {
      if (!mounted) return;
      if (e.event == AuthChangeEvent.passwordRecovery) {
        setState(() { session = e.session; mustSetPassword = true; });
        return;
      }
      switch (authMove(session?.user.id, e.session?.user.id)) {
        case AuthMove.carryOn:
          // A token renewal, which happens about once an hour on its own.
          // Hold the fresh session for the next call to the server and leave
          // the screen completely alone — she is in the middle of a lesson.
          session = e.session;
        case AuthMove.reload:
        case AuthMove.signedOut:
          setState(() { session = e.session; students = null; });
          _load();
      }
    });
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    if (session == null) { setState(() => busy = false); return; }
    setState(() => busy = true);
    try {
      final list = await db.listStudents();
      students = list;
      if (list.length == 1) await state.choose(list.first);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (session == null) return const SignInScreen();
    if (mustSetPassword) {
      return NewPasswordScreen(
        onDone: () {
          setState(() => mustSetPassword = false);
          _load();
        },
      );
    }
    if (busy && students == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if ((students ?? const []).isEmpty) {
      return SetupScreen(first: true, onDone: (s) async {
        students = [...?students, s];
        await state.choose(s);
        setState(() {});
      });
    }
    if (state.student == null) {
      return PickChild(
        students: students!,
        onPick: (s) async { await state.choose(s); setState(() {}); },
        onAdd: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (routeContext) => SetupScreen(first: false, onDone: (s) async {
            students = [...?students, s];
            await state.choose(s);
            if (!routeContext.mounted) return;
            Navigator.of(routeContext).pop();
            if (mounted) setState(() {});
          }),
        )),
      );
    }
    return Scope(state: state, child: const HomeShell());
  }
}

/// "Who's studying?" — only reached with more than one child, or from the
/// parent tab's "Children & add a sibling".
class PickChild extends StatelessWidget {
  const PickChild({super.key, required this.students, required this.onPick, required this.onAdd});
  final List<Student> students;
  final void Function(Student) onPick;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Bounded(
            maxWidth: 520,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              const SizedBox(height: 24),
              const Center(child: Bob(child: Mascot(size: 96))),
              const SizedBox(height: 14),
              Center(child: Text("Who's studying?",
                  style: Theme.of(context).textTheme.headlineSmall)),
              const SizedBox(height: 18),
              for (final s in students)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: BigChoice(
                    emoji: "🎒",
                    title: s.firstName,
                    subtitle: "${s.grade} · ${s.board}",
                    onTap: () => onPick(s),
                  ),
                ),
              const SizedBox(height: 4),
              BigChoice(emoji: "➕", title: "Add another child", onTap: onAdd),
              const SizedBox(height: 22),
              Center(
                child: TextButton(
                  onPressed: () => db.sb.auth.signOut(),
                  child: const Text("Sign out"),
                ),
              ),
            ]),
          ),
        ),
      );
}
