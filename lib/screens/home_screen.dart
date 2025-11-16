import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/audio_manager.dart';
import '../widgets/background_scene.dart';
import '../game_engine.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Home screen uses the shared AudioManager for menu BGM

  @override
  void initState() {
    super.initState();
    try {
      AudioManager.instance.init();
      AudioManager.instance.playBgm('audio/mainbgm.mp3');
    } catch (_) {}
  }

  // No local player to dispose; AudioManager holds global players.

  @override
  Widget build(BuildContext context) {
    final engine = Provider.of<GameEngine>(context);
    return Scaffold(
      // No AppBar here: we'll render a transparent coin badge overlay
      body: Stack(
        fit: StackFit.expand,
        children: [
          const BackgroundScene(),
          // coin badge top-right (transparent background)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0, right: 12.0),
              child: Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pushNamed('/store'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
                        const SizedBox(width: 6),
                        Text('${engine.coins}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  _FancyMenuButton(
                    label: 'PLAY',
                    icon: Icons.play_arrow,
                    onPressed: () async {
                      try {
                        await AudioManager.instance.stopBgm();
                      } catch (_) {}
                      Navigator.of(context).pushReplacementNamed('/game');
                    },
                  ),
                  const SizedBox(height: 12),
                  _FancyMenuButton(
                    label: 'LEADERBOARDS',
                    icon: Icons.leaderboard,
                    onPressed: () {
                      Navigator.of(context).pushNamed('/leaderboard');
                    },
                  ),
                  const SizedBox(height: 12),
                  _FancyMenuButton(
                    label: 'SHOP',
                    icon: Icons.store,
                    onPressed: () {
                      Navigator.of(context).pushNamed('/store');
                    },
                  ),
                  const SizedBox(height: 12),
                  _FancyMenuButton(
                    label: 'HOW TO PLAY',
                    icon: Icons.help_outline,
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('How to play'),
                          content: const Text(
                            'Swipe right when fruits appear, swipe left for vegetables. Each correct swipe adds time and coins. The timer decreases over time, and time decreased will increase as time goes on.',
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FancyMenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _FancyMenuButton({Key? key, required this.label, required this.icon, required this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.deepPurple,
          elevation: 4,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.deepPurple),
        label: Text(label, style: const TextStyle(letterSpacing: 1.2)),
      ),
    );
  }
}


