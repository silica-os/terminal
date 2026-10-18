import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal/src/grid.dart';
import 'package:terminal/src/style.dart';

void main() {
  test('frames update only the rows they carry', () {
    final state = GridState();
    state.apply({
      'cols': 10,
      'rows': 3,
      'full': true,
      'lines': [
        {
          'y': 0,
          'runs': [
            ['hi', -1, -1, 0, 2],
            ['red', 0xcd0000, -1, 1, 3],
          ],
        },
      ],
      'cursor': {'x': 5, 'y': 0, 'visible': true, 'shape': 'block'},
      'modes': 3,
      'title': 'shell',
    });
    expect(state.text, 'hired\n\n');
    expect(state.lines[0].runs[1].bold, isTrue);
    expect(state.modes.appCursor, isTrue);
    expect(state.modes.bracketedPaste, isTrue);
    expect(state.title, 'shell');
    final first = state.lines[0];
    state.apply({
      'cols': 10,
      'rows': 3,
      'full': false,
      'lines': [
        {
          'y': 2,
          'runs': [
            [r'$ ', -1, -1, 0, 2],
          ],
        },
      ],
    });
    expect(identical(state.lines[0], first), isTrue);
    expect(state.text, 'hired\n\n\$ ');
  });

  test('malformed frames are ignored, not thrown', () {
    final state = GridState();
    state.apply({
      'lines': [
        {'y': 99, 'runs': []},
        {'y': 'x'},
        'junk',
      ],
      'cols': 0,
      'rows': -2,
      'scroll': 'nope',
      'selection': [
        [1, 2],
        'x',
      ],
      'marks': ['a', 3],
      'clipboard': ['x', {}],
    });
    expect(state.lines, hasLength(24));
    expect(state.selection, isEmpty);
    expect(state.marks, [3]);
  });

  test('scroll, selection, marks, directory and command come with frames', () {
    final state = GridState();
    state.apply({
      'cols': 20,
      'rows': 5,
      'full': true,
      'lines': <Object>[],
      'scroll': {'offset': 3, 'history': 40},
      'selection': [
        [1, 2, 5],
        [2, 0, 19],
      ],
      'marks': [0, 3],
      'cwd': '/home/me',
      'command': {'running': true},
    });
    expect((state.offset, state.history), (3, 40));
    expect(state.selection, [const RowSpan(1, 2, 5), const RowSpan(2, 0, 19)]);
    expect(state.marks, [0, 3]);
    expect(state.cwd, '/home/me');
    expect(state.commandRunning, isTrue);
    state.apply({
      'command': {'running': false, 'exit': 2},
      'selection': <Object>[],
    });
    expect(state.commandRunning, isFalse);
    expect(state.lastExit, 2);
    expect(state.selection, isEmpty);
    // A frame without the key leaves the value alone.
    state.apply({
      'cursor': {'x': 1, 'y': 1},
    });
    expect(state.marks, [0, 3]);
  });

  test('bells and the clipboard are told to whoever listens', () {
    final state = GridState();
    final requests = <ClipboardRequest>[];
    state.onClipboard = requests.add;
    state.apply({'bell': true});
    state.apply({'bell': true});
    expect(state.bells.value, 2);
    state.apply({
      'clipboard': [
        {'set': 'hello', 'selection': false},
        {'get': true, 'selection': true},
      ],
    });
    expect(requests.map((r) => (r.text, r.selection)), [
      ('hello', false),
      (null, true),
    ]);
  });

  test('cursor blink and shape follow the frame', () {
    final state = GridState();
    state.apply({
      'cursor': {
        'x': 1,
        'y': 2,
        'visible': false,
        'shape': 'beam',
        'blink': true,
      },
    });
    expect((state.cursorX, state.cursorY, state.cursorVisible), (1, 2, false));
    expect((state.cursorShape, state.cursorBlinks), ('beam', true));
  });

  test('a note is written below the output and scrolls a full screen', () {
    final state = GridState();
    state.apply({
      'cols': 20,
      'rows': 3,
      'full': true,
      'lines': [
        {
          'y': 0,
          'runs': [
            ['one', -1, -1, 0, 3],
          ],
        },
        {
          'y': 1,
          'runs': [
            ['two', -1, -1, 0, 3],
          ],
        },
      ],
      'cursor': {'x': 3, 'y': 1, 'visible': true, 'shape': 'block'},
    });
    state.note('ended');
    expect(state.text, 'one\ntwo\nended');
    expect(state.lines[2].runs.first.dim, isTrue);
    expect(state.cursorVisible, isFalse);
    state.note('again');
    expect(state.text, 'two\nended\nagain');
  });

  group('rows', () {
    test('rows with the same content share their key', () {
      final a = GridRow(const [GridRun('ls', -1, -1, 0)]);
      final b = GridRow(const [GridRun('ls', -1, -1, 0)]);
      final c = GridRow(const [GridRun('ls', -1, -1, 1)]);
      final d = GridRow(const [GridRun('ls', -1, -1, 0, 2, 'http://x')]);
      expect(a.key, b.key);
      expect(a.key, isNot(c.key));
      expect(a.key, isNot(d.key));
    });

    test('cells count wide characters twice, text maps back to cells', () {
      final row = GridRow(const [
        GridRun('a', -1, -1, 0, 1),
        GridRun('日本', -1, -1, 256, 4),
        GridRun('b', -1, -1, 0, 1),
      ]);
      expect(row.cells, 6);
      expect(row.simple, isFalse);
      final (text, columns) = row.textAndCells;
      expect(text, 'a日本b');
      expect(columns, [0, 1, 3, 5]);
      expect(row.runAt(2)!.$1.text, '日本');
      expect(row.runAt(2)!.$2, 1);
      expect(row.runAt(9), isNull);
      expect(GridRow(const [GridRun('ls', -1, -1, 0)]).simple, isTrue);
    });
  });

  group('the painter', () {
    GridState sample() => GridState()
      ..apply({
        'cols': 10,
        'rows': 3,
        'full': true,
        'lines': [
          {
            'y': 0,
            'runs': [
              ['ab', -1, -1, 0, 2],
              ['cd', paletteBase + 1, 0x112233, 1, 2],
              ['日', -1, paletteBase + 4, 256, 2],
            ],
          },
          {
            'y': 1,
            'runs': [
              ['link', -1, -1, 0, 4, 'http://example.org'],
            ],
          },
        ],
        'cursor': {'x': 6, 'y': 0, 'visible': true, 'shape': 'block'},
        'selection': [
          [1, 0, 3],
        ],
        'marks': [1],
      });

    GridPainter painter(
      GridState state,
      GridDecor decor,
      ParagraphCache cache,
    ) => GridPainter(
      state,
      colors: const GridColors(
        background: Color(0xffffffff),
        foreground: Color(0xff000000),
        bold: Color(0xff000000),
        selection: Color(0xffb3d7ff),
        cursor: Color(0xff9d9d9d),
      ),
      style: terminalTextStyle(12),
      cellWidth: 7.2,
      cellHeight: 16,
      padding: const EdgeInsets.all(12),
      cache: cache,
      decor: decor,
      selectionColor: const Color(0xffb3d7ff),
      findColor: const Color(0xffc8c8c8),
      currentFindColor: const Color(0xff888888),
      markColor: const Color(0xff9a9ea6),
    );

    test('ANSI colours can be turned off and bold can use the bright ones', () {
      GridPainter with_({bool ansi = true, bool bright = false}) => GridPainter(
        sample(),
        colors: GridColors(
          background: const Color(0xffffffff),
          foreground: const Color(0xff000000),
          bold: const Color(0xff000000),
          selection: const Color(0xffb3d7ff),
          cursor: const Color(0xff9d9d9d),
          ansiColors: ansi,
          brightBold: bright,
        ),
        style: terminalTextStyle(12),
        cellWidth: 7.2,
        cellHeight: 16,
        padding: EdgeInsets.zero,
        cache: ParagraphCache(),
        decor: GridDecor(),
        selectionColor: const Color(0xffb3d7ff),
        findColor: const Color(0xffc8c8c8),
        currentFindColor: const Color(0xff888888),
        markColor: const Color(0xff9a9ea6),
      );
      final red = GridRun('x', paletteBase + 1, paletteBase + 2, 0);
      final boldRed = GridRun('x', paletteBase + 1, -1, 1);
      final normal = with_().runColors(red);
      expect(normal.$1, isNot(const Color(0xff000000)));
      expect(normal.$2, isNotNull);
      final off = with_(ansi: false).runColors(red);
      expect(off.$1, const Color(0xff000000));
      expect(off.$2, const Color(0xffffffff));
      final colours = with_().colors;
      expect(with_().runColors(boldRed).$1, colours.indexed(1));
      expect(with_(bright: true).runColors(boldRed).$1, colours.indexed(9));
      // True colour is not an ANSI colour.
      expect(
        with_(ansi: false).runColors(const GridRun('x', 0x123456, -1, 0)).$1,
        const Color(0xff123456),
      );
    });

    test('paints every kind of row without throwing, and caches layouts', () {
      final state = sample();
      final decor = GridDecor()
        ..update(
          hits: const [RowHit(0, 0, 1), RowHit(0, 2, 3, current: true)],
          link: const RowSpan(1, 0, 3),
          bell: 0.5,
          active: false,
        );
      final cache = ParagraphCache();
      final recorder = ui.PictureRecorder();
      painter(
        state,
        decor,
        cache,
      ).paint(Canvas(recorder), const Size(300, 120));
      recorder.endRecording().dispose();
      // A simple row is one paragraph, a row with a wide run one per run.
      expect(cache.length, greaterThan(0));
      final before = cache.length;
      final again = ui.PictureRecorder();
      painter(state, decor, cache).paint(Canvas(again), const Size(300, 120));
      again.endRecording().dispose();
      expect(cache.length, before, reason: 'laid out once');
      cache.dispose();
      expect(cache.length, 0);
    });

    test('the cache keeps the most recent paragraphs only', () {
      final cache = ParagraphCache(2);
      ui.Paragraph make() =>
          (ui.ParagraphBuilder(ui.ParagraphStyle())..addText('x')).build()
            ..layout(const ui.ParagraphConstraints(width: 10));
      cache.get('a', make);
      cache.get('b', make);
      cache.get('a', make);
      cache.get('c', make);
      expect(cache.length, 2);
      var built = 0;
      cache.get('a', () {
        built++;
        return make();
      });
      expect(built, 0, reason: 'a was used last, b went');
      cache.dispose();
    });

    test('repaints when the colours or the font change', () {
      final state = sample();
      final decor = GridDecor();
      final cache = ParagraphCache();
      final a = painter(state, decor, cache);
      expect(a.shouldRepaint(painter(state, decor, cache)), isFalse);
      expect(a.shouldRepaint(painter(state, decor, ParagraphCache())), isTrue);
      cache.dispose();
    });
  });

  test('the decoration tells only real changes', () {
    final decor = GridDecor();
    var n = 0;
    decor.addListener(() => n++);
    decor.update(cursorOn: true, active: true, bell: 0);
    expect(n, 0);
    decor.update(cursorOn: false);
    decor.update(hits: const [RowHit(1, 2, 3)]);
    decor.update(hits: const [RowHit(1, 2, 3)]);
    decor.update(link: const RowSpan(0, 0, 1));
    decor.update(clearLink: true);
    expect(n, 4);
    expect(decor.link, isNull);
  });
}
