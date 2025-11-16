import 'package:flutter/material.dart';

class BackgroundScene extends StatefulWidget {
  final double cloudsSpeed; // pixels per second roughly
  final double treeSway; // radians
  const BackgroundScene({super.key, this.cloudsSpeed = 40.0, this.treeSway = 0.04});

  @override
  State<BackgroundScene> createState() => _BackgroundSceneState();
}

class _BackgroundSceneState extends State<BackgroundScene> with TickerProviderStateMixin {
  late final AnimationController _cloudController;
  late final AnimationController _treeController;

  @override
  void initState() {
    super.initState();
    _cloudController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _treeController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cloudController.dispose();
    _treeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      // raise the foreground (kubo + trees) a bit more so they sit on the fence/green plain
      final double foregroundBottom = h * 0.26;
      return Stack(
        fit: StackFit.expand,
        children: [
          // static base image
          Image.asset('assets/images/gamebg/static.png', fit: BoxFit.cover),
          // moving clouds
          AnimatedBuilder(
            animation: _cloudController,
            builder: (context, child) {
              final t = _cloudController.value; // 0..1
              // Move clouds from -20% to 20% of width (looping)
              final dx = (t * 1.4 - 0.2) * w; // starts slightly off-left
              return Positioned(
                left: dx,
                top: h * 0.06,
                right: null,
                child: SizedBox(
                  width: w * 0.9,
                  child: Opacity(opacity: 0.9, child: Image.asset('assets/images/gamebg/clouds.png', fit: BoxFit.cover)),
                ),
              );
            },
          ),
          // Align kubo and trees on the same Y axis (move them up toward the fence) and make them a bit bigger
          // kubo centered (drawn behind trees)
          Positioned(
            bottom: foregroundBottom,
            left: (w - (w * 0.52)) / 2,
            child: Image.asset('assets/images/gamebg/kubo.png', width: w * 0.52, fit: BoxFit.contain),
          ),
          // left tree sway (flanking the kubo) - drawn after kubo so trees appear in front
          Positioned(
            left: w * 0.06,
            bottom: foregroundBottom,
            child: AnimatedBuilder(
              animation: _treeController,
              builder: (context, child) {
                final t = _treeController.value; // 0..1
                final angle = (t - 0.5) * 2 * widget.treeSway; // -sway..sway
                return Transform.rotate(angle: angle, alignment: Alignment.bottomCenter, child: child);
              },
              child: Image.asset('assets/images/gamebg/treeleft.png', width: w * 0.38, fit: BoxFit.contain),
            ),
          ),
          // right tree sway (flanking the kubo) - drawn after kubo so trees appear in front
          Positioned(
            right: w * 0.06,
            bottom: foregroundBottom,
            child: AnimatedBuilder(
              animation: _treeController,
              builder: (context, child) {
                final t = _treeController.value;
                final angle = -(t - 0.5) * 2 * widget.treeSway;
                return Transform.rotate(angle: angle, alignment: Alignment.bottomCenter, child: child);
              },
              child: Image.asset('assets/images/gamebg/treeright.png', width: w * 0.38, fit: BoxFit.contain),
            ),
          ),
        ],
      );
    });
  }
}
