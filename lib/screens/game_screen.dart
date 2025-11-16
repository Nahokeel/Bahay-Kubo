import 'dart:async';

import 'package:just_audio/just_audio.dart';
import '../audio/audio_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart';

import '../game_engine.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  // Pool of short players for SFX (also just_audio)
  // Pool of short players for SFX (also just_audio)
  final List<AudioPlayer> _sfxPool = [];
  int _sfxPoolIndex = 0;
  late ConfettiController _confettiController;
  late AnimationController _bgController;
  // Play a short SFX using a transient low-latency AudioPlayer so it doesn't
  // take audio focus away from the looping BGM player.
  void _playTransientSfx(String assetPath) {
    // Play a short SFX via a pooled just_audio player. We don't await
    // playback so UI stays responsive. Use low-latency player mode when
    // possible.
    if (_sfxPool.isEmpty) {
      final p = AudioPlayer();
      try {
        p.setAudioSource(AudioSource.asset(_resolveAsset(assetPath))).then((_) {
          p.play().catchError((_) {});
        }).catchError((_) {});
      } catch (_) {
        // best-effort play
        try {
          p.setAudioSource(AudioSource.asset(assetPath)).then((_) => p.play()).catchError((_) {});
        } catch (_) {}
      }
      // dispose fallback after a short time
      Timer(const Duration(seconds: 2), () {
        try {
          p.dispose();
        } catch (_) {}
      });
      return;
    }

    final player = _sfxPool[_sfxPoolIndex % _sfxPool.length];
    _sfxPoolIndex = (_sfxPoolIndex + 1) % _sfxPool.length;
    try {
      player.setAudioSource(AudioSource.asset(_resolveAsset(assetPath))).then((_) {
        player.play().catchError((_) {});
      }).catchError((_) {});
    } catch (_) {}
  }

  Future<void> _initAudio() async {
    try {
      await AudioManager.instance.init();
    } catch (_) {}

    // Prepare a small pool of SFX players.
    try {
      for (var i = 0; i < 3; i++) {
        final p = AudioPlayer();
        _sfxPool.add(p);
      }
    } catch (_) {}
  }

  String _resolveAsset(String path) {
    // Some existing code returns paths like 'audio/foo.mp3'. Flutter assets
    // are declared under 'assets/...', so ensure the correct prefix is used
    // for just_audio's AudioSource.asset.
    if (path.startsWith('assets/')) return path;
    return 'assets/$path';
  }
  String? _currentBgm;
  GameEngine? _engineRef;
  bool _waitingToStart = true;
  int? _countdownValue;
  Timer? _countdownTimerUI;
  bool _wasRunning = false;
  bool _isAnimating = false;
  Offset _slideOffset = Offset.zero;
  double _opacity = 1.0;
  int _lastPlayedCombo = 0;
  bool _showCombo = false;
  Timer? _comboTimer;
  // Local copy of the currently-displayed item. Using a local reference
  // decouples UI updates from timing/notify order in the engine and makes
  // the card replacement more reliable after swipes.
  SpawnItem? _displayedItem;
  // debug HUD toggle (auto-enabled in debug builds)
  // debug HUD removed
  @override
  void initState() {
    super.initState();
    final engine = Provider.of<GameEngine>(context, listen: false);
    _engineRef = engine;
    // don't auto-start; show start screen with logo and bgm
    // play background music for start screen
    try {
      // Initialize audio session and players asynchronously (no await so initState stays sync)
      _initAudio();
      // confetti for small correct-swipe feedback
      try {
        _confettiController = ConfettiController(duration: const Duration(milliseconds: 700));
      } catch (_) {}
      try {
        _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
      } catch (_) {}
      // don't autoplay menu BGM here; HomeScreen handles menu music. Only
      // play game BGM when the engine transitions to running.
    } catch (_) {}
  engine.addListener(_engineListener);
    // When arriving at the game screen from the main menu, automatically start
    // the 3-2-1 countdown (no logo in-game). Use a post-frame callback so the
    // widget tree is mounted before starting the timer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Check whether this navigation is a transient preview (store -> preview).
      // If so, we should not auto-start the countdown/run.
      final args = ModalRoute.of(context)?.settings.arguments;
      final isPreview = args is Map && args['preview'] == true;
      if (isPreview) {
        // Don't auto-start the countdown; just show the previewed background.
        return;
      }
      if (_wasRunning) return;
      // begin countdown automatically when the screen appears
      _beginCountdownSequence();
    });
  }

  void _beginCountdownSequence() {
    // avoid re-entrancy
    if (_countdownTimerUI != null) return;
    setState(() {
      _countdownValue = 3;
    });
    _countdownTimerUI = Timer.periodic(const Duration(milliseconds: 800), (t) {
      if (!mounted) return;
      setState(() {
        if (_countdownValue != null && _countdownValue! > 1) {
          _countdownValue = _countdownValue! - 1;
        } else {
          // show START then begin
          _countdownTimerUI?.cancel();
          _countdownTimerUI = null;
          _countdownValue = -1; // sentinel for START
          // short delay to show START, then start engine
          Timer(const Duration(milliseconds: 600), () {
            if (!mounted) return;
            final engine = _engineRef ?? Provider.of<GameEngine>(context, listen: false);
            // reset UI combo state before starting a fresh run
            _lastPlayedCombo = 0;
            _showCombo = false;
            engine.start();
            if (!mounted) return;
            setState(() {
              _waitingToStart = false;
              _countdownValue = null;
            });
          });
        }
      });
    });
  }

  void _engineListener() async {
    final engine = _engineRef ?? Provider.of<GameEngine>(context, listen: false);
    // keep a local cache of the engine's current item so the UI can render
    // it consistently even if engine notifies in a timing-sensitive way
    if (mounted) {
      setState(() {
        _displayedItem = engine.currentItem;
      });
    }
    if (kDebugMode) {
      debugPrint('[GameScreen] _engineListener: engine.currentItem=${engine.currentItem?.name} displayed=${_displayedItem?.name} running=${engine.running} timeLeft=${engine.timeLeft}');
    }
    // start/stop music when running toggles. When game starts play game BGM.
    if (engine.running && !_wasRunning) {
      _wasRunning = true;
      try {
        final bgm = engine.bgmAssetPath();
        if (_currentBgm != bgm) {
          await AudioManager.instance.playBgm(bgm);
          _currentBgm = bgm;
        } else {
          // ensure playing
          await AudioManager.instance.playBgm(bgm);
        }
      } catch (_) {}
    } else if (!engine.running && _wasRunning) {
      // only treat this transition as an "end" when time ran out (natural game over).
      // This avoids reacting to internal reset/start sequences (which temporarily set
      // running=false) and accidentally navigating back to results.
      _wasRunning = false;
      try {
        await AudioManager.instance.stopBgm();
        _currentBgm = null;
      } catch (_) {}
      if (engine.timeLeft <= 0.0) {
        // navigate to result screen after small delay so UI updates
        Future.microtask(() {
          if (mounted) Navigator.of(context).pushReplacementNamed('/result');
        });
      }
    }
  }


  /// Try to refresh the local displayed item from the engine, retrying a few
  /// times with a short delay if the engine hasn't produced one yet. This helps
  /// when animation timing and provider notifications race and the UI ends up
  /// briefly showing nothing.
  void _refreshDisplayedItemFromEngine({int retries = 6}) {
    if (!mounted) return;
    final engine = _engineRef ?? Provider.of<GameEngine>(context, listen: false);
    if (engine.currentItem != null) {
      setState(() {
        _displayedItem = engine.currentItem;
      });
      return;
    }
    if (retries <= 0) return;
    // schedule a short retry
    Timer(const Duration(milliseconds: 60), () {
      _refreshDisplayedItemFromEngine(retries: retries - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameEngine>(
      builder: (context, engine, _) {
        // prevent navigating back to main menu while a game is running
        return WillPopScope(
          onWillPop: () async {
            // disallow popping when game is running; allow otherwise
            return !engine.running;
          },
          child: Scaffold(
            appBar: AppBar(automaticallyImplyLeading: false),
            body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _HudCard(
                      icon: Icons.score,
                      label: 'Score',
                      value: engine.score.toString(),
                    ),
                    _HudCard(
                      icon: Icons.monetization_on,
                      label: 'Coins',
                      value: engine.coins.toString(),
                    ),
                    _HudCard(
                      icon: Icons.timer,
                      label: 'Time',
                      value: engine.timeLeft.toStringAsFixed(1) + 's',
                    ),
                    // Pause button. Disable while showing the start/resume countdown
                    // or when the game is not actively running.
                    IconButton(
                      onPressed: (!engine.running || _waitingToStart || _countdownTimerUI != null)
                          ? null
                          : () => _openPauseModal(engine),
                      icon: const Icon(Icons.pause_circle_filled, size: 32),
                    ),
                  ],
                ),
              ),
              LinearProgressIndicator(
                value: (engine.timeLeft / 10.0).clamp(0.0, 1.0),
                minHeight: 8,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragEnd: (details) {
                    final dx = details.velocity.pixelsPerSecond.dx;
                    if (_isAnimating) return;
                    if (dx > 0) {
                      // evaluate swipe (score) now, but spawn next only after outgoing animation
                      _animateThen(() => engine.evaluateSwipe(ItemType.fruit), Offset(1.5, 0));
                    } else if (dx < 0) {
                      _animateThen(() => engine.evaluateSwipe(ItemType.vegetable), Offset(-1.5, 0));
                    }
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // selected background image (covers whole play area)
                      Positioned.fill(
                        child: Image.asset(
                          engine.backgroundAssetPath(),
                          fit: BoxFit.cover,
                        ),
                      ),
                          // confetti overlay for small hits
                          Positioned.fill(
                            child: Align(
                              alignment: Alignment.center,
                              child: ConfettiWidget(
                                confettiController: _confettiController,
                                blastDirectionality: BlastDirectionality.explosive,
                                shouldLoop: false,
                                emissionFrequency: 0.6,
                                numberOfParticles: 12,
                                gravity: 0.2,
                              ),
                            ),
                          ),
                          // parallax overlay: slightly offset the foreground background
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _bgController,
                              builder: (context, child) {
                                final dx = ((_bgController.value * 2) - 1) * 8; // -8 .. 8 px
                                return Transform.translate(
                                  offset: Offset(dx, 0),
                                  child: Opacity(
                                    opacity: 0.12,
                                    child: Image.asset(
                                      engine.backgroundAssetPath(),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      // debug HUD removed
                      Center(
                        child: _displayedItem == null
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text(
                                    'GET READY',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      shadows: [Shadow(blurRadius: 4, color: Colors.black45, offset: Offset(0,2))],
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text('Tap to start or wait for countdown', style: TextStyle(color: Colors.white70, fontSize: 14)),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Left basket
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Image.asset('assets/images/vegleft.png', width: 44, height: 44, fit: BoxFit.contain, errorBuilder: (ctx, e, s) => const Icon(Icons.shopping_basket, size: 40)),
                                          const SizedBox(height: 4),
                                          const Text('Veg')
                                        ],
                                      ),
                                      // item card with animation and combo overlay
                                      AnimatedSlide(
                                        offset: _slideOffset,
                                        duration: const Duration(milliseconds: 300),
                                        child: AnimatedOpacity(
                                          opacity: _opacity,
                                          duration: const Duration(milliseconds: 300),
                                          key: ObjectKey(_displayedItem),
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              SizedBox(
                                                width: 220,
                                                height: 220,
                                                child: Center(
                                                  // show only the PNG (or fallback icon) so images look natural.
                                                  child: _buildItemImage(_displayedItem!),
                                                ),
                                              ),
                                              if (_showCombo)
                                                Positioned(
                                                  top: 8,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(6)),
                                                    child: Text('COMBO $_lastPlayedCombo!', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Right basket
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Image.asset('assets/images/fruitright.png', width: 44, height: 44, fit: BoxFit.contain, errorBuilder: (ctx, e, s) => const Icon(Icons.local_grocery_store, size: 40)),
                                          const SizedBox(height: 4),
                                          const Text('Fruit')
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                      ),
                      if (_waitingToStart)
                        Positioned.fill(
                          child: Material(
                            color: Colors.black.withOpacity(0.4),
                            child: InkWell(
                                  onTap: () {
                                    // begin 3-2-1-START sequence, then engine.start()
                                    _beginCountdownSequence();
                                  },
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // In-game overlay: only show prompt/countdown (no logo)
                                    const SizedBox(height: 12),
                                    if (_countdownValue == null)
                                      const Text('PRESS TO START', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                    if (_countdownValue != null && _countdownValue! > 0)
                                      Text('${_countdownValue}', style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.bold)),
                                    if (_countdownValue != null && _countdownValue == -1)
                                      const Text('START', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ), // close Column (Scaffold body)
        ), // close Scaffold
      ); // close WillPopScope
      }, // close Consumer.builder
    ); // close Consumer
  }

  Widget _buildItemImage(SpawnItem item) {
    // Prefer normalized asset filenames in `assets/images/`.
    // Example: "Eggplant" -> assets/images/eggplant.png
    final filename = item.name.trim().toLowerCase().replaceAll(' ', '_') + '.png';
    final assetPath = 'assets/images/$filename';

    return Image.asset(
      assetPath,
      width: 140,
      height: 140,
      fit: BoxFit.contain,
      // If the asset is missing or fails to decode, show a neutral icon instead
      errorBuilder: (ctx, err, stack) => const Icon(Icons.image_not_supported, size: 72, color: Colors.white),
    );
  }

  Widget _HudCard({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.deepPurple),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  void _openPauseModal(GameEngine engine) {
    // Pause the engine's countdown while the modal is shown so timeLeft
    // does not decrease during the pause. We only allow simple Resume or
    // Back to main menu actions here per the UX request.
    final wasRunning = engine.running && !engine.isPaused;
    if (wasRunning) engine.pauseCountdown();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Center(child: Text('Pause')),
        content: const SizedBox(height: 8, child: Center(child: Text('Game paused'))),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              // Menu: stop the run and navigate home.
              try {
                engine.reset();
              } catch (_) {}
              try {
                AudioManager.instance.stopBgm();
              } catch (_) {}
              Navigator.of(ctx).pop();
              // Use pushReplacement so user can't return to the paused game.
              Navigator.of(context).pushReplacementNamed('/');
            },
            child: const Text('Menu'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (wasRunning) {
                _beginResumeSequence();
              }
            },
            child: const Text('Resume'),
          ),
        ],
      ),
    );
  }

  void _beginResumeSequence() {
    // Show a short 3-2-1 overlay similar to the start sequence, but do
    // not reset scores. After countdown finishes call engine.resumeCountdown().
    if (_countdownTimerUI != null) return;
    setState(() {
      _waitingToStart = true;
      _countdownValue = 3;
    });
    _countdownTimerUI = Timer.periodic(const Duration(milliseconds: 800), (t) {
      if (!mounted) return;
      setState(() {
        if (_countdownValue != null && _countdownValue! > 1) {
          _countdownValue = _countdownValue! - 1;
        } else {
          _countdownTimerUI?.cancel();
          _countdownTimerUI = null;
          _countdownValue = -1; // START sentinel
          Timer(const Duration(milliseconds: 600), () {
            if (!mounted) return;
            final engine = _engineRef ?? Provider.of<GameEngine>(context, listen: false);
            try {
              engine.resumeCountdown();
            } catch (_) {}
            if (!mounted) return;
            setState(() {
              _waitingToStart = false;
              _countdownValue = null;
            });
          });
        }
      });
    });
  }

    void _animateThen(VoidCallback action, Offset target) {
      // animate current item out (slide + fade), then perform action to spawn next item,
      // keep new item invisible and then fade it in centered
      setState(() {
        _isAnimating = true;
        _slideOffset = target;
        _opacity = 0.0;
      });
      Timer(const Duration(milliseconds: 320), () {
        // after the outgoing animation finished, perform the game action which will
        // replace the current item in the engine
        if (kDebugMode) debugPrint('[GameScreen] _animateThen: performing action() (about to call engine swipe)');
        action();
        if (kDebugMode) debugPrint('[GameScreen] _animateThen: action() returned; engine.currentItem=${(_engineRef ?? Provider.of<GameEngine>(context, listen: false)).currentItem?.name}');
        // After evaluating the swipe (scoring), ask the engine to spawn the
        // next item now that the outgoing animation is complete. This moves
        // the spawn timing under UI control and avoids races.
        final engine = _engineRef ?? Provider.of<GameEngine>(context, listen: false);
        try {
          engine.spawnNext();
        } catch (_) {
          // fallback: if spawnNext isn't available for some reason, attempt
          // a conservative ensureItem() call.
          try {
            engine.ensureItem();
          } catch (_) {}
        }
        if (!mounted) return;
        // Use a retry helper to robustly pick up the engine's currentItem even
        // if notifications or spawn happen shortly after this point.
        _refreshDisplayedItemFromEngine();
        if (kDebugMode) debugPrint('[GameScreen] _animateThen: updated _displayedItem=${_displayedItem?.name}');
        // ensure the incoming item starts hidden at center
        if (!mounted) return;
        setState(() {
          _slideOffset = Offset.zero;
          _opacity = 0.0;
        });
        // small delay to allow the new widget to be mounted, then fade it in
        Timer(const Duration(milliseconds: 80), () {
          // Immediately show the incoming card; do not await audio playback so
          // that playback failures or delays can't block the UI fade-in.
          if (mounted) {
            setState(() {
              _opacity = 1.0;
              _isAnimating = false;
            });
          }

          // Decide which SFX to play and whether to show combo overlay.
          final engine = Provider.of<GameEngine>(context, listen: false);
          try {
            if (engine.lastActionCorrect) {
              final curCombo = engine.comboCount;
              if (curCombo >= 3) {
                // Play combo sound only when first reaching 3. For >3, show
                // the combo overlay but play normal correct SFX.
                if (curCombo == 3 && _lastPlayedCombo < 3) {
                  if (engine.sfxEnabled) _playTransientSfx('audio/combo.wav');
                } else {
                  if (engine.sfxEnabled) _playTransientSfx('audio/correct.wav');
                }
                // play a small confetti burst only when the combo first reaches 3
                if (curCombo == 3 && _lastPlayedCombo < 3) {
                  try {
                    _confettiController.play();
                  } catch (_) {}
                }
                // update combo overlay state with the current combo count
                _lastPlayedCombo = curCombo;
                if (mounted) {
                  setState(() {
                    _showCombo = true;
                  });
                }
                _comboTimer?.cancel();
                _comboTimer = Timer(const Duration(milliseconds: 1400), () {
                  if (mounted) {
                    setState(() {
                      _showCombo = false;
                    });
                  }
                });
              } else {
                // regular correct hit
                if (engine.sfxEnabled) _playTransientSfx('audio/correct.wav');
              }
            } else {
              // wrong SFX and reset combo marker (transient)
              if (engine.sfxEnabled) _playTransientSfx('audio/wrong.mp3');
              _lastPlayedCombo = 0;
              if (mounted) {
                setState(() {
                  _showCombo = false;
                });
              }
            }
          } catch (_) {}
        });
      });
    }

    @override
    void dispose() {
      // Clear any transient preview when leaving the game screen so previews
      // don't unintentionally persist across navigation.
      try {
        _engineRef?.clearPreview();
      } catch (_) {}
      // AudioManager holds global BGM player; don't dispose here.
        for (final p in _sfxPool) {
          try {
            p.dispose();
          } catch (_) {}
        }
        try {
          _confettiController.dispose();
        } catch (_) {}
        try {
          _bgController.dispose();
        } catch (_) {}
      _comboTimer?.cancel();
      // remove listener from cached engine ref if possible
      try {
        _engineRef?.removeListener(_engineListener);
      } catch (_) {
        // fallback: try provider lookup only if mounted (safe)
        try {
          final e = Provider.of<GameEngine>(context, listen: false);
          e.removeListener(_engineListener);
        } catch (_) {}
      }
      super.dispose();
    }
}
