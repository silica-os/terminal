// Keys to the bytes a terminal program expects (xterm encoding): Backspace is DEL (^?),
// Ctrl+letter the C0 control, Option as Meta prefixes ESC when enabled, cursor keys follow
// the application-cursor mode (DECCKM), and modifiers on special keys use xterm's
// `CSI 1 ; m X` / `CSI n ; m ~` form (m = 1 + Shift + 2·Alt + 4·Ctrl).

import 'package:flutter/services.dart';

/// What the program asked for (DECCKM, DECKPAM): the bits the embedder's grid sends.
class TerminalModes {
  const TerminalModes(this.bits);
  final int bits;

  static const TerminalModes none = TerminalModes(0);

  bool get appCursor => bits & 1 != 0;
  bool get bracketedPaste => bits & 2 != 0;
  bool get mouse => bits & 4 != 0;
  bool get sgrMouse => bits & 8 != 0;
  bool get focusEvents => bits & 16 != 0;
  bool get altScreen => bits & 32 != 0;
  bool get appKeypad => bits & 64 != 0;

  /// Mouse reporting of drags (1002), of all motion (1003), with UTF-8 coordinates (1005),
  /// in the X10 form (9), and the wheel as arrow keys in the alternate screen (1007).
  bool get mouseDrag => bits & 128 != 0;
  bool get mouseMotion => bits & 256 != 0;
  bool get utf8Mouse => bits & 512 != 0;
  bool get x10Mouse => bits & 1024 != 0;
  bool get alternateScroll => bits & 2048 != 0;
}

/// The bytes for a key press (or repeat); null if the terminal does not handle the key
/// (Command shortcuts, lone modifiers).
String? encodeKey(
  KeyEvent event, {
  required bool shift,
  required bool alt,
  required bool control,
  required bool meta,
  TerminalModes modes = TerminalModes.none,
  bool optionAsMeta = false,
}) {
  if (event is KeyUpEvent) return null;
  // ⌘ belongs to the app (copy, paste, new tab…).
  if (meta) return null;
  final key = event.logicalKey;
  final mod = 1 + (shift ? 1 : 0) + (alt ? 2 : 0) + (control ? 4 : 0);
  final esc = '\x1b';

  String cursor(String letter) {
    if (mod > 1) return '$esc[1;$mod$letter';
    return modes.appCursor ? '${esc}O$letter' : '$esc[$letter';
  }

  String tilde(int n) => mod > 1 ? '$esc[$n;$mod~' : '$esc[$n~';
  String ss3(String letter) =>
      mod > 1 ? '$esc[1;$mod$letter' : '${esc}O$letter';

  final special = <LogicalKeyboardKey, String Function()>{
    LogicalKeyboardKey.arrowUp: () => cursor('A'),
    LogicalKeyboardKey.arrowDown: () => cursor('B'),
    LogicalKeyboardKey.arrowRight: () => cursor('C'),
    LogicalKeyboardKey.arrowLeft: () => cursor('D'),
    LogicalKeyboardKey.home: () => cursor('H'),
    LogicalKeyboardKey.end: () => cursor('F'),
    LogicalKeyboardKey.insert: () => tilde(2),
    LogicalKeyboardKey.delete: () => tilde(3),
    LogicalKeyboardKey.pageUp: () => tilde(5),
    LogicalKeyboardKey.pageDown: () => tilde(6),
    LogicalKeyboardKey.f1: () => ss3('P'),
    LogicalKeyboardKey.f2: () => ss3('Q'),
    LogicalKeyboardKey.f3: () => ss3('R'),
    LogicalKeyboardKey.f4: () => ss3('S'),
    LogicalKeyboardKey.f5: () => tilde(15),
    LogicalKeyboardKey.f6: () => tilde(17),
    LogicalKeyboardKey.f7: () => tilde(18),
    LogicalKeyboardKey.f8: () => tilde(19),
    LogicalKeyboardKey.f9: () => tilde(20),
    LogicalKeyboardKey.f10: () => tilde(21),
    LogicalKeyboardKey.f11: () => tilde(23),
    LogicalKeyboardKey.f12: () => tilde(24),
  };
  final build = special[key];
  if (build != null) return build();

  final prefix = alt && optionAsMeta ? esc : '';
  if (key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter) {
    return '$prefix\r';
  }
  if (key == LogicalKeyboardKey.backspace) {
    // DEL, as every modern terminal sends; Ctrl+Backspace is ^H (erase a word in many shells).
    return control ? '$prefix\b' : '$prefix\x7f';
  }
  if (key == LogicalKeyboardKey.tab) return shift ? '$esc[Z' : '$prefix\t';
  if (key == LogicalKeyboardKey.escape) return '$prefix$esc';

  if (control) {
    final c = _control(key, event.character);
    if (c != null) return '$prefix$c';
  }
  final text = event.character;
  if (text == null || text.isEmpty) return null;
  if (text.runes.any((r) => r < 0x20 || r == 0x7f)) return null;
  return '$prefix$text';
}

/// Ctrl+key → the C0 control character, as xterm does.
String? _control(LogicalKeyboardKey key, String? character) {
  final id = key.keyId;
  // Letters: logical ids are the lowercase code points.
  if (id >= 0x61 && id <= 0x7a) return String.fromCharCode(id - 0x60);
  switch (id) {
    case 0x20: // space
    case 0x32: // 2 / @
      return '\x00';
    case 0x5b: // [
    case 0x33:
      return '\x1b';
    case 0x5c: // backslash
    case 0x34:
      return '\x1c';
    case 0x5d: // ]
    case 0x35:
      return '\x1d';
    case 0x36: // 6 / ^
      return '\x1e';
    case 0x2f: // slash
    case 0x2d: // minus / underscore
    case 0x37:
      return '\x1f';
    case 0x38: // 8 / ?
      return '\x7f';
  }
  return null;
}

/// Pasted text, wrapped for bracketed paste when the program asked for it; line ends as CR.
String encodePaste(String text, TerminalModes modes) {
  final body = text.replaceAll('\r\n', '\r').replaceAll('\n', '\r');
  if (!modes.bracketedPaste) return body;
  // A paste must not be able to end the bracket itself.
  final safe = body.replaceAll('\x1b[201~', '');
  return '\x1b[200~$safe\x1b[201~';
}
