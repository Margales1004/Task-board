// Smoke test: the app boots and shows the home screen.
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:task_board/app_state.dart';
import 'package:task_board/main.dart';

void main() {
  testWidgets('boots to the boards home screen', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final state = AppState();
    await state.load();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const TaskBoardApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Header title and nav labels render.
    expect(find.text('My Boards'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);

    // Empty state on first run.
    expect(find.text('No boards yet'), findsOneWidget);
  });
}
