// The terminal emulated by the embedder (`spawn(grid: true)`): the app keeps only the visible
// rows as runs of text and paints them with one CustomPainter. Parsing escape sequences
// happens in Rust (alacritty_terminal) off the UI thread, and only changed rows arrive, once
// per frame; each row's Paragraph is cached until the row changes, so a frame costs the
// changed rows.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'keys.dart';
import 'style.dart';

/// Colours `paletteBase + i` are entries of the 256-colour palette (the embedder does not
/// bake the palette in, so a profile's ANSI colours apply).
const int paletteBase = 0x1000000;

/// One run of cells with the same attributes. Colours are 0xRRGGBB, -1 for the default.
@immutable
class GridRun {
  const GridRun(
    this.text,
    this.fg,
    this.bg,
    this.flags, [
    int? cells,
    this.link,
  ]) : _cells = cells;
  final String text;
  final int fg;
  final int bg;
  final int flags;
  final int? _cells;

  /// The OSC 8 target of the text, if it is a link.
  final String? link;

  /// The width in cells (wide characters count two).
  int get cells => _cells ?? text.runes.length;

  bool get bold => flags & 1 != 0;
  bool get italic => flags & 2 != 0;
  bool get underline => flags & 4 != 0;
  bool get inverse => flags & 8 != 0;
  bool get dim => flags & 16 != 0;
  bool get strikeout => flags & 32 != 0;
  bool get curly => flags & 64 != 0;
  bool get hidden => flags & 128 != 0;
  bool get wide => flags & 256 != 0;

  /// Plain ASCII: the glyphs of the face advance exactly one cell each.
  bool get simple =>
      !wide && text.codeUnits.every((c) => c >= 0x20 && c < 0x7f);
}

/// A visible row: its runs.
class GridRow {
  GridRow(this.runs);
  final List<GridRun> runs;
  static final GridRow empty = GridRow(const []);

  /// The content as a key: a row that scrolls to another line keeps its painted paragraph.
  late final String key = [
    for (final r in runs)
      '${r.fg},${r.bg},${r.flags},${r.link ?? ''}\u0001${r.text}',
  ].join('\u0000');

  /// Every run is plain ASCII, so one paragraph per row lines up with the cells.
  late final bool simple = runs.every((r) => r.simple);

  /// The width of the content in cells.
  late final int cells = runs.fold<int>(0, (a, r) => a + r.cells);

  /// The text of the row, and for each UTF-16 unit of it the cell it starts in.
  late final (String, List<int>) textAndCells = _textAndCells();

  String get text => textAndCells.$1;

  (String, List<int>) _textAndCells() {
    final buffer = StringBuffer();
    final columns = <int>[];
    var x = 0;
    for (final run in runs) {
      var column = x;
      for (final rune in run.text.runes) {
        final char = String.fromCharCode(rune);
        buffer.write(char);
        for (var i = 0; i < char.length; i++) {
          columns.add(column);
        }
        // Zero-width combining marks sit in the previous cell.
        column += run.wide ? 2 : (_isCombining(rune) ? 0 : 1);
      }
      x += run.cells;
    }
    return (buffer.toString(), columns);
  }

  static bool _isCombining(int rune) =>
      (rune >= 0x300 && rune <= 0x36f) ||
      (rune >= 0x200b && rune <= 0x200f) ||
      rune == 0xfe0f;

  /// The run that covers cell [x], with the cell it starts in.
  (GridRun, int)? runAt(int x) {
    var start = 0;
    for (final run in runs) {
      if (x < start + run.cells) return (run, start);
      start += run.cells;
    }
    return null;
  }
}

/// A stretch of a visible row, cells [x0]…[x1] included: a selection, a link.
@immutable
class RowSpan {
  const RowSpan(this.y, this.x0, this.x1);
  final int y;
  final int x0;
  final int x1;

  @override
  bool operator ==(Object other) =>
      other is RowSpan && other.y == y && other.x0 == x0 && other.x1 == x1;

  @override
  int get hashCode => Object.hash(y, x0, x1);

  @override
  String toString() => 'RowSpan($y, $x0…$x1)';
}

/// A program wrote to or asked for the clipboard (OSC 52).
@immutable
class ClipboardRequest {
  const ClipboardRequest.set(String this.text, {required this.selection});
  const ClipboardRequest.get({required this.selection}) : text = null;

  /// The text to store; null: the program wants to read the clipboard.
  final String? text;
  final bool selection;
}

/// The state of the emulated terminal as the embedder reports it.
class GridState extends ChangeNotifier {
  int cols = 80;
  int rows = 24;
  List<GridRow> lines = List.filled(24, GridRow.empty);
  int cursorX = 0;
  int cursorY = 0;
  bool cursorVisible = true;
  String cursorShape = 'block';
  bool cursorBlinks = false;
  TerminalModes modes = TerminalModes.none;
  String? title;

  /// Lines scrolled back from the bottom, and lines in the scrollback.
  int offset = 0;
  int history = 0;

  /// The selected cells of the visible rows.
  List<RowSpan> selection = const [];

  /// The visible rows that start a prompt (OSC 133, Mark).
  List<int> marks = const [];

  /// The shell's working directory (OSC 7).
  String? cwd;

  /// A command runs (OSC 133 C … D), and the exit code of the last one.
  bool commandRunning = false;
  int? lastExit;

  /// Counts the bells the program rang.
  final ValueNotifier<int> bells = ValueNotifier<int>(0);

  /// Told when the program uses the clipboard (OSC 52).
  void Function(ClipboardRequest request)? onClipboard;

  /// Told when the title, the directory or the command state changed.
  VoidCallback? onMeta;

  /// The view was resized: until the embedder's frame says so, the size is the layout's.
  void resizeTo(int newRows, int newCols) {
    if (newRows < 1 || newCols < 1 || (newRows == rows && newCols == cols)) {
      return;
    }
    lines = [
      for (var y = 0; y < newRows; y++)
        y < lines.length ? lines[y] : GridRow.empty,
    ];
    rows = newRows;
    cols = newCols;
    notifyListeners();
  }

  /// Applies one `grid` message.
  void apply(Map<Object?, Object?> frame) {
    final c = frame['cols'];
    final r = frame['rows'];
    if (c is int &&
        r is int &&
        c > 0 &&
        r > 0 &&
        (c != cols || r != rows || frame['full'] == true)) {
      cols = c;
      rows = r;
      lines = List.filled(r, GridRow.empty, growable: false);
    }
    final changed = frame['lines'];
    if (changed is List) {
      for (final line in changed) {
        if (line is! Map) continue;
        final y = line['y'];
        final runs = line['runs'];
        if (y is! int || y < 0 || y >= lines.length || runs is! List) continue;
        lines[y] = GridRow([
          for (final run in runs)
            if (run is List && run.length >= 4) _run(run),
        ]);
      }
    }
    final cursor = frame['cursor'];
    if (cursor is Map) {
      cursorX = cursor['x'] is int ? cursor['x'] as int : cursorX;
      cursorY = cursor['y'] is int ? cursor['y'] as int : cursorY;
      cursorVisible = cursor['visible'] != false;
      cursorShape = cursor['shape'] is String
          ? cursor['shape'] as String
          : 'block';
      cursorBlinks = cursor['blink'] == true;
    }
    final m = frame['modes'];
    if (m is int) modes = TerminalModes(m);
    var meta = false;
    final t = frame['title'];
    if (t is String) {
      title = t;
      meta = true;
    }
    final scroll = frame['scroll'];
    if (scroll is Map) {
      if (scroll['offset'] is int) offset = scroll['offset'] as int;
      if (scroll['history'] is int) history = scroll['history'] as int;
    }
    final selected = frame['selection'];
    if (selected is List) {
      selection = [
        for (final s in selected)
          if (s is List && s.length == 3 && s.every((v) => v is int))
            RowSpan(s[0] as int, s[1] as int, s[2] as int),
      ];
    }
    final marked = frame['marks'];
    if (marked is List) {
      marks = [
        for (final y in marked)
          if (y is int) y,
      ];
    }
    final directory = frame['cwd'];
    if (directory is String && directory.isNotEmpty) {
      cwd = directory;
      meta = true;
    }
    final command = frame['command'];
    if (command is Map) {
      commandRunning = command['running'] == true;
      lastExit = command['exit'] is int ? command['exit'] as int : null;
      meta = true;
    }
    notifyListeners();
    if (frame['bell'] == true) bells.value++;
    final clipboard = frame['clipboard'];
    if (clipboard is List) {
      for (final entry in clipboard) {
        if (entry is! Map) continue;
        final selection = entry['selection'] == true;
        final set = entry['set'];
        if (set is String) {
          onClipboard?.call(ClipboardRequest.set(set, selection: selection));
        } else if (entry['get'] == true) {
          onClipboard?.call(ClipboardRequest.get(selection: selection));
        }
      }
    }
    if (meta) onMeta?.call();
  }

  static GridRun _run(List<Object?> run) => GridRun(
    run[0] is String ? run[0] as String : '',
    run[1] is int ? run[1] as int : -1,
    run[2] is int ? run[2] as int : -1,
    run[3] is int ? run[3] as int : 0,
    run.length > 4 && run[4] is int ? run[4] as int : null,
    run.length > 5 && run[5] is String ? run[5] as String : null,
  );

  /// The visible text (tests, accessibility).
  String get text =>
      lines.map((l) => l.runs.map((r) => r.text).join()).join('\n');

  /// The visible text with the trailing blank rows dropped.
  String get screenText => text.trimRight();

  /// Writes a dimmed line of the app's own below the output (the process ended, the shell
  /// could not start), scrolling the screen if it is full. The embedder knows nothing of it.
  void note(String message) {
    var row = cursorX == 0 && lines[cursorY.clamp(0, rows - 1)].runs.isEmpty
        ? cursorY
        : cursorY + 1;
    if (row >= rows) {
      lines = [
        ...lines.skip(row - rows + 1),
        for (var i = 0; i < row - rows + 1; i++) GridRow.empty,
      ];
      row = rows - 1;
    }
    row = row.clamp(0, rows - 1);
    lines[row] = GridRow([GridRun(message, -1, -1, 16, message.runes.length)]);
    cursorX = 0;
    cursorY = (row + 1).clamp(0, rows - 1);
    cursorVisible = false;
    notifyListeners();
  }
}

/// A stretch of a visible row to highlight: a find match.
@immutable
class RowHit {
  const RowHit(this.y, this.x0, this.x1, {this.current = false});
  final int y;
  final int x0;
  final int x1;
  final bool current;

  @override
  bool operator ==(Object other) =>
      other is RowHit &&
      other.y == y &&
      other.x0 == x0 &&
      other.x1 == x1 &&
      other.current == current;

  @override
  int get hashCode => Object.hash(y, x0, x1, current);
}

/// What the painter shows besides the rows: it changes without new rows arriving.
class GridDecor extends ChangeNotifier {
  List<RowHit> hits = const [];

  /// The link under the pointer with the Command key held.
  RowSpan? link;

  /// The cursor is in the "on" half of its blink (always true when it does not blink).
  bool cursorOn = true;

  /// The window has the keyboard: a filled cursor; otherwise an outline.
  bool active = true;

  /// The visual bell, 0 (none) to 1 (full flash).
  double bell = 0;

  /// Prompt marks are drawn in the left margin.
  bool showMarks = true;

  void update({
    List<RowHit>? hits,
    RowSpan? link,
    bool clearLink = false,
    bool? cursorOn,
    bool? active,
    double? bell,
    bool? showMarks,
  }) {
    var changed = false;
    if (hits != null && !listEquals(hits, this.hits)) {
      this.hits = hits;
      changed = true;
    }
    if ((link != null || clearLink) && link != this.link) {
      this.link = link;
      changed = true;
    }
    if (cursorOn != null && cursorOn != this.cursorOn) {
      this.cursorOn = cursorOn;
      changed = true;
    }
    if (active != null && active != this.active) {
      this.active = active;
      changed = true;
    }
    if (bell != null && bell != this.bell) {
      this.bell = bell;
      changed = true;
    }
    if (showMarks != null && showMarks != this.showMarks) {
      this.showMarks = showMarks;
      changed = true;
    }
    if (changed) notifyListeners();
  }
}

/// Paragraphs by row (or run) content, least recently used first: rows that only moved, as
/// when output scrolls, are not laid out again. Valid for one style: replace it when the font
/// or the colours change.
class ParagraphCache {
  ParagraphCache([this.capacity = 2048]);
  final int capacity;
  final Map<String, ui.Paragraph> _map = <String, ui.Paragraph>{};

  ui.Paragraph get(String key, ui.Paragraph Function() build) {
    final cached = _map.remove(key);
    if (cached != null) {
      _map[key] = cached;
      return cached;
    }
    final made = build();
    _map[key] = made;
    if (_map.length > capacity) {
      _map.remove(_map.keys.first)?.dispose();
    }
    return made;
  }

  int get length => _map.length;

  void dispose() {
    for (final p in _map.values) {
      p.dispose();
    }
    _map.clear();
  }
}

/// Paints the rows: backgrounds, selection and find highlights, one cached Paragraph per row
/// (per run for rows with wide or non-ASCII text, so that every run starts on its cell), the
/// cursor, the prompt marks.
class GridPainter extends CustomPainter {
  GridPainter(
    this.state, {
    required this.colors,
    required this.style,
    required this.cellWidth,
    required this.cellHeight,
    required this.padding,
    required this.cache,
    required this.decor,
    required this.selectionColor,
    required this.findColor,
    required this.currentFindColor,
    required this.markColor,
    this.boldFace = true,
  }) : super(repaint: Listenable.merge([state, decor]));

  final GridState state;
  final GridColors colors;
  final TextStyle style;
  final double cellWidth;
  final double cellHeight;
  final EdgeInsets padding;
  final ParagraphCache cache;
  final GridDecor decor;
  final Color selectionColor;
  final Color findColor;
  final Color currentFindColor;
  final Color markColor;

  /// Bold text uses the bold face (the profile can turn it off).
  final bool boldFace;

  Color _color(int value, {required bool foreground}) {
    if (value < 0) return foreground ? colors.foreground : colors.background;
    if (value >= paletteBase) return colors.indexed(value - paletteBase);
    return Color(0xff000000 | value);
  }

  /// The foreground and background of a run after inverse, dim and bold.
  (Color, Color?) _runColors(GridRun run) {
    var fg = _color(run.fg, foreground: true);
    if (run.bold && run.fg < 0) fg = colors.bold;
    Color? bg = run.bg >= 0 ? _color(run.bg, foreground: false) : null;
    if (run.inverse) {
      final swapped = bg ?? colors.background;
      bg = fg;
      fg = swapped;
    }
    if (run.dim) fg = fg.withValues(alpha: fg.a * 0.6);
    if (run.hidden) fg = const Color(0x00000000);
    return (fg, bg);
  }

  ui.TextStyle _textStyle(GridRun run, Color fg) => style
      .copyWith(
        color: fg,
        fontWeight: run.bold && boldFace ? FontWeight.w700 : FontWeight.w400,
        fontStyle: run.italic ? FontStyle.italic : FontStyle.normal,
        decoration: TextDecoration.combine([
          if (run.underline || run.curly || run.link != null)
            TextDecoration.underline,
          if (run.strikeout) TextDecoration.lineThrough,
        ]),
        decorationStyle: run.curly ? TextDecorationStyle.wavy : null,
        decorationColor: fg,
        height: cellHeight / (style.fontSize ?? 12),
      )
      .getTextStyle();

  ui.ParagraphBuilder _builder() => ui.ParagraphBuilder(
    ui.ParagraphStyle(
      maxLines: 1,
      height: 1,
      textHeightBehavior: const ui.TextHeightBehavior(),
    ),
  );

  ui.Paragraph _rowParagraph(GridRow row) => cache.get(row.key, () {
    final builder = _builder();
    for (final run in row.runs) {
      builder.pushStyle(_textStyle(run, _runColors(run).$1));
      builder.addText(run.text);
      builder.pop();
    }
    return builder.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));
  });

  ui.Paragraph _runParagraph(GridRun run) => cache.get(
    'r${run.fg},${run.bg},${run.flags},${run.link ?? ''}\u0001${run.text}',
    () {
      final builder = _builder()
        ..pushStyle(_textStyle(run, _runColors(run).$1));
      builder.addText(run.text);
      return builder.build()
        ..layout(const ui.ParagraphConstraints(width: double.infinity));
    },
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.background);
    final origin = Offset(padding.left, padding.top);
    final fill = Paint();
    Rect cells(int y, int x0, int x1) => Rect.fromLTRB(
      origin.dx + x0 * cellWidth,
      origin.dy + y * cellHeight,
      origin.dx + (x1 + 1) * cellWidth,
      origin.dy + (y + 1) * cellHeight,
    );
    for (var y = 0; y < state.lines.length; y++) {
      final row = state.lines[y];
      var x = 0;
      for (final run in row.runs) {
        final bg = _runColors(run).$2;
        if (bg != null) {
          fill.color = bg;
          canvas.drawRect(cells(y, x, x + run.cells - 1), fill);
        }
        x += run.cells;
      }
    }
    fill.color = selectionColor;
    for (final span in state.selection) {
      canvas.drawRect(cells(span.y, span.x0, span.x1), fill);
    }
    for (final hit in decor.hits) {
      fill.color = hit.current ? currentFindColor : findColor;
      canvas.drawRect(cells(hit.y, hit.x0, hit.x1), fill);
    }
    for (var y = 0; y < state.lines.length; y++) {
      final row = state.lines[y];
      if (row.runs.isEmpty) continue;
      final dy = origin.dy + y * cellHeight;
      if (row.simple) {
        canvas.drawParagraph(_rowParagraph(row), Offset(origin.dx, dy));
        continue;
      }
      var x = 0;
      for (final run in row.runs) {
        if (run.text.trim().isNotEmpty) {
          canvas.drawParagraph(
            _runParagraph(run),
            Offset(origin.dx + x * cellWidth, dy),
          );
        }
        x += run.cells;
      }
    }
    final link = decor.link;
    if (link != null && link.y >= 0 && link.y < state.rows) {
      final rect = cells(link.y, link.x0, link.x1);
      canvas.drawLine(
        Offset(rect.left, rect.bottom - 1.5),
        Offset(rect.right, rect.bottom - 1.5),
        Paint()
          ..color = colors.foreground
          ..strokeWidth = 1,
      );
    }
    if (decor.showMarks) {
      fill.color = markColor;
      for (final y in state.marks) {
        if (y < 0 || y >= state.rows) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              3,
              origin.dy + y * cellHeight + cellHeight * 0.2,
              3,
              cellHeight * 0.6,
            ),
            const Radius.circular(1.5),
          ),
          fill,
        );
      }
    }
    _cursor(canvas, origin);
    if (decor.bell > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = colors.foreground.withValues(alpha: 0.18 * decor.bell),
      );
    }
  }

  void _cursor(Canvas canvas, Offset origin) {
    if (!state.cursorVisible || (!decor.cursorOn && decor.active)) return;
    if (state.cursorY < 0 || state.cursorY >= state.rows) return;
    final rect = Rect.fromLTWH(
      origin.dx + state.cursorX * cellWidth,
      origin.dy + state.cursorY * cellHeight,
      cellWidth,
      cellHeight,
    );
    if (!decor.active) {
      // A window without the keyboard: the cursor is an outline.
      canvas.drawRect(
        rect.deflate(0.5),
        Paint()
          ..color = colors.cursor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      return;
    }
    final paint = Paint()..color = colors.cursor.withValues(alpha: 0.7);
    switch (state.cursorShape) {
      case 'beam':
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.top, 2, rect.height),
          paint,
        );
      case 'underline':
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.bottom - 2, rect.width, 2),
          paint,
        );
      default:
        canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(GridPainter old) =>
      old.state != state ||
      old.colors != colors ||
      old.style != style ||
      old.cellWidth != cellWidth ||
      old.cellHeight != cellHeight ||
      old.selectionColor != selectionColor ||
      old.boldFace != boldFace ||
      old.padding != padding ||
      old.cache != cache;
}
