import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nag_alarm/app_controller.dart';
import 'package:nag_alarm/core/models.dart';
import 'package:nag_alarm/core/settings.dart';
import 'package:nag_alarm/core/task_store.dart';
import 'package:nag_alarm/ui/alarm_screen.dart';

import 'call_pause_test.dart' show FakeCalls, FakeRinger;
import 'engine_test.dart' show FakeEngine;

void main() {
  final now = DateTime(2026, 9, 27, 8);
  late Directory dir;
  late FakeEngine engine;
  late AppController controller;

  Future<void> setUpRinging({Repeat repeat = const Repeat()}) async {
    dir = Directory.systemTemp.createTempSync('tnwr_cancel');
    engine = FakeEngine();
    final store = TaskStore(File('${dir.path}/tasks.json'));
    controller = AppController(
      store,
      FakeRinger(),
      settings: AppSettings(File('${dir.path}/settings.json')),
      engine: engine,
      calls: FakeCalls(),
      clock: () => now,
    );
    await store.upsert(
      NagTask(
        id: 'a',
        title: 'Dishes',
        dueAt: now,
        repeat: repeat,
        updatedAt: now,
      ),
    );
    await controller.tick();
  }

  tearDown(() => dir.deleteSync(recursive: true));

  test(
    'cancelling stops the alarm without counting the task as done',
    () async {
      await setUpRinging();
      await controller.cancelRing(controller.store.byId('a')!);
      final t = controller.store.byId('a')!;
      expect(t.status, TaskStatus.done);
      expect(t.completedAt, isNull, reason: 'not proven');
      expect(engine.stopped, ['a']);
      expect(controller.ringingTask, isNull);
    },
  );

  test('a cancelled repeating task rings again at its next time', () async {
    await setUpRinging(repeat: const Repeat(kind: RepeatKind.daily));
    await controller.cancelRing(controller.store.byId('a')!);
    final t = controller.store.byId('a')!;
    expect(t.status, TaskStatus.scheduled);
    expect(t.dueAt.isAfter(now), isTrue);
  });

  testWidgets('the button needs a 10 s hold, then a confirmation', (
    tester,
  ) async {
    await tester.runAsync(setUpRinging);
    await tester.pumpWidget(
      MaterialApp(
        home: AlarmScreen(
          controller: controller,
          task: controller.ringingTask!,
        ),
      ),
    );
    final button = find.byType(HoldToCancelButton);
    await tester.ensureVisible(button);

    // Letting go early starts over.
    var hold = await tester.startGesture(tester.getCenter(button));
    await tester.pump(); // The hold timer starts on the next frame.
    await tester.pump(const Duration(seconds: 9));
    await hold.up();
    await tester.pump(const Duration(seconds: 2));
    expect(
      find.text('Are you sure you wish to cancel this alarm?'),
      findsNothing,
    );

    hold = await tester.startGesture(tester.getCenter(button));
    await tester.pump(); // The hold timer starts on the next frame.
    await tester.pump(const Duration(seconds: 5));
    expect(find.textContaining('Keep holding'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await hold.up();
    expect(
      find.text('Are you sure you wish to cancel this alarm?'),
      findsOneWidget,
    );

    // "Keep ringing" backs out.
    await tester.tap(find.text('Keep ringing'));
    await tester.pumpAndSettle();
    expect(controller.store.byId('a')!.status, TaskStatus.ringing);

    hold = await tester.startGesture(tester.getCenter(button));
    await tester.pump(); // The hold timer starts on the next frame.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    await hold.up();
    await tester.runAsync(() async {
      await tester.tap(find.text('Cancel alarm'));
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    expect(controller.store.byId('a')!.status, TaskStatus.done);
    expect(controller.store.byId('a')!.completedAt, isNull);
  });
}
