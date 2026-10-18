// The app as a whole: the preferences, the pseudo-terminal service, the desktop, and the
// windows that share them. A window is a view of the one Flutter engine; tabs are sessions
// that can move from one window to another.

import 'dart:async';

import 'package:flutter/scheduler.dart';
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

  /// Whether the first window of this run has opened (it may open the launch group).
  bool launched = false;

  /// The open windows, the first being the main one.
  final List<TerminalWindowState> windows = [];

  /// The window that has the keyboard (or the last that had it).
  TerminalWindowState? active;

  /// The window whose menus are in the menu bar: Flutter lets one menu bar exist at a time,
  /// so the windows take turns; a window builds its bar only while it is the owner.
  final ValueNotifier<TerminalWindowState?> menuOwner = ValueNotifier(null);

  /// [window] wants the menu bar (it got the keyboard or the pointer). The window that has
  /// it lets go first and the new one takes over a frame later.
  void claimMenus(TerminalWindowState window) {
    active = window;
    final owner = menuOwner.value;
    if (owner == window) return;
    if (owner == null) {
      menuOwner.value = window;
      return;
    }
    menuOwner.value = null;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (active == window && windows.contains(window)) {
        menuOwner.value = window;
      } else if (menuOwner.value == null && windows.isNotEmpty) {
        menuOwner.value = active != null && windows.contains(active)
            ? active
            : windows.first;
      }
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// [window] is going away: another one takes the menu bar.
  void releaseMenus(TerminalWindowState window) {
    if (menuOwner.value != window) return;
    menuOwner.value = null;
    final rest = windows.where((w) => w != window).toList();
    if (rest.isEmpty) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (menuOwner.value == null && windows.isNotEmpty) {
        menuOwner.value = windows.contains(active) ? active : windows.first;
      }
    });
  }

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
