// The app as a whole: the preferences, the pseudo-terminal service, the desktop, and the
// windows that share them. A window is a view of the one Flutter engine; tabs are sessions
// that can move from one window to another.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';
import 'pty.dart';
import 'session.dart';
import 'settings.dart';
import 'style.dart';
import 'system.dart';
import 'window.dart';

/// What a new window starts with.
class WindowSeed {
  const WindowSeed({
    this.profile,
    this.command,
    this.cwd,
    this.sessions = const [],
  });

  /// The profile (null: the default).
  final TerminalProfile? profile;

  /// The program to run instead of the login shell, and the directory to start in.
  final List<String>? command;
  final String? cwd;

  /// Tabs that already run, moved from another window.
  final List<TerminalSession> sessions;
}

class TerminalApp {
  TerminalApp({
    required this.pty,
    TerminalSettings? settings,
    SystemActions? system,
    this.command,
    this.shellName,
    this.cwd,
    this.windowOpener,
  }) : settings = settings ?? TerminalSettings(saveDelay: Duration.zero),
       system = system ?? FakeSystem();

  final PtyBackend pty;
  final TerminalSettings settings;
  final SystemActions system;

  /// The program every new session runs (`-e`); null: the login shell.
  final List<String>? command;
  final String? shellName;

  /// The directory the first window starts in.
  final String? cwd;

  /// Opens another window; null result: the system cannot. Tests replace it.
  final Future<bool> Function(TerminalApp app, WindowSeed seed)? windowOpener;

  /// The open windows, the first being the main one.
  final List<TerminalWindowState> windows = [];

  /// The window that has the keyboard (or the last that had it).
  TerminalWindowState? active;

  /// Opens a window; false if the system cannot open one.
  Future<bool> openWindow(WindowSeed seed) async {
    final opener = windowOpener;
    if (opener != null) return opener(this, seed);
    final width = windowWidth(seed.profile?.columns ?? defaultColumns);
    final height = windowHeight(seed.profile?.rows ?? defaultRows);
    SilicaWindowController? window;
    window = await SilicaWindows.openWindow(
      title: l10n.appTitle,
      size: Size(width, height),
      minSize: minimumWindowSize,
      toolbarHeight: titleBarHeight,
      builder: (context) => TerminalWindow(
        app: this,
        seed: seed,
        onLastTabClosed: () => unawaited(window?.close() ?? Future.value()),
        onTitle: (title) =>
            unawaited(window?.setTitle(title) ?? Future.value(false)),
      ),
    );
    if (window == null) return false;
    window.onCloseRequested = () async {
      for (final w in windows) {
        if (w.viewIdOrNull == window?.viewId) return w.requestCloseWindow();
      }
      return true;
    };
    return true;
  }
}
