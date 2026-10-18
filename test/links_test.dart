import 'package:flutter_test/flutter_test.dart';
import 'package:terminal/src/grid.dart';
import 'package:terminal/src/links.dart';

void main() {
  GridRow row(String text) => GridRow([GridRun(text, -1, -1, 0)]);

  test('URLs in the text of a row are found under their cells', () {
    final r = row('see https://example.org/a?b=1, and (http://x.io/y).');
    final link = linkAt(r, 3, 8)!;
    expect(link.target, 'https://example.org/a?b=1');
    expect(link.span, const RowSpan(3, 4, 28));
    expect(linkAt(r, 3, 2), isNull);
    expect(linkAt(r, 3, 29), isNull, reason: 'the comma is not part of it');
    expect(linkAt(r, 3, 40)!.target, 'http://x.io/y');
    expect(linkAt(r, 3, 79), isNull);
  });

  test('brackets belong to the URL when they are balanced', () {
    expect(
      linkAt(row('https://en.wikipedia.org/wiki/Foo_(bar)'), 0, 3)!.target,
      'https://en.wikipedia.org/wiki/Foo_(bar)',
    );
    expect(
      linkAt(row('(https://example.org)'), 0, 5)!.target,
      'https://example.org',
    );
  });

  test('wide characters before a URL do not shift its cells', () {
    final r = GridRow(const [
      GridRun('日本', -1, -1, 256, 4),
      GridRun(' https://a.io', -1, -1, 0, 13),
    ]);
    final link = linkAt(r, 0, 6)!;
    expect(link.target, 'https://a.io');
    expect(link.span.x0, 5);
    expect(link.span.x1, 16);
  });

  test('an OSC 8 link covers the neighbouring runs with the same target', () {
    final r = GridRow(const [
      GridRun('go ', -1, -1, 0, 3),
      GridRun('here', -1, -1, 0, 4, 'https://t.example'),
      GridRun('!', -1, -1, 1, 1, 'https://t.example'),
      GridRun(' not', -1, -1, 0, 4),
    ]);
    final link = linkAt(r, 2, 4)!;
    expect(link.target, 'https://t.example');
    expect(link.span, const RowSpan(2, 3, 7));
    expect(linkAt(r, 2, 1), isNull);
  });

  test('paths are quoted for the shell', () {
    expect(shellQuote('/home/me/a.txt'), '/home/me/a.txt');
    expect(shellQuote('my file'), "'my file'");
    expect(shellQuote("it's"), "'it'\\''s'");
    expect(shellQuote(''), "''");
    expect(shellQuote(r'$HOME;rm'), r"'$HOME;rm'");
  });

  test('dropped files become quoted paths', () {
    expect(
      quotedPaths([
        'file:///home/me/My%20Docs/a.txt',
        'file:///tmp/b',
        'https://example.org/x y',
        'file:///t/%27q%27',
        '',
      ]),
      "'/home/me/My Docs/a.txt' /tmp/b 'https://example.org/x y' '/t/'\\''q'\\'''",
    );
    expect(quotedPaths(const []), isEmpty);
  });

  test('pasted text can be escaped for the shell', () {
    expect(escapeForShell('a b'), r'a\ b');
    expect(escapeForShell(r'$(x);'), r'\$\(x\)\;');
    expect(escapeForShell('plain/path-1.txt'), 'plain/path-1.txt');
    expect(escapeForShell('è'), 'è');
    expect(escapeForShell('a\nb'), 'a\nb');
  });
}
