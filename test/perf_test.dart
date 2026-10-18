// Does the Dart side keep up with a flood? The embedder parses off the UI thread and sends
// at most one frame per 16.7 ms; here is what a frame costs the UI thread: decoding the
// message, building the rows, laying out their paragraphs and painting. The numbers are
// printed (docs/performance.md); the assertions only guard against a collapse.

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal/src/grid.dart';
import 'package:flutter/services.dart';
import 'package:silica_ui/silica_ui.dart';
import 'package:terminal/src/keys.dart';
import 'package:terminal/src/pty.dart';
import 'package:terminal/src/session.dart';
import 'package:terminal/src/terminal_view.dart';
import 'package:terminal/src/style.dart';

Map<String, Object?> floodFrame(
  int frame, {
  required int rows,
  required int cols,
}) {
  // A `seq` flood: every row is new in every frame; the colour variant has a run per word.
  final lines = <Object>[];
  for (var y = 0; y < rows; y++) {
    final n = frame * rows + y;
    final text =
        '${n.toString().padLeft(8, '0')} The quick brown fox jumps over the lazy dog';
    lines.add({
      'y': y,
      'runs': frame.isEven
          ? [
              [
                text.substring(0, cols.clamp(0, text.length)),
                -1,
                -1,
                0,
                text.length,
              ],
            ]
          : [
              [text.substring(0, 8), 0x1000000 + (y % 8), -1, 1, 8],
              [' ', -1, -1, 0, 1],
              [text.substring(9, 24), -1, 0x1000000 + ((y + 3) % 8), 0, 15],
              [text.substring(24), 0x2288cc, -1, 4, text.length - 24],
            ],
    });
  }
  return {
    'id': 1,
    'cols': cols,
    'rows': rows,
    'full': false,
    'lines': lines,
    'cursor': {'x': 0, 'y': rows - 1, 'visible': true, 'shape': 'block'},
    'modes': 0,
  };
}

double percentile(List<double> sorted, double p) =>
    sorted.isEmpty ? 0 : sorted[((sorted.length - 1) * p).round()];

void main() {
  testWidgets('what a flood frame costs the UI thread (60 rows × 200 columns)', (
    tester,
  ) async {
    const rows = 60;
    const cols = 200;
    final state = GridState()
      ..apply({'cols': cols, 'rows': rows, 'full': true, 'lines': <Object>[]});
    final style = terminalTextStyle(12);
    final painter = GridPainter(
      state,
      colors: const GridColors(
        background: Color(0xffffffff),
        foreground: Color(0xff000000),
        bold: Color(0xff000000),
        selection: Color(0xffb3d7ff),
        cursor: Color(0xff9d9d9d),
      ),
      style: style,
      cellWidth: cellWidthFor(12),
      cellHeight: cellHeightFor(12),
      padding: gridPadding,
      cache: ParagraphCache(),
      decor: GridDecor(),
      selectionColor: const Color(0xffb3d7ff),
      findColor: const Color(0xffc8c8c8),
      currentFindColor: const Color(0xff888888),
      markColor: const Color(0xff999999),
    );
    final decode = <double>[];
    final apply = <double>[];
    final paint = <double>[];
    final total = <double>[];
    final sizes = <double>[];
    const frames = 120;
    for (var f = 0; f < frames; f++) {
      final text = jsonEncode(floodFrame(f, rows: rows, cols: cols));
      sizes.add(text.length / 1024);
      final bytes = utf8.encode(text);
      final all = Stopwatch()..start();
      final t0 = all.elapsedMicroseconds;
      final map = jsonDecode(utf8.decode(bytes)) as Map<Object?, Object?>;
      final t1 = all.elapsedMicroseconds;
      state.apply(map);
      final t2 = all.elapsedMicroseconds;
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(1500, 1000));
      recorder.endRecording().dispose();
      final t3 = all.elapsedMicroseconds;
      decode.add((t1 - t0) / 1000);
      apply.add((t2 - t1) / 1000);
      paint.add((t3 - t2) / 1000);
      total.add((t3 - t0) / 1000);
    }
    for (final list in [decode, apply, paint, total, sizes]) {
      list.sort();
    }
    // ignore: avoid_print
    print(
      'flood frame, $rows × $cols, every row new: ${percentile(sizes, 0.5).toStringAsFixed(0)} KB; '
      'decode p50 ${percentile(decode, 0.5).toStringAsFixed(2)} ms, apply p50 ${percentile(apply, 0.5).toStringAsFixed(2)} ms, '
      'layout + paint p50 ${percentile(paint, 0.5).toStringAsFixed(2)} ms p99 ${percentile(paint, 0.99).toStringAsFixed(2)} ms; '
      'UI thread per frame p50 ${percentile(total, 0.5).toStringAsFixed(2)} ms p99 ${percentile(total, 0.99).toStringAsFixed(2)} ms max ${percentile(total, 1).toStringAsFixed(2)} ms',
    );
    // A collapse, not a benchmark: a frame is far under a second.
    expect(percentile(total, 0.5), lessThan(200));
    painter.cache.dispose();
  });

  testWidgets('frames keep coming and keys keep going while the view is flooded', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final pty = FakePty();
    final session = TerminalSession(pty: pty);
    final focus = FocusNode();
    addTearDown(session.dispose);
    addTearDown(focus.dispose);
    final colors = Profile.of(
      const AmalfiThemeData(brightness: Brightness.light, app: 'Terminal'),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: AmalfiTheme(
          app: 'Terminal',
          child: TerminalView(
            session: session,
            look: TerminalLook(
              colors: colors.grid,
              selection: colors.grid.selection,
              find: colors.findMatch,
              currentFind: colors.grid.selection,
              mark: const Color(0xff999999),
            ),
            focusNode: focus,
            decor: GridDecor(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final rows = pty.sizes[1]!.$1;
    final cols = pty.sizes[1]!.$2;
    final pumps = <double>[];
    final keys = <double>[];
    for (var f = 0; f < 120; f++) {
      pty.grid(1, floodFrame(f, rows: rows, cols: cols));
      final t = Stopwatch()..start();
      await tester.pump(const Duration(milliseconds: 16));
      pumps.add(t.elapsedMicroseconds / 1000);
      final k = Stopwatch()..start();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
      keys.add(k.elapsedMicroseconds / 1000);
    }
    pumps.sort();
    keys.sort();
    // ignore: avoid_print
    print(
      'view flooded, $rows × $cols: build + layout + paint per frame p50 ${percentile(pumps, 0.5).toStringAsFixed(2)} ms p99 ${percentile(pumps, 0.99).toStringAsFixed(2)} ms; '
      'a key sent between frames p50 ${percentile(keys, 0.5).toStringAsFixed(2)} ms p99 ${percentile(keys, 0.99).toStringAsFixed(2)} ms; '
      '${pty.written[1]!.length} keys reached the pty',
    );
    // Every key reached the process, none was dropped.
    expect(pty.written[1], List.filled(120, 0x61));
  });

  test('a key press costs the UI thread microseconds', () {
    final watch = Stopwatch()..start();
    var n = 0;
    for (var i = 0; i < 10000; i++) {
      n += encodePaste('line $i\nsecond', const TerminalModes(2)).length;
    }
    watch.stop();
    // ignore: avoid_print
    print(
      'encoding 10000 pastes of 2 lines: ${(watch.elapsedMicroseconds / 10000).toStringAsFixed(2)} µs each ($n bytes)',
    );
    expect(watch.elapsedMilliseconds, lessThan(5000));
  });
}
