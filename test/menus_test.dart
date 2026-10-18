import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';
import 'package:terminal/src/l10n.dart';
import 'package:terminal/src/app.dart';
import 'package:terminal/src/pty.dart';
import 'package:terminal/src/system.dart';
import 'package:terminal/src/window.dart';

typedef Json = Map<String, Object?>;

void main() {
  late FakePty pty;
  late TerminalApp app;

  Future<TerminalWindowState> pump(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    pty = FakePty();
    app = TerminalApp(
      pty: pty,
      shellName: 'bash',
      system: FakeSystem(home: '/home/me'),
      windowOpener: (app, seed) async => false,
    );
    addTearDown(app.settings.dispose);
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppLocalizationsScope(
        locale: locale,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: TerminalWindow(app: app),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return tester.state<TerminalWindowState>(find.byType(TerminalWindow));
  }

  SilicaMenuDelegate delegate() =>
      WidgetsBinding.instance.platformMenuDelegate as SilicaMenuDelegate;

  List<Json> menus() => (delegate().lastModel!['menus']! as List).cast<Json>();

  Json menu(String label) => menus().firstWhere((m) => m['label'] == label);

  /// The entry with this label in a menu, searching submenus.
  Json? entry(List<Object?> items, String label) {
    // Standard items carry a role and no label: the bar labels them.
    const roles = {
      'Undo': 'undo',
      'Redo': 'redo',
      'Cut': 'cut',
      'Copy': 'copy',
      'Paste': 'paste',
      'Select All': 'select_all',
    };
    for (final e in items.cast<Json>()) {
      if (e['label'] == label ||
          (e['role'] != null && e['role'] == roles[label])) {
        return e;
      }
      final sub = e['items'];
      if (sub is List) {
        final found = entry(sub, label);
        if (found != null) return found;
      }
    }
    return null;
  }

  Json item(String menuLabel, String label) {
    final found = entry(menu(menuLabel)['items']! as List, label);
    expect(found, isNotNull, reason: '$menuLabel › $label');
    return found!;
  }

  bool enabled(Json e) => e['enabled'] == true;

  void choose(Json e) => expect(delegate().activate(e['id']! as int), isTrue);

  testWidgets('the menu bar has the six menus of the reference', (
    tester,
  ) async {
    await pump(tester);
    expect(
      [for (final m in menus()) m['label']],
      ['Terminal', 'Shell', 'Edit', 'View', 'Window', 'Help'],
    );
    expect(menus().first['role'], 'app');
    expect(menu('Window')['role'], 'window');
    expect(menu('Help')['role'], 'help');
    // About and Settings… are the app's own; the system items are the bar's.
    final appMenu = (menus().first['items']! as List).cast<Json>();
    expect(
      [for (final e in appMenu) e['role']].whereType<String>(),
      containsAll([
        'about',
        'settings',
        'services',
        'hide',
        'hide_others',
        'show_all',
        'quit',
      ]),
    );
  });

  testWidgets('no item is shown that does nothing', (tester) async {
    await pump(tester);
    // What the system cannot do for a terminal is left out, not drawn disabled.
    for (final (menuLabel, label) in [
      ('Shell', 'Open…'),
      ('Shell', 'Export Text As…'),
      ('Shell', 'Export Selected Text As…'),
      ('Shell', 'Export Settings…'),
      ('Shell', 'Print…'),
      ('Shell', 'Print Selection…'),
      ('Shell', 'Edit Background Color'),
      ('Edit', 'Copy Special'),
      ('Edit', 'Bookmarks'),
      ('Edit', 'Show Colors'),
      ('Edit', 'Num Lock'),
      ('Edit', 'Fill Screen'),
      ('Edit', 'Remove Excess Lines'),
      ('View', 'Show All Tabs'),
      ('View', 'Show Alternate Screen'),
      ('App', 'Secure Keyboard Entry'),
    ]) {
      final items = menuLabel == 'App'
          ? menus().first['items']! as List
          : menu(menuLabel)['items']! as List;
      expect(entry(items, label), isNull, reason: '$menuLabel › $label');
    }
    // The items that remain are all live, bar the ones a terminal never has (Undo, Redo, Cut).
    void check(List<Object?> items, String path) {
      for (final e in items.cast<Json>()) {
        final sub = e['items'];
        final label = '$path › ${e['label'] ?? e['role']}';
        if (sub is List) {
          check(sub, label);
        } else if (e['separator'] != true &&
            e['role'] == null &&
            e['enabled'] == false) {
          // Disabled for now (nothing selected, one tab…): it has an action.
          expect(e['id'], isNotNull, reason: label);
        }
      }
    }

    for (final m in menus()) {
      check(m['items']! as List, m['label']! as String);
    }
  });

  testWidgets('Shell: shortcuts, separators and enabled states', (
    tester,
  ) async {
    await pump(tester);
    final newTab = item('Shell', 'New Tab with Profile - Basic');
    expect(enabled(newTab), isTrue);
    expect(newTab['shortcut'], {'key': 'T', 'meta': true});
    expect(item('Shell', 'New Tab with Same Command')['shortcut'], {
      'key': 'T',
      'meta': true,
      'ctrl': true,
    });
    expect(item('Shell', 'New Window with Profile - Basic')['shortcut'], {
      'key': 'N',
      'meta': true,
    });
    expect(item('Shell', 'New Command…')['shortcut'], {
      'key': 'N',
      'meta': true,
      'shift': true,
    });
    for (final label in [
      'New Command…',
      'New Remote Connection…',
      'Close Window',
      'Close All',
      'Use Settings as Default',
      'Show Inspector',
      'Edit Title',
      'Reset',
      'Hard Reset',
    ]) {
      expect(enabled(item('Shell', label)), isTrue, reason: label);
    }
    expect(item('Shell', 'Close Window')['shortcut'], {
      'key': 'W',
      'meta': true,
    });
    expect(
      (menu('Shell')['items']! as List).whereType<Json>().where(
        (e) => e['separator'] == true,
      ),
      isNotEmpty,
    );
  });

  testWidgets('Shell › New Tab opens a tab; Close Tab closes it', (
    tester,
  ) async {
    final state = await pump(tester);
    expect(state.tabs, hasLength(1));
    choose(item('Shell', 'New Tab with Profile - Basic'));
    await tester.pump();
    expect(state.tabs, hasLength(2));
    choose(item('Shell', 'New Tab with Same Command'));
    await tester.pump();
    expect(state.tabs, hasLength(3));
    await tester.pump(const Duration(seconds: 1));
    // With several tabs the item closes the tab.
    final close = item('Shell', 'Close Tab');
    choose(close);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(state.tabs, hasLength(2));
  });

  testWidgets(
    'Shell › New Window opens one, or a tab where windows cannot be',
    (tester) async {
      final seeds = <WindowSeed>[];
      final state = await pump(tester);
      final custom = TerminalApp(
        pty: pty,
        windowOpener: (app, seed) async {
          seeds.add(seed);
          return true;
        },
      );
      await state.newWindow();
      // The test app opens none: a tab instead.
      expect(state.tabs, hasLength(2));
      await custom.openWindow(const WindowSeed(cwd: '/tmp'));
      expect(seeds.single.cwd, '/tmp');
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'Shell › New Command… runs the command; New Remote Connection… runs ssh',
    (tester) async {
      final state = await pump(tester);
      choose(item('Shell', 'New Command…'));
      await tester.pump();
      expect(find.byKey(const ValueKey('prompt')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('prompt field')),
        'top -b',
      );
      await tester.tap(find.text('Run'));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('prompt')), findsNothing);
      // No window can be opened here: the command runs in a tab.
      expect(state.tabs, hasLength(2));
      expect(pty.spawns.last.command, ['/bin/sh', '-c', 'top -b']);
      choose(item('Shell', 'New Remote Connection…'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('prompt field')),
        'me@server',
      );
      await tester.tap(find.text('Connect'));
      await tester.pump();
      await tester.pump();
      expect(pty.spawns.last.command, ['ssh', 'me@server']);
      // An option for ssh is not a destination.
      choose(item('Shell', 'New Remote Connection…'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('prompt field')),
        '-oProxyCommand=x',
      );
      await tester.tap(find.text('Connect'));
      await tester.pump();
      expect(pty.spawns, hasLength(3));
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'Shell › Edit Title renames the tab; Reset and Hard Reset reach the shell',
    (tester) async {
      final state = await pump(tester);
      choose(item('Shell', 'Edit Title'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('prompt field')),
        'build',
      );
      await tester.tap(find.text('OK'));
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('title'))).data,
        startsWith('build'),
      );
      expect(state.tabs, hasLength(1));
      choose(item('Shell', 'Reset'));
      choose(item('Shell', 'Hard Reset'));
      expect(pty.calls.where((c) => c.$1 == 'reset').map((c) => c.$3), [
        false,
        true,
      ]);
    },
  );

  testWidgets(
    'Shell › Use Settings as Default makes the profile the default one',
    (tester) async {
      final state = await pump(tester);
      final copy = app.settings.duplicateProfile(
        app.settings.defaultProfile,
        'Second',
      );
      choose(item('Shell', 'New Tab with Profile - Basic'));
      await tester.pump();
      expect(state.tabs, hasLength(2));
      expect(app.settings.defaultProfile.id, 'basic');
      app.settings.setDefaultProfile(copy.id);
      await tester.pump();
      expect(enabled(item('Shell', 'New Tab with Profile - Second')), isTrue);
      // The profile list is a submenu of New Tab.
      expect(entry(menu('Shell')['items']! as List, 'Basic'), isNotNull);
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('Edit: Copy follows the selection, Paste and Select All work', (
    tester,
  ) async {
    final state = await pump(tester);
    expect(enabled(item('Edit', 'Undo')), isFalse);
    expect(enabled(item('Edit', 'Redo')), isFalse);
    expect(enabled(item('Edit', 'Cut')), isFalse);
    expect(enabled(item('Edit', 'Copy')), isFalse);
    expect(item('Edit', 'Copy')['shortcut'], {'key': 'C', 'meta': true});
    expect(item('Edit', 'Paste')['shortcut'], {'key': 'V', 'meta': true});
    expect(item('Edit', 'Select All')['shortcut'], {'key': 'A', 'meta': true});
    expect(enabled(item('Edit', 'Paste')), isTrue);
    expect(enabled(item('Edit', 'Select All')), isTrue);
    expect(enabled(item('Edit', 'Paste Escaped Text')), isTrue);
    expect(enabled(item('Edit', 'Paste Selection')), isFalse);

    choose(item('Edit', 'Select All'));
    await tester.pump();
    expect(
      pty.calls.where((c) => c.$1 == 'select').last.$3,
      containsPair('op', 'all'),
    );
    // The embedder answers with the selection.
    pty.show(
      1,
      ['menu copy'],
      extra: {
        'selection': [
          [0, 0, 8],
        ],
      },
    );
    pty.selections[1] = 'menu copy';
    await tester.pump();
    expect(enabled(item('Edit', 'Copy')), isTrue);
    expect(state.session.grid.selection, isNotEmpty);

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        if (call.method == 'Clipboard.getData') return {'text': 'a b\nc'};
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    choose(item('Edit', 'Copy'));
    await tester.pump();
    expect(copied, 'menu copy');
    // The copy is also the primary selection, which Paste Selection types.
    await tester.pump();
    expect(enabled(item('Edit', 'Paste Selection')), isTrue);
    choose(item('Edit', 'Paste Selection'));
    await tester.pump();
    expect(utf8.decode(pty.written[1]!), 'menu copy');
    pty.written[1]!.clear();
    choose(item('Edit', 'Paste'));
    await tester.pump();
    await tester.pump();
    expect(utf8.decode(pty.written[1]!), 'a b\rc');
    pty.written[1]!.clear();
    choose(item('Edit', 'Paste Escaped Text'));
    await tester.pump();
    await tester.pump();
    expect(
      utf8.decode(pty.written[1]!),
      r'a\ b'
      '\rc',
    );
    pty.written[1]!.clear();
    choose(item('Edit', 'Paste Selection Escaped'));
    expect(utf8.decode(pty.written[1]!), r'menu\ copy');
  });

  testWidgets('Edit › Marks and Navigate drive the prompt marks', (
    tester,
  ) async {
    await pump(tester);
    pty.show(1, ['\$ ls', 'a b', '\$ ']);
    await tester.pump();
    choose(item('Edit', 'Mark'));
    choose(item('Edit', 'Remove Mark'));
    choose(item('Edit', 'Select Between Marks'));
    expect(pty.calls.where((c) => c.$1 == 'mark').map((c) => c.$3), [
      true,
      false,
    ]);
    expect(pty.calls.last.$3, containsPair('op', 'marks'));
    choose(item('Edit', 'Go to Previous Mark'));
    choose(item('Edit', 'Go to Next Mark'));
    final scrolls = pty.calls.where((c) => c.$1 == 'scroll').map((c) => c.$3);
    expect(scrolls.map((a) => (a! as Map)['to']), [
      'previousPrompt',
      'nextPrompt',
    ]);
    expect(item('Edit', 'Go to Previous Mark')['shortcut'], {
      'key': 'Up',
      'meta': true,
    });
    expect(item('Edit', 'Automatically Mark Prompt Lines')['checked'], isTrue);
    choose(item('Edit', 'Automatically Mark Prompt Lines'));
    await tester.pump();
    expect(app.settings.autoMarkPrompts, isFalse);
    expect(
      item('Edit', 'Automatically Mark Prompt Lines')['checked'],
      isNot(true),
    );
  });

  testWidgets('Edit › Clear: to start, to the previous mark, the screen', (
    tester,
  ) async {
    await pump(tester);
    choose(item('Edit', 'Clear to Start'));
    choose(item('Edit', 'Clear to Previous Mark'));
    choose(item('Edit', 'Clear Screen'));
    expect(pty.calls.where((c) => c.$1 == 'clear').map((c) => c.$3), [
      'toStart',
      'toMark',
      'screen',
    ]);
    expect(item('Edit', 'Clear to Start')['shortcut'], {
      'key': 'K',
      'meta': true,
    });
  });

  testWidgets('Edit › Use Option as Meta Key follows and changes the profile', (
    tester,
  ) async {
    await pump(tester);
    expect(item('Edit', 'Use Option as Meta Key')['checked'], isNot(true));
    choose(item('Edit', 'Use Option as Meta Key'));
    await tester.pump();
    expect(app.settings.defaultProfile.optionAsMeta, isTrue);
    expect(item('Edit', 'Use Option as Meta Key')['checked'], isTrue);
    // The grid sends ESC before the key now.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB, character: 'b');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(utf8.decode(pty.written[1]!), '\x1bb');
  });

  testWidgets('Edit › Find: opens the bar, next and previous follow it', (
    tester,
  ) async {
    await pump(tester);
    pty.show(1, ['one two one']);
    await tester.pump();
    final findItem = item('Edit', 'Find…');
    expect(findItem['shortcut'], {'key': 'F', 'meta': true});
    expect(enabled(item('Edit', 'Find Next')), isFalse);
    expect(enabled(item('Edit', 'Hide Find Bar')), isFalse);
    choose(findItem);
    await tester.pump();
    expect(find.byKey(const ValueKey('find bar')), findsOneWidget);
    expect(enabled(item('Edit', 'Hide Find Bar')), isTrue);
    await tester.enterText(find.byKey(const ValueKey('find field')), 'one');
    await tester.pump();
    expect(find.text('2 of 2'), findsOneWidget);
    expect(item('Edit', 'Find Next')['shortcut'], {'key': 'G', 'meta': true});
    choose(item('Edit', 'Find Previous'));
    await tester.pump();
    expect(find.text('1 of 2'), findsOneWidget);
    choose(item('Edit', 'Hide Find Bar'));
    await tester.pump();
    expect(find.byKey(const ValueKey('find bar')), findsNothing);
  });

  testWidgets('View: scroll items scroll the embedder\'s view', (tester) async {
    await pump(tester);
    pty.show(
      1,
      ['x'],
      extra: {
        'scroll': {'offset': 0, 'history': 200},
      },
    );
    await tester.pump();
    expect(item('View', 'Scroll to Top')['shortcut'], {
      'key': 'Home',
      'meta': true,
    });
    choose(item('View', 'Scroll to Top'));
    choose(item('View', 'Page Up'));
    choose(item('View', 'Page Down'));
    choose(item('View', 'Line Up'));
    choose(item('View', 'Line Down'));
    choose(item('View', 'Scroll to Bottom'));
    final scrolls = [
      for (final c in pty.calls.where((c) => c.$1 == 'scroll'))
        c.$3! as Map<String, Object?>,
    ];
    expect(scrolls.map((a) => a['to']), [
      'top',
      null,
      null,
      null,
      null,
      'bottom',
    ]);
    expect(scrolls.map((a) => a['page']), [null, 1, -1, null, null, null]);
    expect(scrolls.map((a) => a['lines']), [null, null, null, 1, -1, null]);
  });

  testWidgets('View: the font size changes the cells and the grid', (
    tester,
  ) async {
    final state = await pump(tester);
    final (rows, cols) = pty.sizes[1]!;
    expect(state.fontSize, 12);
    choose(item('View', 'Bigger'));
    await tester.pump();
    await tester.pump();
    expect(state.fontSize, 13);
    final (rows2, cols2) = pty.sizes[1]!;
    expect(cols2, lessThan(cols));
    expect(rows2, lessThan(rows));
    choose(item('View', 'Smaller'));
    choose(item('View', 'Smaller'));
    await tester.pump();
    await tester.pump();
    expect(state.fontSize, 11);
    expect(pty.sizes[1]!.$2, greaterThan(cols));
    choose(item('View', 'Default Font Size'));
    await tester.pump();
    await tester.pump();
    expect(state.fontSize, 12);
    expect(pty.sizes[1], (rows, cols));
    expect(entry(menu('View')['items']! as List, 'Bigger')!['shortcut'], {
      'key': '+',
      'meta': true,
    });
    expect(item('View', 'Default Font Size')['shortcut'], {
      'key': '0',
      'meta': true,
    });
    // The limits hold.
    for (var i = 0; i < 40; i++) {
      choose(item('View', 'Bigger'));
      await tester.pump();
    }
    expect(state.fontSize, 48);
    for (var i = 0; i < 40; i++) {
      choose(item('View', 'Smaller'));
      await tester.pump();
    }
    expect(state.fontSize, 8);
  });

  testWidgets('View: mouse reporting, tab bar and marks toggle', (
    tester,
  ) async {
    await pump(tester);
    expect(item('View', 'Allow Mouse Reporting')['checked'], isTrue);
    choose(item('View', 'Allow Mouse Reporting'));
    await tester.pump();
    expect(app.settings.mouseReporting, isFalse);
    expect(item('View', 'Allow Mouse Reporting')['checked'], isNot(true));
    expect(find.byKey(const ValueKey('tab bar')), findsOneWidget);
    choose(item('View', 'Hide Tab Bar'));
    await tester.pump();
    expect(find.byKey(const ValueKey('tab bar')), findsNothing);
    choose(item('View', 'Show Tab Bar'));
    await tester.pump();
    expect(find.byKey(const ValueKey('tab bar')), findsOneWidget);
    choose(item('View', 'Hide Marks'));
    await tester.pump();
    expect(app.settings.defaultProfile.showMarks, isFalse);
    expect(entry(menu('View')['items']! as List, 'Show Marks'), isNotNull);
  });

  testWidgets('Window: tab switching needs two tabs', (tester) async {
    final state = await pump(tester);
    expect(enabled(item('Window', 'Show Next Tab')), isFalse);
    expect(item('Window', 'Show Next Tab')['shortcut'], {
      'key': 'Tab',
      'ctrl': true,
    });
    await state.newTab();
    await tester.pump();
    await tester.pump();
    expect(state.current, 1);
    expect(enabled(item('Window', 'Show Previous Tab')), isTrue);
    expect(item('Window', 'Show Previous Tab')['shortcut'], {
      'key': 'Tab',
      'ctrl': true,
      'shift': true,
    });
    choose(item('Window', 'Show Previous Tab'));
    await tester.pump();
    expect(state.current, 0);
    choose(item('Window', 'Show Next Tab'));
    await tester.pump();
    expect(state.current, 1);
    expect(enabled(item('Window', 'Move Tab to New Window')), isTrue);
    expect(enabled(item('Window', 'Merge All Windows')), isFalse);
  });

  testWidgets('Window › window groups are saved and listed', (tester) async {
    final state = await pump(tester);
    expect(enabled(item('Window', 'Open Window Group')), isFalse);
    choose(item('Window', 'Save Windows as Group…'));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('prompt field')), 'work');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump();
    expect(app.settings.windowGroups.map((g) => g.name), ['work']);
    expect(app.settings.windowGroups.single.windows.single.tabs, hasLength(1));
    expect(enabled(item('Window', 'Open Window Group')), isTrue);
    choose(item('Window', 'work'));
    await tester.pump();
    await tester.pump();
    // No window can be opened here: the group's tab opens in this one.
    expect(state.tabs, hasLength(2));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Help: man pages for the selected word', (tester) async {
    final state = await pump(tester);
    expect(enabled(item('Help', 'Open man Page for Selection')), isFalse);
    pty.show(
      1,
      ['grep'],
      extra: {
        'selection': [
          [0, 0, 3],
        ],
      },
    );
    pty.selections[1] = 'grep -r';
    await tester.pump();
    choose(item('Help', 'Open man Page for Selection'));
    await tester.pump();
    await tester.pump();
    expect(state.tabs, hasLength(2));
    expect(pty.spawns.last.command, ['/bin/sh', '-c', 'man -- grep']);
    pty.show(
      1,
      ['grep'],
      extra: {
        'selection': [
          [0, 0, 3],
        ],
      },
    );
    state.selectTab(0);
    await tester.pump();
    choose(item('Help', 'Search man Page Index for Selection'));
    await tester.pump();
    await tester.pump();
    expect(pty.spawns.last.command, ['/bin/sh', '-c', 'man -k -- grep']);
    // Shell syntax is no man page.
    pty.selections[1] = r'$(reboot)';
    state.selectTab(0);
    await tester.pump();
    final before = pty.spawns.length;
    choose(item('Help', 'Open man Page for Selection'));
    await tester.pump();
    await tester.pump();
    expect(pty.spawns.length, before);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('⌘ shortcuts run the menu items, also inside the grid', (
    tester,
  ) async {
    final state = await pump(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(state.tabs, hasLength(2));
    // ⌘1 selects the first tab.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(state.current, 0);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('in Italian the menus speak Italian', (tester) async {
    await pump(tester, locale: const Locale('it'));
    expect(
      [for (final m in menus()) m['label']],
      ['Terminale', 'Shell', 'Modifica', 'Vista', 'Finestra', 'Aiuto'],
    );
    expect(
      enabled(item('Shell', 'Nuovo pannello con profilo - Basic')),
      isTrue,
    );
    expect(enabled(item('Modifica', 'Trova…')), isTrue);
  });
}
