import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'alarm/alarm_engine.dart';
import 'alexa/alexa_link.dart';
import 'alarm/ringer.dart';
import 'alarm/system_volume.dart';
import 'app_controller.dart';
import 'core/branding.dart';
import 'core/settings.dart';
import 'core/task_store.dart';
import 'desktop/desktop_shell.dart';
import 'ui/alarm_screen.dart';
import 'ui/task_list_screen.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final dir = await getApplicationSupportDirectory();
  String path(String name) => '${dir.path}${Platform.pathSeparator}$name';
  final store = TaskStore(File(path('tasks.json')));
  final settings = AppSettings(File(path('settings.json')));
  await Future.wait([store.load(), settings.load()]);

  DesktopShell? shell;
  if (DesktopShell.isDesktop) {
    shell = DesktopShell();
    await shell.init(startHidden: args.contains('--minimized'));
  }

  final controller = AppController(store, Ringer(SystemVolume()),
      settings: settings,
      surface: shell,
      engine: Platform.isAndroid
          ? AndroidAlarmEngine()
          : Platform.isIOS
              ? IosAlarmEngine()
              : null)
    ..start();
  final alexa = AlexaLink(store);
  unawaited(alexa.init()); // Network: don't hold up startup.
  runApp(NagAlarmApp(controller: controller, settings: settings, alexa: alexa));
}

class NagAlarmApp extends StatelessWidget {
  const NagAlarmApp(
      {super.key,
      required this.controller,
      required this.settings,
      required this.alexa});

  final AppController controller;
  final AppSettings settings;
  final AlexaLink alexa;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: appName,
        debugShowCheckedModeBanner: false,
        themeMode: settings.themeMode,
        theme: ThemeData(colorSchemeSeed: Colors.deepOrange),
        darkTheme: ThemeData(
            colorSchemeSeed: Colors.deepOrange, brightness: Brightness.dark),
        home: TaskListScreen(
            controller: controller, settings: settings, alexa: alexa),
        // The alarm covers everything, whatever screen was open. The normal
        // screens stay alive underneath (Offstage) and come back afterwards.
        builder: (context, child) => ListenableBuilder(
          listenable: controller.store,
          builder: (context, _) {
            final ringing = controller.ringingTask;
            return Stack(
              children: [
                Offstage(offstage: ringing != null, child: child),
                if (ringing != null)
                  // Its own Navigator gives the alarm an Overlay for text
                  // fields; it must not share the app's HeroController.
                  HeroControllerScope.none(
                    child: Navigator(
                      key: ValueKey(ringing.id),
                      onGenerateRoute: (_) => MaterialPageRoute(
                        builder: (_) =>
                            AlarmScreen(controller: controller, task: ringing),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
