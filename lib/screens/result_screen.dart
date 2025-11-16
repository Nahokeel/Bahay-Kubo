import 'dart:convert';
import '../audio/audio_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../game_engine.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final _nameController = TextEditingController();
  String? _imageBase64;
  // Use global AudioManager for one-shot result sound
  // screenshot controller removed; using simple text share for now

  @override
  void dispose() {
    // AudioManager is global; no local player to dispose here.
    _nameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    try {
      AudioManager.instance.init();
      AudioManager.instance.playSfx('audio/time.wav');
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final res = await picker.pickImage(source: ImageSource.gallery, maxWidth: 400, maxHeight: 400);
    if (res != null) {
      final bytes = await res.readAsBytes();
      setState(() {
        _imageBase64 = base64Encode(bytes);
      });
    }
  }

  Future<void> _captureImage() async {
    final picker = ImagePicker();
    try {
      final res = await picker.pickImage(source: ImageSource.camera, maxWidth: 400, maxHeight: 400);
      if (res != null) {
        final bytes = await res.readAsBytes();
        setState(() {
          _imageBase64 = base64Encode(bytes);
        });
      }
    } catch (_) {
      // camera may be unavailable on some platforms; ignore errors
    }
  }

  @override
  Widget build(BuildContext context) {
    final engine = Provider.of<GameEngine>(context);
  // Always show the score from the just-ended run (engine.score). Using
  // leaderboard.first can show a different entry and confuse the UI when
  // the player hasn't yet added the current run to the leaderboard.
  final score = engine.score;
  final coinsFinal = engine.coins;
  final coinsBefore = engine.coinsAtRunStart;
  final coinsGained = engine.lastRunCoinsGained;

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                const Text('TIME!', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Text('Score: $score', style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 8),
                // Show coins breakdown: before + gained = final total
                Text('Coins: $coinsBefore  +  $coinsGained  =  $coinsFinal', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    // show dialog to enter 3-letter name and optional picture
                    final entered = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Add to leaderboard'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: _nameController,
                              maxLength: 3,
                              decoration: const InputDecoration(labelText: '3-letter name'),
                            ),
                            const SizedBox(height: 8),
                            Column(
                              children: [
                                // Use a Wrap so the buttons break onto multiple lines
                                // instead of overflowing on narrow screens.
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _captureImage,
                                      icon: const Icon(Icons.camera_alt),
                                      label: const Text('Take photo'),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: _pickImage,
                                      icon: const Icon(Icons.photo),
                                      label: const Text('Pick image'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (_imageBase64 != null)
                                  CircleAvatar(
                                    backgroundImage: MemoryImage(base64Decode(_imageBase64!)),
                                    radius: 28,
                                  )
                              ],
                            )
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () async {
                              final name = _nameController.text.trim().toUpperCase();
                              if (name.isEmpty || name.length > 3) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter up to 3 letters')));
                                return;
                              }
                              // Add a new leaderboard entry (explicit action)
                              await engine.updateLatestEntry(name: name, imageBase64: _imageBase64);
                              Navigator.of(ctx).pop(true);
                            },
                            child: const Text('Add'),
                          )
                        ],
                      ),
                    );

                    if (entered == true) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to leaderboard')));
                    }
                  },
                  child: const Text('Add to leaderboard'),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Share Result'),
                  onPressed: () async {
                    try {
                      // Share localized/templated message with a placeholder link.
                      final placeholderLink = 'https://example.com'; // replace with your install/join link
                      final shareText = 'Kamusta kaibigan! I got $score points in Bahay Kubo. Got what it takes to beat my score? Tara na and download Bahay Kubo! $placeholderLink';
                      await Share.share(shareText);
                    } catch (_) {}
                  },
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    // retry: navigate to game screen and let the game screen handle starting
                    Navigator.of(context).pushReplacementNamed('/game');
                  },
                  child: const Text('Retry'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                  },
                  child: const Text('Main menu'),
                ),
              ],
            ),
          ),
      ),
    );
  }
}
