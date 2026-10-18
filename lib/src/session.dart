// One terminal session: a pseudo-terminal of the embedder whose emulation also runs there
// (grid mode). Keystrokes go to the process as UTF-8; the embedder sends the rows that
// changed, which [GridState] keeps; a layout change resizes the pseudo-terminal; the title,
// the working directory and the shell's marks follow the escape sequences of the program.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'grid.dart';
import 'keys.dart';
import 'l10n.dart';
import 'links.dart';
import 'pty.dart';
import 'settings.dart';

/// The primary selection of the app: the last text selected with the mouse, pasted by the
/// middle button. (Between apps it needs the embedder's primary selection protocol.)
abstract final class PrimarySelection {
  static final ValueNotifier<String?> _value = ValueNotifier<String?>(null);

  /// Tells when a new selection becomes the primary one.
  static ValueListenable<String?> get listenable => _value;

  static String? get text => _value.value;
  static set text(String? text) => _value.value = text;
}

/// A match of the find bar, in rows counted from the top of the buffer: one piece per row
/// it covers.
@immutable
class FindMatch {
  const FindMatch(this.pieces);
  final List<(int row, int x0, int x1)> pieces;

  int get firstRow => pieces.isEmpty ? 0 : pieces.first.$1;
}

/// Why a session ended.
@immutable
class SessionExit {
  const SessionExit({this.code, this.signal});
  final int? code;
  final int? signal;

  /// The shell exited with status 0.
  bool get clean => signal == null && (code ?? 0) == 0;
}

class TerminalSession extends ChangeNotifier {
  TerminalSession({
    required this.pty,
    this.command,
    this.cwd,
    String? shellName,
    TerminalProfile? profile,
    bool clipboardWrite = true,
    bool clipboardRead = false,
    this.onExit,
  }) : profile = profile ?? basicProfile,
       _clipboardWrite = clipboardWrite,
       _clipboardRead = clipboardRead,
       _defaultTitle = shellName ?? 'sh' {
    grid.onMeta = notifyListeners;
    grid.onClipboard = _clipboard;
  }

  final PtyBackend pty;

  /// The program to run; null: the user's login shell.
  final List<String>? command;

  /// The directory to start in; null: the home directory.
  final String? cwd;
  final String _defaultTitle;

  /// The profile the session was opened with (its scrollback, startup command…).
  TerminalProfile profile;

  /// OSC 52: whether the program may write to the clipboard, and read it.
  bool _clipboardWrite;
  bool _clipboardRead;
  bool get clipboardWrite => _clipboardWrite;
  bool get clipboardRead => _clipboardRead;

  /// Changes what the program may do with the clipboard (also in the running grid).
  void allowClipboard({required bool write, required bool read}) {
    if (write == _clipboardWrite && read == _clipboardRead) return;
    _clipboardWrite = write;
    _clipboardRead = read;
    final id = _id;
    if (id != null && !_ended) {
      pty.configure(id, clipboardWrite: write, clipboardRead: read).ignore();
    }
  }

  /// Told when the process ends, with how.
  final void Function(TerminalSession session, SessionExit exit)? onExit;

  final GridState grid = GridState();

  /// The other half of a split (view 1 of the embedder's grid), while there is one.
  GridState? get split => _split;
  GridState? _split;

  int? _id;
  StreamSubscription<PtyEvent>? _events;
  bool _starting = false;
  bool _disposed = false;

  /// The row (from the top of the buffer) where the selection began; null without one.
  int? selectionRow;

  /// The id of the pseudo-terminal, once spawned.
  int? get id => _id;

  /// The title set by the program, else the name of the shell.
  String get title {
    final set = grid.title;
    return set != null && set.isNotEmpty ? set : _defaultTitle;
  }

  /// The title with the shell's directory when the program set none: "bash — ~/src".
  String titleWithDirectory(String? home) {
    final set = grid.title;
    if (set != null && set.isNotEmpty) return set;
    final dir = grid.cwd;
    if (dir == null) return _defaultTitle;
    final shown =
        home != null &&
            home.isNotEmpty &&
            (dir == home || dir.startsWith('$home/'))
        ? '~${dir.substring(home.length)}'
        : dir;
    return '$_defaultTitle — $shown';
  }

  /// The process has ended (or never started).
  bool get ended => _ended;
  bool _ended = false;

  /// How it ended, once it did (null: never started).
  SessionExit? get exit => _exit;
  SessionExit? _exit;

  /// Why the session could not start, if it could not: [PtyUnavailable] or another error.
  Object? get error => _error;
  Object? _error;

  /// The program of the foreground has not been asked about yet; see [hasForegroundProcess].
  bool get started => _id != null || _error != null;

  /// Starts the process, or, once started, resizes it: the view calls this with the size
  /// its layout gives.
  Future<void> attach(
    int rows,
    int cols, {
    int? pixelWidth,
    int? pixelHeight,
  }) async {
    final id = _id;
    if (id != null) {
      if (rows != grid.rows || cols != grid.cols) {
        // An ended grid session lives on in the embedder: its text reflows too.
        pty
            .resize(
              id,
              rows: rows,
              cols: cols,
              pixelWidth: pixelWidth,
              pixelHeight: pixelHeight,
            )
            .ignore();
        grid.resizeTo(rows, cols);
        notifyListeners();
      }
      return;
    }
    if (_starting || _ended) return;
    _starting = true;
    _events = pty.events.listen(_event);
    grid
      ..cols = cols
      ..rows = rows
      ..lines = List.filled(rows, GridRow.empty);
    try {
      _id = await pty.spawn(
        command: command,
        cwd: cwd,
        env: const {'TERM_PROGRAM': 'Silica Terminal', 'SILICA_TERMINAL': '1'},
        rows: rows,
        cols: cols,
        scrollback: profile.scrollback,
        clipboardWrite: _clipboardWrite,
        clipboardRead: _clipboardRead,
        cursor: profile.cursor.name,
        cursorBlink: profile.cursorBlink,
        theme: _theme,
      );
    } on Object catch (error) {
      _error = error;
      _ended = true;
      _starting = false;
      grid.note(
        error is PtyUnavailable ? l10n.noPty : l10n.spawnFailed('$error'),
      );
      notifyListeners();
      return;
    }
    _starting = false;
    if (_disposed) {
      pty.close(_id!).ignore();
      return;
    }
    final startup = profile.startupCommand.trim();
    if (startup.isNotEmpty && command == null) write('$startup\r');
    notifyListeners();
  }

  void _event(PtyEvent event) {
    if (event.id != _id) return;
    switch (event) {
      case PtyGrid(:final frame):
        if (frame['view'] == 1) {
          _split?.apply(frame);
        } else {
          grid.apply(frame);
        }
      case PtyExit(:final code, :final signal):
        _ended = true;
        _exit = SessionExit(code: code, signal: signal);
        grid.note(
          signal != null
              ? l10n.processKilled(signal)
              : l10n.processExited(code ?? 0),
        );
        notifyListeners();
        onExit?.call(this, _exit!);
      case PtyOutput():
        // Sessions are spawned in grid mode: the embedder sends rows, not bytes.
        break;
    }
  }

  void _clipboard(ClipboardRequest request) {
    final id = _id;
    if (id == null || _ended) return;
    final text = request.text;
    if (text != null) {
      if (_clipboardWrite)
        Clipboard.setData(ClipboardData(text: text)).ignore();
      return;
    }
    if (!_clipboardRead) return;
    Clipboard.getData(Clipboard.kTextPlain).then((data) {
      if (!_ended && !_disposed)
        pty.clipboardReply(id, data?.text ?? '').ignore();
    }, onError: (Object _) {});
  }

  /// Sends text to the process (keys, pastes, reports).
  void write(String data) {
    final id = _id;
    if (id == null || _ended || data.isEmpty) return;
    pty.write(id, Uint8List.fromList(utf8.encode(data))).ignore();
  }

  /// Sends pasted text: bracketed when the program asked for it, line ends as CR.
  void pasteText(String text, {bool escaped = false}) {
    if (text.isEmpty) return;
    if (grid.offset > 0) scrollTo('bottom');
    write(encodePaste(escaped ? escapeForShell(text) : text, grid.modes));
  }

  /// Pastes the clipboard.
  Future<void> paste({bool escaped = false}) async {
    final ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } on Object {
      return;
    }
    pasteText(data?.text ?? '', escaped: escaped);
  }

  /// Pastes the last mouse selection (middle click).
  void pastePrimary({bool escaped = false}) =>
      pasteText(PrimarySelection.text ?? '', escaped: escaped);

  /// Copies the selection; false when there is none.
  Future<bool> copy() async {
    final text = await selectionText();
    if (text == null) return false;
    PrimarySelection.text = text;
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  }

  /// A program other than the shell runs in the foreground (closing would terminate it).
  Future<bool> hasForegroundProcess() async {
    final id = _id;
    if (id == null || _ended) return false;
    return await pty.hasForegroundProcess(id) || grid.commandRunning;
  }

  /// The shell's working directory, if it can be told.
  Future<String?> workingDirectory() async {
    final known = grid.cwd;
    if (known != null) return known;
    final id = _id;
    if (id == null || _ended) return null;
    try {
      return await pty.cwd(id);
    } on Object {
      return null;
    }
  }

  /// Sends Ctrl-C's signal to the process.
  void interrupt() {
    final id = _id;
    if (id != null && !_ended) pty.signal(id, 'INT').ignore();
  }

  // ---- the view ---------------------------------------------------------------------

  // The scrolling methods act on view 0, the screen, or on view 1, the other half of a split.
  void scrollLines(int lines, {int view = 0}) =>
      _scroll(lines: lines, view: view);
  void scrollPage(int page, {int view = 0}) => _scroll(page: page, view: view);
  void scrollTo(String to, {int view = 0}) => _scroll(to: to, view: view);
  void scrollToRow(int row, {int view = 0}) =>
      _scroll(to: 'row', row: row, view: view);

  /// Scrolls to show [offset] lines back from the bottom.
  void scrollToOffset(int offset, {int view = 0}) {
    final state = view == 1 ? _split : grid;
    if (state == null) return;
    final delta = offset - state.offset;
    if (delta != 0) _scroll(lines: delta, view: view);
  }

  void _scroll({int? lines, int? page, String? to, int? row, int view = 0}) {
    final id = _id;
    final state = view == 1 ? _split : grid;
    if (id == null || state == null || _ended && state.history == 0) return;
    pty
        .scroll(id, lines: lines, page: page, to: to, row: row, view: view)
        .ignore();
  }

  /// The profile's colours, which programs may ask for; set before the session starts and
  /// whenever they change.
  PtyTheme? get theme => _theme;
  PtyTheme? _theme;

  void setTheme(PtyTheme theme) {
    if (theme == _theme) return;
    _theme = theme;
    final id = _id;
    if (id != null && !_ended) pty.configure(id, theme: theme).ignore();
  }

  bool _splitOpened = false;

  /// Makes the state of the other half of a split, so that its view can listen to it; the
  /// embedder hears of it when the view knows its size ([openSplit]).
  GridState beginSplit() => _split ??= GridState();

  /// Opens the other half of a split with [rows] rows, or resizes it.
  void openSplit(int rows) {
    final id = _id;
    if (id == null) return;
    final state = beginSplit();
    if (_splitOpened && state.rows == rows) return;
    final fresh = !_splitOpened;
    _splitOpened = true;
    state.resizeTo(rows, grid.cols);
    pty.split(id, op: fresh ? 'open' : 'resize', rows: rows).ignore();
  }

  /// Closes the other half of the split.
  void closeSplit() {
    final id = _id;
    final opened = _splitOpened;
    _split = null;
    _splitOpened = false;
    if (id != null && opened) pty.split(id, op: 'close').ignore();
    notifyListeners();
  }

  Future<bool> select(
    String op, {
    String? kind,
    int x = 0,
    int y = 0,
    bool right = false,
    int view = 0,
  }) async {
    final id = _id;
    if (id == null) return false;
    if (op == 'all') selectionRow = 0;
    if (op == 'clear') selectionRow = null;
    return pty.select(id, op, kind: kind, x: x, y: y, right: right, view: view);
  }

  /// The selected text, with soft wraps joined; null without a selection.
  Future<String?> selectionText() async {
    final id = _id;
    if (id == null) return null;
    final text = await pty.selectionText(id);
    return text == null || text.isEmpty ? null : text;
  }

  /// The text of the whole buffer.
  Future<String> text() async {
    final id = _id;
    return id == null ? '' : pty.text(id);
  }

  /// Every match of [query] in the buffer.
  Future<List<FindMatch>> find(
    String query, {
    bool caseSensitive = false,
  }) async {
    final id = _id;
    if (id == null || query.isEmpty) return const [];
    final raw = await pty.search(id, query, caseSensitive: caseSensitive);
    return [
      for (final match in raw)
        FindMatch([for (final piece in match) (piece[0], piece[1], piece[2])]),
    ];
  }

  /// The top of the view as a row counted from the top of the buffer.
  int get topRow => grid.history - grid.offset;

  /// The same for the other half of the split.
  int get splitTopRow {
    final state = _split;
    return state == null ? 0 : state.history - state.offset;
  }

  Future<bool> mark({bool add = true}) async {
    final id = _id;
    return id == null ? false : pty.mark(id, add: add);
  }

  Future<bool> clear(String what) async {
    final id = _id;
    return id == null ? false : pty.clear(id, what);
  }

  void reset({bool hard = false}) {
    final id = _id;
    if (id != null && !_ended) pty.reset(id, hard: hard).ignore();
  }

  /// Applies a profile's scrollback size and cursor to the running grid.
  void apply(TerminalProfile next) {
    profile = next;
    final id = _id;
    if (id == null || _ended) return;
    pty
        .configure(
          id,
          scrollback: next.scrollback,
          cursor: next.cursor.name,
          cursorBlink: next.cursorBlink,
        )
        .ignore();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _events?.cancel();
    final id = _id;
    if (id != null && !_ended) pty.close(id).ignore();
    grid.dispose();
    _split?.dispose();
    super.dispose();
  }
}
