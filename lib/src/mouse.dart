// Mouse reports for programs that ask for them (vim, tmux, htop, less…), as the modes the
// embedder's grid tells (X10 9, normal 1000, button-event 1002, any-event 1003; encodings
// default, UTF-8 1005 and SGR 1006). A report is a button, its modifiers and a cell.

import 'keys.dart';

/// What the pointer did.
enum MouseAction { press, release, motion }

/// A pointer button as a report names it.
enum MouseButton { left, middle, right, none, wheelUp, wheelDown }

/// The report for a pointer event, or null when the program did not ask for it. [x] and [y]
/// are cells, zero-based. [held] is the button down during a motion, if any.
String? encodeMouse(
  TerminalModes modes, {
  required MouseAction action,
  required MouseButton button,
  required int x,
  required int y,
  bool shift = false,
  bool alt = false,
  bool control = false,
}) {
  if (!modes.mouse || x < 0 || y < 0) return null;
  final wheel =
      button == MouseButton.wheelUp || button == MouseButton.wheelDown;
  switch (action) {
    case MouseAction.motion:
      // Button-event mode reports motion with a button down; any-event mode all motion.
      if (wheel) return null;
      if (button == MouseButton.none
          ? !modes.mouseMotion
          : !modes.mouseDrag && !modes.mouseMotion) {
        return null;
      }
    case MouseAction.release:
      // X10 reports presses only; the wheel has no release.
      if (modes.x10Mouse || wheel) return null;
    case MouseAction.press:
      break;
  }
  var code = switch (button) {
    MouseButton.left => 0,
    MouseButton.middle => 1,
    MouseButton.right => 2,
    MouseButton.none => 3,
    MouseButton.wheelUp => 64,
    MouseButton.wheelDown => 65,
  };
  if (!modes.x10Mouse) {
    if (shift) code += 4;
    if (alt) code += 8;
    if (control) code += 16;
  }
  if (action == MouseAction.motion) code += 32;
  final cx = x + 1;
  final cy = y + 1;
  if (modes.sgrMouse) {
    final end = action == MouseAction.release ? 'm' : 'M';
    return '\x1b[<$code;$cx;$cy$end';
  }
  // The older encodings have no release button: the release is "button 3".
  if (action == MouseAction.release) code = (code & ~3) | 3;
  if (modes.utf8Mouse) {
    if (cx > 2015 || cy > 2015) return null;
    return '\x1b[M${String.fromCharCode(32 + code)}'
        '${String.fromCharCode(32 + cx)}${String.fromCharCode(32 + cy)}';
  }
  if (cx > 223 || cy > 223 || code > 223) return null;
  return '\x1b[M${String.fromCharCode(32 + code)}'
      '${String.fromCharCode(32 + cx)}${String.fromCharCode(32 + cy)}';
}

/// Focus reports (DEC mode 1004): `CSI I` when the terminal gains the keyboard, `CSI O` when
/// it loses it; null when the program did not ask.
String? encodeFocus(TerminalModes modes, {required bool focused}) {
  if (!modes.focusEvents) return null;
  return focused ? '\x1b[I' : '\x1b[O';
}

/// The arrow keys a wheel turn becomes in the alternate screen of a program that did not ask
/// for the mouse (DEC mode 1007): [lines] > 0 scrolls up.
String encodeWheelAsArrows(TerminalModes modes, int lines) {
  final up = lines > 0;
  final key = modes.appCursor
      ? (up ? '\x1bOA' : '\x1bOB')
      : (up ? '\x1b[A' : '\x1b[B');
  return key * lines.abs().clamp(0, 50);
}
