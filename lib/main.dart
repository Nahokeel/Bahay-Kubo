import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'game_engine.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/game_screen.dart';
import 'screens/store_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/result_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final engine = GameEngine();
  await engine.loadFromStorage();
  runApp(MyApp(gameEngine: engine));
}

class MyApp extends StatelessWidget {
  final GameEngine gameEngine;
  const MyApp({super.key, required this.gameEngine});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GameEngine>.value(
      value: gameEngine,
      child: MaterialApp(
        title: 'Bahay Kubo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          textTheme: GoogleFonts.poppinsTextTheme(),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            ),
          ),
        ),
        initialRoute: '/splash',
        routes: {
          '/': (_) => const HomeScreen(),
          '/splash': (_) => const SplashScreen(),
          '/game': (_) => const GameScreen(),
          '/result': (_) => const ResultScreen(),
          '/store': (_) => const StoreScreen(),
          '/leaderboard': (_) => const LeaderboardScreen(),
        },
      ),
    );
  }
}
