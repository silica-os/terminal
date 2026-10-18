import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';
import 'package:terminal/src/app.dart';
import 'package:terminal/src/l10n.dart';
import 'package:terminal/src/pty.dart';
import 'package:terminal/src/style.dart';
import 'package:terminal/src/system.dart';
import 'package:terminal/src/terminal_view.dart';
import 'package:terminal/src/window.dart';

void main() {
  final lightProfile = Profile.of(
    const AmalfiThemeData(brightness: Brightness.light, app: 'Terminal'),
  );

  Future<(FakePty, TerminalWindowState)> pump(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    FakePty? pty,
  }) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = pty ?? FakePty();
    var closed = false;
    final app = TerminalApp(
      pty: fake,
      shellName: 'bash',
      system: FakeSystem(home: '/home/me'),
    );
    addTearDown(app.settings.dispose);
    await tester.pumpWidget(
      AppLocalizationsScope(
        locale: locale,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AmalfiTheme(
            app: 'Terminal',
            child: TerminalWindow(
              app: app,
              onLastTabClosed: () => closed = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(closed, isFalse);
    return (
      fake,
      tester.state<TerminalWindowState>(find.byType(TerminalWindow)),
    );
  }

  Future<void> keys(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool meta = false,
    bool control = false,
    bool shift = false,
  }) async {
    if (meta) await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    if (meta) await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('the grid fits the window: the pseudo-terminal gets its size', (
    tester,
  ) async {
    final (pty, window) = await pump(tester);
    expect(pty.calls.first.$1, 'spawn');
    final (rows, cols) = pty.sizes[1]!;
    // 800 × 600 minus the chrome (68) and the 12 pt padding, in 7.2 × 16 cells.
    expect(cols, ((800 - 24) / 7.2).floor());
    expect(rows, (600 - 68 - 24) ~/ 16);
    final title = tester.widget<Text>(find.byKey(const ValueKey('title')));
    expect(title.data, 'bash — $cols×$rows');
    // Resizing the window resizes the pseudo-terminal.
    tester.view.physicalSize = const Size(500, 400);
    await tester.pump();
    final (rows2, cols2) = pty.sizes[1]!;
    expect(cols2, lessThan(cols));
    expect(rows2, lessThan(rows));
    expect(window.tabs, hasLength(1));
    // The title follows the size live: the resize arrives during layout, the title the
    // frame after.
    await tester.pump();
    final title2 = tester.widget<Text>(find.byKey(const ValueKey('title')));
    expect(title2.data, 'bash — $cols2×$rows2');
  });

  testWidgets('a new tab slides in from the right in ~550 ms', (tester) async {
    final (_, window) = await pump(tester);
    final full = tester.getSize(find.byKey(const ValueKey('tab 0'))).width;
    await keys(tester, LogicalKeyboardKey.keyT, meta: true);
    await tester.pump(const Duration(milliseconds: 100));
    final entering = tester.getSize(find.byKey(const ValueKey('tab 1'))).width;
    expect(entering, greaterThan(0));
    expect(entering, lessThan(full / 2));
    await tester.pump(const Duration(milliseconds: 500));
    final settled = tester.getSize(find.byKey(const ValueKey('tab 1'))).width;
    expect(settled, moreOrLessEquals((full + 4) / 2 - 4, epsilon: 0.5));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('tab 1'))).dx,
      greaterThan(tester.getTopLeft(find.byKey(const ValueKey('tab 0'))).dx),
    );
    expect(window.tabs, hasLength(2));
  });

  testWidgets('an inactive window: hollow cursor and grey selection', (
    tester,
  ) async {
    final (_, window) = await pump(tester);
    TerminalView view() =>
        tester.widget<TerminalView>(find.byType(TerminalView));
    expect(view().focusNode.hasFocus, isTrue);
    expect(window.decor.active, isTrue);
    expect(view().look.selection, lightProfile.grid.selection);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    // The painter draws the cursor as an outline and the selection grey.
    expect(window.decor.active, isFalse);
    expect(view().look.selection, lightProfile.inactiveSelection);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(view().focusNode.hasFocus, isTrue);
    expect(window.decor.active, isTrue);
    expect(view().look.selection, const Color(0xFFB3D7FF));
  });

  testWidgets('the find bar grows the window by 32 pt and back', (
    tester,
  ) async {
    final sizes = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('silica/window', JSONMethodCodec()),
      (call) async {
        if (call.method == 'setSize') sizes.add(call.arguments);
        return true;
      },
    );
    final (pty, _) = await pump(tester);
    pty.show(1, ['one fish', 'two fish']);
    await tester.pump();
    await keys(tester, LogicalKeyboardKey.keyF, meta: true);
    expect(
      tester.getSize(find.byKey(const ValueKey('find bar'))).height,
      findBarHeight,
    );
    await tester.enterText(find.byKey(const ValueKey('find field')), 'fish');
    await tester.pump();
    expect(find.text('2 of 2'), findsOneWidget);
    final segments = tester.getRect(find.byType(AmalfiActionSegments));
    await tester.tapAt(segments.centerLeft + const Offset(14, 0));
    await tester.pump();
    expect(find.text('1 of 2'), findsOneWidget);
    await tester.tapAt(segments.centerRight - const Offset(14, 0));
    await tester.pump();
    expect(find.text('2 of 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('find done')));
    await tester.pump();
    expect(find.byKey(const ValueKey('find bar')), findsNothing);
    expect(sizes, hasLength(2));
    expect(sizes.first.toString(), contains('632'));
    expect(sizes.last.toString(), contains('568'));
  });

  testWidgets('tabs: ⌘T opens, ⌃⇥ switches, ⌘W closes', (tester) async {
    final (pty, window) = await pump(tester);
    // The tab bar is always visible, with one tab too.
    expect(find.byKey(const ValueKey('tab bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab 0')), findsOneWidget);
    await keys(tester, LogicalKeyboardKey.keyT, meta: true);
    await tester.pumpAndSettle();
    expect(window.tabs, hasLength(2));
    expect(window.current, 1);
    expect(find.byKey(const ValueKey('tab bar')), findsOneWidget);
    expect(pty.calls.where((c) => c.$1 == 'spawn'), hasLength(2));
    await keys(tester, LogicalKeyboardKey.tab, control: true);
    expect(window.current, 0);
    await tester.tap(find.byKey(const ValueKey('tab 1')));
    await tester.pump();
    expect(window.current, 1);
    await keys(tester, LogicalKeyboardKey.keyW, meta: true);
    expect(window.tabs, hasLength(1));
    expect(pty.calls.where((c) => c.$1 == 'close').single.$2, 2);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tab bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab 1')), findsNothing);
  });

  Future<TestGesture> hover(WidgetTester tester, String key) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(700, 400));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byKey(ValueKey(key))));
    await tester.pump();
    return mouse;
  }

  testWidgets('the × shows on the selected and the hovered tab, trailing', (
    tester,
  ) async {
    await pump(tester);
    await keys(tester, LogicalKeyboardKey.keyT, meta: true);
    await tester.pumpAndSettle();
    Finder cross(int i) => find.descendant(
      of: find.byKey(ValueKey('tab $i')),
      matching: find.byType(AmalfiGlyph),
    );
    // Tab 1 is selected; tab 0 shows it only under the pointer.
    expect(cross(1), findsOneWidget);
    expect(cross(0), findsNothing);
    await hover(tester, 'tab 0');
    expect(cross(0), findsOneWidget);
    expect(tester.getSize(cross(0)), const Size(12, 12));
    final tab = tester.getRect(find.byKey(const ValueKey('tab 0')));
    // 8 pt of padding inside the trailing edge.
    expect(tab.right - tester.getRect(cross(0)).right, 8);
  });

  testWidgets('the × closes the tab and its pty', (tester) async {
    final (pty, window) = await pump(tester);
    await keys(tester, LogicalKeyboardKey.keyT, meta: true);
    await tester.pumpAndSettle();
    final mouse = await hover(tester, 'tab 0');
    final close = find.descendant(
      of: find.byKey(const ValueKey('tab 0')),
      matching: find.byType(AmalfiGlyph),
    );
    await mouse.moveTo(tester.getCenter(close));
    await tester.tapAt(tester.getCenter(close));
    await tester.pump();
    await tester.pump();
    expect(window.tabs, hasLength(1));
    expect(pty.calls.where((c) => c.$1 == 'close').single.$2, 1);
    await tester.pumpAndSettle();
  });

  testWidgets('closing the last tab with the × closes the window', (
    tester,
  ) async {
    var closed = false;
    final pty = FakePty();
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppLocalizationsScope(
        locale: const Locale('en'),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AmalfiTheme(
            app: 'Terminal',
            child: TerminalWindow(
              app: TerminalApp(pty: pty, shellName: 'bash'),
              onLastTabClosed: () => closed = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('tab 0')),
        matching: find.byType(AmalfiGlyph),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(closed, isTrue);
  });

  testWidgets('a busy tab asks before closing; Cancel keeps it', (
    tester,
  ) async {
    final (pty, window) = await pump(tester);
    pty.busy.add(1);
    await keys(tester, LogicalKeyboardKey.keyW, meta: true);
    expect(
      find.text('Do you want to terminate running processes in this tab?'),
      findsOneWidget,
    );
    expect(window.tabs, hasLength(1));
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.byKey(const ValueKey('close confirmation')), findsNothing);
    expect(window.tabs, hasLength(1));
    expect(pty.calls.where((c) => c.$1 == 'close'), isEmpty);
  });

  testWidgets('a busy tab: Terminate closes it (× and ⌘W alike)', (
    tester,
  ) async {
    final (pty, window) = await pump(tester);
    await keys(tester, LogicalKeyboardKey.keyT, meta: true);
    await tester.pumpAndSettle();
    pty.busy.addAll([1, 2]);
    await hover(tester, 'tab 0');
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('tab 0')),
        matching: find.byType(AmalfiGlyph),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('close confirmation')), findsOneWidget);
    await tester.tap(find.text('Terminate'));
    await tester.pump();
    expect(window.tabs, hasLength(1));
    expect(pty.calls.where((c) => c.$1 == 'close').single.$2, 1);
    await tester.pumpAndSettle();
    await keys(tester, LogicalKeyboardKey.keyW, meta: true);
    expect(find.byKey(const ValueKey('close confirmation')), findsOneWidget);
    await tester.tap(find.text('Terminate'));
    await tester.pump();
    expect(window.tabs, isEmpty);
  });

  testWidgets('closing the window with nothing running is not asked', (
    tester,
  ) async {
    await pump(tester);
    expect(
      await SilicaWindows.handle('closeRequested', {'viewId': 0}),
      isFalse, // the embedder closes it
    );
    expect(find.byKey(const ValueKey('close confirmation')), findsNothing);
  });

  testWidgets('closing the window with a process running asks first', (
    tester,
  ) async {
    final (pty, window) = await pump(tester);
    pty.busy.add(1);
    final closing = SilicaWindows.handle('closeRequested', {'viewId': 0});
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Do you want to terminate running processes in this window?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(await closing, isTrue); // kept open
    expect(window.tabs, hasLength(1));
    expect(find.byKey(const ValueKey('close confirmation')), findsNothing);

    final again = SilicaWindows.handle('closeRequested', {'viewId': 0});
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Terminate'));
    await tester.pump();
    expect(await again, isFalse); // the embedder closes the window
  });

  testWidgets('find: ⌘F, matches counted, Esc closes', (tester) async {
    final (pty, _) = await pump(tester);
    pty.show(1, ['one fish', 'two FISH', 'red']);
    await tester.pump();
    await keys(tester, LogicalKeyboardKey.keyF, meta: true);
    expect(find.byKey(const ValueKey('find bar')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('find field')), 'fish');
    await tester.pump();
    expect(find.text('2 of 2'), findsOneWidget);
    await keys(tester, LogicalKeyboardKey.enter);
    expect(find.text('1 of 2'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('find field')), 'cat');
    await tester.pump();
    expect(find.text('No matches'), findsOneWidget);
    await keys(tester, LogicalKeyboardKey.escape);
    expect(find.byKey(const ValueKey('find bar')), findsNothing);
  });

  testWidgets('a mouse selection is copied with ⌘C', (tester) async {
    final (pty, _) = await pump(tester);
    pty.show(1, ['copy me please']);
    pty.selections[1] = 'copy me please';
    await tester.pump();
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    await keys(tester, LogicalKeyboardKey.keyA, meta: true);
    expect(
      pty.calls.where((c) => c.$1 == 'select').last.$3,
      containsPair('op', 'all'),
    );
    pty.show(
      1,
      ['copy me please'],
      extra: {
        'selection': [
          [0, 0, 13],
        ],
      },
    );
    await tester.pump();
    await keys(tester, LogicalKeyboardKey.keyC, meta: true);
    await tester.pump();
    expect(copied, 'copy me please');
  });

  testWidgets('in Italian: tabs and the missing service speak Italian', (
    tester,
  ) async {
    final pty = FakePty()..spawnError = const PtyUnavailable();
    final (_, window) = await pump(
      tester,
      locale: const Locale('it'),
      pty: pty,
    );
    expect(window.session.grid.text, contains('scrivania di Silica'));
    expect(l10n.newTab, 'Nuovo pannello');
    expect(l10n.findDone, 'Fine');
    expect(l10n.findPrevious, 'Risultato precedente');
    expect(l10n.findNext, 'Risultato successivo');
    useLocale(const Locale('en'));
  });

  testWidgets('the empty title band moves the window', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('silica/window', JSONMethodCodec()),
      (call) async {
        calls.add(call.method);
        return null;
      },
    );
    await pump(tester);
    final band = tester.getRect(find.byKey(const ValueKey('title band')));
    final gesture = await tester.startGesture(
      band.centerLeft + const Offset(20, 0),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(40, 0));
    await gesture.up();
    // Let the double-tap timer of the title band expire before the tree is disposed.
    await tester.pump(const Duration(seconds: 1));
    expect(calls, contains('startMove'));
  });
  testWidgets('the title is centred between the window controls', (
    tester,
  ) async {
    await pump(tester);
    expect(tester.getSize(find.byKey(const ValueKey('title band'))).height, 32);
    final title = tester.getRect(find.byKey(const ValueKey('title')));
    expect(title.left, 84);
    expect(title.right, 800 - 84);
    expect(title.top, 7);
    expect(title.height, 18);
  });

  testWidgets('the tab bar and the new-tab circle (kit Tab Bar 1)', (
    tester,
  ) async {
    await pump(tester);
    final bar = tester.getRect(find.byKey(const ValueKey('tab bar')));
    expect(bar.top, 32);
    expect(bar.height, 36);
    final plus = tester.getRect(find.byKey(const ValueKey('new tab')));
    expect(plus.size, const Size(28, 28));
    expect(800 - plus.right, 8);
    expect(plus.top - bar.top, 4);
    final tab = tester.getRect(find.byKey(const ValueKey('tab 0')));
    expect(tab.left, closeTo(8, 0.01));
    expect(tab.right, closeTo(800 - 44, 0.01));
    expect(tab.top - bar.top, 4);
    expect(tab.height, 28);
  });

  testWidgets('the kit window: 640 × 476, parts on the masters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 476);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppLocalizationsScope(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AmalfiTheme(
            app: 'Terminal',
            child: TerminalWindow(
              app: TerminalApp(pty: FakePty(), shellName: 'bash'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    Rect r(String key) => tester.getRect(find.byKey(ValueKey(key)));
    // `Apps/Terminal/Session`: title bar 0..32, tab bar 32..68, text from y 68 + 12.
    expect(r('title band'), const Rect.fromLTWH(0, 0, 640, 32));
    expect(r('tab bar'), const Rect.fromLTWH(0, 32, 640, 36));
    expect(r('tab 0'), const Rect.fromLTWH(8, 36, 588, 28));
    expect(r('new tab'), const Rect.fromLTWH(604, 36, 28, 28));
    final view = tester.widget<TerminalView>(find.byType(TerminalView));
    expect(view.padding, const EdgeInsets.all(12));
    expect(view.look.fontSize, 12);
    expect(tester.getTopLeft(find.byType(TerminalView)), const Offset(0, 68));
    // Find bar (`Apps/Terminal/Find`): 68..100, field 480 × 24 at x 8, segments 56 × 24 at 504.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    await tester.pump();
    expect(r('find bar'), const Rect.fromLTWH(0, 68, 640, 32));
    expect(r('find field'), const Rect.fromLTWH(8, 72, 480, 24));
    expect(
      tester.getRect(find.byType(AmalfiActionSegments)),
      const Rect.fromLTWH(504, 72, 56, 24),
    );
    expect(r('find done').left, 580);
    expect(r('find done').height, 24);
  });

  testWidgets('the split: two views of the session on the kit\'s measures', (
    tester,
  ) async {
    final sizes = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('silica/window', JSONMethodCodec()),
      (call) async {
        if (call.method == 'setSize') sizes.add(call.arguments);
        return true;
      },
    );
    tester.view.physicalSize = const Size(640, 476);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final pty = FakePty();
    final app = TerminalApp(pty: pty, shellName: 'bash');
    addTearDown(app.settings.dispose);
    await tester.pumpWidget(
      AppLocalizationsScope(
        locale: const Locale('en'),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AmalfiTheme(
            app: 'Terminal',
            child: TerminalWindow(app: app),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final window = tester.state<TerminalWindowState>(
      find.byType(TerminalWindow),
    );
    expect(find.byKey(const ValueKey('splitter')), findsNothing);
    expect(pty.sizes[1], (24, 85));
    window.splitPane();
    await tester.pump();
    // The window grows by 32 pt (8 for the splitter and 12 + 12 for the second half).
    expect(sizes.single.toString(), contains('508'));
    tester.view.physicalSize = const Size(640, 508);
    await tester.pump();
    await tester.pump();
    Rect r(String key) => tester.getRect(find.byKey(ValueKey(key)));
    // `Apps/Terminal/Split`: the splitter at y 284, 8 pt tall; 12 rows in each half.
    expect(r('splitter'), const Rect.fromLTWH(0, 284, 640, 8));
    expect(r('split view'), const Rect.fromLTWH(0, 68, 640, 216));
    expect(r('view'), const Rect.fromLTWH(0, 292, 640, 216));
    expect(pty.sizes[1]!.$1, 12, reason: 'the live half is the pty\'s size');
    // It opened with the rows the old window gave it and resized when the window grew.
    final splits = [
      for (final c in pty.calls.where((c) => c.$1 == 'split')) c.$3! as Map,
    ];
    expect(splits.map((m) => m['op']), ['open', 'resize']);
    expect(splits.last['rows'], 12);
    // Typing goes to the process from either half.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
    expect(utf8.decode(pty.written[1]!), 'a');
    // The split is not twice a command: the item is off while it is open.
    expect(window.session.split, isNotNull);
    window.closeSplitPane();
    await tester.pump();
    expect(find.byKey(const ValueKey('splitter')), findsNothing);
    expect(window.session.split, isNull);
    expect(
      (pty.calls.where((c) => c.$1 == 'split').last.$3! as Map)['op'],
      'close',
    );
    expect(sizes, hasLength(2));
    expect(sizes.last.toString(), contains('476'));
    await tester.pump(const Duration(seconds: 1));
  });

  test('the selected tab keeps 120 pt while the others shrink', () {
    final widths = tabWidths(width: 300, weights: [1, 1, 1, 1], selected: 2);
    expect(widths[2], 120);
    expect(widths.reduce((a, b) => a + b), closeTo(300, 0.001));
    expect(widths[0], closeTo(60, 0.001));
    expect(tabWidths(width: 300, weights: [1, 1], selected: 0), [150, 150]);
    expect(tabWidths(width: 100, weights: [1], selected: 0), [100]);
  });

  test('the minimum window width keeps the traffic lights clear', () {
    expect(minimumWindowSize.width, 177);
    expect(minimumWindowWidth, 177);
  });
}
