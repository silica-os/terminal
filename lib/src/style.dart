// Geometry and colours of the window and of the profiles, from the measurements of TE-01
// (silica-reference#75, `terminal.md`): 1 pt = 1 px, window origin at its top-left corner.
// Values not measured are marked "estimated"; docs/parity.md lists both.

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

/// The title band at the top (kit `Titlebars/Bar/Title Only`, 32 pt): the compositor draws the
/// window controls in it, the app the centred title.
const double titleBarHeight = 32;

/// The tab bar under the title band: always visible, even with one tab (kit `Apps/Terminal/Tab
/// Bar *`: 36 pt, the last point is the `Line/Separator`).
const double tabBarHeight = 36;

/// The title is kept clear of the window controls on both sides (`AmalfiTitleBar.titleOnlyInset`).
const double titleInset = 84;

/// Tabs are 28 pt tall (`AmalfiTabMetrics.height`) at y +4, from x +8, 4 pt apart; the
/// selected tab keeps at least this width while the others shrink.
const double selectedTabMinWidth = 120;
const double tabHeight = 28;
const double tabTop = 4;
const double tabBarLeft = 8;
const double tabGap = 4;

/// The new-tab button: a round 28 pt icon button, 8 pt from the right edge, at y +4.
const double newTabSide = 28;
const double newTabRight = 8;
const double newTabTop = 4;

/// The tabs end 8 pt before the new-tab button (kit: x +596 against +604 in a 640 window).
const double tabsToNewTab = 8;

/// A new tab slides in from the right and settles in ~550 ms; a closed one shrinks away in
/// ~500 ms (measured, TE-01).
const Duration tabEnter = Duration(milliseconds: 550);
const Duration tabExit = Duration(milliseconds: 500);

/// The content area starts at window y +68 (title band + tab bar).
const double chromeHeight = titleBarHeight + tabBarHeight;

/// Content padding 12 on every side (`components.md`); the scroll bar floats over it.
const EdgeInsets gridPadding = EdgeInsets.all(12);

/// The find bar, inserted under the tab bar: 32 pt; the window grows by as much. Kit `Apps/
/// Terminal/Find Bar`: search field (small, 24) at x +8, previous/next segments 56 × 24 and
/// "Done" 56 × 24 ending 4 pt before the right edge, bottom separator.
const double findBarHeight = 32;
const double findFieldLeft = 8;
const double findFieldWidth = 480;
const double findControlHeight = 24;
const double findSegmentsWidth = 56;
const double findDoneWidth = 56;
const double findRight = 4;

/// The splitter between the two halves of a split view (kit `Apps/Terminal/Split`): 8 pt of
/// `Surface/Sunken` between two 1 pt separators, with a 4 pt dot of `Text/Tertiary` in the
/// middle. The window grows by as much as a half needs for the rows to stay: 8 + 2 × 12 pt.
const double splitterHeight = 8;
const double splitterDot = 4;
const double splitGrow = 32;

/// A cell is 7.2 × 16 pt: JetBrains Mono 12 / 16 (`components.md`, Mono token); the bundled
/// JetBrains Mono NL advances 0.6 em.
const Size cellSize = Size(7.2, 16);
const double terminalFontSize = 12;

/// The terminal font: JetBrains Mono NL (OFL 1.1, bundled).
const String terminalFontFamily = 'JetBrains Mono';
const List<String> terminalFontFallback = [
  'Noto Sans Mono',
  'DejaVu Sans Mono',
  'monospace',
];

/// The text style of the grid at `size` points: the cell is 0.6 em wide and 4/3 em tall.
TextStyle terminalTextStyle(
  double size, {
  String family = terminalFontFamily,
}) => TextStyle(
  fontFamily: family,
  fontFamilyFallback: terminalFontFallback,
  fontSize: size,
  height: cellHeightFor(size) / size,
);

/// The cell for a font size (the face advances 0.6 em; the line is 16 pt at 12 pt).
double cellWidthFor(double size) => size * 0.6;
double cellHeightFor(double size) => size * 16 / 12;

/// The font sizes Bigger and Smaller step through; the first and last are the limits.
const List<double> fontSizeSteps = [
  8, 9, 10, 11, 12, 13, 14, 16, 18, 20, 24, 28, 32, 40, 48, //
];

/// The default window: 80 × 24 cells.
const int defaultColumns = 80;
const int defaultRows = 24;

/// The smallest window we allow: 20 × 4 cells (estimated: not measured).
const int minimumColumns = 20;
const int minimumRows = 4;

/// The narrowest window that keeps the window buttons clear (177 pt, titlebar.md).
const double minimumWindowWidth = 177;

/// The widths of the tabs in a track `width` wide: shared by `weights` (presence, so that
/// opening and closing animate), except that the `selected` tab (index or -1) keeps at least
/// [selectedTabMinWidth] and the others take what is left.
List<double> tabWidths({
  required double width,
  required List<double> weights,
  required int selected,
}) {
  final total = weights.fold<double>(0, (a, b) => a + b);
  if (total <= 0) return [for (final _ in weights) 0];
  final widths = [for (final w in weights) width * w / total];
  if (selected < 0 || widths[selected] >= selectedTabMinWidth) return widths;
  final keep = selectedTabMinWidth < width ? selectedTabMinWidth : width;
  final others = total - weights[selected];
  return [
    for (var i = 0; i < widths.length; i++)
      i == selected
          ? keep
          : others <= 0
          ? 0
          : (width - keep) * weights[i] / others,
  ];
}

/// The window width for `columns`: 12 + 7.2 · columns + 12.
double windowWidth(int columns) =>
    gridPadding.horizontal + cellSize.width * columns;

/// The window height for `rows`: 68 + 12 + 16 · rows + 12 (24 → 476).
double windowHeight(int rows, {bool findBar = false}) =>
    chromeHeight +
    gridPadding.vertical +
    cellSize.height * rows +
    (findBar ? findBarHeight : 0);

/// The default window size: 640 × 476, as the kit's masters.
Size get defaultWindowSize => Size(640, windowHeight(defaultRows));

/// The smallest window size.
Size get minimumWindowSize => Size(
  windowWidth(minimumColumns) > minimumWindowWidth
      ? windowWidth(minimumColumns)
      : minimumWindowWidth,
  windowHeight(minimumRows),
);

/// The cursor blinks 500 ms on, 500 ms off when a program asks for a blinking shape; the
/// default is steady.
const Duration cursorBlinkHalf = Duration(milliseconds: 500);

/// Our ANSI palettes, one per appearance (the window surface decides which): every colour
/// but the blacks and the greys reads at 4.5:1 or more on its surface.
const List<Color> ansiLightNormal = [
  Color(0xFF3B4652),
  Color(0xFFB3433A),
  Color(0xFF2F7D4B),
  Color(0xFF8A6A12),
  Color(0xFF2F63A8),
  Color(0xFF7B4AA0),
  Color(0xFF1F7C85),
  Color(0xFF6A7580),
];
const List<Color> ansiLightBright = [
  Color(0xFF56616E),
  Color(0xFFC9352B),
  Color(0xFF246B3E),
  Color(0xFF7A5A08),
  Color(0xFF1F55A0),
  Color(0xFF6B3A94),
  Color(0xFF176B73),
  Color(0xFF4E5864),
];
const List<Color> ansiDarkNormal = [
  Color(0xFF2A2D33),
  Color(0xFFE3857A),
  Color(0xFF86C494),
  Color(0xFFD6B96C),
  Color(0xFF78AEE3),
  Color(0xFFC096DB),
  Color(0xFF76C7CC),
  Color(0xFFC8CCD2),
];
const List<Color> ansiDarkBright = [
  Color(0xFF50555E),
  Color(0xFFF59A8F),
  Color(0xFF9DDAAA),
  Color(0xFFEFD282),
  Color(0xFF93C3F0),
  Color(0xFFD7AEEB),
  Color(0xFF92DDE1),
  Color(0xFFF0F2F5),
];

/// A colour profile of the grid. The palettes are our own (clean room).
@immutable
class GridColors {
  const GridColors({
    required this.background,
    required this.foreground,
    required this.bold,
    required this.selection,
    required this.cursor,
    this.opacity = 1,
    this.normal = ansiDarkNormal,
    this.bright = ansiDarkBright,
  });

  final Color background;
  final Color foreground;
  final Color bold;
  final Color selection;
  final Color cursor;

  /// How opaque the background is (translucent profiles let the desktop through).
  final double opacity;
  final List<Color> normal;
  final List<Color> bright;

  GridColors withOpacity(double value) => GridColors(
    background: background,
    foreground: foreground,
    bold: bold,
    selection: selection,
    cursor: cursor,
    opacity: value.clamp(0.3, 1.0),
    normal: normal,
    bright: bright,
  );

  /// Entry `i` of the 256-colour palette: the profile's 16 ANSI colours, then the xterm
  /// 6 × 6 × 6 cube and the 24 greys.
  Color indexed(int i) {
    if (i < 0) return foreground;
    if (i < 8) return normal[i];
    if (i < 16) return bright[i - 8];
    if (i < 232) {
      final n = i - 16;
      int level(int v) => v == 0 ? 0 : 55 + v * 40;
      return Color.fromARGB(
        0xff,
        level(n ~/ 36),
        level(n ~/ 6 % 6),
        level(n % 6),
      );
    }
    final v = (8 + (i - 232) * 10).clamp(0, 255);
    return Color.fromARGB(0xff, v, v, v);
  }
}

List<Color> _hex(List<int> values) => [for (final v in values) Color(v)];

/// The colour schemes of the built-in profiles, under our own names: every one has its
/// background, text, bold, selection, cursor and 16 ANSI colours (`color_schemes_test.dart`
/// checks the contrast of each).
final Map<String, GridColors> extraProfiles = {
  'slate': GridColors(
    background: Color(0xFF1E2229),
    foreground: Color(0xFFD5DAE0),
    bold: Color(0xFFF2F4F7),
    selection: Color(0xFF3A4656),
    cursor: Color(0xFF8FB7D9),
    normal: _hex([
      0xFF2B313A, 0xFFD9776C, 0xFF7DB78A, 0xFFC9A95E, //
      0xFF6FA2D6, 0xFFB58BD1, 0xFF68B9BE, 0xFFB9C0C9,
    ]),
    bright: _hex([
      0xFF4A5260, 0xFFF08D80, 0xFF95CEA2, 0xFFE3C479, //
      0xFF8DBCEB, 0xFFCDA3E6, 0xFF86D2D6, 0xFFE6EAEF,
    ]),
  ),
  'frost': GridColors(
    background: Color(0xFFF3F6F9),
    foreground: Color(0xFF2D3640),
    bold: Color(0xFF141A20),
    selection: Color(0xFFC9DAEA),
    cursor: Color(0xFF3A6EA5),
    normal: _hex([
      0xFF3B4652, 0xFFB3433A, 0xFF2F7D4B, 0xFF8A6A12, //
      0xFF2F63A8, 0xFF7B4AA0, 0xFF1F7C85, 0xFF6A7580,
    ]),
    bright: _hex([
      0xFF56616E, 0xFFC9352B, 0xFF246B3E, 0xFF7A5A08, //
      0xFF1F55A0, 0xFF6B3A94, 0xFF176B73, 0xFF4E5864,
    ]),
  ),
  'smoke': GridColors(
    background: Color(0xFF16181C),
    foreground: Color(0xFFE2E4E8),
    bold: Color(0xFFFFFFFF),
    selection: Color(0xFF3B4350),
    cursor: Color(0xFFA9C4E0),
    normal: _hex([
      0xFF2A2D33, 0xFFE3857A, 0xFF86C494, 0xFFD6B96C, //
      0xFF78AEE3, 0xFFC096DB, 0xFF76C7CC, 0xFFC8CCD2,
    ]),
    bright: _hex([
      0xFF50555E, 0xFFF59A8F, 0xFF9DDAAA, 0xFFEFD282, //
      0xFF93C3F0, 0xFFD7AEEB, 0xFF92DDE1, 0xFFF0F2F5,
    ]),
  ),
  'contrast': GridColors(
    background: Color(0xFF000000),
    foreground: Color(0xFFFFFFFF),
    bold: Color(0xFFFFFFFF),
    selection: Color(0xFF2A4F8F),
    cursor: Color(0xFFFFFF00),
    normal: _hex([
      0xFF1A1A1A, 0xFFFF6B6B, 0xFF4DFF7A, 0xFFFFE24D, //
      0xFF6FA8FF, 0xFFFF7AF0, 0xFF4DFFF0, 0xFFE6E6E6,
    ]),
    bright: _hex([
      0xFF5C5C5C, 0xFFFF9494, 0xFF85FFA3, 0xFFFFF085, //
      0xFF9CC4FF, 0xFFFFA3F5, 0xFF85FFF5, 0xFFFFFFFF,
    ]),
  ),
  'phosphor': GridColors(
    background: Color(0xFF07120A),
    foreground: Color(0xFF59E07A),
    bold: Color(0xFF9BFFB2),
    selection: Color(0xFF1D4D2B),
    cursor: Color(0xFF8CFFA8),
    normal: _hex([
      0xFF0F2A18, 0xFFE0715F, 0xFF59E07A, 0xFFC8D65A, //
      0xFF5FA8E0, 0xFFC27AE0, 0xFF5FE0C8, 0xFF9FCFA9,
    ]),
    bright: _hex([
      0xFF2F6B43, 0xFFFF8F7D, 0xFF84F59E, 0xFFE6F27A, //
      0xFF82C4F5, 0xFFDB9AF5, 0xFF82F5E0, 0xFFD2F5DA,
    ]),
  ),
  'amber': GridColors(
    background: Color(0xFF1C1206),
    foreground: Color(0xFFF2B24A),
    bold: Color(0xFFFFD27A),
    selection: Color(0xFF4D3510),
    cursor: Color(0xFFFFC45E),
    normal: _hex([
      0xFF2E1F0A, 0xFFE2745A, 0xFFB8C75A, 0xFFF2B24A, //
      0xFF7FA6C9, 0xFFD08AB0, 0xFF72C2A8, 0xFFD9BE8E,
    ]),
    bright: _hex([
      0xFF6B4B1C, 0xFFF59A80, 0xFFD3E27A, 0xFFFFCF6E, //
      0xFFA0C4E3, 0xFFE6A6C9, 0xFF92DBC2, 0xFFF5E3BE,
    ]),
  ),
  'paper': GridColors(
    background: Color(0xFFFAF6EC),
    foreground: Color(0xFF3B3731),
    bold: Color(0xFF1B1814),
    selection: Color(0xFFE3D8BC),
    cursor: Color(0xFF7A4B2A),
    normal: _hex([
      0xFF4A453D, 0xFFA63D32, 0xFF3F7A3C, 0xFF8A6414, //
      0xFF2F5F95, 0xFF84508A, 0xFF2A7A78, 0xFF77705F,
    ]),
    bright: _hex([
      0xFF655F54, 0xFFBA3A2D, 0xFF356E33, 0xFF7A560A, //
      0xFF255287, 0xFF74407A, 0xFF206B69, 0xFF4D483F,
    ]),
  ),
  'lagoon': GridColors(
    background: Color(0xFF0E2A3F),
    foreground: Color(0xFFD3E8F2),
    bold: Color(0xFFFFFFFF),
    selection: Color(0xFF24557A),
    cursor: Color(0xFF7FD6E8),
    normal: _hex([
      0xFF16384F, 0xFFF0836F, 0xFF7FD39A, 0xFFE8CB6E, //
      0xFF7DB4F2, 0xFFD29AEB, 0xFF6FDCE0, 0xFFBFD6E2,
    ]),
    bright: _hex([
      0xFF3F6580, 0xFFFFA08D, 0xFF9CEBB2, 0xFFFFE38A, //
      0xFF9BCBFF, 0xFFE6B4FA, 0xFF8FEFF2, 0xFFEAF6FB,
    ]),
  ),
  'dune': GridColors(
    background: Color(0xFF2B2118),
    foreground: Color(0xFFE6D5B8),
    bold: Color(0xFFFFF1D6),
    selection: Color(0xFF57432B),
    cursor: Color(0xFFE0A458),
    normal: _hex([
      0xFF3A2D20, 0xFFDE7B5B, 0xFFA6BF5F, 0xFFE0B04C, //
      0xFF73A3C4, 0xFFC48BA8, 0xFF6FBFA6, 0xFFCDBB9C,
    ]),
    bright: _hex([
      0xFF6B5A44, 0xFFF29675, 0xFFBFD87A, 0xFFF5C86A, //
      0xFF93BCDA, 0xFFDAA5C0, 0xFF8DD6BD, 0xFFF0E2C8,
    ]),
  ),
  'manuscript': GridColors(
    background: Color(0xFFFBF3C0),
    foreground: Color(0xFF2E2A1E),
    bold: Color(0xFF000000),
    selection: Color(0xFFE3D68E),
    cursor: Color(0xFF6B3F12),
    normal: _hex([
      0xFF3D3829, 0xFFA33224, 0xFF35703A, 0xFF7F5A0A, //
      0xFF274F8C, 0xFF7A4480, 0xFF1F6F6C, 0xFF6E664F,
    ]),
    bright: _hex([
      0xFF5A533E, 0xFFB52E1F, 0xFF2B6330, 0xFF6F4B00, //
      0xFF1C4380, 0xFF6A3470, 0xFF165F5C, 0xFF45402D,
    ]),
  ),
};

/// The grey of a selection in an inactive window.
// Assumption: not measured on the Amalfi palette; the measured greys of TE-01.
const Color inactiveSelectionLight = Color(0xFFE3E3E3);
const Color inactiveSelectionDark = Color(0xFF777777);

/// The grid colours for an appearance: the window surface under `Text/Primary`, the
/// `App/Terminal` palette for selection, cursor and find matches.
@immutable
class Profile {
  const Profile({
    required this.grid,
    required this.inactiveSelection,
    required this.findMatch,
  });

  factory Profile.of(AmalfiThemeData theme) {
    final colors = theme.colors;
    final palette = colors.terminal;
    return Profile(
      grid: GridColors(
        background: colors.surfaceWindow,
        foreground: colors.textPrimary,
        bold: colors.textPrimary,
        selection: palette.selection,
        cursor: palette.cursor,
        normal: theme.isDark ? ansiDarkNormal : ansiLightNormal,
        bright: theme.isDark ? ansiDarkBright : ansiLightBright,
      ),
      inactiveSelection: theme.isDark
          ? inactiveSelectionDark
          : inactiveSelectionLight,
      findMatch: palette.findMatch,
    );
  }

  final GridColors grid;

  /// The selection in an inactive window: grey.
  final Color inactiveSelection;

  /// `App/Terminal/Find Match`.
  final Color findMatch;

  /// The selection colour of an active or inactive window.
  Color selectionColor({required bool active}) =>
      active ? grid.selection : inactiveSelection;
}

/// The profile for the appearance in effect.
Profile profileOf(BuildContext context) => Profile.of(AmalfiTheme.of(context));
