import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ItemType { fruit, vegetable }

class SpawnItem {
  final ItemType type;
  final String name;
  SpawnItem({required this.type, required this.name});
}

class LeaderboardEntry {
  final String name; // 3-letter
  final int score;
  final int timestamp;
  final String? imageBase64; // optional

  LeaderboardEntry({required this.name, required this.score, required this.timestamp, this.imageBase64});

  Map<String, dynamic> toJson() => {
        'name': name,
        'score': score,
        'timestamp': timestamp,
        'image': imageBase64,
      };

  static LeaderboardEntry fromJson(Map<String, dynamic> j) => LeaderboardEntry(
        name: (j['name'] ?? '') as String,
        score: (j['score'] ?? 0) as int,
        timestamp: (j['timestamp'] ?? 0) as int,
        imageBase64: j['image'] as String?,
      );
}

class GameEngine extends ChangeNotifier {
  static const _prefsKey = 'bahaykubo_data_v1';

  final Random _rng = Random();
  SpawnItem? currentItem;
  Timer? _countdownTimer;

  double timeLeft = 10.0; // seconds
  bool running = false;
  int score = 0;
  /// Difficulty level increases as player scores more. Higher values make
  /// time decay faster and rewards smaller.
  int difficultyLevel = 0;
  int coins = 0;
  // User settings persisted in the same storage: audio toggles and difficulty
  bool bgmEnabled = true;
  bool sfxEnabled = true;
  int preferredDifficulty = 0; // 0=normal, 1=hard, etc.
  // Track coins at the start of a run so the UI can show "before + gained = total"
  int _coinsAtRunStart = 0;
  int highScore = 0;
  // Shop / skin support
  // ownedSkins stores ids like 'bg_default', 'bg_skin1', 'bgm_default', 'bgm_lullaby'
  final Set<String> ownedSkins = <String>{'bg_default', 'bgm_default'};
  String selectedBackground = 'bg_default';
  String selectedBgm = 'bgm_default';
  List<LeaderboardEntry> leaderboard = [];
  // Transient preview: when non-null, UI should show this background
  // without persisting it. Useful for shop previews.
  String? previewBackgroundId;

  // Pause state: when true, the countdown timer is suspended but the
  // overall run state (`running`) remains unchanged. This allows UI to
  // present a pause modal without resetting the run.
  bool _paused = false;

  // Combo tracking
  int comboCount = 0; // increments on consecutive correct swipes
  bool lastActionCorrect = false; // last swipe result

  GameEngine() {
    // nothing heavy in constructor
  }

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_prefsKey);
    if (s != null) {
      try {
        final data = jsonDecode(s) as Map<String, dynamic>;
        highScore = data['highScore'] ?? 0;
        coins = data['coins'] ?? 0;
        // load shop state
        final owned = data['ownedSkins'] as List<dynamic>?;
        if (owned != null) {
          ownedSkins.clear();
          ownedSkins.addAll(owned.cast<String>());
        }
        selectedBackground = data['selectedBackground'] ?? selectedBackground;
        selectedBgm = data['selectedBgm'] ?? selectedBgm;
        final raw = data['leaderboard'] as List<dynamic>?;
        if (raw != null) {
          leaderboard = raw.map((e) => LeaderboardEntry.fromJson(Map<String, dynamic>.from(e))).toList();
        }
        // load user settings
        bgmEnabled = data['bgmEnabled'] ?? bgmEnabled;
        sfxEnabled = data['sfxEnabled'] ?? sfxEnabled;
        preferredDifficulty = data['preferredDifficulty'] ?? preferredDifficulty;
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'highScore': highScore,
      'coins': coins,
      'ownedSkins': ownedSkins.toList(),
      'selectedBackground': selectedBackground,
      'selectedBgm': selectedBgm,
      'leaderboard': leaderboard.map((e) => e.toJson()).toList(),
      'bgmEnabled': bgmEnabled,
      'sfxEnabled': sfxEnabled,
      'preferredDifficulty': preferredDifficulty,
    };
    await prefs.setString(_prefsKey, jsonEncode(data));
  }

  void start() {
    reset();
    // record coins at run start so we can compute run-earned coins later
    _coinsAtRunStart = coins;
    running = true;
    // spawn the first item immediately; subsequent items only spawn after swipes
    _spawnNext();
    _startCountdown();
    notifyListeners();
  }

  /// Set a transient preview background. This does not persist ownership
  /// or selection; it's only used for showing a preview in the UI.
  void previewBackground(String id) {
    previewBackgroundId = id;
    notifyListeners();
  }

  /// Clear any active transient preview.
  void clearPreview() {
    previewBackgroundId = null;
    notifyListeners();
  }

  void reset() {
    _countdownTimer?.cancel();
    currentItem = null;
    timeLeft = 10.0;
    running = false;
    score = 0;
    // reset combo and last action state so retries/start fresh have no lingering combo
    comboCount = 0;
    lastActionCorrect = false;
    notifyListeners();
  }

  void _spawnNext() {
    // Randomly choose fruit or vegetable and a name
    final isFruit = _rng.nextBool();
    currentItem = SpawnItem(
      type: isFruit ? ItemType.fruit : ItemType.vegetable,
      name: isFruit ? _randomFruitName() : _randomVegName(),
    );
    if (kDebugMode) debugPrint('[GameEngine] _spawnNext -> ${currentItem?.name}');
    notifyListeners();
  }

  /// Ensure there is a current item when the game is running.
  /// This is a public helper used by UI code as a safety-net when
  /// notify order and animation timing cause transient nulls.
  void ensureItem() {
    if (running && currentItem == null) {
      _spawnNext();
    }
  }

  String _randomFruitName() {
    const fruits = ['Mango', 'Banana', 'Apple', 'Guava', 'Papaya'];
    return fruits[_rng.nextInt(fruits.length)];
  }

  String _randomVegName() {
    const vegs = ['Ginger', 'Eggplant', 'Garlic', 'Okra', 'Onion'];
    return vegs[_rng.nextInt(vegs.length)];
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!running) return;
      if (_paused) return;
      // Base tick is increased slightly by score and scaled by difficulty.
      final baseTick = 0.2 * (1 + score * 0.02);
      final difficultyMultiplier = 1.0 + difficultyLevel * 0.12;
      timeLeft -= baseTick * difficultyMultiplier;
      if (timeLeft <= 0) {
        timeLeft = 0;
        _endGame();
      }
      notifyListeners();
    });
  }

  /// Pause the internal countdown timer without ending the run. Useful
  /// when showing a pause modal from the UI.
  void pauseCountdown() {
    _countdownTimer?.cancel();
    _paused = true;
    notifyListeners();
  }

  /// Resume the countdown timer after a pause. Does nothing if the run
  /// is not currently running.
  void resumeCountdown() {
    if (!_paused) return;
    _paused = false;
    if (running) {
      _startCountdown();
    }
    notifyListeners();
  }

  /// Whether the engine is currently paused (countdown suspended).
  bool get isPaused => _paused;

  void swipeLeft() => _handleSwipe(ItemType.vegetable);
  void swipeRight() => _handleSwipe(ItemType.fruit);
  /// Evaluate the swipe result (apply scoring/combo/time changes) but do NOT
  /// spawn the next item. This allows callers (UI) to control when the next
  /// item appears (for example, after an outgoing animation completes).
  void evaluateSwipe(ItemType chosen) {
    if (!running || currentItem == null) return;
    if (kDebugMode) debugPrint('[GameEngine] evaluateSwipe: chosen=$chosen current=${currentItem?.name}');
    if (chosen == currentItem!.type) {
      // correct
      score += 1;
      // reward shrinks as difficulty increases so higher difficulties are
      // harder to sustain.
      final reward = 1.5 / (1.0 + difficultyLevel * 0.08);
      timeLeft += reward;
      coins += 1;
      comboCount += 1;
      lastActionCorrect = true;
      // possibly increase difficulty when score crosses thresholds
      _updateDifficulty();
    } else {
      // penalty (reduce timer slightly)
      timeLeft -= 1.0 * (1.0 + difficultyLevel * 0.1);
      score = (score - 1).clamp(0, 999999);
      comboCount = 0;
      lastActionCorrect = false;
    }
    // small cap on time to avoid infinite runaway
    timeLeft = timeLeft.clamp(0.0, 9999.0);
    notifyListeners();
  }

  void _updateDifficulty() {
    // Simple rule: difficulty increases every 5 points. You can tweak this
    // threshold (or make it adaptive) for a different curve.
    final newLevel = score ~/ 5;
    if (newLevel != difficultyLevel) {
      difficultyLevel = newLevel;
      if (kDebugMode) debugPrint('[GameEngine] difficulty increased to $difficultyLevel');
    }
  }

  void _handleSwipe(ItemType chosen) {
    // backward-compatible internal method: evaluate then spawn next
    evaluateSwipe(chosen);
    _spawnNext();
    if (kDebugMode) debugPrint('[GameEngine] _handleSwipe -> new current=${currentItem?.name} combo=$comboCount score=$score timeLeft=$timeLeft');
    notifyListeners();
  }

  /// Public wrapper to spawn the next item. UI can call this after finishing
  /// an outgoing animation to ensure the new item appears at the right time.
  void spawnNext() => _spawnNext();

  void _endGame() {
    running = false;
    _countdownTimer?.cancel();
    if (score > highScore) {
      highScore = score;
    }
    // NOTE: do NOT add a leaderboard entry automatically here. Leaderboard entries
    // should be added explicitly by the player via `updateLatestEntry`.
    _saveToStorage();
    notifyListeners();
  }

  /// Update the most recent (index 0) leaderboard entry's name and/or image.
  /// If there is no entry, this will add one.
  /// Add a new leaderboard entry with the provided name and optional image.
  Future<void> updateLatestEntry({required String name, String? imageBase64}) async {
    final entry = LeaderboardEntry(
      name: name,
      score: score,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      imageBase64: imageBase64,
    );
    leaderboard.insert(0, entry);
    if (leaderboard.length > 10) leaderboard = leaderboard.sublist(0, 10);
    await _saveToStorage();
    notifyListeners();
  }

  /// Coins gained during the last run (current coins minus coins at run start).
  int get lastRunCoinsGained => coins - _coinsAtRunStart;

  /// Coins value at the start of the current/last run.
  int get coinsAtRunStart => _coinsAtRunStart;

  /// Save current data to storage (exposed for external calls).
  Future<void> saveToStorage() async {
    await _saveToStorage();
  }

  Future<bool> buyItem(String id, int price) async {
    if (coins >= price) {
      coins -= price;
      await _saveToStorage();
      notifyListeners();
      return true;
    }
    return false;
  }

  void addCoins(int amount) {
    coins += amount;
    _saveToStorage();
    notifyListeners();
  }

  /// Shop helpers
  bool isOwned(String id) => ownedSkins.contains(id);

  /// Attempt to buy a skin/background/bgm. Price must fit in coins.
  bool buySkin(String id, int price) {
    if (ownedSkins.contains(id)) return true;
    if (coins >= price) {
      coins -= price;
      ownedSkins.add(id);
      _saveToStorage();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Select background or bgm. id must be owned to select.
  void selectBackground(String id) {
    if (!ownedSkins.contains(id)) return;
    selectedBackground = id;
    _saveToStorage();
    notifyListeners();
  }

  void selectBgm(String id) {
    if (!ownedSkins.contains(id)) return;
    selectedBgm = id;
    _saveToStorage();
    notifyListeners();
  }

  /// Resolve selected background id to an asset path
  String backgroundAssetPath() {
    // If a transient preview is active, return the preview path so the UI
    // can show the temporary skin without persisting it.
    final idToResolve = previewBackgroundId ?? selectedBackground;
    switch (idToResolve) {
      case 'bg_skin1':
        return 'assets/images/skin1gamebg.png';
      case 'bg_skin2':
        return 'assets/images/skin2gamebg.png';
      case 'bg_default':
      default:
        return 'assets/images/defaultgamebg.png';
    }
  }

  /// Resolve selected bgm id to an asset path
  String bgmAssetPath() {
    switch (selectedBgm) {
      case 'bgm_skin1':
        return 'audio/skin1gamebgm.mp3';
      case 'bgm_default':
      default:
        return 'audio/defaultgamebgm.mp3';
    }
  }
}
