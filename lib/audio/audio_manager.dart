import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

class AudioManager {
  AudioManager._();
  static final AudioManager instance = AudioManager._();

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  String? _currentBgm;

  Future<void> init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration.music());
    } catch (_) {}
  }

  String _resolve(String path) => path.startsWith('assets/') ? path : 'assets/$path';

  Future<void> playBgm(String path) async {
    try {
      final p = _resolve(path);
      if (_currentBgm == path) {
        // already set - ensure playing
        if (!_bgmPlayer.playing) await _bgmPlayer.play();
        return;
      }
      _currentBgm = path;
      await _bgmPlayer.setAudioSource(AudioSource.asset(p));
      await _bgmPlayer.setLoopMode(LoopMode.one);
      await _bgmPlayer.play();
    } catch (_) {}
  }

  Future<void> stopBgm() async {
    try {
      await _bgmPlayer.stop();
    } catch (_) {}
    _currentBgm = null;
  }

  Future<void> playSfx(String path) async {
    try {
      final p = _resolve(path);
      await _sfxPlayer.setAudioSource(AudioSource.asset(p));
      await _sfxPlayer.play();
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _bgmPlayer.dispose();
    } catch (_) {}
    try {
      await _sfxPlayer.dispose();
    } catch (_) {}
  }
}
