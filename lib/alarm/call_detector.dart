import 'dart:io';

import 'package:flutter/services.dart';
import 'package:win32_registry/win32_registry.dart';

/// Tells whether the user is on a call, so the alarm can wait until it's over.
///
/// - Android: phone calls, ringing calls and voice/video chats switch the audio
///   mode (MainActivity.kt).
/// - Windows: any app using the microphone or webcam (Teams, Zoom, Discord,
///   Meet in a browser...), read from Windows' own privacy usage records.
/// - iPhone: phone calls, FaceTime and CallKit apps like WhatsApp
///   (CXCallObserver in AlarmChain.swift).
class CallDetector {
  static const _channel = MethodChannel('nag_alarm/calls');

  bool get isSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isWindows;

  Future<bool> isInCall() async {
    if (Platform.isWindows) return windowsMicOrCameraInUse();
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('isInCall') ?? false;
    } on PlatformException {
      return false;
    }
  }
}

const _consentStore =
    r'Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore';

/// Windows records, per app, when it last started and stopped using the mic
/// or camera; "stopped" is 0 while it's still in use. Desktop apps are listed
/// under NonPackaged, Store apps directly. No permission needed.
bool windowsMicOrCameraInUse() {
  for (final device in const ['microphone', 'webcam']) {
    final base = '$_consentStore\\$device';
    if (_anyAppInUse(base) || _anyAppInUse('$base\\NonPackaged')) return true;
  }
  return false;
}

bool _anyAppInUse(String path) {
  RegistryKey? key;
  try {
    key = Registry.openPath(RegistryHive.currentUser, path: path);
    for (final app in key.subkeyNames.toList()) {
      if (app == 'NonPackaged') continue;
      final entry = Registry.openPath(RegistryHive.currentUser, path: '$path\\$app');
      final started = entry.getIntValue('LastUsedTimeStart') ?? 0;
      final stopped = entry.getIntValue('LastUsedTimeStop') ?? 1;
      entry.close();
      if (started > 0 && stopped == 0) return true;
    }
  } catch (_) {
    // Missing key (never used) or no access: treat as not in use.
  } finally {
    key?.close();
  }
  return false;
}
