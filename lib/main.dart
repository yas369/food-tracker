import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'data/catalog.dart';
import 'services/webview_migration.dart';
import 'store.dart';
import 'ui/screens/add_food.dart';
import 'ui/screens/diet.dart';
import 'ui/screens/goal.dart';
import 'ui/screens/me.dart';
import 'ui/screens/move.dart';
import 'ui/screens/onboarding.dart';
import 'ui/screens/progress.dart';
import 'ui/screens/today.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  runApp(PlateCheckApp(store: store));
  store.init();
}

class PlateCheckApp extends StatelessWidget {
  const PlateCheckApp({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) => MaterialApp(
          title: 'Plate Check',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: store.themeMode,
          home: store.loaded ? HomeShell(store: store) : const _Starting(),
        ),
      );
}

/// Shown for a moment at start, while saved data loads. If data is being
/// recovered from the earlier version, its hidden WebView sits here at 1 px.
class _Starting extends StatelessWidget {
  const _Starting();
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: heroGradient(Pal.of(context))),
          child: Stack(children: [
            const Center(child: Icon(Icons.restaurant, size: 64, color: Colors.white)),
            ValueListenableBuilder<WebViewController?>(
              valueListenable: migrationWebView,
              builder: (_, c, _) => c == null ? const SizedBox.shrink() : SizedBox(width: 1, height: 1, child: WebViewWidget(controller: c)),
            ),
          ]),
        ),
      );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});
  final AppStore store;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int tab = 0;
  late String day = widget.store.today;
  late String lastToday = widget.store.today;
  bool setupShown = false;

  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.notifications.onTap = _openFromNotification;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeSetup();
      final launch = store.notifications.launchPayload;
      if (launch != null) {
        store.notifications.launchPayload = null;
        _openFromNotification(launch);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back on screen: follow the date past midnight, and refresh reminders and
  /// permissions (the user may have changed them in Android settings).
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) store.saveSteps();
    if (s != AppLifecycleState.resumed) return;
    final t = store.today;
    if (t != lastToday) {
      if (day == lastToday) setState(() => day = t);
      lastToday = t;
    }
    store.reschedule();
    store.resumeSteps();
  }

  Future<void> _maybeSetup() async {
    if (setupShown || store.d.me.onboarded) return;
    setupShown = true;
    await openSetup(context, store, SetupMode.onboard);
    if (mounted && store.d.profile == null) await openGoal(context, store);
  }

  void _openFromNotification(String payload) {
    if (!mounted || store.d.profile == null) return;
    setState(() {
      tab = 0;
      day = store.today;
    });
    if (payload.isNotEmpty) openAddFood(context, store, store.today, meal: meals.any((m) => m.id == payload) ? payload : null);
  }

  String get _title => switch (tab) {
        0 => _greeting(),
        1 => 'Diet plan',
        2 => 'Move',
        3 => 'Your progress',
        _ => 'Me',
      };

  String _greeting() {
    final h = store.now.hour;
    final g = h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
    final n = store.d.me.name.trim().split(RegExp(r'\s+')).first;
    return '$g${n.isEmpty ? '' : ', $n'}';
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final prof = store.d.profile;
    return PopScope(
      canPop: tab == 0 && day == store.today,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() {
          if (tab != 0) {
            tab = 0;
          } else {
            day = store.today;
          }
        });
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: (p.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(statusBarColor: Colors.transparent),
        child: Scaffold(
          backgroundColor: p.bg,
          body: Column(children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 10, 16, 8),
              child: Row(children: [
                GestureDetector(onTap: () => setState(() => tab = 4), child: Avatar(me: store.d.me, size: 36, border: 0)),
                gap12,
                Expanded(child: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
              ]),
            ),
            Expanded(
              child: switch (tab) {
                0 => TodayScreen(store: store, day: day, onDay: (d) => setState(() => day = d), goMe: () => openGoal(context, store)),
                1 => DietScreen(store: store, goMe: () => setState(() => tab = 4)),
                2 => MoveScreen(store: store),
                3 => ProgressScreen(store: store),
                _ => MeScreen(store: store),
              },
            ),
          ]),
          floatingActionButton: tab == 0 && prof != null
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Color(0x730FA548), blurRadius: 24, offset: Offset(0, 8))],
                  ),
                  child: FloatingActionButton.extended(
                    backgroundColor: Pal.goSolid,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onPressed: () => openAddFood(context, store, day),
                    icon: const Icon(Icons.add, size: 28),
                    label: const Text('Add food', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            backgroundColor: p.surface,
            indicatorColor: p.brandSoft,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Today'),
              NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu), label: 'Diet'),
              NavigationDestination(icon: Icon(Icons.directions_walk_outlined), selectedIcon: Icon(Icons.directions_walk), label: 'Move'),
              NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Progress'),
              NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Me'),
            ],
          ),
        ),
      ),
    );
  }
}
