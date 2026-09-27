import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_controller.dart';
import '../core/branding.dart';
import '../core/settings.dart';
import '../core/models.dart';
import '../proof/proof.dart';
import '../alarm/alarm_engine.dart';
import '../alexa/alexa_link.dart';
import 'phone_setup.dart';
import 'settings_screen.dart';
import 'task_edit_screen.dart';

class TaskListScreen extends StatelessWidget {
  const TaskListScreen(
      {super.key,
      required this.controller,
      required this.settings,
      required this.alexa});

  final AppController controller;
  final AppSettings settings;
  final AlexaLink alexa;

  Future<void> _edit(BuildContext context, [NagTask? task]) async {
    final saved = await Navigator.of(context).push<NagTask>(
        MaterialPageRoute(builder: (_) => TaskEditScreen(task: task)));
    if (saved != null) await controller.store.upsert(saved);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(appName),
            Text(appTagline, style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SettingsScreen(
                    settings: settings,
                    engine: controller.engine,
                    alexa: alexa))),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_alarm),
        label: const Text('New reminder'),
        onPressed: () => _edit(context),
      ),
      body: ListenableBuilder(
        listenable: controller.store,
        builder: (context, _) {
          final tasks = controller.store.tasks;
          final active =
              tasks.where((t) => t.status != TaskStatus.done).toList();
          final done = tasks.where((t) => t.status == TaskStatus.done).toList();
          if (tasks.isEmpty) {
            return Column(
              children: [
                if (controller.engine case final PhoneSetup engine)
                  PhoneSetupBanner(engine: engine),
                const Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No reminders yet.\nAdd one, and it will nag you until you prove it\'s done.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView(
            // Room for the floating button and the phone's navigation bar.
            padding: EdgeInsets.only(
                bottom: 96 + MediaQuery.viewPaddingOf(context).bottom),
            children: [
              if (controller.engine case final PhoneSetup engine)
                PhoneSetupBanner(engine: engine),
              for (final t in active) _tile(context, t),
              if (done.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text('Done'),
                ),
                for (final t in done) _tile(context, t),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, NagTask t) {
    final when = DateFormat('EEE MMM d, h:mm a').format(t.dueAt);
    final repeat = switch (t.repeat.kind) {
      RepeatKind.none => '',
      RepeatKind.daily => ' · daily',
      RepeatKind.weekly => ' · weekly',
    };
    final proofs = t.proofs.map(proofLabel).join(t.proofMode == ProofMode.all
        ? ' + '
        : ' or ');
    return ListTile(
      leading: Icon(switch (t.status) {
        TaskStatus.scheduled => Icons.alarm,
        TaskStatus.ringing => Icons.notifications_active,
        TaskStatus.done => Icons.check_circle_outline,
      }),
      title: Text(t.title,
          style: t.status == TaskStatus.done
              ? const TextStyle(decoration: TextDecoration.lineThrough)
              : null),
      subtitle: Text('$when$repeat\n$proofs'),
      isThreeLine: true,
      onTap: t.status == TaskStatus.ringing ? null : () => _edit(context, t),
      trailing: t.status == TaskStatus.ringing
          ? null
          : PopupMenuButton<String>(
              onSelected: (action) async {
                switch (action) {
                  case 'test':
                    await controller.testRing(t);
                  case 'delete':
                    await controller.store.delete(t.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'test', child: Text('Test: ring in 5 seconds')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
    );
  }
}
