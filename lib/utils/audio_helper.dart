import 'package:audioplayers/audioplayers.dart';

class AudioHelper {
  AudioHelper._();
  static final AudioHelper instance = AudioHelper._();

  final _player = AudioPlayer();

  Future<void> playChime() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/chime.wav'));
    } catch (_) {}
  }

  Future<void> playChimeTimes(int times) async {
    for (int i = 0; i < times; i++) {
      if (i > 0) await Future.delayed(const Duration(milliseconds: 500));
      await playChime();
    }
  }

  void dispose() => _player.dispose();
}
