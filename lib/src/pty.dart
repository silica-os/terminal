// The pseudo-terminal of the Silica embedder: channel `silica/pty` (JSONMethodCodec). The app
// has no native code; the embedder spawns the shell on a PTY and streams its output.
//
// app → embedder: `spawn {command?, cwd?, env?, rows, cols, grid?, scrollback?, clipboardWrite?,
// clipboardRead?}` → `{id}`; `write {id, data}` (base64); `resize {id, rows, cols, pixelWidth?,
// pixelHeight?}`; `signal {id, signal}` ("INT", "TERM", "HUP", "KILL"); `close {id}`; `busy`,
// `cwd`, and on grid sessions `scroll`, `select`, `selectionText`, `text`, `search`, `mark`,
// `clear`, `reset`, `configure`, `clipboard` (docs/protocols.md of silica-desktop).
// embedder → app: `exit {id, code?, signal?}`, and `grid {id, cols, rows, full, lines, cursor,
// modes, …}`: the embedder emulates the terminal and sends the rows that changed. Sessions
// spawned without `grid: true` get `output {id, data}` (base64) instead.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Something that happened to a pseudo-terminal.
@immutable
sealed class PtyEvent {
  const PtyEvent(this.id);
  final int id;
}

/// Bytes written by the process.
class PtyOutput extends PtyEvent {
  const PtyOutput(super.id, this.data);
  final Uint8List data;
}

/// The rows of an emulated terminal that changed (`spawn(grid: true)`), as sent by the
/// embedder: the raw message map, decoded by `GridState.apply`.
class PtyGrid extends PtyEvent {
  const PtyGrid(super.id, this.frame);
  final Map<Object?, Object?> frame;
}

/// The process ended: with an exit `code`, or killed by `signal`.
class PtyExit extends PtyEvent {
  const PtyExit(super.id, {this.code, this.signal});
  final int? code;
  final int? signal;
}

/// The pseudo-terminal service is missing (the app runs outside Silica).
class PtyUnavailable implements Exception {
  const PtyUnavailable();
  @override
  String toString() => 'the silica/pty channel is not available';
}

/// The pseudo-terminals of the app: real ones on the embedder, fake ones in tests.
abstract class PtyBackend {
  /// Starts `command` (null: the user's login shell) on a new pseudo-terminal of `rows` ×
  /// `cols` cells and returns its id. Throws [PtyUnavailable] outside Silica.
  Future<int> spawn({
    List<String>? command,
    String? cwd,
    Map<String, String>? env,
    required int rows,
    required int cols,
    bool grid = true,
    int? scrollback,
    bool? clipboardWrite,
    bool? clipboardRead,
    String? cursor,
    bool? cursorBlink,
  });

  Future<void> write(int id, Uint8List data);

  /// Moves the view of a grid session: `lines` towards older text (negative: newer), `page`
  /// (±1), or `to`: `top`, `bottom`, `previousPrompt`, `nextPrompt`, `row` (with [row], counted
  /// from the top of the buffer; centred if out of view).
  Future<void> scroll(
    int id, {
    int? lines,
    int? page,
    String? to,
    int? row,
    int view = 0,
  });

  /// Opens the second view of a split with [rows] rows (or resizes it), or closes it
  /// (`close`, no rows). Its frames come as [PtyGrid] with `view: 1`.
  Future<void> split(int id, {required String op, int? rows});

  /// A selection operation: [op] `start` (with [kind] `simple`, `semantic`, `lines` or `block`),
  /// `update`, `clear`, `all` or `marks`; [x], [y] are visible cells, [right] the right half
  /// of the cell. False when `marks` found nothing to select.
  Future<bool> select(
    int id,
    String op, {
    String? kind,
    int x = 0,
    int y = 0,
    bool right = false,
    int view = 0,
  });

  /// The selected text, soft wraps joined; null without a selection.
  Future<String?> selectionText(int id);

  /// The text of the whole buffer, scrollback included.
  Future<String> text(int id);

  /// Every match of [query] in the buffer: each a list of `[row, x0, x1]` pieces (rows from
  /// the top of the buffer).
  Future<List<List<List<int>>>> search(
    int id,
    String query, {
    bool caseSensitive = false,
  });

  /// Marks the cursor row (`add`), or removes the nearest mark above it.
  Future<bool> mark(int id, {bool add = true});

  /// `scrollback`, `toStart`, `toMark` or `screen`; false if there was nothing to clear.
  Future<bool> clear(int id, String what);

  /// Resets the emulator (a soft reset, or a hard one that also clears the scrollback).
  Future<void> reset(int id, {bool hard = false});

  /// Changes the scrollback size or what OSC 52 may do.
  Future<void> configure(
    int id, {
    int? scrollback,
    bool? clipboardWrite,
    bool? clipboardRead,
    String? cursor,
    bool? cursorBlink,
  });

  /// Answers a clipboard read of the program (OSC 52).
  Future<void> clipboardReply(int id, String text);

  /// The shell's working directory (OSC 7, else the process's); null if unknown.
  Future<String?> cwd(int id);

  Future<void> resize(
    int id, {
    required int rows,
    required int cols,
    int? pixelWidth,
    int? pixelHeight,
  });

  /// One of "INT", "TERM", "HUP", "KILL".
  Future<void> signal(int id, String signal);

  Future<void> close(int id);

  /// A process other than the shell runs in the foreground of the pseudo-terminal `id`.
  Future<bool> hasForegroundProcess(int id);

  /// Output and exits of every pseudo-terminal.
  Stream<PtyEvent> get events;
}

/// The embedder's `silica/pty` channel.
class SilicaPty implements PtyBackend {
  SilicaPty({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('silica/pty', JSONMethodCodec()) {
    _channel.setMethodCallHandler(_handle);
  }

  final MethodChannel _channel;
  final StreamController<PtyEvent> _events = StreamController.broadcast();

  @override
  Stream<PtyEvent> get events => _events.stream;

  Future<Object?> _handle(MethodCall call) async {
    final event = parseEvent(call.method, call.arguments);
    if (event != null) _events.add(event);
    return null;
  }

  /// An event from a call of the embedder; null if it is not one (or is malformed).
  static PtyEvent? parseEvent(String method, Object? args) {
    if (args is! Map) return null;
    final id = args['id'];
    if (id is! int) return null;
    switch (method) {
      case 'output':
        final data = args['data'];
        if (data is! String) return null;
        try {
          return PtyOutput(id, base64Decode(data));
        } on FormatException {
          return null;
        }
      case 'grid':
        return PtyGrid(id, args);
      case 'exit':
        final code = args['code'];
        final signal = args['signal'];
        return PtyExit(
          id,
          code: code is int ? code : null,
          signal: signal is int ? signal : null,
        );
    }
    return null;
  }

  Future<Object?> _invoke(String method, Map<String, Object?> args) async {
    try {
      return await _channel.invokeMethod<Object?>(method, args);
    } on MissingPluginException {
      throw const PtyUnavailable();
    }
  }

  @override
  Future<int> spawn({
    List<String>? command,
    String? cwd,
    Map<String, String>? env,
    required int rows,
    required int cols,
    bool grid = true,
    int? scrollback,
    bool? clipboardWrite,
    bool? clipboardRead,
    String? cursor,
    bool? cursorBlink,
  }) async {
    final reply = await _invoke('spawn', {
      'command': ?command,
      'cwd': ?cwd,
      'env': ?env,
      'rows': rows,
      'cols': cols,
      if (grid) 'grid': true,
      'scrollback': ?scrollback,
      'clipboardWrite': ?clipboardWrite,
      'clipboardRead': ?clipboardRead,
      'cursor': ?cursor,
      'cursorBlink': ?cursorBlink,
    });
    final id = reply is Map ? reply['id'] : null;
    if (id is! int) {
      throw PlatformException(code: 'spawn', message: 'no id in $reply');
    }
    return id;
  }

  @override
  Future<void> write(int id, Uint8List data) =>
      _invoke('write', {'id': id, 'data': base64Encode(data)});

  @override
  Future<void> resize(
    int id, {
    required int rows,
    required int cols,
    int? pixelWidth,
    int? pixelHeight,
  }) => _invoke('resize', {
    'id': id,
    'rows': rows,
    'cols': cols,
    'pixelWidth': ?pixelWidth,
    'pixelHeight': ?pixelHeight,
  });

  @override
  Future<void> scroll(
    int id, {
    int? lines,
    int? page,
    String? to,
    int? row,
    int view = 0,
  }) => _invoke('scroll', {
    'id': id,
    'lines': ?lines,
    'page': ?page,
    'to': ?to,
    'row': ?row,
    if (view != 0) 'view': view,
  });

  @override
  Future<void> split(int id, {required String op, int? rows}) =>
      _invoke('split', {'id': id, 'op': op, 'rows': ?rows});

  @override
  Future<bool> select(
    int id,
    String op, {
    String? kind,
    int x = 0,
    int y = 0,
    bool right = false,
    int view = 0,
  }) async =>
      await _invoke('select', {
        'id': id,
        'op': op,
        'kind': ?kind,
        'x': x,
        'y': y,
        if (right) 'right': true,
        if (view != 0) 'view': view,
      }) !=
      false;

  @override
  Future<String?> selectionText(int id) async {
    final reply = await _invoke('selectionText', {'id': id});
    return reply is String ? reply : null;
  }

  @override
  Future<String> text(int id) async {
    final reply = await _invoke('text', {'id': id});
    return reply is String ? reply : '';
  }

  @override
  Future<List<List<List<int>>>> search(
    int id,
    String query, {
    bool caseSensitive = false,
  }) async {
    final reply = await _invoke('search', {
      'id': id,
      'query': query,
      if (caseSensitive) 'caseSensitive': true,
    });
    return parseMatches(reply);
  }

  /// The matches of a `search` reply; malformed entries are skipped.
  static List<List<List<int>>> parseMatches(Object? reply) {
    if (reply is! List) return const [];
    return [
      for (final match in reply)
        if (match is List)
          [
            for (final piece in match)
              if (piece is List &&
                  piece.length == 3 &&
                  piece.every((v) => v is int))
                [for (final v in piece) v as int],
          ],
    ];
  }

  @override
  Future<bool> mark(int id, {bool add = true}) async =>
      await _invoke('mark', {'id': id, 'op': add ? 'add' : 'remove'}) == true;

  @override
  Future<bool> clear(int id, String what) async =>
      await _invoke('clear', {'id': id, 'what': what}) == true;

  @override
  Future<void> reset(int id, {bool hard = false}) =>
      _invoke('reset', {'id': id, if (hard) 'hard': true});

  @override
  Future<void> configure(
    int id, {
    int? scrollback,
    bool? clipboardWrite,
    bool? clipboardRead,
    String? cursor,
    bool? cursorBlink,
  }) => _invoke('configure', {
    'id': id,
    'scrollback': ?scrollback,
    'clipboardWrite': ?clipboardWrite,
    'clipboardRead': ?clipboardRead,
    'cursor': ?cursor,
    'cursorBlink': ?cursorBlink,
  });

  @override
  Future<void> clipboardReply(int id, String text) =>
      _invoke('clipboard', {'id': id, 'text': text});

  @override
  Future<String?> cwd(int id) async {
    try {
      final reply = await _invoke('cwd', {'id': id});
      return reply is String && reply.isNotEmpty ? reply : null;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> signal(int id, String signal) =>
      _invoke('signal', {'id': id, 'signal': signal});

  @override
  Future<void> close(int id) => _invoke('close', {'id': id});

  // `busy` (silica/pty): true while a foreground process other than the shell runs; an older
  // embedder answers with an error, and the tab then counts as idle.
  @override
  Future<bool> hasForegroundProcess(int id) async {
    try {
      return await _invoke('busy', {'id': id}) == true;
    } on Object {
      return false;
    }
  }
}

/// The arguments of a spawn, as the [FakePty] saw them.
class FakeSpawn {
  const FakeSpawn({
    this.command,
    this.cwd,
    this.env,
    this.scrollback,
    this.clipboardWrite,
    this.clipboardRead,
    this.cursor,
    this.cursorBlink,
  });
  final String? cursor;
  final bool? cursorBlink;
  final List<String>? command;
  final String? cwd;
  final Map<String, String>? env;
  final int? scrollback;
  final bool? clipboardWrite;
  final bool? clipboardRead;
}

/// A pseudo-terminal backend in memory, for tests: records what the app does and lets the
/// test play the process.
class FakePty implements PtyBackend {
  final StreamController<PtyEvent> _events = StreamController.broadcast(
    sync: true,
  );
  int _next = 1;

  /// Every spawn, write, resize, signal and close, as `(method, id, details)`.
  final List<(String, int, Object?)> calls = [];

  /// Bytes the app wrote to each pseudo-terminal.
  final Map<int, List<int>> written = {};

  /// The last size of each pseudo-terminal, `(rows, cols)`.
  final Map<int, (int, int)> sizes = {};

  /// Throw this from [spawn] (e.g. [PtyUnavailable]).
  Object? spawnError;

  @override
  Stream<PtyEvent> get events => _events.stream;

  @override
  Future<int> spawn({
    List<String>? command,
    String? cwd,
    Map<String, String>? env,
    required int rows,
    required int cols,
    bool grid = true,
    int? scrollback,
    bool? clipboardWrite,
    bool? clipboardRead,
    String? cursor,
    bool? cursorBlink,
  }) async {
    final error = spawnError;
    if (error != null) throw error;
    final id = _next++;
    calls.add(('spawn', id, command));
    spawns.add(
      FakeSpawn(
        command: command,
        cwd: cwd,
        env: env,
        scrollback: scrollback,
        clipboardWrite: clipboardWrite,
        clipboardRead: clipboardRead,
        cursor: cursor,
        cursorBlink: cursorBlink,
      ),
    );
    sizes[id] = (rows, cols);
    written[id] = [];
    return id;
  }

  /// The arguments of every spawn, in order.
  final List<FakeSpawn> spawns = [];

  /// What the next `selectionText` answers, `text`, `cwd` and `search` of each id.
  final Map<int, String?> selections = {};
  final Map<int, String> texts = {};
  final Map<int, String?> cwds = {};
  final Map<int, List<List<List<int>>>> matches = {};

  @override
  Future<void> scroll(
    int id, {
    int? lines,
    int? page,
    String? to,
    int? row,
    int view = 0,
  }) async => calls.add((
    'scroll',
    id,
    {'lines': lines, 'page': page, 'to': to, 'row': row, 'view': view},
  ));

  @override
  Future<void> split(int id, {required String op, int? rows}) async =>
      calls.add(('split', id, {'op': op, 'rows': rows}));

  @override
  Future<bool> select(
    int id,
    String op, {
    String? kind,
    int x = 0,
    int y = 0,
    bool right = false,
    int view = 0,
  }) async {
    calls.add((
      'select',
      id,
      {'op': op, 'kind': kind, 'x': x, 'y': y, 'right': right, 'view': view},
    ));
    return true;
  }

  @override
  Future<String?> selectionText(int id) async => selections[id];

  @override
  Future<String> text(int id) async => texts[id] ?? '';

  /// The lines each id last [show]ed, which [search] looks through.
  final Map<int, List<String>> screens = {};

  @override
  Future<List<List<List<int>>>> search(
    int id,
    String query, {
    bool caseSensitive = false,
  }) async {
    calls.add(('search', id, query));
    final scripted = matches[id];
    if (scripted != null) return scripted;
    final found = <List<List<int>>>[];
    if (query.isEmpty) return found;
    final needle = caseSensitive ? query : query.toLowerCase();
    final lines = screens[id] ?? const <String>[];
    for (var y = 0; y < lines.length; y++) {
      final line = caseSensitive ? lines[y] : lines[y].toLowerCase();
      for (
        var at = line.indexOf(needle);
        at >= 0;
        at = line.indexOf(needle, at + needle.length)
      ) {
        found.add([
          [y, at, at + needle.length - 1],
        ]);
      }
    }
    return found;
  }

  @override
  Future<bool> mark(int id, {bool add = true}) async {
    calls.add(('mark', id, add));
    return true;
  }

  @override
  Future<bool> clear(int id, String what) async {
    calls.add(('clear', id, what));
    return true;
  }

  @override
  Future<void> reset(int id, {bool hard = false}) async =>
      calls.add(('reset', id, hard));

  @override
  Future<void> configure(
    int id, {
    int? scrollback,
    bool? clipboardWrite,
    bool? clipboardRead,
    String? cursor,
    bool? cursorBlink,
  }) async => calls.add((
    'configure',
    id,
    {
      'scrollback': scrollback,
      'clipboardWrite': clipboardWrite,
      'clipboardRead': clipboardRead,
      'cursor': cursor,
      'cursorBlink': cursorBlink,
    },
  ));

  @override
  Future<void> clipboardReply(int id, String text) async =>
      calls.add(('clipboard', id, text));

  @override
  Future<String?> cwd(int id) async => cwds[id];

  @override
  Future<void> write(int id, Uint8List data) async {
    calls.add(('write', id, data));
    written.putIfAbsent(id, () => []).addAll(data);
  }

  @override
  Future<void> resize(
    int id, {
    required int rows,
    required int cols,
    int? pixelWidth,
    int? pixelHeight,
  }) async {
    calls.add(('resize', id, (rows, cols)));
    sizes[id] = (rows, cols);
  }

  @override
  Future<void> signal(int id, String signal) async =>
      calls.add(('signal', id, signal));

  @override
  Future<void> close(int id) async => calls.add(('close', id, null));

  /// Ids whose shell has a foreground program (vim, a build, ...).
  final Set<int> busy = {};

  @override
  Future<bool> hasForegroundProcess(int id) async => busy.contains(id);

  /// The embedder sends a grid frame for `id`.
  void grid(int id, Map<String, Object?> frame) =>
      _events.add(PtyGrid(id, {'id': id, ...frame}));

  /// The process of `id` shows `lines` on the screen (a full frame; plain text, default
  /// colours), with the cursor after the last line's text unless [cursor] says otherwise.
  void show(
    int id,
    List<String> lines, {
    (int, int)? cursor,
    int modes = 0,
    Map<String, Object?> extra = const {},
  }) {
    final (rows, cols) = sizes[id] ?? (24, 80);
    final shown = lines.take(rows).toList();
    screens[id] = shown;
    final at =
        cursor ?? (shown.isEmpty ? 0 : shown.last.length, shown.length - 1);
    grid(id, {
      'cols': cols,
      'rows': rows,
      'full': true,
      'lines': [
        for (var y = 0; y < shown.length; y++)
          {
            'y': y,
            'runs': shown[y].isEmpty
                ? []
                : [
                    [shown[y], -1, -1, 0, shown[y].runes.length],
                  ],
          },
      ],
      'cursor': {
        'x': at.$1,
        'y': at.$2 < 0 ? 0 : at.$2,
        'visible': true,
        'shape': 'block',
      },
      'modes': modes,
      ...extra,
    });
  }

  /// The process of `id` exits.
  void exit(int id, {int? code, int? signal}) =>
      _events.add(PtyExit(id, code: code, signal: signal));
}
