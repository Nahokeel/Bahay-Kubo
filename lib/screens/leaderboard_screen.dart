import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:provider/provider.dart';

import '../game_engine.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
  final engine = Provider.of<GameEngine>(context);
  // Present a sorted copy of the leaderboard (highest score first)
  final list = [...engine.leaderboard];
  list.sort((a, b) => b.score.compareTo(a.score));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: [
          IconButton(
            tooltip: 'Reset leaderboard',
            icon: const Icon(Icons.delete_forever),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Reset leaderboard'),
                  content: const Text('Are you sure you want to clear the leaderboard? This cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Reset')),
                  ],
                ),
              );
              if (confirm == true) {
                engine.leaderboard.clear();
                engine.addCoins(0); // trigger save
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leaderboard cleared')));
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Top scores', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final e = list[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: e.imageBase64 != null ? MemoryImage(base64Decode(e.imageBase64!)) : null,
                      child: e.imageBase64 == null ? Text(e.name.isNotEmpty ? e.name[0] : '?') : null,
                    ),
                    title: Text('${e.name} — ${e.score}'),
                    subtitle: Text('${DateTime.fromMillisecondsSinceEpoch(e.timestamp)}'),
                    onTap: () {
                      // Show full player details including full picture, name and score
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(e.name.isNotEmpty ? e.name : 'Player'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (e.imageBase64 != null)
                                CircleAvatar(
                                  radius: 48,
                                  backgroundImage: MemoryImage(base64Decode(e.imageBase64!)),
                                )
                              else
                                const CircleAvatar(
                                  radius: 48,
                                  child: Icon(Icons.person, size: 48),
                                ),
                              const SizedBox(height: 12),
                              Text('Score: ${e.score}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text('Achieved: ${DateTime.fromMillisecondsSinceEpoch(e.timestamp).toLocal()}'),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // clear leaderboard for testing
                // Not exposed in UI normally
                engine.leaderboard.clear();
                engine.addCoins(0); // trigger save
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cleared for demo')));
              },
              child: const Text('Clear (demo)'),
            ),
          ],
        ),
      ),
    );
  }
}
