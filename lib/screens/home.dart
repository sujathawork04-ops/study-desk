// The shell: a friendly header, five tabs along the bottom, and one centred
// column of content so a laptop screen doesn't stretch everything flat.
import "dart:async";

import "package:flutter/material.dart";
import "../rules.dart";
import "../state.dart";
import "../theme.dart";
import "../ui/mascot.dart";
import "chat.dart";
import "lessons.dart";
import "parent.dart";
import "settings.dart";
import "today.dart";

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int tab = 0;
  Timer? clock;
  String? chatPrefill;
  bool chatWantsPhoto = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A phone left on the kitchen table overnight, or a browser tab never
    // closed: at some point midnight passes and yesterday's homework is still
    // on screen. Checking the clock costs nothing.
    clock = Timer.periodic(const Duration(minutes: 1), (_) => _rollOver());
  }

  @override
  void dispose() {
    clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) _rollOver();
  }

  Future<void> _rollOver() async {
    if (!mounted) return;
    final state = Scope.of(context);
    if (!state.dayHasRolledOver) return;
    await state.refreshIfNewDay();
    if (mounted) {
      setState(() => tab = 0);      // back to Today, it's a new one
    }
  }

  // An arrow body takes an expression, not an `if` — and this one is called
  // straight from a button, never after an await, so the shell is certainly
  // still here.
  void _goChat(String prefill, {bool withPhoto = false}) =>
      setState(() { tab = 3; chatPrefill = prefill; chatWantsPhoto = withPhoto; });

  Future<void> _openSettings(AppState state) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scope(state: state, child: const SettingsScreen()),
    ));
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Scope.of(context);
    final s = state.student;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Cleared by the Children button — the screen above this one takes over.
    // Just chosen — her plan and her day are still on their way from the
    // database, and every tab below needs them, so wait here rather than
    // building a half-empty desk.
    if (s == null || state.plan == null || state.day == null) {
      // A load that failed used to leave this spinner turning for ever, with
      // nothing to press. Two families on one project means two home networks,
      // so this stopped being a rare case.
      if (state.loadFailed) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text("🌧️", style: TextStyle(fontSize: 34)),
                const SizedBox(height: 10),
                Text("Couldn't load today's desk",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  "Check the internet and try again. Nothing is lost — "
                  "everything is saved.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: state.reload,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text("Try again"),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: state.clearStudent,
                  child: const Text("Choose a different child"),
                ),
              ]),
            ),
          ),
        );
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = [
      TodayScreen(onGoChat: _goChat, section: TodaySection.today),
      TodayScreen(onGoChat: _goChat, section: TodaySection.practice),
      const LessonsScreen(),
      ChatScreen(
        prefill: chatPrefill,
        wantsPhoto: chatWantsPhoto,
        onPrefillUsed: () => setState(() { chatPrefill = null; chatWantsPhoto = false; }),
      ),
      const ParentScreen(),
    ];

    final width = MediaQuery.sizeOf(context).width;
    final wide = wideLayout(width);
    // Today and Practice are tiles and can take a second column; Teacher and
    // Lessons are reading, and stay near a comfortable line length.
    final maxW = contentWidth(width, cards: tab == 0 || tab == 1);

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 8),
      child: Row(children: [
        if (!wide) ...[const Mascot(size: 40), const SizedBox(width: 11)],
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${s.firstName}'s Study Desk",
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium),
              Text("${s.grade} · ${s.board}",
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        _RoundButton(emoji: "👧", tooltip: "Switch child", onTap: state.clearStudent),
        const SizedBox(width: 6),
        _RoundButton(emoji: "⚙️", tooltip: "Settings", onTap: () => _openSettings(state)),
      ]),
    );

    // IndexedStack, not pages[tab]: every tab stays alive while the others are
    // on top. Building only the chosen one threw the chat away the moment she
    // tapped Lessons, and with it any answer Teacher was still writing. It also
    // loses her scroll position and anything half-typed. Five light screens
    // cost nothing to keep.
    final content = Column(children: [
      Bounded(maxWidth: maxW, child: header),
      Expanded(
        child: Bounded(maxWidth: maxW, child: IndexedStack(index: tab, children: pages)),
      ),
    ]);

    if (wide) {
      return Scaffold(
        body: SafeArea(
          child: Row(children: [
            _Rail(
              tab: tab,
              onPick: (i) => setState(() => tab = i),
              dark: dark,
            ),
            Expanded(child: content),
          ]),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(child: content),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: dark ? C.dLine : C.line)),
        ),
        child: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: [
            for (final (emoji, label) in kTabs)
              NavigationDestination(
                  icon: Text(emoji, style: const TextStyle(fontSize: 21)), label: label),
          ],
        ),
      ),
    );
  }
}

/// The five tabs, in order, shared by the bottom bar and the side rail.
const kTabs = [
  ("📒", "Today"),
  ("🎯", "Practice"),
  ("📖", "Lessons"),
  ("💬", "Teacher"),
  ("🔒", "Parent"),
];

/// Navigation down the left on a laptop or a desktop browser, where a bar
/// stretched across the whole window puts the tabs further apart than they are
/// from the edges, and wastes the margin the content is already leaving empty.
class _Rail extends StatelessWidget {
  const _Rail({required this.tab, required this.onPick, required this.dark});
  final int tab;
  final void Function(int) onPick;
  final bool dark;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: dark ? C.dLine : C.line)),
        ),
        child: NavigationRail(
          selectedIndex: tab,
          onDestinationSelected: onPick,
          labelType: NavigationRailLabelType.all,
          groupAlignment: -0.85,
          leading: const Padding(
            padding: EdgeInsets.only(top: 10, bottom: 6),
            child: Mascot(size: 40),
          ),
          destinations: [
            for (final (emoji, label) in kTabs)
              NavigationRailDestination(
                icon: Text(emoji, style: const TextStyle(fontSize: 21)),
                label: Text(label),
              ),
          ],
        ),
      );
}

/// The soft circular buttons in the header.
class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.emoji, required this.tooltip, required this.onTap});
  final String emoji;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: dark ? C.dBlueSoft : C.blueSoft,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42, height: 42,
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
          ),
        ),
      ),
    );
  }
}
