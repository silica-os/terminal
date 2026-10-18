import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal/src/l10n.dart';
import 'package:terminal/src/pty.dart';
import 'package:terminal/src/session.dart';
import 'package:terminal/src/settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    useLocale(const Locale('en'));
    PrimarySelection.text = null;
  });

  Future<(FakePty, TerminalSession)> started({
    TerminalProfile? profile,
    List<String>? command,
    String? cwd,
    bool write = true,
    bool read = false,
    void Function(TerminalSession, SessionExit)? onExit,
  }) async {
    final pty = FakePty();
    final s = TerminalSession(
      pty: pty,
      shellName: 'bash',
      profile: profile,
      command: command,
      cwd: cwd,
      clipboardWrite: write,
      clipboardRead: read,
      onExit: onExit,
    );
    await s.attach(24, 80);
    return (pty, s);
  }

  test(
    'spawns with the layout size, the profile and the clipboard rules',
    () async {
      final (pty, s) = await started(
        profile: basicProfile.copyWith(
          scrollbackLines: 500,
          cursor: CursorStyleChoice.beam,
          cursorBlink: true,
        ),
        cwd: '/home/me',
        read: true,
      );
      expect(s.id, 1);
      expect(pty.sizes[1], (24, 80));
      final spawn = pty.spawns.single;
      expect(spawn.scrollback, 500);
      expect((spawn.clipboardWrite, spawn.clipboardRead), (true, true));
      expect((spawn.cursor, spawn.cursorBlink), ('beam', true));
      expect(spawn.cwd, '/home/me');
      expect(spawn.env, containsPair('TERM_PROGRAM', 'Silica Terminal'));
      expect(s.title, 'bash');
      // A second attach with the same size spawns nothing.
      await s.attach(24, 80);
      expect(pty.spawns, hasLength(1));
    },
  );

  test(
    'frames fill the grid; the title and the directory follow the program',
    () async {
      final (pty, s) = await started();
      pty.show(1, ['hello', 'world']);
      expect(s.grid.text.startsWith('hello\nworld'), isTrue);
      expect(s.title, 'bash');
      expect(s.titleWithDirectory('/home/me'), 'bash');
      pty.grid(1, {'cwd': '/home/me/src', 'lines': <Object>[]});
      expect(s.titleWithDirectory('/home/me'), 'bash — ~/src');
      expect(s.titleWithDirectory('/elsewhere'), 'bash — /home/me/src');
      expect(s.titleWithDirectory(null), 'bash — /home/me/src');
      pty.grid(1, {'title': '~/src — vim'});
      expect(s.title, '~/src — vim');
      expect(s.titleWithDirectory('/home/me'), '~/src — vim');
      // The program resets its title: the shell's name again.
      pty.grid(1, {'title': ''});
      expect(s.title, 'bash');
      // Frames of other sessions are not ours.
      pty.grid(7, {'title': 'x'});
      expect(s.title, 'bash');
    },
  );

  test(
    'keys go to the process as UTF-8; a resize reaches the pty and the grid',
    () async {
      final (pty, s) = await started();
      s.write('ls -l\r');
      s.write('è');
      s.write('');
      expect(utf8.decode(pty.written[1]!), 'ls -l\rè');
      await s.attach(30, 100, pixelWidth: 720, pixelHeight: 480);
      expect(pty.sizes[1], (30, 100));
      expect((s.grid.rows, s.grid.cols), (30, 100));
    },
  );

  test(
    'exit: a closing line, then no more input, and the text stays reachable',
    () async {
      SessionExit? seen;
      final (pty, s) = await started(onExit: (_, e) => seen = e);
      pty.show(
        1,
        ['output'],
        extra: {
          'scroll': {'offset': 0, 'history': 10},
        },
      );
      pty.exit(1, code: 3);
      expect(s.ended, isTrue);
      expect(seen!.code, 3);
      expect(seen!.clean, isFalse);
      expect(s.grid.text, contains(l10n.processExited(3)));
      expect(s.grid.text, startsWith('output'));
      s.write('x');
      expect(pty.written[1], isEmpty);
      // The embedder keeps the grid of an ended session: scrolling and copying still work.
      s.scrollLines(5);
      expect(pty.calls.where((c) => c.$1 == 'scroll'), hasLength(1));
      pty.selections[1] = 'output';
      expect(await s.selectionText(), 'output');
      s.dispose();
      expect(pty.calls.where((c) => c.$1 == 'close'), isEmpty);
    },
  );

  test('killed by a signal, and a clean exit', () async {
    final exits = <SessionExit>[];
    final (pty, s) = await started(onExit: (_, e) => exits.add(e));
    pty.exit(1, signal: 9);
    expect(s.grid.text, contains(l10n.processKilled(9)));
    expect(exits.single.clean, isFalse);
    final (pty2, s2) = await started(onExit: (_, e) => exits.add(e));
    pty2.exit(1, code: 0);
    expect(exits.last.clean, isTrue);
    expect(s2.exit!.code, 0);
  });

  test('outside Silica: a clear message instead of a shell', () async {
    final pty = FakePty()..spawnError = const PtyUnavailable();
    final s = TerminalSession(pty: pty);
    await s.attach(24, 80);
    expect(s.ended, isTrue);
    expect(s.error, isA<PtyUnavailable>());
    expect(s.grid.text.replaceAll('\n', ''), contains('Silica desktop'));
    s.write('x');
    expect(await s.hasForegroundProcess(), isFalse);
    expect(await s.workingDirectory(), isNull);
  });

  test('a spawn that fails says why', () async {
    final pty = FakePty()..spawnError = StateError('no shell');
    final s = TerminalSession(pty: pty);
    await s.attach(24, 80);
    expect(s.grid.text, contains('no shell'));
  });

  test('closing a running session closes its pseudo-terminal', () async {
    final (pty, s) = await started();
    s.interrupt();
    s.dispose();
    expect(pty.calls.map((c) => c.$1), ['spawn', 'signal', 'close']);
  });

  test('a session closed while it starts does not leak its pty', () async {
    final pty = FakePty();
    final s = TerminalSession(pty: pty);
    final starting = s.attach(24, 80);
    s.dispose();
    await starting;
    expect(pty.calls.map((c) => c.$1), ['spawn', 'close']);
  });

  test('foreground processes: the pty says, so does OSC 133', () async {
    final (pty, s) = await started();
    expect(await s.hasForegroundProcess(), isFalse);
    pty.busy.add(1);
    expect(await s.hasForegroundProcess(), isTrue);
    pty.busy.clear();
    pty.grid(1, {
      'command': {'running': true},
    });
    expect(await s.hasForegroundProcess(), isTrue);
    pty.grid(1, {
      'command': {'running': false, 'exit': 0},
    });
    expect(await s.hasForegroundProcess(), isFalse);
  });

  test('the working directory comes from OSC 7, else from the pty', () async {
    final (pty, s) = await started();
    pty.cwds[1] = '/proc/cwd';
    expect(await s.workingDirectory(), '/proc/cwd');
    pty.grid(1, {'cwd': '/osc7'});
    expect(await s.workingDirectory(), '/osc7');
  });

  test(
    'a startup command is typed into the shell, not into a program',
    () async {
      final (pty, _) = await started(
        profile: basicProfile.copyWith(startupCommand: 'cd /tmp'),
      );
      expect(utf8.decode(pty.written[1]!), 'cd /tmp\r');
      final (pty2, _) = await started(
        profile: basicProfile.copyWith(startupCommand: 'cd /tmp'),
        command: ['top'],
      );
      expect(pty2.written[1], isEmpty);
    },
  );

  test(
    'pastes are bracketed when asked, end lines as CR, and jump to the bottom',
    () async {
      final (pty, s) = await started();
      s.pasteText('a\nb');
      expect(utf8.decode(pty.written[1]!), 'a\rb');
      pty.written[1]!.clear();
      pty.show(
        1,
        ['x'],
        modes: 2,
        extra: {
          'scroll': {'offset': 10, 'history': 50},
        },
      );
      s.pasteText('hi');
      expect(utf8.decode(pty.written[1]!), '\x1b[200~hi\x1b[201~');
      expect(
        pty.calls.where((c) => c.$1 == 'scroll').last.$3,
        containsPair('to', 'bottom'),
      );
      pty.written[1]!.clear();
      s.pasteText('');
      expect(pty.written[1], isEmpty);
      s.pasteText('a b', escaped: true);
      expect(utf8.decode(pty.written[1]!), '\x1b[200~a\\ b\x1b[201~');
    },
  );

  test(
    'copy puts the selection on the clipboard and in the primary selection',
    () async {
      final (pty, s) = await started();
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String?;
            }
            if (call.method == 'Clipboard.getData')
              return {'text': 'from clip'};
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      expect(await s.copy(), isFalse, reason: 'nothing selected');
      pty.selections[1] = 'picked';
      expect(await s.copy(), isTrue);
      expect(copied, 'picked');
      expect(PrimarySelection.text, 'picked');
      s.pastePrimary();
      expect(utf8.decode(pty.written[1]!), 'picked');
      pty.written[1]!.clear();
      await s.paste();
      expect(utf8.decode(pty.written[1]!), 'from clip');
    },
  );

  test(
    'OSC 52: a program may write to the clipboard; reading needs the setting',
    () async {
      final sets = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              sets.add((call.arguments as Map)['text'] as String);
            }
            if (call.method == 'Clipboard.getData') return {'text': 'secret'};
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final (pty, s) = await started();
      pty.grid(1, {
        'clipboard': [
          {'set': 'from program', 'selection': false},
          {'get': true, 'selection': false},
        ],
      });
      await Future<void>.delayed(Duration.zero);
      expect(sets, ['from program']);
      expect(pty.calls.where((c) => c.$1 == 'clipboard'), isEmpty);
      s.allowClipboard(write: false, read: true);
      expect(pty.calls.last.$1, 'configure');
      expect(pty.calls.last.$3, containsPair('clipboardRead', true));
      pty.grid(1, {
        'clipboard': [
          {'set': 'blocked', 'selection': false},
          {'get': true, 'selection': false},
        ],
      });
      await Future<void>.delayed(Duration.zero);
      expect(sets, ['from program']);
      expect(pty.calls.last, ('clipboard', 1, 'secret'));
    },
  );

  test(
    'find returns matches as pieces of rows, and the top row follows the scroll',
    () async {
      final (pty, s) = await started();
      pty.show(1, ['one two one']);
      final found = await s.find('one');
      expect(found, hasLength(2));
      expect(found.first.pieces.single, (0, 0, 2));
      expect(found.last.firstRow, 0);
      expect(await s.find(''), isEmpty);
      pty.grid(1, {
        'scroll': {'offset': 4, 'history': 30},
      });
      expect(s.topRow, 26);
    },
  );

  test('a new profile reaches the running grid', () async {
    final (pty, s) = await started();
    s.apply(
      basicProfile.copyWith(
        scrollbackLines: 7,
        cursor: CursorStyleChoice.underline,
      ),
    );
    expect(pty.calls.last.$3, containsPair('scrollback', 7));
    expect(pty.calls.last.$3, containsPair('cursor', 'underline'));
    expect(s.profile.scrollbackLines, 7);
  });

  test('mark, clear, reset and select go to the embedder', () async {
    final (pty, s) = await started();
    expect(await s.mark(), isTrue);
    expect(await s.mark(add: false), isTrue);
    expect(await s.clear('toStart'), isTrue);
    s.reset(hard: true);
    await s.select('start', kind: 'semantic', x: 3, y: 1, right: true);
    expect(s.selectionRow, isNull);
    await s.select('all');
    expect(s.selectionRow, 0);
    await s.select('clear');
    expect(s.selectionRow, isNull);
    expect(pty.calls.map((c) => c.$1), [
      'spawn',
      'mark',
      'mark',
      'clear',
      'reset',
      'select',
      'select',
      'select',
    ]);
  });
}
