import 'package:flutter/material.dart';

import '../alarm/alarm_engine.dart';
import 'insets.dart';

/// Checklist of what the phone must allow for alarms to ring with the app
/// closed. Re-checks whenever the user comes back from a settings page.
class PhoneSetupScreen extends StatelessWidget {
  const PhoneSetupScreen({super.key, required this.engine});

  final PhoneSetup engine;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phone setup')),
      body: _SetupStatus(
        engine: engine,
        builder: (context, status, note) => ListView(
          padding: screenListPadding(context),
          children: [
            Text(
              !status.containsValue(false)
                  ? 'All set. Alarms will ring even when T.N.W.R. is closed '
                      'or the phone is locked.'
                  : 'Allow these so alarms ring when T.N.W.R. is closed or the '
                      'phone is locked. Each button opens the right screen; '
                      'come back here afterwards.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            for (final MapEntry(key: item, value: done) in status.entries)
              Card(
                child: ListTile(
                  leading: Icon(
                    done ? Icons.check_circle : Icons.error_outline,
                    color: done
                        ? Colors.green
                        : Theme.of(context).colorScheme.error,
                  ),
                  title: Text(item.title),
                  subtitle: Text(item.why),
                  trailing: done
                      ? null
                      : FilledButton(
                          onPressed: () => engine.fixSetup(item),
                          child: const Text('Fix')),
                ),
              ),
            if (note != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(note),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Banner on the reminder list while setup is incomplete.
class PhoneSetupBanner extends StatelessWidget {
  const PhoneSetupBanner({super.key, required this.engine});

  final PhoneSetup engine;

  @override
  Widget build(BuildContext context) {
    return _SetupStatus(
      engine: engine,
      builder: (context, status, _) {
        final missing = status.values.where((done) => !done).length;
        return missing == 0
          ? const SizedBox.shrink()
          : Card(
              margin: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.warning_amber),
                title: const Text('Finish phone setup'),
                subtitle: Text(
                    '$missing thing${missing == 1 ? '' : 's'} '
                    'to allow so alarms ring when T.N.W.R. is closed.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PhoneSetupScreen(engine: engine))),
              ),
            );
      },
    );
  }
}

class _SetupStatus extends StatefulWidget {
  const _SetupStatus({required this.engine, required this.builder});

  final PhoneSetup engine;
  final Widget Function(
          BuildContext, Map<SetupItem, bool> status, String? note)
      builder;

  @override
  State<_SetupStatus> createState() => _SetupStatusState();
}

class _SetupStatusState extends State<_SetupStatus>
    with WidgetsBindingObserver {
  Map<SetupItem, bool>? _status;
  String? _note;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final status = await widget.engine.setupStatus();
    final note = await widget.engine.setupNote();
    if (mounted) {
      setState(() {
        _status = status;
        _note = note;
      });
    }
  }

  @override
  Widget build(BuildContext context) => _status == null
      ? const SizedBox.shrink()
      : widget.builder(context, _status!, _note);
}
