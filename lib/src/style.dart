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

/// The ANSI palette, identical in light and dark (sRGB).
const List<Color> ansiNormal = [
  Color(0xFF000000),
  Color(0xFF990100),
  Color(0xFF00A502),
  Color(0xFF999901),
  Color(0xFF0021B2),
  Color(0xFFB200B2),
  Color(0xFF02A5B3),
  Color(0xFFBFBFBF),
];
const List<Color> ansiBright = [
  Color(0xFF666666),
  Color(0xFFE60000),
  Color(0xFF02D801),
  Color(0xFFE6E600),
  Color(0xFF0033FF),
  Color(0xFFE500E5),
  Color(0xFF03E6E6),
  Color(0xFFE5E5E5),
];

/// A colour profile of the grid (values measured on the reference's default profiles; the
/// names are ours).
@immutable
class GridColors {
  const GridColors({
    required this.background,
    required this.foreground,
    required this.bold,
    required this.selection,
    required this.cursor,
    this.normal = ansiNormal,
    this.bright = ansiBright,
  });

  final Color background;
  final Color foreground;
  final Color bold;
  final Color selection;
  final Color cursor;
  final List<Color> normal;
  final List<Color> bright;

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

/// The other measured default profiles, under our own names (colours only).
final Map<String, GridColors> extraProfiles = {
  'night glass': GridColors(
    background: const Color(0xFF262C38),
    foreground: const Color(0xFFE6E6E6),
    bold: const Color(0xFFF0F0F0),
    selection: const Color(0xFF334D5F),
    cursor: const Color(0xFF9D9D9D),
    normal: _hex([
      0xFF35424B, 0xFFB45647, 0xFF6CAA71, 0xFFC4AC62, //
      0xFF6D96B4, 0xFFBD7BCD, 0xFF7CCACD, 0xFFDEE5EB,
    ]),
    bright: _hex([
      0xFF475C6D, 0xFFDF6C5A, 0xFF79BD7E, 0xFFE5C872, //
      0xFF67B6ED, 0xFFD389E5, 0xFF84DEE0, 0xFFE5EFF5,
    ]),
  ),
  'day glass': GridColors(
    background: const Color(0xFFF6F6F6),
    foreground: const Color(0xFF3A4851),
    bold: const Color(0xFF303D44),
    selection: const Color(0xFFE5ECF1),
    cursor: const Color(0xFF919191),
    normal: _hex([
      0xFF2C3840, 0xFFB45647, 0xFF6CAA71, 0xFFC4AC62, //
      0xFF5685A7, 0xFFAD64BE, 0xFF6AC6CA, 0xFFC1C8CC,
    ]),
    bright: _hex([
      0xFF506573, 0xFFDF6C5A, 0xFF79BD7E, 0xFFE5C872, //
      0xFF49A2E2, 0xFFD389E5, 0xFF77E1E5, 0xFFD8E1E7,
    ]),
  ),
  'meadow': const GridColors(
    background: Color(0xFF13773D),
    foreground: Color(0xFFFFF0A5),
    bold: Color(0xFFFFB03C),
    selection: Color(0xFFB64826),
    cursor: Color(0xFF8E2900),
  ),
  'phosphor': const GridColors(
    background: Color(0xFF0D0D0D),
    foreground: Color(0xFF27FE13),
    bold: Color(0xFF00FA00),
    selection: Color(0xFF494BDB),
    cursor: Color(0xFF38FE26),
  ),
  'paper': const GridColors(
    background: Color(0xFFFEF49C),
    foreground: Color(0xFF000000),
    bold: Color(0xFF000000),
    selection: Color(0xFFBFB875),
    cursor: Color(0xFF9D9D9D),
  ),
  'parchment': const GridColors(
    background: Color(0xFFDFDBC3),
    foreground: Color(0xFF4D2E2D),
    bold: Color(0xFF933A21),
    selection: Color(0xFF929077),
    cursor: Color(0xFF665656),
  ),
  'deep sea': const GridColors(
    background: Color(0xFF2B66C8),
    foreground: Color(0xFFFFFFFF),
    bold: Color(0xFFFFFFFF),
    selection: Color(0xFF2886FF),
    cursor: Color(0xFF9D9D9D),
  ),
  'graphite': const GridColors(
    background: Color(0xFF141414),
    foreground: Color(0xFFF4F4F4),
    bold: Color(0xFFFFFFFF),
    selection: Color(0xFF525252),
    cursor: Color(0xFF606060),
  ),
  'desert': const GridColors(
    background: Color(0xFF8D4136),
    foreground: Color(0xFFD6C9A7),
    bold: Color(0xFFE5C72B),
    selection: Color(0xFF3D1917),
    cursor: Color(0xFFFFFFFF),
  ),
  'silver': const GridColors(
    background: Color(0xFF8A8A8A),
    foreground: Color(0xFF000000),
    bold: Color(0xFFFFFFFF),
    selection: Color(0xFF787A9B),
    cursor: Color(0xFFE0E0E0),
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
