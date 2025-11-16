import 'package:flutter/material.dart';
import '../widgets/background_scene.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _logoScale;
  late final Animation<double> _textScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.96, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Slightly offset the text animation to make it feel lively
    _textScale = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: const Interval(0.2, 1.0, curve: Curves.easeInOut)),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _goToMain() {
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: InkWell(
        onTap: _goToMain,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const BackgroundScene(),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 56), // push logo toward top-center
                  Center(
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, st) => const Icon(Icons.park, size: 140, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ScaleTransition(
                    scale: _textScale,
                    child: const Text(
                      'PRESS TO START',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.6),
                    ),
                  ),
                  // fill remaining space so content stays at top area
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
