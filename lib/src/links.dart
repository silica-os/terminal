// Links in the grid: the targets an OSC 8 program set, and URLs recognised in the text of
// a row. Command+click opens them.

import 'grid.dart';

/// What lies under a cell that Command+click can open.
class GridLink {
  const GridLink(this.target, this.span);

  /// The URL (or path) to open.
  final String target;

  /// The cells it covers on its row.
  final RowSpan span;
}

final RegExp _url = RegExp(
  r'''\b(?:https?|ftp|file|ssh|mailto):(?://)?[^\s<>"'`\x00-\x1f]+''',
  caseSensitive: false,
);

/// Characters a sentence puts after a URL that are not part of it.
const String _trailing = '.,;:!?\'")]}>';

/// The link under cell [x] of [row] (row number [y]): the OSC 8 link of the run, else a URL
/// found in the row's text. Null when there is none.
GridLink? linkAt(GridRow row, int y, int x) {
  final run = row.runAt(x);
  if (run == null) return null;
  final (found, start) = run;
  if (found.link != null) {
    // The whole stretch of neighbouring runs with the same target.
    var x0 = start;
    var x1 = start + found.cells - 1;
    var before = 0;
    final runs = row.runs;
    final index = runs.indexOf(found);
    for (var i = index - 1; i >= 0 && runs[i].link == found.link; i--) {
      before += runs[i].cells;
    }
    x0 -= before;
    for (
      var i = index + 1;
      i < runs.length && runs[i].link == found.link;
      i++
    ) {
      x1 += runs[i].cells;
    }
    return GridLink(found.link!, RowSpan(y, x0, x1));
  }
  final (text, columns) = row.textAndCells;
  for (final match in _url.allMatches(text)) {
    var end = match.end;
    while (end > match.start + 1 && _trailing.contains(text[end - 1])) {
      // A closing bracket belongs to the URL when it has its opening one.
      final c = text[end - 1];
      final open = const {')': '(', ']': '[', '}': '{'}[c];
      if (open != null &&
          text.substring(match.start, end).split(open).length >=
              text.substring(match.start, end).split(c).length) {
        break;
      }
      end--;
    }
    if (end > columns.length || match.start >= columns.length) continue;
    final x0 = columns[match.start];
    final x1 = columns[end - 1];
    if (x >= x0 && x <= x1) {
      return GridLink(text.substring(match.start, end), RowSpan(y, x0, x1));
    }
  }
  return null;
}

/// A path or text quoted for a POSIX shell: single quotes unless it is plain.
String shellQuote(String text) {
  if (text.isEmpty) return "''";
  if (RegExp(r'^[A-Za-z0-9_@%+=:,./~-]+$').hasMatch(text)) return text;
  return "'${text.replaceAll("'", "'\\''")}'";
}

/// The paths of `file://` URIs (percent-decoded), quoted and joined by spaces; other URIs are
/// quoted as they are. Empty when nothing usable came.
String quotedPaths(Iterable<String> uris) {
  final items = <String>[];
  for (final uri in uris) {
    final parsed = Uri.tryParse(uri);
    if (parsed != null && parsed.scheme == 'file') {
      String path;
      try {
        path = parsed.toFilePath();
      } on UnsupportedError {
        // A query or fragment in a file URI: take the path part.
        path = Uri.decodeComponent(parsed.path);
      }
      if (path.isNotEmpty) items.add(shellQuote(path));
    } else if (uri.isNotEmpty) {
      items.add(shellQuote(uri));
    }
  }
  return items.join(' ');
}

/// Text pasted as "escaped": every character the shell would read specially gets a backslash.
String escapeForShell(String text) =>
    text.replaceAllMapped(RegExp(r'''[^A-Za-z0-9_@%+=:,./~\n-]'''), (m) {
      final c = m[0] ?? '';
      return c.codeUnitAt(0) < 0x80 ? '\\$c' : c;
    });
