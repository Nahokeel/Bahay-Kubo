import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game_engine.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> with SingleTickerProviderStateMixin {
  // helper lists
  final List<Map<String, Object>> bgItems = [
    {'id': 'bg_default', 'name': 'Default Background', 'price': 0},
    {'id': 'bg_skin1', 'name': 'Starry Night', 'price': 100},
    {'id': 'bg_skin2', 'name': 'Bright Boracay', 'price': 100},
  ];

  final List<Map<String, Object>> bgmItems = [
    {'id': 'bgm_default', 'name': 'Default BGM', 'price': 0},
    {'id': 'bgm_skin1', 'name': 'Lullaby', 'price': 100},
  ];

  OverlayEntry? _coinOverlay;

  String _assetForBgId(String id) {
    switch (id) {
      case 'bg_skin1':
        return 'assets/images/skin1gamebg.png';
      case 'bg_skin2':
        return 'assets/images/skin2gamebg.png';
      case 'bg_default':
      default:
        return 'assets/images/defaultgamebg.png';
    }
  }

  void _showPreviewDialog(BuildContext ctx, String id, String name) {
    final asset = _assetForBgId(id);
    showDialog<void>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        // Show the skin name only; remove the 'Preview:' prefix per UX request.
        title: Text(name),
        content: SizedBox(
          height: 240,
          child: Image.asset(asset, fit: BoxFit.cover, errorBuilder: (c, e, s) => const SizedBox.shrink()),
        ),
        actions: [
          // Removed "Preview in Game" action per request. Only allow closing.
          TextButton(onPressed: () => Navigator.of(dctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showCoinFly(BuildContext context) {
    // Simple overlay animation: float a coin from center -> top-right
  final overlay = Overlay.of(context);
    final size = MediaQuery.of(context).size;
    final start = Offset(size.width / 2 - 24, size.height / 2 - 24);
    final end = Offset(size.width - 72, 28);

    final controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    final animation = Tween<Offset>(begin: start, end: end).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic));

    _coinOverlay = OverlayEntry(builder: (context) {
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Positioned(
            left: animation.value.dx,
            top: animation.value.dy,
            child: child ?? const SizedBox.shrink(),
          );
        },
        child: SizedBox(width: 48, height: 48, child: Image.asset('assets/images/coin.png', fit: BoxFit.contain)),
      );
    });

    overlay.insert(_coinOverlay!);
    controller.forward();
    controller.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _coinOverlay?.remove();
        _coinOverlay = null;
        controller.dispose();
      }
    });
  }

  Widget _buildRow(BuildContext context, Map<String, Object> it, bool isBgm) {
    final engine = Provider.of<GameEngine>(context, listen: false);
    final id = it['id'] as String;
    final name = it['name'] as String;
    final price = it['price'] as int;
    final owned = engine.isOwned(id);
    final selected = isBgm ? engine.selectedBgm == id : engine.selectedBackground == id;

    return ListTile(
      title: Text(name),
      subtitle: Text(owned ? 'Owned' : (price > 0 ? '$price coins' : 'Free')),
      onTap: () {
        // For background items, open a preview dialog on tap
        if (!isBgm) {
          _showPreviewDialog(context, id, name);
        }
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Eye/preview button removed per request (preview dialog still available via tap)
          if (!owned && price > 0)
            ElevatedButton(
              onPressed: () {
                final ok = engine.buySkin(id, price);
                if (ok) {
                  // animate a coin flying to the HUD and auto-select the skin
                  _showCoinFly(context);
                  if (!isBgm) engine.selectBackground(id);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Purchased $name')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not enough coins')));
                }
              },
              child: Text('$price'),
            ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: owned
                ? () {
                    if (isBgm) {
                      engine.selectBgm(id);
                    } else {
                      engine.selectBackground(id);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Selected $name')));
                  }
                : null,
            child: Text(selected ? 'Selected' : 'Select'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final engine = Provider.of<GameEngine>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store'),
        automaticallyImplyLeading: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                const SizedBox(width: 6),
                Text('${engine.coins}'),
              ],
            ),
          ),
        ],
      ),
      body: Consumer<GameEngine>(builder: (context, engine, _) {
        return ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text('Backgrounds', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ...bgItems.map((it) => _buildRow(context, it, false)),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text('Background Music', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ...bgmItems.map((it) => _buildRow(context, it, true)),
          ],
        );
      }),
    );
  }
}
