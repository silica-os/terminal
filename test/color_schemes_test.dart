import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';
import 'package:terminal/src/settings.dart';
import 'package:terminal/src/style.dart';

double _channel(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

/// WCAG contrast ratio.
double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  // The hue colours of the ANSI rows (not the blacks and the greys).
  const hues = [1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14];

  void checkScheme(String name, GridColors c, {bool cursor = true}) {
    expect(contrast(c.foreground, c.background), greaterThanOrEqualTo(4.5));
    expect(contrast(c.bold, c.background), greaterThanOrEqualTo(4.5));
    // Text over a selection.
    expect(contrast(c.foreground, c.selection), greaterThanOrEqualTo(4.5));
    // The cursor is a graphic: 3:1.
    if (cursor) {
      expect(contrast(c.cursor, c.background), greaterThanOrEqualTo(3));
    }
    expect(c.normal, hasLength(8), reason: name);
    expect(c.bright, hasLength(8), reason: name);
    for (final i in hues) {
      expect(
        contrast(c.indexed(i), c.background),
        greaterThanOrEqualTo(4.5),
        reason: '$name colour $i',
      );
    }
  }

  test('every built-in colour scheme reads at WCAG AA', () {
    expect(extraProfiles, hasLength(10));
    extraProfiles.forEach((name, c) => checkScheme(name, c));
  });

  for (final brightness in Brightness.values) {
    test('Basic reads at WCAG AA in ${brightness.name}', () {
      final theme = AmalfiThemeData(brightness: brightness, app: 'Terminal');
      // The cursor is the App/Terminal palette's, not ours.
      checkScheme('basic', Profile.of(theme).grid, cursor: false);
    });
  }

  test(
    'the starting profiles: Basic is the default, then ten built-in ones',
    () {
      expect(startingProfiles.first.id, 'basic');
      expect(startingProfiles.first.scheme, 'default');
      expect(builtInProfiles, hasLength(10));
      final ids = {for (final p in startingProfiles) p.id};
      expect(ids, hasLength(11));
      for (final p in builtInProfiles) {
        expect(extraProfiles, contains(p.scheme));
        expect(p.opacity, inInclusiveRange(0.3, 1.0));
      }
      // Some are translucent.
      expect(builtInProfiles.where((p) => p.opacity < 1), isNotEmpty);
      final settings = TerminalSettings();
      expect(settings.profiles, hasLength(11));
      expect(settings.defaultProfile.id, 'basic');
    },
  );

  test('a file saved before the built-in profiles gets them once', () async {
    final store = MemorySettingsStore();
    await store.write(
      '{"profiles":[{"id":"basic","name":"Basic"},{"id":"mine","name":"Mine"}],'
      '"defaultProfile":"mine"}',
    );
    final settings = TerminalSettings(store: store);
    await settings.load();
    expect(settings.profiles, hasLength(12));
    expect(settings.defaultProfile.id, 'mine');
    await settings.flush();
    // Saved with the marker: a built-in profile removed later stays removed.
    settings.removeProfile('slate');
    await settings.flush();
    final again = TerminalSettings(store: store);
    await again.load();
    expect(again.profileById('slate'), isNull);
    expect(again.profiles, hasLength(11));
  });

  test('the opacity survives the JSON and is clamped', () {
    final p = TerminalProfile.fromJson({
      'id': 'x',
      'name': 'X',
      'opacity': 0.1,
    });
    expect(p?.opacity, 0.3);
    expect(builtInProfiles[1].copyWith(opacity: 0.5).toJson()['opacity'], 0.5);
  });
}
