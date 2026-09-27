import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nag_alarm/alarm/alarm_engine.dart';
import 'package:nag_alarm/app_controller.dart';
import 'package:nag_alarm/core/models.dart';
import 'package:nag_alarm/core/settings.dart';
import 'package:nag_alarm/core/task_store.dart';

import 'call_pause_test.dart' show FakeRinger;

class FakeEngine implements AlarmEngine {
  List<String> synced = [];
  final ringing = <String>[];
  final stopped = <String>[];
  bool paused = false;
  bool owns = true;

  @override
  bool get ownsRinging => owns;
  @override
  Future<void> sync(List<NagTask> scheduled, AppSettings settings) async =>
      synced = [for (final t in scheduled) t.id];

  /// Every ring/stop in order, to catch a ring that sneaks in after a stop.
  final calls = <String>[];

  /// Runs while stop is "in flight", like a timer tick landing mid-call.
  Future<void> Function()? duringStop;

  @override
  Future<void> ring(NagTask task) async {
    ringing.add(task.id);
    calls.add('ring ${task.id}');
  }

  @override
  Future<void> stop(String id) async {
    stopped.add(id);
    calls.add('stop $id');
    await duringStop?.call();
  }

  final holds = <String, DateTime>{};
  @override
  Future<void> hold(String id, DateTime until) async => holds[id] = until;
  @override
  Future<void> releaseHold(String id) async => holds.remove(id);
  @override
  Future<bool> isPausedForCall() async => paused;
}

void main() {
  late Directory dir;
  late DateTime now;
  late FakeRinger ringer;
  late FakeEngine engine;
  late TaskStore store;
  late AppController controller;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tnwr_engine');
    now = DateTime(2026, 9, 25, 8);
    ringer = FakeRinger();
    engine = FakeEngine();
    store = TaskStore(File('${dir.path}/tasks.json'));
    final settings = AppSettings(File('${dir.path}/settings.json'));
    for (final (id, minutes) in [('a', 0), ('b', 30)]) {
      await store.upsert(
        NagTask(
          id: id,
          title: id,
          dueAt: now.add(Duration(minutes: minutes)),
          escalation: const EscalationPolicy(maxSnoozes: 1),
          updatedAt: now,
        ),
      );
    }
    controller = AppController(
      store,
      ringer,
      settings: settings,
      engine: engine,
      clock: () => now,
    );
  });

  tearDown(() => dir.delete(recursive: true));

  test('only upcoming tasks are synced to the engine', () async {
    await controller.syncEngine();
    expect(engine.synced, ['a', 'b']);

    await controller.tick(); // 'a' is due now.
    await controller.syncEngine();
    expect(engine.synced, ['b']);
  });

  test('the engine rings, not the app, and stops on proof', () async {
    await controller.tick();
    expect(engine.ringing, contains('a'));
    expect(ringer.isRinging, isFalse, reason: 'the engine plays the sound');

    engine.paused = true;
    await controller.tick();
    expect(controller.pausedForCall, isTrue);

    await controller.complete(store.byId('a')!);
    expect(engine.stopped, ['a']);
    expect(store.byId('a')!.status, TaskStatus.done);
  });

  test('an engine that does not own ringing (iPhone) is still told what '
      'rings and what is held, while the app plays the sound', () async {
    engine.owns = false;
    await controller.tick();
    expect(ringer.isRinging, isTrue, reason: 'the app rings while open');
    expect(engine.ringing, contains('a'));

    await controller.holdForApproval(
      store.byId('a')!,
      const Duration(minutes: 5),
    );
    expect(engine.holds.keys, ['a']);
    expect(ringer.isRinging, isFalse);

    await controller.releaseApprovalHold();
    expect(engine.holds, isEmpty);

    await controller.complete(store.byId('a')!);
    expect(engine.stopped, ['a']);
  });

  for (final owns in [true, false]) {
    for (final (action, act) in [
      ('proof', (AppController c, NagTask t) => c.complete(t)),
      ('snooze', (AppController c, NagTask t) => c.snooze(t)),
    ]) {
      test('a tick landing during stop does not ring again after the '
          '$action (ownsRinging: $owns)', () async {
        engine.owns = owns;
        await controller.tick();
        engine.duringStop = controller.tick;

        await act(controller, store.byId('a')!);
        expect(engine.calls.last, 'stop a');
      });
    }
  }

  test('snoozing stops the engine and reschedules', () async {
    await controller.tick();
    await controller.snooze(store.byId('a')!);
    expect(engine.stopped, ['a']);
    await controller.syncEngine();
    expect(engine.synced, containsAll(['a', 'b']));
  });
}
