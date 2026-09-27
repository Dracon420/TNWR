import 'package:flutter/material.dart';

import '../alarm/alarm_engine.dart';
import '../core/settings.dart';
import '../alexa/alexa_link.dart';
import 'alexa_screen.dart';
import 'insets.dart';
import 'phone_setup.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen(
      {super.key, required this.settings, this.engine, this.alexa});

  final AppSettings settings;
  final AlarmEngine? engine;
  final AlexaLink? alexa;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget section(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
          child: Text(text, style: theme.textTheme.titleMedium),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: screenListPadding(context),
          children: [
            if (engine case final PhoneSetup engine) ...[
              section('Background alarms'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phonelink_setup),
                title: const Text('Phone setup'),
                subtitle: const Text(
                    'Permissions needed for alarms to ring when the app is closed'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PhoneSetupScreen(engine: engine))),
              ),
            ],
            if (alexa case final alexa? when alexa.available) ...[
              section('Alexa'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.speaker),
                title: Text(alexa.linked ? 'Alexa connected' : 'Connect Alexa'),
                subtitle: const Text(
                    'Your Echo says your reminders and repeats them until they are done'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AlexaScreen(alexa: alexa))),
              ),
            ],
            section('Appearance'),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto),
                    label: Text('System')),
                ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode),
                    label: Text('Light')),
                ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode),
                    label: Text('Dark')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => settings.setThemeMode(s.first),
            ),
            section('Calls'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Pause alarms during calls'),
              subtitle: const Text(
                  'Phone calls, video chats and FaceTime-style calls. On a PC: '
                  'whenever an app is using the microphone or camera (Teams, '
                  'Zoom, Discord...). The alarm goes quiet during the call and '
                  'comes back afterwards at the same loudness. The task still '
                  'has to be proven.'),
              value: settings.pauseDuringCalls,
              onChanged: settings.setPauseDuringCalls,
            ),
            if (settings.pauseDuringCalls)
              Row(
                children: [
                  const SizedBox(width: 140, child: Text('Resume after call')),
                  Expanded(
                    child: Slider(
                      value: settings.callResumeDelaySeconds.toDouble(),
                      min: 0,
                      max: 120,
                      divisions: 8,
                      onChanged: (v) =>
                          settings.setCallResumeDelaySeconds(v.round()),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                        settings.callResumeDelaySeconds == 0
                            ? 'right away'
                            : '${settings.callResumeDelaySeconds} s',
                        textAlign: TextAlign.end),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
