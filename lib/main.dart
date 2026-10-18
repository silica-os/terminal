// Terminal, the terminal of Silica.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'src/app.dart';
import 'src/l10n.dart';
import 'src/pty.dart';
import 'src/settings.dart';
import 'src/style.dart';
import 'src/system.dart';
import 'src/window.dart';

Future<void> main(List<String> args) async {
  final env = Platform.environment;
  // `-e program args…` runs a program instead of the login shell.
  final dash = args.indexOf('-e');
  final command = dash >= 0 && dash + 1 < args.length
      ? args.sublist(dash + 1)
      : null;
  final shell = env['SHELL'];
  final shellName = command?.first.split('/').last ?? shell?.split('/').last;
  WidgetsFlutterBinding.ensureInitialized();
  final settings = TerminalSettings(store: FileSettingsStore());
  await settings.load();
  // The title band is part of the window: Ossido draws only the window buttons in it.
  SilicaWindow.setFullSizeContent(titleBarHeight).ignore();
  // The default profile's size opens the window (80 × 24 cells: 640 × 476 pt); the minimum
  // keeps 20 × 4 cells. Resizing does not snap to whole cells yet (docs/parity.md).
  SilicaWindow.setSizeLimits(min: minimumWindowSize).ignore();
  // SILICA_TERMINAL_SIZE=WxH (benchmarks: the same grid in every terminal under test).
  final size = env['SILICA_TERMINAL_SIZE']?.split('x');
  final width = size != null && size.length == 2
      ? double.tryParse(size[0])
      : null;
  final height = size != null && size.length == 2
      ? double.tryParse(size[1])
      : null;
  final profile = settings.defaultProfile;
  SilicaWindow.setSize(
    width != null && height != null
        ? Size(width, height)
        : Size(windowWidth(profile.columns), windowHeight(profile.rows)),
  ).ignore();
  final app = TerminalApp(
    pty: SilicaPty(),
    settings: settings,
    system: DesktopSystem(),
    command: command,
    shellName: shellName,
    cwd: env['HOME'],
  );
  runApp(
    AppLocalizationsScope(
      child: Directionality(
        textDirection: TextDirection.ltr,
        // The app palette `App/Terminal`; the appearance follows the system's.
        child: AmalfiTheme(
          app: 'Terminal',
          // The other windows (New Window, the settings, the inspector) are views of this
          // engine, built next to the main one.
          child: SilicaWindowHost(
            // Closing the last window keeps Terminal running; a reopen (the Dock, the
            // Launcher) opens a new window with a new shell (APP-LC).
            child: SilicaAppWindow(
              builder: (context) => TerminalWindow(
                app: app,
                onLastTabClosed: () => SilicaApp.closeWindow(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
