import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:terminal/src/settings.dart';

void main() {
  test(
    'the defaults: one Basic profile, mouse and links on, clipboard read off',
    () async {
      final s = TerminalSettings();
      await s.load();
      expect(s.profiles.map((p) => p.name), ['Basic']);
      expect(s.defaultProfile.id, 'basic');
      expect(s.clipboardWrite, isTrue);
      expect(s.clipboardRead, isFalse);
      expect(s.mouseReporting, isTrue);
      expect(s.openLinks, isTrue);
      expect(s.newTabDirectory, NewDirectory.sameAsCurrent);
      expect(s.newWindowDirectory, NewDirectory.home);
      final p = s.defaultProfile;
      expect(p.scrollback, 10000);
      expect(p.closeOnExit, CloseOnExit.keep);
      expect(p.askBeforeClosing, AskBeforeClosing.running);
      expect(p.optionAsMeta, isFalse);
      expect((p.columns, p.rows), (80, 24));
    },
  );

  test('changes are saved once, soon, and come back', () async {
    final store = MemorySettingsStore();
    final s = TerminalSettings(store: store);
    s.set(clipboardRead: true, openLinks: false);
    s.updateProfile(
      s.defaultProfile.copyWith(optionAsMeta: true, scrollbackLimited: false),
    );
    expect(store.writes, 0);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(store.writes, 1);
    final back = TerminalSettings(store: store);
    await back.load();
    expect(back.clipboardRead, isTrue);
    expect(back.openLinks, isFalse);
    expect(back.defaultProfile.optionAsMeta, isTrue);
    expect(back.defaultProfile.scrollback, unlimitedScrollback);
    s.dispose();
  });

  test('profiles: duplicate, edit, set the default, remove', () async {
    final s = TerminalSettings();
    final copy = s.duplicateProfile(s.defaultProfile, 'Basic copy');
    expect(copy.id, isNot('basic'));
    expect(s.profiles, hasLength(2));
    s.setDefaultProfile(copy.id);
    expect(s.defaultProfile.name, 'Basic copy');
    s.updateProfile(
      copy.copyWith(fontSize: 14, cursor: CursorStyleChoice.beam),
    );
    expect(s.profileById(copy.id)!.fontSize, 14);
    expect(s.removeProfile(copy.id), isTrue);
    expect(s.defaultProfile.id, 'basic');
    expect(s.removeProfile('basic'), isFalse, reason: 'the last one stays');
    expect(s.removeProfile('nope'), isFalse);
    s.dispose();
  });

  test(
    'a damaged or odd file gives the defaults, bad values one by one',
    () async {
      for (final text in [
        '',
        'not json',
        '[]',
        '{"profiles": 3}',
        '{"profiles": []}',
      ]) {
        final s = TerminalSettings(store: MemorySettingsStore(text));
        await s.load();
        expect(s.profiles, hasLength(1), reason: text);
      }
      final odd = jsonEncode({
        'defaultProfile': 'missing',
        'profiles': [
          {
            'id': 'a',
            'name': 'A',
            'fontSize': 9000,
            'scrollbackLines': -5,
            'cursor': 'triangle',
            'closeOnExit': 'maybe',
            'columns': 5,
            'scheme': 'no such scheme',
            'optionAsMeta': 'yes',
          },
          {'id': 'a', 'name': 'duplicate id'},
          {'name': 'no id'},
          7,
        ],
        'windowGroups': [
          {
            'name': 'g',
            'windows': [
              [
                {
                  'profile': 'a',
                  'cwd': '/tmp',
                  'command': ['ls'],
                },
              ],
            ],
          },
          {'name': 'empty', 'windows': []},
          'x',
        ],
      });
      final s = TerminalSettings(store: MemorySettingsStore(odd));
      await s.load();
      expect(s.profiles, hasLength(1));
      final p = s.profiles.single;
      expect(p.fontSize, lessThanOrEqualTo(48));
      expect(p.scrollbackLines, 0);
      expect(p.cursor, CursorStyleChoice.block);
      expect(p.closeOnExit, CloseOnExit.keep);
      expect(p.columns, greaterThanOrEqualTo(20));
      expect(p.scheme, 'default');
      expect(p.optionAsMeta, isFalse);
      expect(s.defaultProfile.id, 'a');
      expect(s.windowGroups.map((g) => g.name), ['g']);
      expect(s.windowGroups.single.windows.single.tabs.single.command, ['ls']);
    },
  );

  test('window groups are saved by name and replace the same name', () {
    final s = TerminalSettings();
    const tab = WindowGroupTab(profile: 'basic', cwd: '/tmp');
    s.saveWindowGroup(
      const WindowGroup('work', [
        WindowGroupWindow([tab]),
      ]),
    );
    s.saveWindowGroup(
      const WindowGroup('play', [
        WindowGroupWindow([tab, tab]),
      ]),
    );
    s.saveWindowGroup(
      const WindowGroup('work', [
        WindowGroupWindow([tab, tab, tab]),
      ]),
    );
    expect(s.windowGroups.map((g) => g.name), ['play', 'work']);
    expect(s.windowGroups.last.windows.single.tabs, hasLength(3));
    s.removeWindowGroup('play');
    expect(s.windowGroups.map((g) => g.name), ['work']);
    s.dispose();
  });

  test('the scrollback of a profile is bounded', () {
    const p = TerminalProfile(id: 'x', name: 'x', scrollbackLines: 5000000);
    expect(p.scrollback, unlimitedScrollback);
    expect(
      const TerminalProfile(
        id: 'x',
        name: 'x',
        scrollbackLimited: false,
      ).scrollback,
      unlimitedScrollback,
    );
  });
}
