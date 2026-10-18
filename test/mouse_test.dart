import 'package:flutter_test/flutter_test.dart';
import 'package:terminal/src/keys.dart';
import 'package:terminal/src/mouse.dart';

void main() {
  // Mode bits as the embedder sends them: 4 any mouse, 8 SGR, 16 focus, 128 drag, 256 motion,
  // 512 UTF-8, 1024 X10, 2048 alternate scroll.
  const normal = TerminalModes(4);
  const drag = TerminalModes(4 | 128);
  const any = TerminalModes(4 | 256);
  const sgr = TerminalModes(4 | 8);
  const x10 = TerminalModes(4 | 1024);
  const utf8 = TerminalModes(4 | 512);

  String? send(
    TerminalModes modes,
    MouseAction action,
    MouseButton button, {
    int x = 0,
    int y = 0,
    bool shift = false,
    bool alt = false,
    bool control = false,
  }) => encodeMouse(
    modes,
    action: action,
    button: button,
    x: x,
    y: y,
    shift: shift,
    alt: alt,
    control: control,
  );

  test('nothing is reported unless the program asked', () {
    expect(
      send(TerminalModes.none, MouseAction.press, MouseButton.left),
      isNull,
    );
  });

  test('normal mode: press and release, default encoding', () {
    expect(
      send(normal, MouseAction.press, MouseButton.left, x: 4, y: 9),
      '\x1b[M ${String.fromCharCode(32 + 5)}${String.fromCharCode(32 + 10)}',
    );
    // The release names no button.
    expect(
      send(normal, MouseAction.release, MouseButton.left, x: 4, y: 9),
      '\x1b[M#${String.fromCharCode(37)}${String.fromCharCode(42)}',
    );
    // Modifiers: shift 4, alt 8, control 16.
    expect(
      send(
        normal,
        MouseAction.press,
        MouseButton.right,
        shift: true,
        alt: true,
        control: true,
      ),
      '\x1b[M${String.fromCharCode(32 + 2 + 4 + 8 + 16)}!!',
    );
    // Motion is not reported in normal mode.
    expect(send(normal, MouseAction.motion, MouseButton.left), isNull);
    expect(send(normal, MouseAction.motion, MouseButton.none), isNull);
  });

  test('button-event mode reports drags, any-event mode all motion', () {
    expect(send(drag, MouseAction.motion, MouseButton.left, x: 1), isNotNull);
    expect(send(drag, MouseAction.motion, MouseButton.none), isNull);
    expect(send(any, MouseAction.motion, MouseButton.none), isNotNull);
    expect(send(any, MouseAction.motion, MouseButton.left), isNotNull);
    // Motion sets bit 32: 0 + 32 + 32 offset.
    expect(send(drag, MouseAction.motion, MouseButton.left), '\x1b[M@!!');
  });

  test('SGR keeps the release button and goes beyond column 223', () {
    expect(
      send(sgr, MouseAction.press, MouseButton.left, x: 299, y: 0),
      '\x1b[<0;300;1M',
    );
    expect(
      send(sgr, MouseAction.release, MouseButton.right, x: 1, y: 1),
      '\x1b[<2;2;2m',
    );
    expect(
      send(sgr, MouseAction.press, MouseButton.wheelUp, x: 0, y: 0),
      '\x1b[<64;1;1M',
    );
    expect(
      send(sgr, MouseAction.press, MouseButton.wheelDown, shift: true),
      '\x1b[<69;1;1M',
    );
    expect(send(sgr, MouseAction.release, MouseButton.wheelUp), isNull);
  });

  test('the default encoding drops what it cannot say', () {
    expect(send(normal, MouseAction.press, MouseButton.left, x: 223), isNull);
    expect(
      send(normal, MouseAction.press, MouseButton.left, x: 221),
      isNotNull,
    );
    expect(send(normal, MouseAction.press, MouseButton.left, x: -1), isNull);
  });

  test('UTF-8 coordinates reach 2015', () {
    expect(
      send(utf8, MouseAction.press, MouseButton.left, x: 299, y: 0),
      '\x1b[M ${String.fromCharCode(32 + 300)}!',
    );
    expect(send(utf8, MouseAction.press, MouseButton.left, x: 2015), isNull);
  });

  test('X10 reports presses only, without modifiers', () {
    expect(
      send(x10, MouseAction.press, MouseButton.left, x: 0, y: 0, shift: true),
      '\x1b[M !!',
    );
    expect(send(x10, MouseAction.release, MouseButton.left), isNull);
    expect(send(x10, MouseAction.motion, MouseButton.left), isNull);
  });

  test('focus reports follow mode 1004', () {
    expect(encodeFocus(const TerminalModes(16), focused: true), '\x1b[I');
    expect(encodeFocus(const TerminalModes(16), focused: false), '\x1b[O');
    expect(encodeFocus(TerminalModes.none, focused: true), isNull);
  });

  test('the wheel becomes arrow keys in the alternate screen', () {
    expect(encodeWheelAsArrows(TerminalModes.none, 3), '\x1b[A\x1b[A\x1b[A');
    expect(encodeWheelAsArrows(TerminalModes.none, -2), '\x1b[B\x1b[B');
    expect(encodeWheelAsArrows(const TerminalModes(1), 1), '\x1bOA');
    expect(encodeWheelAsArrows(TerminalModes.none, 500).length, 150);
  });
}
