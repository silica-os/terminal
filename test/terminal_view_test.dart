import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';
import 'package:terminal/src/grid.dart';
import 'package:terminal/src/l10n.dart';
import 'package:terminal/src/pty.dart';
import 'package:terminal/src/session.dart';
import 'package:terminal/src/style.dart';
import 'package:terminal/src/terminal_view.dart';

void main() {
  final colors = Profile.of(
    const AmalfiThemeData(brightness: Brightness.light, app: 'Terminal'),
  );

  late FakePty pty;
  late TerminalSession session;
  late FocusNode focus;
  late GridDecor decor;
  final opened = <String>[];
  final menus = <Offset>[];
  var look = TerminalLook(
    colors: colors.grid,
    selection: colors.grid.selection,
    find: colors.findMatch,
    currentFind: colors.grid.selection,
    mark: const Color(0xff999999),
  );

  /// The centre of a cell, in the view's coordinates (12 pt padding, 7.2 × 16 cells).
  Offset cell(WidgetTester tester, int x, int y) =>
      tester.getTopLeft(find.byType(TerminalView)) +
      Offset(12 + 7.2 * x + 3.6, 12 + 16.0 * y + 8);

  Future<void> pumpView(
    WidgetTester tester, {
    bool mouseReporting = true,
    bool openLinks = true,
    bool optionAsMeta = false,
    Size size = const Size(400, 300),
  }) async {
    useLocale(const Locale('en'));
    pty = FakePty();
    session = TerminalSession(pty: pty, shellName: 'bash');
    focus = FocusNode();
    decor = GridDecor();
    opened.clear();
    menus.clear();
    addTearDown(session.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: AmalfiTheme(
          app: 'Terminal',
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: TerminalView(
                session: session,
                look: look,
                focusNode: focus,
                decor: decor,
                mouseReporting: mouseReporting,
                openLinks: openLinks,
                optionAsMeta: optionAsMeta,
                onOpenLink: opened.add,
                onContextMenu: menus.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  List<(String, int, Object?)> calls(String name) => [
    for (final c in pty.calls)
      if (c.$1 == name) c,
  ];

  Map<String, Object?> lastSelect() =>
      calls('select').last.$3! as Map<String, Object?>;

  String sent() => utf8.decode(pty.written[1] ?? const []);

  Future<TestGesture> mouse(WidgetTester tester, Offset at) async {
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: at);
    addTearDown(g.removePointer);
    return g;
  }

  testWidgets('the view starts the session with the size of its layout', (
    tester,
  ) async {
    await pumpView(tester);
    // (400 − 24) / 7.2 = 52 columns, (300 − 24) / 16 = 17 rows.
    expect(pty.sizes[1], (17, 52));
    expect(focus.hasFocus, isTrue);
    await pumpView(tester, size: const Size(200, 100));
    expect(pty.sizes[1], (4, 24));
  });

  testWidgets('an odd constraint does not break the view', (tester) async {
    await pumpView(tester, size: const Size(1, 1));
    expect(pty.sizes[1], (1, 1));
    expect(tester.takeException(), isNull);
    await pumpView(tester, size: Size.zero);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keys go to the process: text, Enter, arrows by the program mode',
    (tester) async {
      await pumpView(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL, character: 'l');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS, character: 's');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      expect(sent(), 'ls\r\x1b[A');
      pty.show(1, ['x'], modes: 1);
      await tester.pump();
      pty.written[1]!.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      expect(sent(), '\x1bOA');
    },
  );

  testWidgets('Option as Meta sends ESC first, only when the profile asks', (
    tester,
  ) async {
    await pumpView(tester, optionAsMeta: true);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB, character: 'b');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    expect(sent(), '\x1bb');
  });

  testWidgets('typing while scrolled back jumps to the bottom first', (
    tester,
  ) async {
    await pumpView(tester);
    pty.show(
      1,
      ['x'],
      extra: {
        'scroll': {'offset': 12, 'history': 100},
      },
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
    expect(calls('scroll').last.$3, containsPair('to', 'bottom'));
    expect(sent(), 'a');
  });

  testWidgets(
    'Shift+PageUp, PageDown, Home and End scroll the view, not the program',
    (tester) async {
      await pumpView(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      final args = [
        for (final c in calls('scroll')) c.$3! as Map<String, Object?>,
      ];
      expect(args.map((a) => a['page']), [1, -1, null, null]);
      expect(args.map((a) => a['to']), [null, null, 'top', 'bottom']);
      expect(sent(), isEmpty);
      // In the alternate screen the program has them.
      pty.show(1, ['x'], modes: 32);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(sent(), '\x1b[5;2~');
    },
  );

  group('selection', () {
    testWidgets('drag selects; the release makes it the primary selection', (
      tester,
    ) async {
      await pumpView(tester);
      pty.selections[1] = 'hello';
      final g = await mouse(tester, cell(tester, 2, 1));
      await g.down(cell(tester, 2, 1));
      expect(lastSelect(), containsPair('op', 'start'));
      expect(lastSelect(), containsPair('kind', 'simple'));
      expect((lastSelect()['x'], lastSelect()['y']), (2, 1));
      await g.moveTo(cell(tester, 6, 1));
      expect(lastSelect(), containsPair('op', 'update'));
      expect((lastSelect()['x'], lastSelect()['y']), (6, 1));
      await g.up();
      await tester.pump();
      expect(PrimarySelection.text, 'hello');
      expect(session.selectionRow, 1);
    });

    testWidgets('the cell side tells where a selection starts', (tester) async {
      await pumpView(tester);
      final g = await mouse(tester, cell(tester, 2, 0));
      await g.down(cell(tester, 2, 0) + const Offset(2.5, 0));
      expect(lastSelect()['right'], isTrue);
      await g.up();
      await g.down(cell(tester, 2, 0) - const Offset(2.5, 0));
      expect(lastSelect()['right'], isFalse);
      await g.up();
    });

    testWidgets('a plain click leaves no selection', (tester) async {
      await pumpView(tester);
      final g = await mouse(tester, cell(tester, 2, 0));
      await g.down(cell(tester, 2, 0));
      await g.up();
      expect(lastSelect(), containsPair('op', 'clear'));
      expect(session.selectionRow, isNull);
    });

    testWidgets(
      'double click selects a word, triple click a line, Option a block',
      (tester) async {
        await pumpView(tester);
        final at = cell(tester, 4, 2);
        final g = await mouse(tester, at);
        await g.down(at);
        await g.up();
        await g.down(at);
        expect(lastSelect(), containsPair('kind', 'semantic'));
        await g.up();
        await g.down(at);
        expect(lastSelect(), containsPair('kind', 'lines'));
        await g.up();
        // A slow fourth click starts again.
        await tester.pump(const Duration(seconds: 1));
        await g.down(at, timeStamp: const Duration(seconds: 5));
        expect(lastSelect(), containsPair('kind', 'simple'));
        await g.up(timeStamp: const Duration(seconds: 5));
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await g.down(at, timeStamp: const Duration(seconds: 9));
        expect(lastSelect(), containsPair('kind', 'block'));
        await g.up(timeStamp: const Duration(seconds: 9));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      },
    );

    testWidgets('Shift+click extends the selection', (tester) async {
      await pumpView(tester);
      pty.show(
        1,
        ['abc'],
        extra: {
          'selection': [
            [0, 0, 2],
          ],
        },
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      final g = await mouse(tester, cell(tester, 8, 3));
      await g.down(cell(tester, 8, 3));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(lastSelect(), containsPair('op', 'update'));
      expect((lastSelect()['x'], lastSelect()['y']), (8, 3));
      await g.up();
    });

    testWidgets('dragging above the view scrolls the scrollback under it', (
      tester,
    ) async {
      await pumpView(tester);
      pty.show(
        1,
        ['x'],
        extra: {
          'scroll': {'offset': 5, 'history': 100},
        },
      );
      await tester.pump();
      final g = await mouse(tester, cell(tester, 2, 2));
      await g.down(cell(tester, 2, 2));
      await g.moveTo(const Offset(40, -30));
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        calls('scroll').where((c) => (c.$3! as Map)['lines'] != null),
        isNotEmpty,
      );
      final lines = (calls('scroll').last.$3! as Map)['lines']! as int;
      expect(lines, greaterThan(0));
      await g.up();
      await tester.pump(const Duration(milliseconds: 200));
      final n = calls('scroll').length;
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        calls('scroll').length,
        n,
        reason: 'the timer stopped with the drag',
      );
    });

    testWidgets('the middle button pastes the primary selection', (
      tester,
    ) async {
      await pumpView(tester);
      PrimarySelection.text = 'primary';
      final g = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kMiddleMouseButton,
      );
      await g.down(cell(tester, 1, 1));
      await g.up();
      expect(sent(), 'primary');
    });

    testWidgets('the secondary button asks for the context menu', (
      tester,
    ) async {
      await pumpView(tester);
      final g = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      await g.down(cell(tester, 1, 1));
      await g.up();
      expect(menus, hasLength(1));
      expect(
        calls('select').where((c) => (c.$3! as Map)['op'] == 'start'),
        isEmpty,
      );
    });
  });

  group('mouse reporting', () {
    testWidgets('programs that ask get presses, drags and releases', (
      tester,
    ) async {
      await pumpView(tester);
      pty.show(1, ['x'], modes: 4 | 8 | 128);
      await tester.pump();
      final g = await mouse(tester, cell(tester, 3, 2));
      await g.down(cell(tester, 3, 2));
      await g.moveTo(cell(tester, 5, 2));
      await g.up();
      expect(sent(), '\x1b[<0;4;3M\x1b[<32;6;3M\x1b[<0;6;3m');
      // The selection stays out of it.
      expect(calls('select'), isEmpty);
    });

    testWidgets('motion without a button only in any-event mode', (
      tester,
    ) async {
      await pumpView(tester);
      pty.show(1, ['x'], modes: 4 | 8 | 128);
      await tester.pump();
      final g = await mouse(tester, cell(tester, 0, 0));
      await g.moveTo(cell(tester, 1, 1));
      expect(sent(), isEmpty);
      pty.show(1, ['x'], modes: 4 | 8 | 256);
      await tester.pump();
      await g.moveTo(cell(tester, 2, 1));
      await g.moveTo(cell(tester, 2, 1) + const Offset(1, 1));
      expect(sent(), '\x1b[<35;3;2M', reason: 'once per cell');
    });

    testWidgets('Shift bypasses the report and selects', (tester) async {
      await pumpView(tester);
      pty.show(1, ['x'], modes: 4 | 8);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      final g = await mouse(tester, cell(tester, 3, 2));
      await g.down(cell(tester, 3, 2));
      await g.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(sent(), isEmpty);
      expect(calls('select'), isNotEmpty);
    });

    testWidgets('the setting turns reporting off', (tester) async {
      await pumpView(tester, mouseReporting: false);
      pty.show(1, ['x'], modes: 4 | 8);
      await tester.pump();
      final g = await mouse(tester, cell(tester, 3, 2));
      await g.down(cell(tester, 3, 2));
      await g.up();
      expect(sent(), isEmpty);
      expect(calls('select'), isNotEmpty);
    });

    testWidgets('the wheel is reported as buttons 64 and 65', (tester) async {
      await pumpView(tester);
      pty.show(1, ['x'], modes: 4 | 8);
      await tester.pump();
      final g = await mouse(tester, cell(tester, 3, 2));
      await g.moveTo(cell(tester, 3, 2));
      sent();
      pty.written[1]!.clear();
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: cell(tester, 3, 2),
          scrollDelta: const Offset(0, -20),
        ),
      );
      expect(sent(), contains('\x1b[<64;4;3M'));
      pty.written[1]!.clear();
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: cell(tester, 3, 2),
          scrollDelta: const Offset(0, 40),
        ),
      );
      expect(sent(), startsWith('\x1b[<65;4;3M'));
      expect(calls('scroll'), isEmpty, reason: 'the program scrolls itself');
    });

    testWidgets('in the alternate screen the wheel is the arrow keys', (
      tester,
    ) async {
      await pumpView(tester);
      pty.show(1, ['x'], modes: 32 | 2048);
      await tester.pump();
      final g = await mouse(tester, cell(tester, 3, 2));
      await g.moveTo(cell(tester, 3, 2));
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: cell(tester, 3, 2),
          scrollDelta: const Offset(0, 32),
        ),
      );
      expect(sent(), '\x1b[B\x1b[B');
    });

    testWidgets('focus in and out are reported to programs that ask', (
      tester,
    ) async {
      await pumpView(tester);
      pty.show(1, ['x'], modes: 16);
      await tester.pump();
      focus.unfocus();
      await tester.pump();
      expect(sent(), '\x1b[O');
      focus.requestFocus();
      await tester.pump();
      expect(sent(), '\x1b[O\x1b[I');
      pty.show(1, ['x'], modes: 0);
      await tester.pump();
      focus.unfocus();
      await tester.pump();
      expect(sent(), '\x1b[O\x1b[I');
    });
  });

  group('links', () {
    testWidgets(
      'Command+click opens a URL or an OSC 8 link, plain click does not',
      (tester) async {
        await pumpView(tester);
        pty.grid(1, {
          'cols': 52,
          'rows': 17,
          'full': true,
          'lines': [
            {
              'y': 0,
              'runs': [
                ['see https://example.org/x now', -1, -1, 0, 29],
              ],
            },
            {
              'y': 1,
              'runs': [
                ['docs', -1, -1, 0, 4, 'https://docs.example'],
              ],
            },
          ],
        });
        await tester.pump();
        final g = await mouse(tester, cell(tester, 8, 0));
        await g.down(cell(tester, 8, 0));
        await g.up();
        expect(opened, isEmpty);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await g.down(cell(tester, 8, 0));
        await g.up();
        await g.down(cell(tester, 1, 1));
        await g.up();
        // No link under this cell.
        await g.down(cell(tester, 40, 5));
        await g.up();
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        expect(opened, ['https://example.org/x', 'https://docs.example']);
      },
    );

    testWidgets('with Command held the link under the pointer is underlined', (
      tester,
    ) async {
      await pumpView(tester);
      pty.show(1, ['go http://a.io ok']);
      await tester.pump();
      final g = await mouse(tester, cell(tester, 0, 5));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await g.moveTo(cell(tester, 5, 0));
      expect(decor.link, const RowSpan(0, 3, 13));
      await g.moveTo(cell(tester, 1, 0));
      expect(decor.link, isNull);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    });

    testWidgets('the setting turns link opening off', (tester) async {
      await pumpView(tester, openLinks: false);
      pty.show(1, ['http://a.io']);
      await tester.pump();
      final g = await mouse(tester, cell(tester, 2, 0));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await g.down(cell(tester, 2, 0));
      await g.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      expect(opened, isEmpty);
    });
  });

  group('scrolling', () {
    testWidgets('the scroller follows the scrollback the embedder reports', (
      tester,
    ) async {
      await pumpView(tester);
      pty.show(
        1,
        ['x'],
        extra: {
          'scroll': {'offset': 0, 'history': 100},
        },
      );
      await tester.pump();
      await tester.pump();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      // 100 lines of 16 pt above the screen: at the bottom of the track.
      expect(position.maxScrollExtent, 1600);
      expect(position.pixels, 1600);
      pty.show(
        1,
        ['x'],
        extra: {
          'scroll': {'offset': 30, 'history': 100},
        },
      );
      await tester.pump();
      await tester.pump();
      expect(position.pixels, 1600 - 30 * 16);
      expect(calls('scroll'), isEmpty, reason: 'the embedder asked for none');
    });

    testWidgets('moving the scroller scrolls the embedder\'s view', (
      tester,
    ) async {
      await pumpView(tester);
      pty.show(
        1,
        ['x'],
        extra: {
          'scroll': {'offset': 0, 'history': 100},
        },
      );
      await tester.pump();
      await tester.pump();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      position.jumpTo(1600 - 20 * 16);
      await tester.pump();
      expect((calls('scroll').last.$3! as Map)['lines'], 20);
      // The embedder moved the view; the user takes it back down.
      pty.show(
        1,
        ['x'],
        extra: {
          'scroll': {'offset': 20, 'history': 100},
        },
      );
      await tester.pump();
      position.jumpTo(1600);
      await tester.pump();
      expect((calls('scroll').last.$3! as Map)['lines'], -20);
    });

    testWidgets('the wheel scrolls the scrollback', (tester) async {
      await pumpView(tester);
      pty.show(
        1,
        ['x'],
        extra: {
          'scroll': {'offset': 0, 'history': 100},
        },
      );
      await tester.pump();
      await tester.pump();
      final g = await mouse(tester, cell(tester, 3, 2));
      await g.moveTo(cell(tester, 3, 2));
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: cell(tester, 3, 2),
          scrollDelta: const Offset(0, -64),
        ),
      );
      await tester.pump();
      expect((calls('scroll').last.$3! as Map)['lines'], 4);
    });

    testWidgets('a scrollback of zero lines has nothing to scroll', (
      tester,
    ) async {
      await pumpView(tester);
      pty.show(1, ['x']);
      await tester.pump();
      await tester.pump();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      expect(position.maxScrollExtent, 0);
    });
  });

  testWidgets('the bell flashes the view for 150 ms', (tester) async {
    await pumpView(tester);
    pty.grid(1, {'bell': true});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(decor.bell, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 200));
    expect(decor.bell, 0);
  });

  testWidgets('a blinking cursor toggles every 500 ms, a steady one does not', (
    tester,
  ) async {
    await pumpView(tester);
    pty.show(
      1,
      ['x'],
      extra: {
        'cursor': {
          'x': 1,
          'y': 0,
          'visible': true,
          'shape': 'block',
          'blink': true,
        },
      },
    );
    await tester.pump();
    expect(decor.cursorOn, isTrue);
    await tester.pump(const Duration(milliseconds: 510));
    expect(decor.cursorOn, isFalse);
    await tester.pump(const Duration(milliseconds: 500));
    expect(decor.cursorOn, isTrue);
    // Typing shows the cursor again at once.
    await tester.pump(const Duration(milliseconds: 500));
    expect(decor.cursorOn, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
    expect(decor.cursorOn, isTrue);
    pty.show(
      1,
      ['x'],
      extra: {
        'cursor': {
          'x': 1,
          'y': 0,
          'visible': true,
          'shape': 'block',
          'blink': false,
        },
      },
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(decor.cursorOn, isTrue);
  });
}
