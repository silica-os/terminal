// Terminal, the terminal of Silica.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'src/app_info.dart';
import 'src/grid.dart';
import 'src/l10n.dart';
import 'src/pty.dart';
import 'src/style.dart';
import 'src/window.dart';

void main(List<String> args) {
  final env = Platform.environment;
  // `-e program args…` runs a program instead of the login shell.
  final dash = args.indexOf('-e');
  final command = dash >= 0 && dash + 1 < args.length
      ? args.sublist(dash + 1)
      : null;
  final shell = env['SHELL'];
  final shellName = command?.first.split('/').last ?? shell?.split('/').last;
  WidgetsFlutterBinding.ensureInitialized();
  // About Terminal and the standard app menu (silica-ui#99).
  SilicaApp.info = appInfo;
  // The title band is part of the window: Ossido draws only the window buttons in it.
  SilicaWindow.setFullSizeContent(titleBarHeight).ignore();
  // 80 × 24 cells open a 597 × 421 pt window (terminal.md › Default size); the minimum keeps
  // 20 × 4 cells. Resizing does not snap to whole cells yet (docs/parity.md).
  SilicaWindow.setSizeLimits(min: minimumWindowSize).ignore();
  // SILICA_TERMINAL_SIZE=WxH (benchmarks: the same grid in every terminal under test).
  final size = env['SILICA_TERMINAL_SIZE']?.split('x');
  final width = size != null && size.length == 2
      ? double.tryParse(size[0])
      : null;
  final height = size != null && size.length == 2
      ? double.tryParse(size[1])
      : null;
  SilicaWindow.setSize(
    width != null && height != null ? Size(width, height) : defaultWindowSize,
  ).ignore();
  // SILICA_TERMINAL_ENGINE=grid: the embedder emulates the terminal and the app only paints
  // the rows (experimental; measured against the default xterm.dart path).
  if (env['SILICA_TERMINAL_ENGINE'] == 'grid') {
    final colors = Profile.of(
      const AmalfiThemeData(brightness: Brightness.light, app: 'Terminal'),
    ).grid;
    runApp(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: colors.background,
          child: Padding(
            padding: const EdgeInsets.only(top: chromeHeight),
            child: GridTerminalView(
              session: GridSession(pty: SilicaPty(), command: command),
              palette: GridPalette(
                foreground: colors.foreground,
                background: colors.background,
                cursor: colors.cursor,
              ),
              textStyle: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: terminalFontSize,
                fontFamilyFallback: [
                  'Noto Sans Mono',
                  'DejaVu Sans Mono',
                  'monospace',
                ],
              ),
              padding: gridPadding,
            ),
          ),
        ),
      ),
    );
    return;
  }
  runApp(
    AppLocalizationsScope(
      child: Directionality(
        textDirection: TextDirection.ltr,
        // The app palette `App/Terminal`; the appearance follows the system's.
        child: AmalfiTheme(
          app: 'Terminal',
          // Closing the last window keeps Terminal running; a reopen (the Dock, the Launcher)
          // opens a new window with a new shell (APP-LC).
          child: SilicaAppWindow(
            builder: (context) => TerminalWindow(
              pty: SilicaPty(),
              command: command,
              cwd: env['HOME'],
              shellName: shellName,
              onLastTabClosed: () => SilicaApp.closeWindow(),
            ),
          ),
        ),
      ),
    ),
  );
}
