import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../core/models.dart';
import '../core/settings.dart';

/// OS-level alarms that fire and ring with the app closed.
abstract class AlarmEngine {
  /// True when the engine plays the sound, escalates and pauses for calls
  /// itself, so the Dart ringer stays silent.
  bool get ownsRinging;

  /// Replaces all upcoming alarms with [scheduled].
  Future<void> sync(List<NagTask> scheduled, AppSettings settings);

  /// Makes sure [task] is ringing (it came due while the app was open).
  Future<void> ring(NagTask task);

  /// The task was proven or snoozed.
  Future<void> stop(String id);

  /// Silence [id] until [until] (waiting for a photo approval), then ring at
  /// the volume it had.
  Future<void> hold(String id, DateTime until);

  /// End a [hold] early (the approver said no).
  Future<void> releaseHold(String id);

  Future<bool> isPausedForCall();
}

/// Permissions and settings the phone needs for background alarms. The
/// native side reports only the items that apply on that phone.
enum SetupItem {
  notifications(
    'Allow notifications',
    'The alarm shows as a notification and opens over the lock screen.',
    'Reminders ring as notifications while T.N.W.R. is closed.',
  ),
  fullScreen(
    'Allow full-screen alarms',
    'Lets the alarm fill the screen like an incoming call.',
  ),
  exactAlarms('Allow alarms & reminders', 'Rings at the exact time you set.'),
  battery(
    'Set battery to Unrestricted',
    "Stops the phone from putting T.N.W.R. to sleep and skipping alarms.",
  ),
  alarmKit(
    'Allow alarms',
    'Reminders ring as real alarms, through silent mode and Focus, even '
        'with T.N.W.R. closed.',
  );

  /// [_iosWhy] replaces [_why] on iPhone.
  const SetupItem(this.title, this._why, [this._iosWhy]);
  final String title;
  final String _why;
  final String? _iosWhy;

  String get why => Platform.isIOS ? _iosWhy ?? _why : _why;
}

/// The phone setup checklist (PhoneSetupScreen), shared by the Android and
/// iPhone engines.
mixin PhoneSetup {
  static const _channel = MethodChannel('nag_alarm/alarms');

  /// The items that apply on this phone, each true once it's done.
  Future<Map<SetupItem, bool>> setupStatus() async {
    final status =
        await _channel.invokeMapMethod<String, bool>('setupStatus') ?? {};
    return {for (final item in SetupItem.values) item: ?status[item.name]};
  }

  /// Missing items; empty when the phone is fully set up.
  Future<Set<SetupItem>> missingSetup() async => {
    for (final MapEntry(key: item, value: done)
        in (await setupStatus()).entries)
      if (!done) item,
  };

  /// Opens the permission prompt or settings page for [item].
  Future<void> fixSetup(SetupItem item) =>
      _channel.invokeMethod('fixSetup', item.name);

  /// A warning shown under the checklist, or null.
  Future<String?> setupNote() async => null;
}

/// Android: lib side of AlarmScheduler / AlarmService (Kotlin).
class AndroidAlarmEngine with PhoneSetup implements AlarmEngine {
  static const _channel = MethodChannel('nag_alarm/alarms');

  @override
  bool get ownsRinging => true;

  @override
  Future<void> sync(List<NagTask> scheduled, AppSettings settings) =>
      _channel.invokeMethod(
        'sync',
        jsonEncode({
          'alarms': [for (final t in scheduled) alarmJson(t)],
          'pauseDuringCalls': settings.pauseDuringCalls,
          'callResumeDelaySeconds': settings.callResumeDelaySeconds,
        }),
      );

  @override
  Future<void> ring(NagTask task) => _channel.invokeMethod(
    'ring',
    jsonEncode({
      ...alarmJson(task),
      if (task.ringingSince != null)
        'since': task.ringingSince!.millisecondsSinceEpoch,
    }),
  );

  @override
  Future<void> stop(String id) => _channel.invokeMethod('stop', id);

  @override
  Future<void> hold(String id, DateTime until) => _channel.invokeMethod(
    'hold',
    {'id': id, 'until': until.millisecondsSinceEpoch},
  );

  @override
  Future<void> releaseHold(String id) =>
      _channel.invokeMethod('hold', {'id': id, 'until': 0});

  @override
  Future<bool> isPausedForCall() async =>
      await _channel.invokeMethod<bool>('isPausedForCall') ?? false;

  /// Shape read by AlarmStore.kt and AlarmChain.swift.
  static Map<String, dynamic> alarmJson(NagTask t) => {
    'id': t.id,
    'title': t.title,
    'dueAt': t.dueAt.millisecondsSinceEpoch,
    'snoozesUsed': t.snoozesUsed,
    'esc': {
      'startVolume': t.escalation.startVolume,
      'stepSize': t.escalation.stepSize,
      'stepSeconds': t.escalation.stepSeconds,
      'maxVolume': t.escalation.maxVolume,
      'sound': t.escalation.sound.file,
      'escalationSound': t.escalation.escalationSound.file,
      'sirenAfterSeconds': t.escalation.sirenAfterSeconds,
      'vibrate': t.escalation.vibrate,
    },
  };
}

/// iPhone: lib side of AlarmChain.swift. It can't raise the volume or keep
/// ringing in the background, so it schedules a chain of system alarms
/// (AlarmKit on iOS 26+, time-sensitive notifications before that) that
/// repeat until the proof is passed. While the app is open, the Dart [Ringer]
/// plays the alarm and the chain is pushed ahead so both don't ring at once.
class IosAlarmEngine with PhoneSetup implements AlarmEngine {
  static const _channel = MethodChannel('nag_alarm/alarms');

  @override
  bool get ownsRinging => false;

  @override
  Future<void> sync(List<NagTask> scheduled, AppSettings settings) =>
      _channel.invokeMethod(
        'sync',
        jsonEncode({
          'alarms': [
            for (final t in scheduled) AndroidAlarmEngine.alarmJson(t),
          ],
          'pauseDuringCalls': settings.pauseDuringCalls,
          'callResumeDelaySeconds': settings.callResumeDelaySeconds,
        }),
      );

  /// Called every tick while [task] rings in the app, so the chain keeps
  /// going if the app is closed.
  @override
  Future<void> ring(NagTask task) => _channel.invokeMethod(
    'ring',
    jsonEncode(AndroidAlarmEngine.alarmJson(task)),
  );

  @override
  Future<void> stop(String id) => _channel.invokeMethod('stop', id);

  @override
  Future<void> hold(String id, DateTime until) => _channel.invokeMethod(
    'hold',
    {'id': id, 'until': until.millisecondsSinceEpoch},
  );

  @override
  Future<void> releaseHold(String id) =>
      _channel.invokeMethod('hold', {'id': id, 'until': 0});

  @override
  Future<bool> isPausedForCall() async =>
      await _channel.invokeMethod<bool>('isPausedForCall') ?? false;

  @override
  Future<String?> setupNote() async {
    if (await _channel.invokeMethod<bool>('usesSystemAlarms') ?? false) {
      return null;
    }
    return 'On this iOS version, silent mode mutes alarms while T.N.W.R. is '
        'closed. Leave silent mode off at night, or update to iOS 26 or '
        'later, where alarms ring through silent mode and Focus.';
  }
}
