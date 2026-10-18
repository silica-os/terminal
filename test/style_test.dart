import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';
import 'package:terminal/src/style.dart';

void main() {
  final lightProfile = Profile.of(
    const AmalfiThemeData(brightness: Brightness.light, app: 'Terminal'),
  );
  final darkProfile = Profile.of(
    const AmalfiThemeData(brightness: Brightness.dark, app: 'Terminal'),
  );

  test('window sizes from cells (kit: padding 12, Mono 12/16)', () {
    expect(cellSize, const Size(7.2, 16));
    expect(gridPadding, const EdgeInsets.all(12));
    expect(windowWidth(80), moreOrLessEquals(600));
    expect(windowHeight(24), 476);
    expect(defaultWindowSize, const Size(640, 476));
    // The find bar adds 32 pt, the grid keeps its rows.
    expect(windowHeight(24, findBar: true), 508);
    expect(
      minimumWindowSize,
      Size(minimumWindowWidth, windowHeight(minimumRows)),
    );
  });

  test('the bundled font advances exactly one cell', () {
    final painter = TextPainter(
      text: TextSpan(
        text: 'M' * 80,
        style: terminalTextStyle(terminalFontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(painter.width, moreOrLessEquals(80 * 7.2, epsilon: 0.5));
    expect(painter.height, moreOrLessEquals(16, epsilon: 0.05));
  });

  test('the ANSI palettes follow the appearance', () {
    for (final palette in [
      ansiLightNormal,
      ansiLightBright,
      ansiDarkNormal,
      ansiDarkBright,
    ]) {
      expect(palette, hasLength(8));
    }
    expect(lightProfile.grid.indexed(1), ansiLightNormal[1]);
    expect(lightProfile.grid.indexed(15), ansiLightBright[7]);
    expect(darkProfile.grid.indexed(1), ansiDarkNormal[1]);
    expect(darkProfile.grid.indexed(9), ansiDarkBright[1]);
    // The xterm cube and the greys.
    expect(lightProfile.grid.indexed(16), const Color(0xFF000000));
    expect(lightProfile.grid.indexed(196), const Color(0xFFFF0000));
    expect(lightProfile.grid.indexed(231), const Color(0xFFFFFFFF));
    expect(lightProfile.grid.indexed(232), const Color(0xFF080808));
    expect(lightProfile.grid.indexed(255), const Color(0xFFEEEEEE));
  });

  test('cells scale with the font size', () {
    expect(cellWidthFor(12), moreOrLessEquals(7.2));
    expect(cellHeightFor(12), 16);
    expect(cellWidthFor(24), moreOrLessEquals(14.4));
    expect(cellHeightFor(24), 32);
    expect(fontSizeSteps, contains(terminalFontSize));
  });

  test(
    'the profiles come from the App/Terminal palette and the window surface',
    () {
      final light = AmalfiColors.of(Brightness.light);
      final dark = AmalfiColors.of(Brightness.dark);
      expect(lightProfile.grid.background, light.surfaceWindow);
      expect(darkProfile.grid.background, dark.surfaceWindow);
      expect(lightProfile.grid.foreground, light.textPrimary);
      expect(lightProfile.grid.selection, const Color(0xFFB3D7FF));
      expect(darkProfile.grid.selection, const Color(0xFF3E638B));
      expect(lightProfile.grid.cursor, const Color(0xFF9D9D9D));
      expect(darkProfile.grid.cursor, const Color(0xFF9D9D9D));
      expect(lightProfile.findMatch, const Color(0xFFC8C8C8));
      expect(darkProfile.findMatch, const Color(0xFF5A5A5B));
      // Grey selection when the window is inactive.
      for (final profile in [lightProfile, darkProfile]) {
        expect(profile.selectionColor(active: true), profile.grid.selection);
        final inactive = profile.selectionColor(active: false);
        expect(inactive, profile.inactiveSelection);
        expect(inactive.r, inactive.g);
        expect(inactive.g, inactive.b);
      }
      expect(extraProfiles, hasLength(10));
    },
  );

  test('cursor blink 500/500 ms, tab animation ~550 ms', () {
    expect(cursorBlinkHalf, const Duration(milliseconds: 500));
    expect(tabEnter, const Duration(milliseconds: 550));
    expect(tabBarHeight, 36);
    expect(tabHeight, 28);
    expect(newTabSide, 28);
    expect(findBarHeight, 32);
    expect(chromeHeight, 68);
  });
}
