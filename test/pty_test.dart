import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal/src/pty.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('events from the embedder: output, exit, malformed ones ignored', () {
    final out = SilicaPty.parseEvent('output', {
      'id': 3,
      'data': base64Encode(utf8.encode('hi')),
    });
    expect(out, isA<PtyOutput>());
    expect(utf8.decode((out! as PtyOutput).data), 'hi');
    expect(out.id, 3);
    final exit = SilicaPty.parseEvent('exit', {'id': 3, 'code': 2});
    expect((exit! as PtyExit).code, 2);
    expect((exit as PtyExit).signal, isNull);
    final killed = SilicaPty.parseEvent('exit', {'id': 3, 'signal': 9});
    expect((killed! as PtyExit).signal, 9);
    expect(SilicaPty.parseEvent('output', {'id': 3, 'data': '%%%'}), isNull);
    expect(SilicaPty.parseEvent('output', {'data': 'aGk='}), isNull);
    expect(SilicaPty.parseEvent('exit', 'nope'), isNull);
    expect(SilicaPty.parseEvent('other', {'id': 1}), isNull);
  });

  test('requests on silica/pty follow the protocol', () async {
    const channel = MethodChannel('silica/pty', JSONMethodCodec());
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'spawn' ? {'id': 7} : null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final pty = SilicaPty(channel: channel);
    final id = await pty.spawn(rows: 24, cols: 80, cwd: '/tmp');
    expect(id, 7);
    await pty.write(7, Uint8List.fromList(utf8.encode('ls\r')));
    await pty.resize(7, rows: 30, cols: 100, pixelWidth: 800);
    await pty.signal(7, 'INT');
    await pty.close(7);
    expect(calls.map((c) => c.method), [
      'spawn',
      'write',
      'resize',
      'signal',
      'close',
    ]);
    expect(calls[0].arguments, {
      'cwd': '/tmp',
      'rows': 24,
      'cols': 80,
      'grid': true,
    });
    expect(calls[1].arguments, {
      'id': 7,
      'data': base64Encode(utf8.encode('ls\r')),
    });
    expect(calls[2].arguments, {
      'id': 7,
      'rows': 30,
      'cols': 100,
      'pixelWidth': 800,
    });
    expect(calls[3].arguments, {'id': 7, 'signal': 'INT'});
  });

  test('grid calls follow the protocol', () async {
    const channel = MethodChannel('silica/pty', JSONMethodCodec());
    final calls = <MethodCall>[];
    final replies = <String, Object?>{
      'spawn': {'id': 4},
      'select': true,
      'selectionText': 'text',
      'text': 'all',
      'search': [
        [
          [1, 2, 3],
        ],
        [
          [4, 0, 1],
          [5, 0, 0],
        ],
        'junk',
        [
          [1, 2],
        ],
      ],
      'mark': true,
      'clear': true,
      'cwd': '/tmp/x',
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return replies[call.method];
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final pty = SilicaPty(channel: channel);
    final id = await pty.spawn(
      rows: 5,
      cols: 6,
      scrollback: 50,
      clipboardRead: true,
      cursor: 'beam',
      cursorBlink: true,
    );
    expect(calls.first.arguments, {
      'rows': 5,
      'cols': 6,
      'grid': true,
      'scrollback': 50,
      'clipboardRead': true,
      'cursor': 'beam',
      'cursorBlink': true,
    });
    await pty.scroll(id, lines: 3);
    await pty.scroll(id, to: 'row', row: 9);
    expect(
      await pty.select(id, 'start', kind: 'block', x: 1, y: 2, right: true),
      isTrue,
    );
    expect(await pty.selectionText(id), 'text');
    expect(await pty.text(id), 'all');
    expect(await pty.search(id, 'x', caseSensitive: true), [
      [
        [1, 2, 3],
      ],
      [
        [4, 0, 1],
        [5, 0, 0],
      ],
      <List<int>>[],
    ]);
    expect(await pty.mark(id, add: false), isTrue);
    expect(await pty.clear(id, 'toStart'), isTrue);
    await pty.reset(id, hard: true);
    await pty.configure(id, scrollback: 9, clipboardWrite: false);
    await pty.clipboardReply(id, 'pasted');
    expect(await pty.cwd(id), '/tmp/x');
    expect(calls.skip(1).map((c) => c.method), [
      'scroll',
      'scroll',
      'select',
      'selectionText',
      'text',
      'search',
      'mark',
      'clear',
      'reset',
      'configure',
      'clipboard',
      'cwd',
    ]);
    expect(calls[1].arguments, {'id': 4, 'lines': 3});
    expect(calls[2].arguments, {'id': 4, 'to': 'row', 'row': 9});
    expect(calls[3].arguments, {
      'id': 4,
      'op': 'start',
      'kind': 'block',
      'x': 1,
      'y': 2,
      'right': true,
    });
    expect(calls[6].arguments, {'id': 4, 'query': 'x', 'caseSensitive': true});
    expect(calls[7].arguments, {'id': 4, 'op': 'remove'});
    expect(calls[9].arguments, {'id': 4, 'hard': true});
    expect(calls[10].arguments, {
      'id': 4,
      'scrollback': 9,
      'clipboardWrite': false,
    });
    expect(calls[11].arguments, {'id': 4, 'text': 'pasted'});
  });

  test('the frame of the embedder reaches the app as a PtyGrid', () {
    final event = SilicaPty.parseEvent('grid', {'id': 2, 'cols': 3, 'rows': 1});
    expect(event, isA<PtyGrid>());
    expect((event! as PtyGrid).frame['cols'], 3);
  });

  test('outside Silica the channel is missing: PtyUnavailable', () async {
    final pty = SilicaPty(
      channel: const MethodChannel('silica/pty-missing', JSONMethodCodec()),
    );
    expect(() => pty.spawn(rows: 24, cols: 80), throwsA(isA<PtyUnavailable>()));
  });
}
