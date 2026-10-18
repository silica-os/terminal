import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';
import 'package:terminal/src/app.dart';
import 'package:terminal/src/l10n.dart';
import 'package:terminal/src/pty.dart';
import 'package:terminal/src/settings.dart';
import 'package:terminal/src/system.dart';
import 'package:terminal/src/window.dart';

typedef Json = Map<String, Object?>;

void main() {
  late FakePty pty;
  late FakeSystem system;
  late TerminalApp app;
  late List<WindowSeed> opened;
  var closedLast = 0;

  Future<TerminalWindowState> pump(
    WidgetTester tester, {
    TerminalProfile? profile,
    bool windows = false,
  }) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    useLocale(const Locale('en'));
    pty = FakePty();
    system = FakeSystem(home: '/home/me');
    opened = [];
    closedLast = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('silica/window', JSONMethodCodec()),
      (call) async => null,
    );
    app = TerminalApp(
      pty: pty,
      shellName: 'bash',
      system: system,
      windowOpener: (app, seed) async {
        opened.add(seed);
        return windows;
      },
    );
    addTearDown(app.settings.dispose);
    if (profile != null) app.settings.updateProfile(profile);
    await tester.pumpWidget(
      AppLocalizationsScope(
        locale: const Locale('en'),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AmalfiTheme(
            app: 'Terminal',
            child: TerminalWindow(
              app: app,
              onLastTabClosed: () => closedLast++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return tester.state<TerminalWindowState>(find.byType(TerminalWindow));
  }

  SilicaMenuDelegate delegate() =>
      WidgetsBinding.instance.platformMenuDelegate as SilicaMenuDelegate;

  Json? find_(List<Object?> items, String label) {
    for (final e in items.cast<Json>()) {
      if (e['label'] == label || (e['role'] != null && e['role'] == label)) {
        return e;
      }
      final sub = e['items'];
      if (sub is List) {
        final found = find_(sub, label);
        if (found != null) return found;
      }
    }
    return null;
  }

  void choose(String menu, String label) {
    final m = (delegate().lastModel!['menus']! as List).cast<Json>().firstWhere(
      (m) => m['label'] == menu || m['role'] == menu,
    );
    final item = find_(m['items']! as List, label);
    expect(item, isNotNull, reason: '$menu › $label');
    expect(delegate().activate(item!['id']! as int), isTrue);
  }

  group('when the shell ends', () {
    testWidgets(
      '"close the window" closes the tab, and the window with the last',
      (tester) async {
        final window = await pump(
          tester,
          profile: basicProfile.copyWith(closeOnExit: CloseOnExit.close),
        );
        await window.newTab();
        await tester.pump();
        pty.exit(2, code: 1);
        await tester.pump();
        expect(window.tabs, hasLength(1));
        pty.exit(1, code: 0);
        await tester.pump();
        expect(closedLast, 1);
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets('"close if it exited cleanly" keeps a failed shell on screen', (
      tester,
    ) async {
      final window = await pump(
        tester,
        profile: basicProfile.copyWith(closeOnExit: CloseOnExit.closeIfClean),
      );
      await window.newTab();
      await tester.pump();
      pty.exit(1, code: 3);
      await tester.pump();
      expect(window.tabs, hasLength(2));
      expect(window.tabs.first.grid.text, contains(l10n.processExited(3)));
      pty.exit(2, code: 0);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(window.tabs, hasLength(1));
    });

    testWidgets('"don\'t close" keeps the tab and its text', (tester) async {
      final window = await pump(tester);
      pty.show(1, ['output']);
      pty.exit(1, code: 0);
      await tester.pump();
      expect(window.tabs, hasLength(1));
      expect(window.session.grid.text, contains('output'));
      expect(closedLast, 0);
    });
  });

  group('asking before closing', () {
    testWidgets(
      'always asks, even for an idle shell; never does not, even for a busy one',
      (tester) async {
        final window = await pump(
          tester,
          profile: basicProfile.copyWith(
            askBeforeClosing: AskBeforeClosing.always,
          ),
        );
        await window.requestCloseTab();
        await tester.pump();
        expect(
          find.byKey(const ValueKey('close confirmation')),
          findsOneWidget,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pump();
        app.settings.updateProfile(
          app.settings.defaultProfile.copyWith(
            askBeforeClosing: AskBeforeClosing.never,
          ),
        );
        pty.busy.add(1);
        await tester.pump();
        // The session still has the profile it was opened with: a new tab uses the new one.
        await window.newTab();
        await tester.pump(const Duration(seconds: 1));
        pty.busy.add(2);
        await window.requestCloseTab();
        await tester.pump();
        expect(find.byKey(const ValueKey('close confirmation')), findsNothing);
        expect(window.tabs, hasLength(1));
      },
    );

    testWidgets('an ended shell is never asked about', (tester) async {
      final window = await pump(
        tester,
        profile: basicProfile.copyWith(
          askBeforeClosing: AskBeforeClosing.always,
        ),
      );
      pty.exit(1, code: 0);
      await tester.pump();
      await window.requestCloseTab();
      await tester.pump();
      expect(find.byKey(const ValueKey('close confirmation')), findsNothing);
      expect(closedLast, 1);
    });
  });

  testWidgets(
    'a new tab opens where the shell is, by OSC 7, or at home by the setting',
    (tester) async {
      final window = await pump(tester);
      pty.grid(1, {'cwd': '/home/me/src'});
      await window.newTab();
      await tester.pump();
      expect(pty.spawns.last.cwd, '/home/me/src');
      // Without OSC 7 the process's directory is asked from the pty.
      pty.cwds[2] = '/proc/dir';
      await window.newTab();
      await tester.pump();
      expect(pty.spawns.last.cwd, '/proc/dir');
      app.settings.set(newTabDirectory: NewDirectory.home);
      await window.newTab();
      await tester.pump();
      expect(
        pty.spawns.last.cwd,
        isNull,
        reason: 'the pty starts in the home folder',
      );
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('a new window follows the setting for its folder', (
    tester,
  ) async {
    final window = await pump(tester, windows: true);
    pty.grid(1, {'cwd': '/home/me/src'});
    await window.newWindow();
    expect(opened.single.cwd, isNull);
    app.settings.set(newWindowDirectory: NewDirectory.sameAsCurrent);
    await window.newWindow();
    expect(opened.last.cwd, '/home/me/src');
    expect(opened.last.profile, app.settings.defaultProfile);
    await tester.pump(const Duration(seconds: 1));
  });

  group('the bell', () {
    testWidgets('a background tab marks itself and notifies once in a while', (
      tester,
    ) async {
      final window = await pump(tester);
      await window.newTab();
      await tester.pump(const Duration(seconds: 1));
      // Tab 0 is behind the current one.
      pty.grid(1, {'bell': true});
      pty.grid(1, {'bell': true});
      await tester.pump();
      expect(system.notifications, hasLength(1));
      expect(system.notifications.single.$2, 'bash rang the bell.');
      expect(find.text('• bash'), findsOneWidget);
      window.selectTab(0);
      await tester.pump();
      expect(find.text('• bash'), findsNothing);
    });

    testWidgets('a window in the background notifies for its current tab', (
      tester,
    ) async {
      await pump(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      pty.grid(1, {'bell': true});
      await tester.pump();
      expect(system.notifications, hasLength(1));
    });

    testWidgets('the active tab of the active window only flashes', (
      tester,
    ) async {
      await pump(tester);
      pty.grid(1, {'bell': true});
      await tester.pump(const Duration(milliseconds: 50));
      expect(system.notifications, isEmpty);
    });

    testWidgets('the profile can turn the notification off', (tester) async {
      await pump(tester, profile: basicProfile.copyWith(bellNotify: false));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      pty.grid(1, {'bell': true});
      await tester.pump();
      expect(system.notifications, isEmpty);
    });
  });

  testWidgets('files dropped on the window are typed as quoted paths', (
    tester,
  ) async {
    await pump(tester);
    Future<void> drop(List<String> uris) =>
        tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'silica/drag',
          const JSONMethodCodec().encodeMethodCall(
            MethodCall('drop', {'x': 10, 'y': 10, 'uris': uris}),
          ),
          (_) {},
        );
    // Listen first: the stream starts with its first listener.
    await tester.pump();
    await drop(['file:///home/me/My%20Docs/a.txt', 'file:///tmp/b']);
    await tester.pump();
    expect(utf8.decode(pty.written[1]!), "'/home/me/My Docs/a.txt' /tmp/b ");
    // A window that is not the active one does not take the drop.
    pty.written[1]!.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await drop(['file:///tmp/c']);
    await tester.pump();
    expect(pty.written[1], isEmpty);
  });

  testWidgets('a profile changed in the settings reaches the running tabs', (
    tester,
  ) async {
    await pump(tester);
    app.settings.updateProfile(
      app.settings.defaultProfile.copyWith(
        scrollbackLines: 321,
        cursor: CursorStyleChoice.beam,
      ),
    );
    await tester.pump();
    final configure =
        pty.calls.where((c) => c.$1 == 'configure').last.$3! as Map;
    expect(configure['scrollback'], 321);
    expect(configure['cursor'], 'beam');
    app.settings.set(clipboardRead: true);
    await tester.pump();
    expect(
      (pty.calls.where((c) => c.$1 == 'configure').last.$3!
          as Map)['clipboardRead'],
      true,
    );
  });

  testWidgets(
    'the title shows the directory and the size, as the profile says',
    (tester) async {
      await pump(tester);
      String title() =>
          tester.widget<Text>(find.byKey(const ValueKey('title'))).data!;
      expect(title(), startsWith('bash — '));
      pty.grid(1, {'cwd': '/home/me/src'});
      await tester.pump();
      await tester.pump();
      expect(title(), contains('bash — ~/src — '));
      app.settings.updateProfile(
        app.settings.defaultProfile.copyWith(titleShowsSize: false),
      );
      await tester.pump();
      await tester.pump();
      expect(title(), 'bash — ~/src');
      app.settings.updateProfile(
        app.settings.defaultProfile.copyWith(titleShowsDirectory: false),
      );
      await tester.pump();
      await tester.pump();
      expect(title(), 'bash');
    },
  );

  testWidgets('About, the inspector and the settings open where windows cannot', (
    tester,
  ) async {
    await pump(tester);
    choose('app', 'about');
    await tester.pump();
    expect(
      find.text(
        'Version 0.1.0. The terminal of Silica. Free software under the MIT and Apache 2.0 licenses.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(find.byKey(const ValueKey('about')), findsNothing);

    choose('Shell', 'Show Inspector');
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('inspector panel')), findsOneWidget);
    expect(find.text('80 × 24'), findsNothing);
    expect(find.text('Basic'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('inspector close')));
    await tester.pump();
    expect(find.byKey(const ValueKey('inspector panel')), findsNothing);

    choose('app', 'settings');
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('settings sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings tabs')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings close')));
    await tester.pump();
    expect(find.byKey(const ValueKey('settings sheet')), findsNothing);
  });

  testWidgets(
    'a tab moves to a window of its own, and Merge All Windows brings it back',
    (tester) async {
      tester.view.physicalSize = const Size(900, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      useLocale(const Locale('en'));
      pty = FakePty();
      opened = [];
      app = TerminalApp(
        pty: pty,
        shellName: 'bash',
        system: FakeSystem(),
        windowOpener: (app, seed) async {
          opened.add(seed);
          return true;
        },
      );
      addTearDown(app.settings.dispose);
      Widget window() =>
          SizedBox(width: 450, height: 600, child: TerminalWindow(app: app));
      await tester.pumpWidget(
        AppLocalizationsScope(
          locale: const Locale('en'),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: AmalfiTheme(
              app: 'Terminal',
              child: Row(
                textDirection: TextDirection.ltr,
                children: [window(), window()],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(app.windows, hasLength(2));
      final (first, second) = (app.windows[0], app.windows[1]);
      await first.newTab();
      await tester.pump(const Duration(seconds: 1));
      final moved = first.session;
      await first.moveTabToNewWindow();
      await tester.pump();
      expect(opened.single.sessions, [moved]);
      expect(first.tabs, isNot(contains(moved)));
      // The app opened it as a window of its own: here, the second one takes it.
      second.adopt(moved);
      await tester.pump(const Duration(seconds: 1));
      expect(second.tabs, contains(moved));
      // The process of the moved tab was never closed.
      expect(pty.calls.where((c) => c.$1 == 'close'), isEmpty);
      // Only the window that owns the menu bar builds one.
      expect(find.byType(SilicaMenuBar), findsOneWidget);
      second.mergeAllWindows();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(second.tabs, hasLength(3));
      expect(second.tabs, contains(moved));
      expect(first.tabs, isEmpty);
    },
  );
}
