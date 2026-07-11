import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'theme.dart';
import 'screens/today_screen.dart';
import 'screens/home_screen.dart';
import 'screens/board_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/archive_screen.dart';
import 'widgets/board_sheet.dart';
import 'widgets/task_sheet.dart';
import 'widgets/common.dart';
import 'widgets/ideas_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Pin intl to a known locale so date formatting works regardless of the
  // host/browser locale (an unrecognized ambient locale throws in intl).
  Intl.defaultLocale = 'en_US';
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..load(),
      child: const TaskBoardApp(),
    ),
  );
}

class TaskBoardApp extends StatelessWidget {
  const TaskBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Boards',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const RootShell(),
    );
  }
}

class RootShell extends StatelessWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    if (!app.loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Surface any newly-unlocked achievements as a toast.
    if (app.pendingUnlocks.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || app.pendingUnlocks.isEmpty) return;
        final items = List<String>.from(app.pendingUnlocks);
        app.pendingUnlocks.clear();
        Toast.show(context, '🏅 Unlocked: ${items.join(', ')}');
      });
    }

    // First open of a new day → pop the "ideas for today" suggestions.
    if (app.pendingDailySuggestions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || !app.pendingDailySuggestions) return;
        app.markSuggestionsShown();
        showDailyIdeasSheet(context);
      });
    }

    final inBoard = app.tab == AppTab.home && app.currentBoardId != null;

    Widget body;
    switch (app.tab) {
      case AppTab.today:
        body = const TodayScreen();
        break;
      case AppTab.stats:
        body = const StatsScreen();
        break;
      case AppTab.archive:
        body = const ArchiveScreen();
        break;
      case AppTab.home:
        body = inBoard ? const BoardScreen() : const HomeScreen();
        break;
    }

    return PopScope(
      canPop: !inBoard,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) app.goHome();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: body,
            ),
          ),
        ),
        floatingActionButton: app.tab == AppTab.home ? _buildFab(context, app) : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        bottomNavigationBar: _BottomNav(app: app),
      ),
    );
  }

  Widget _buildFab(BuildContext context, AppState app) {
    final label = app.currentBoardId != null ? 'New task' : 'New board';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FloatingActionButton.extended(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        elevation: 6,
        onPressed: () {
          if (app.currentBoardId != null) {
            showTaskSheet(context, boardId: app.currentBoardId!);
          } else {
            showBoardSheet(context);
          }
        },
        icon: const Icon(Icons.add, size: 22),
        label: Text(label,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final AppState app;
  const _BottomNav({required this.app});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF0FFFFFF),
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _navBtn('☀️', 'Today', app.tab == AppTab.today,
                  () => app.goTab(AppTab.today)),
              _navBtn('🗂️', 'Boards', app.tab == AppTab.home,
                  () => app.goTab(AppTab.home)),
              _navBtn('📊', 'Insights', app.tab == AppTab.stats,
                  () => app.goTab(AppTab.stats)),
              _navBtn('🗄️', 'Archive', app.tab == AppTab.archive,
                  () => app.goTab(AppTab.archive)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navBtn(String icon, String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 21)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.ink : AppColors.muted,
                )),
          ],
        ),
      ),
    );
  }
}
