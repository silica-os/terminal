import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';
import 'package:terminal/src/app.dart';
import 'package:terminal/src/l10n.dart';
import 'package:terminal/src/pty.dart';
import 'package:terminal/src/settings.dart';
import 'package:terminal/src/settings_window.dart';

void main() {
  late TerminalApp app;

  Future<void> pump(
    WidgetTester tester, {
    SettingsTab tab = SettingsTab.general,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(800, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    app = TerminalApp(pty: FakePty());
    addTearDown(app.settings.dispose);
    await tester.pumpWidget(
      AppLocalizationsScope(
        locale: locale,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AmalfiTheme(
            app: 'Terminal',
            child: TerminalSettingsView(app: app, initial: tab),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> choosePopup(
    WidgetTester tester,
    String key,
    String label,
  ) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(label).last);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
    'the window is 800 × 680 with the four panes of the Amalfi design',
    (tester) async {
      expect(settingsWindowSize, const Size(800, 680));
      expect(profileRowHeight, 44);
      await pump(tester);
      expect(find.byKey(const ValueKey('settings tabs')), findsOneWidget);
      for (final t in ['General', 'Profiles', 'Window Groups', 'Encodings']) {
        expect(find.text(t), findsWidgets, reason: t);
      }
    },
  );

  testWidgets('General: the switches change the settings', (tester) async {
    await pump(tester);
    expect(app.settings.clipboardRead, isFalse);
    await tester.tap(find.text('Allow programs to read the clipboard'));
    await tester.pump();
    expect(app.settings.clipboardRead, isTrue);
    await tester.tap(find.text('Allow programs to write to the clipboard'));
    await tester.pump();
    expect(app.settings.clipboardWrite, isFalse);
    await tester.tap(find.text('Command-click opens links'));
    await tester.pump();
    expect(app.settings.openLinks, isFalse);
    await tester.tap(
      find.text('Report mouse events to programs that ask for them'),
    );
    await tester.pump();
    expect(app.settings.mouseReporting, isFalse);
    await tester.tap(find.text('Mark prompts automatically'));
    await tester.pump();
    expect(app.settings.autoMarkPrompts, isFalse);
  });

  testWidgets(
    'General: where new windows and tabs open, and the default profile',
    (tester) async {
      await pump(tester);
      final copy = app.settings.duplicateProfile(
        app.settings.defaultProfile,
        'Second',
      );
      await tester.pump();
      await choosePopup(tester, 'default profile', 'Second');
      expect(app.settings.defaultProfile.id, copy.id);
      expect(app.settings.newTabDirectory, NewDirectory.sameAsCurrent);
    },
  );

  testWidgets(
    'Profiles: edit the text, window, tab, shell, keyboard and advanced settings',
    (tester) async {
      await pump(tester, tab: SettingsTab.profiles);
      expect(find.byKey(const ValueKey('profile list')), findsOneWidget);
      expect(find.text('Basic (default)'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('profile basic'))).height,
        44,
      );
      TerminalProfile profile() => app.settings.defaultProfile;

      // Text
      await tester.enterText(
        find.byKey(const ValueKey('font basic')),
        'Noto Sans Mono',
      );
      await tester.pump();
      expect(profile().fontFamily, 'Noto Sans Mono');
      await tester.enterText(find.byKey(const ValueKey('name basic')), 'Mine');
      await tester.pump();
      expect(profile().name, 'Mine');
      await tester.tap(find.text('Blink the cursor'));
      await tester.pump();
      expect(profile().cursorBlink, isTrue);
      await tester.tap(find.text('Use the bold face for bold text'));
      await tester.pump();
      expect(profile().boldText, isFalse);
      await choosePopup(tester, 'cursor', 'Bar');
      expect(profile().cursor, CursorStyleChoice.beam);
      await choosePopup(tester, 'scheme', 'Phosphor');
      expect(profile().scheme, 'phosphor');

      // Window
      await tester.tap(find.text('Window').last);
      await tester.pump();
      await tester.tap(find.text('Show the size in the window title'));
      await tester.pump();
      expect(profile().titleShowsSize, isFalse);

      // Tab
      await tester.tap(find.text('Tab').last);
      await tester.pump();
      await tester.tap(find.text('Show the directory in the title'));
      await tester.pump();
      expect(profile().titleShowsDirectory, isFalse);

      // Shell
      await tester.tap(find.text('Shell').last);
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('startup basic')),
        'cd /tmp',
      );
      await tester.pump();
      expect(profile().startupCommand, 'cd /tmp');
      await choosePopup(tester, 'close on exit', 'Close the window');
      expect(profile().closeOnExit, CloseOnExit.close);
      await tester.tap(find.text('Never'));
      await tester.pump();
      expect(profile().askBeforeClosing, AskBeforeClosing.never);

      // Keyboard
      await tester.tap(find.text('Keyboard').last);
      await tester.pump();
      await tester.tap(find.text('Use Option as Meta Key'));
      await tester.pump();
      expect(profile().optionAsMeta, isTrue);

      // Advanced
      await tester.tap(find.text('Advanced').last);
      await tester.pump();
      expect(find.byKey(const ValueKey('scrollback lines')), findsOneWidget);
      await choosePopup(tester, 'scrollback mode', 'Unlimited');
      expect(profile().scrollbackLimited, isFalse);
      expect(find.byKey(const ValueKey('scrollback lines')), findsNothing);
      await tester.tap(find.text('Flash the window for the bell'));
      await tester.pump();
      expect(profile().bellVisual, isFalse);
      await tester.tap(
        find.text('Notify when a background tab rings the bell'),
      );
      await tester.pump();
      expect(profile().bellNotify, isFalse);
    },
  );

  testWidgets('Profiles: duplicate, select, make default and remove', (
    tester,
  ) async {
    await pump(tester, tab: SettingsTab.profiles);
    await tester.tap(find.byKey(const ValueKey('duplicate profile')));
    await tester.pump();
    expect(app.settings.profiles, hasLength(12));
    expect(app.settings.profiles.last.name, 'Basic copy');
    expect(find.text('Basic copy'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('remove profile')));
    await tester.pump();
    expect(app.settings.profiles, hasLength(11));
    // The last profile cannot be removed: the button is off.
    for (final p in app.settings.profiles.skip(1).toList()) {
      app.settings.removeProfile(p.id);
    }
    await tester.pump();
    final remove = tester.widget<AmalfiPushButton>(
      find.byKey(const ValueKey('remove profile')),
    );
    expect(remove.onPressed, isNull);
  });

  testWidgets('Window Groups: listed and removable; Encodings: UTF-8 only', (
    tester,
  ) async {
    await pump(tester, tab: SettingsTab.windowGroups);
    expect(find.textContaining('No window groups yet'), findsOneWidget);
    app.settings.saveWindowGroup(
      const WindowGroup('work', [
        WindowGroupWindow([WindowGroupTab(profile: 'basic')]),
        WindowGroupWindow([WindowGroupTab(profile: 'basic')]),
      ]),
    );
    await tester.pump();
    expect(find.text('work — 2 windows'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('remove group work')));
    await tester.pump();
    expect(app.settings.windowGroups, isEmpty);
    await tester.tap(find.text('Encodings'));
    await tester.pump();
    expect(find.text('Unicode (UTF-8)'), findsOneWidget);
    expect(
      tester.widget<AmalfiCheckbox>(find.byType(AmalfiCheckbox)).onChanged,
      isNull,
    );
  });

  testWidgets('the settings speak Italian', (tester) async {
    await pump(tester, locale: const Locale('it'));
    expect(find.text('Generale'), findsWidgets);
    expect(find.text('Profili'), findsWidgets);
    expect(find.text('Gruppi di finestre'), findsWidgets);
    expect(find.text('Codifiche'), findsWidgets);
    useLocale(const Locale('en'));
  });

  testWidgets('the layout follows the Amalfi measures', (tester) async {
    await pump(tester);
    // Pane switcher: 4 panes of 112 + 8, centred, top at 52.
    final bar = tester.getRect(find.byKey(const ValueKey('settings tabs')));
    expect(bar, const Rect.fromLTWH(172, 52, 456, 52));
    // Controls at x 212; the default profile row is the second, 40 below the first.
    final profile = tester.getTopLeft(
      find.byKey(const ValueKey('default profile')),
    );
    expect(profile, const Offset(212, 200));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('on launch'))),
      const Offset(212, 160),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('default profile'))).height,
      28,
    );

    await tester.tap(find.text('Profiles').last);
    await tester.pump();
    expect(
      tester.getRect(find.byKey(const ValueKey('profile list'))).topLeft,
      const Offset(24, 124),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('profile list'))).width,
      200,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('profile tabs'))),
      const Rect.fromLTWH(268, 124, 488, 28),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('duplicate profile'))),
      const Offset(24, 628),
    );
    // The preview is 40 x 28 and the row 44.
    expect(
      tester.getSize(find.byKey(const ValueKey('profile preview basic'))),
      const Size(40, 28),
    );
  });

  testWidgets('Profiles: the presets are real profiles with their previews', (
    tester,
  ) async {
    await pump(tester, tab: SettingsTab.profiles);
    expect(app.settings.profiles, hasLength(11));
    for (final p in app.settings.profiles) {
      await tester.ensureVisible(find.byKey(ValueKey('profile ${p.id}')));
    }
    final slate = app.settings.profileById('slate')!;
    await tester.tap(find.byKey(const ValueKey('profile slate')));
    await tester.pump();
    expect(find.byKey(ValueKey('name ${slate.id}')), findsOneWidget);
  });

  testWidgets('General: launch group, shell for new windows, tab switching', (
    tester,
  ) async {
    await pump(tester);
    final s = app.settings;
    s.saveWindowGroup(
      const WindowGroup('work', [
        WindowGroupWindow([WindowGroupTab(profile: 'basic')]),
      ]),
    );
    await tester.pump();
    await choosePopup(tester, 'on launch', 'Window group “work”');
    expect(s.launchGroup, 'work');
    await choosePopup(tester, 'on launch', 'A new window');
    expect(s.launchGroup, isNull);
    expect(s.shellForNewWindows, isNull);
    await choosePopup(tester, 'shell for new windows', 'A command');
    expect(s.shellForNewWindows, ['/bin/sh']);
    await tester.enterText(
      find.byKey(const ValueKey('shell command')),
      '/bin/zsh -l',
    );
    await tester.pump();
    expect(s.shellForNewWindows, ['/bin/zsh', '-l']);
    await choosePopup(tester, 'shell for new windows', 'Default login shell');
    expect(s.shellCommand, isEmpty);
    expect(s.tabSwitching, isTrue);
    await tester.tap(find.text('⌘1 to ⌘9 select tabs'));
    await tester.pump();
    expect(s.tabSwitching, isFalse);
    // Removing the group clears the launch choice.
    s.set(launchGroup: 'work');
    s.removeWindowGroup('work');
    expect(s.launchGroup, isNull);
  });

  testWidgets('Profiles > Text: ANSI colors, bright bold, edited colours', (
    tester,
  ) async {
    await pump(tester, tab: SettingsTab.profiles);
    TerminalProfile profile() => app.settings.defaultProfile;
    await tester.tap(find.text('Use bright colors for bold text'));
    await tester.pump();
    expect(profile().brightBold, isTrue);
    await tester.tap(find.text('Display ANSI colors'));
    await tester.pump();
    expect(profile().ansiColors, isFalse);
    // The wells are editable: a colour sticks to the profile, a new scheme drops it.
    final well = find.byKey(const ValueKey('color background basic'));
    expect(tester.widget<AmalfiColorWell>(well).onChanged, isNotNull);
    tester.widget<AmalfiColorWell>(well).onChanged!(const Color(0xFF102030));
    await tester.pump();
    expect(profile().backgroundColor, 0xFF102030);
    await choosePopup(tester, 'scheme', 'Phosphor');
    expect(profile().backgroundColor, isNull);
  });

  testWidgets('Profiles: what the emulator cannot do yet is disabled', (
    tester,
  ) async {
    await pump(tester, tab: SettingsTab.profiles);
    for (final key in ['antialias', 'blinking text']) {
      expect(
        tester
            .widget<AmalfiCheckbox>(
              find.descendant(
                of: find.byKey(ValueKey(key)),
                matching: find.byType(AmalfiCheckbox),
              ),
            )
            .onChanged,
        isNull,
        reason: key,
      );
    }
    await tester.tap(find.text('Window').last);
    await tester.pump();
    for (final key in ['title process', 'restore text']) {
      expect(
        tester
            .widget<AmalfiCheckbox>(
              find.descendant(
                of: find.byKey(ValueKey(key)),
                matching: find.byType(AmalfiCheckbox),
              ),
            )
            .onChanged,
        isNull,
        reason: key,
      );
    }
    expect(
      tester
          .widget<AmalfiStepperField>(
            find.byKey(const ValueKey('restore lines')),
          )
          .onChanged,
      isNull,
    );
  });

  testWidgets('Profiles > Text: the font size stepper moves along the steps', (
    tester,
  ) async {
    await pump(tester, tab: SettingsTab.profiles);
    final field = find.byKey(const ValueKey('font size'));
    tester.widget<AmalfiStepperField>(field).onChanged!(13);
    await tester.pump();
    expect(app.settings.defaultProfile.fontSize, 13);
    tester.widget<AmalfiStepperField>(field).onChanged!(15);
    await tester.pump();
    expect(app.settings.defaultProfile.fontSize, 16);
    tester.widget<AmalfiStepperField>(field).onChanged!(15);
    await tester.pump();
    expect(app.settings.defaultProfile.fontSize, 14);
  });
}
