import 'package:flutter_test/flutter_test.dart';
import 'package:bahay_kubo/game_engine.dart';
import 'package:bahay_kubo/main.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    final engine = GameEngine();
    await tester.pumpWidget(MyApp(gameEngine: engine));
    // App now starts on the splash screen; tap it to go to main menu and verify PLAY
    await tester.pumpAndSettle();
    expect(find.text('PRESS TO START'), findsOneWidget);
    await tester.tap(find.text('PRESS TO START'));
    await tester.pumpAndSettle();
    // Verify main menu button is present
    expect(find.text('PLAY'), findsOneWidget);
  });
}
