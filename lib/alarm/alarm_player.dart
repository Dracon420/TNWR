import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Loops one alarm sound at a time.
abstract class AlarmPlayer {
  factory AlarmPlayer() =>
      Platform.isWindows ? _WindowsPlayer() : _AudioplayersPlayer();

  /// [asset] is a file name in assets/sounds/.
  Future<void> loop(String asset);

  /// 0..1. Ignored where the system volume is controlled instead.
  Future<void> setVolume(double volume);
  Future<void> stop();
}

/// Plays a few seconds of a sound so it can be picked in the editor.
class SoundPreview {
  static final _player = AlarmPlayer();
  static Timer? _stopTimer;

  static Future<void> play(String asset) async {
    _stopTimer?.cancel();
    await _player.setVolume(1.0);
    await _player.loop(asset);
    _stopTimer = Timer(const Duration(seconds: 4), stop);
  }

  static Future<void> stop() async {
    _stopTimer?.cancel();
    _stopTimer = null;
    await _player.stop();
  }
}

/// Uses the Win32 PlaySound API (windows/runner/flutter_window.cpp). The
/// audioplayers Windows plugin posts events off the platform thread.
class _WindowsPlayer implements AlarmPlayer {
  static const _channel = MethodChannel('nag_alarm/sound');

  @override
  Future<void> loop(String asset) {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return _channel.invokeMethod('loop',
        '$exeDir\\data\\flutter_assets\\assets\\sounds\\$asset');
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() => _channel.invokeMethod('stop');
}

class _AudioplayersPlayer implements AlarmPlayer {
  final _player = AudioPlayer();
  bool _configured = false;

  @override
  Future<void> loop(String asset) async {
    if (!_configured && (Platform.isAndroid || Platform.isIOS)) {
      // Android: alarm usage plays on the alarm stream, which silent and
      // vibrate mode don't mute, and which SystemVolume raises.
      // iPhone: the playback category ignores the silent switch and, with
      // the audio background mode, keeps ringing when the phone locks.
      await _player.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.gainTransient,
          stayAwake: true,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
      ));
    }
    _configured = true;
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('sounds/$asset'));
  }

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> stop() => _player.stop();
}
