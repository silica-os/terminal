// The terminal on screen: the grid of a session painted by one CustomPainter, over an
// invisible scroll view that gives the measured scroller and the wheel and trackpad scrolling
// of the scrollback. Keys go to the process; the mouse selects, or is reported to programs that
// ask for it (Shift always selects); Command+click opens links.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'grid.dart';
import 'keys.dart';
import 'links.dart';
import 'mouse.dart';
import 'session.dart';
import 'style.dart';

/// How the view looks: colours and font.
@immutable
class TerminalLook {
  const TerminalLook({
    required this.colors,
    required this.selection,
    required this.find,
    required this.currentFind,
    required this.mark,
    this.fontSize = terminalFontSize,
    this.fontFamily = terminalFontFamily,
    this.boldFace = true,
  });

  final GridColors colors;
  final Color selection;
  final Color find;
  final Color currentFind;
  final Color mark;
  final double fontSize;
  final String fontFamily;
  final bool boldFace;

  double get cellWidth => cellWidthFor(fontSize);
  double get cellHeight => cellHeightFor(fontSize);

  @override
  bool operator ==(Object other) =>
      other is TerminalLook &&
      other.colors == colors &&
      other.selection == selection &&
      other.find == find &&
      other.currentFind == currentFind &&
      other.mark == mark &&
      other.fontSize == fontSize &&
      other.fontFamily == fontFamily &&
      other.boldFace == boldFace;

  @override
  int get hashCode => Object.hash(
    colors,
    selection,
    find,
    currentFind,
    mark,
    fontSize,
    fontFamily,
    boldFace,
  );
}

class TerminalView extends StatefulWidget {
  const TerminalView({
    super.key,
    required this.session,
    required this.look,
    required this.focusNode,
    required this.decor,
    this.padding = gridPadding,
    this.optionAsMeta = false,
    this.mouseReporting = true,
    this.openLinks = true,
    this.autofocus = true,
    this.onKeyEvent,
    this.onOpenLink,
    this.onContextMenu,
  });

  final TerminalSession session;
  final TerminalLook look;
  final FocusNode focusNode;
  final GridDecor decor;
  final EdgeInsets padding;
  final bool optionAsMeta;

  /// Programs that ask for the mouse get it (Shift still selects).
  final bool mouseReporting;

  /// Command+click opens links.
  final bool openLinks;
  final bool autofocus;

  /// Sees every key first; handled keys do not reach the process.
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;

  /// Command+click on a link.
  final void Function(String target)? onOpenLink;

  /// The secondary button was pressed on the grid (not reported to the program).
  final void Function(Offset globalPosition)? onContextMenu;

  @override
  State<TerminalView> createState() => TerminalViewState();
}

class TerminalViewState extends State<TerminalView> {
  final ScrollController _scroll = ScrollController();
  ParagraphCache _cache = ParagraphCache();
  Size _viewport = Size.zero;
  (int, int)? _size;
  bool _syncing = false;
  bool _syncScheduled = false;
  Timer? _blink;
  Timer? _autoScroll;

  GridState get _grid => widget.session.grid;
  TerminalLook get _look => widget.look;

  @override
  void initState() {
    super.initState();
    _grid.addListener(_gridChanged);
    _scroll.addListener(_scrolled);
    widget.focusNode.addListener(_focusChanged);
    _bellSeen = _grid.bells.value;
    _grid.bells.addListener(_bell);
    _modes = _grid.modes.bits;
  }

  @override
  void didUpdateWidget(TerminalView old) {
    super.didUpdateWidget(old);
    if (old.session != widget.session) {
      old.session.grid.removeListener(_gridChanged);
      old.session.grid.bells.removeListener(_bell);
      _grid.addListener(_gridChanged);
      _grid.bells.addListener(_bell);
      _bellSeen = _grid.bells.value;
      _size = null;
      _modes = _grid.modes.bits;
    }
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_focusChanged);
      widget.focusNode.addListener(_focusChanged);
    }
    if (old.look != widget.look) {
      _cache.dispose();
      _cache = ParagraphCache();
      _size = null;
    }
  }

  @override
  void dispose() {
    _grid.removeListener(_gridChanged);
    _grid.bells.removeListener(_bell);
    widget.focusNode.removeListener(_focusChanged);
    _scroll.dispose();
    _cache.dispose();
    _blink?.cancel();
    _autoScroll?.cancel();
    _bellTicker?.dispose();
    super.dispose();
  }

  // ---- size and scrolling -----------------------------------------------------------

  void _layout(Size size) {
    _viewport = size;
    final inner = widget.padding.deflateSize(size);
    final cols = (inner.width / _look.cellWidth).floor().clamp(1, 1000);
    final rows = (inner.height / _look.cellHeight).floor().clamp(1, 1000);
    if (_size == (rows, cols)) return;
    _size = (rows, cols);
    final session = widget.session;
    final width = (cols * _look.cellWidth).round();
    final height = (rows * _look.cellHeight).round();
    // Not during layout: the session may notify its listeners.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.session == session && _size == (rows, cols)) {
        session
            .attach(rows, cols, pixelWidth: width, pixelHeight: height)
            .ignore();
      }
    });
  }

  int _modes = 0;

  void _gridChanged() {
    final modes = _grid.modes.bits;
    if (modes != _modes) {
      _modes = modes;
      if (mounted) setState(() {});
    } else if (_scroll.hasClients) {
      // The scroller's extent follows the scrollback; redo it after the layout.
      if (!_syncScheduled) {
        _syncScheduled = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _syncScheduled = false;
          _followGrid();
        });
      }
    }
    _blinkTimer();
    if (_historySeen != _grid.history) {
      _historySeen = _grid.history;
      if (mounted) setState(() {});
    }
  }

  int _historySeen = 0;

  /// Puts the scroller where the grid says the view is.
  void _followGrid() {
    if (!mounted || !_scroll.hasClients) return;
    final position = _scroll.position;
    final target = ((_grid.history - _grid.offset) * _look.cellHeight).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((position.pixels - target).abs() < 0.5) return;
    _syncing = true;
    _scroll.jumpTo(target);
    _syncing = false;
  }

  /// The user moved the scroller (wheel, trackpad, thumb): tell the embedder.
  void _scrolled() {
    if (_syncing || !_scroll.hasClients) return;
    final lines = _scroll.position.pixels / _look.cellHeight;
    final offset = (_grid.history - lines.round()).clamp(0, _grid.history);
    if (offset != _grid.offset) widget.session.scrollToOffset(offset);
  }

  // ---- focus, blink, bell -----------------------------------------------------------

  bool _hadFocus = false;

  void _focusChanged() {
    final focused = widget.focusNode.hasFocus;
    if (focused == _hadFocus) return;
    _hadFocus = focused;
    final report = encodeFocus(_grid.modes, focused: focused);
    if (report != null) widget.session.write(report);
  }

  void _blinkTimer() {
    final wants =
        _grid.cursorBlinks && widget.decor.active && _grid.cursorVisible;
    if (wants && _blink == null) {
      _blink = Timer.periodic(cursorBlinkHalf, (_) {
        widget.decor.update(cursorOn: !widget.decor.cursorOn);
      });
    } else if (!wants && _blink != null) {
      _blink?.cancel();
      _blink = null;
      widget.decor.update(cursorOn: true);
    }
  }

  int _bellSeen = 0;
  Ticker? _bellTicker;

  void _bell() {
    if (_grid.bells.value == _bellSeen) return;
    _bellSeen = _grid.bells.value;
    flash();
  }

  /// The visual bell: a flash that fades in 150 ms.
  void flash() {
    _bellTicker?.dispose();
    _bellTicker = Ticker((elapsed) {
      final t = elapsed.inMilliseconds / 150;
      if (t >= 1) {
        widget.decor.update(bell: 0);
        _bellTicker?.stop();
      } else {
        widget.decor.update(bell: 1 - t);
      }
    })..start();
  }

  // ---- keys -------------------------------------------------------------------------

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    final first = widget.onKeyEvent?.call(node, event);
    if (first == KeyEventResult.handled) return first!;
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    final modes = _grid.modes;
    final key = event.logicalKey;
    if (keyboard.isShiftPressed &&
        !keyboard.isControlPressed &&
        !keyboard.isAltPressed &&
        !keyboard.isMetaPressed &&
        !modes.altScreen) {
      if (key == LogicalKeyboardKey.pageUp) {
        widget.session.scrollPage(1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.pageDown) {
        widget.session.scrollPage(-1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.home) {
        widget.session.scrollTo('top');
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.end) {
        widget.session.scrollTo('bottom');
        return KeyEventResult.handled;
      }
    }
    final bytes = encodeKey(
      event,
      shift: keyboard.isShiftPressed,
      alt: keyboard.isAltPressed,
      control: keyboard.isControlPressed,
      meta: keyboard.isMetaPressed,
      modes: modes,
      optionAsMeta: widget.optionAsMeta,
    );
    if (bytes == null) return KeyEventResult.ignored;
    if (_grid.offset > 0) widget.session.scrollTo('bottom');
    widget.decor.update(cursorOn: true);
    widget.session.write(bytes);
    return KeyEventResult.handled;
  }

  // ---- the pointer ------------------------------------------------------------------

  /// The cell under a point of the view, and whether it is in the right half of it.
  (int, int, bool) _cellAt(Offset local) {
    final dx = local.dx - widget.padding.left;
    final dy = local.dy - widget.padding.top;
    final cw = _look.cellWidth;
    final x = (dx / cw).floor().clamp(0, _grid.cols - 1);
    final y = (dy / _look.cellHeight).floor().clamp(0, _grid.rows - 1);
    final right = dx - x * cw > cw / 2;
    return (x, y, right);
  }

  bool get _reporting => _grid.modes.mouse && widget.mouseReporting;

  bool _shift() => HardwareKeyboard.instance.isShiftPressed;
  bool _alt() => HardwareKeyboard.instance.isAltPressed;
  bool _ctrl() => HardwareKeyboard.instance.isControlPressed;
  bool _meta() => HardwareKeyboard.instance.isMetaPressed;

  MouseButton? _held;
  (int, int)? _lastCell;
  bool _selecting = false;
  bool _dragged = false;
  int _clicks = 0;
  Duration? _lastDown;
  Offset _lastDownAt = Offset.zero;
  (int, int, bool)? _lastSelected;
  Offset? _lastLocal;

  void _report(MouseAction action, MouseButton button, int x, int y) {
    final text = encodeMouse(
      _grid.modes,
      action: action,
      button: button,
      x: x,
      y: y,
      shift: _shift(),
      alt: _alt(),
      control: _ctrl(),
    );
    if (text != null) widget.session.write(text);
  }

  MouseButton _buttonOf(int buttons) {
    if (buttons & kPrimaryButton != 0) return MouseButton.left;
    if (buttons & kMiddleMouseButton != 0) return MouseButton.middle;
    if (buttons & kSecondaryButton != 0) return MouseButton.right;
    return MouseButton.none;
  }

  void _down(PointerDownEvent event) {
    widget.focusNode.requestFocus();
    if (event.kind == PointerDeviceKind.touch) return;
    final (x, y, right) = _cellAt(event.localPosition);
    _lastLocal = event.localPosition;
    final button = _buttonOf(event.buttons);
    final reporting = _reporting && !_shift();
    if (button == MouseButton.left && _meta() && widget.openLinks) {
      final link = _grid.lines.length > y ? linkAt(_grid.lines[y], y, x) : null;
      if (link != null) {
        widget.onOpenLink?.call(link.target);
        return;
      }
    }
    if (reporting) {
      _held = button;
      _lastCell = (x, y);
      _report(MouseAction.press, button, x, y);
      return;
    }
    switch (button) {
      case MouseButton.right:
        widget.onContextMenu?.call(event.position);
      case MouseButton.middle:
        widget.session.pastePrimary();
      case MouseButton.left:
        _startSelection(event, x, y, right);
      default:
        break;
    }
  }

  void _startSelection(PointerDownEvent event, int x, int y, bool right) {
    final now = event.timeStamp;
    final near =
        (event.localPosition - _lastDownAt).distance <= _look.cellWidth;
    final quick =
        _lastDown != null &&
        now - _lastDown! <= const Duration(milliseconds: 500);
    _clicks = quick && near ? _clicks % 3 + 1 : 1;
    _lastDown = now;
    _lastDownAt = event.localPosition;
    _selecting = true;
    _dragged = false;
    if (_shift() && _grid.selection.isNotEmpty && _clicks == 1) {
      // Shift+click extends the selection.
      widget.session.select('update', x: x, y: y, right: right).ignore();
      _lastSelected = (x, y, right);
      return;
    }
    final kind = switch (_clicks) {
      2 => 'semantic',
      3 => 'lines',
      _ => _alt() ? 'block' : 'simple',
    };
    widget.session.selectionRow = widget.session.topRow + y;
    widget.session
        .select('start', kind: kind, x: x, y: y, right: right)
        .ignore();
    _lastSelected = (x, y, right);
  }

  void _move(PointerMoveEvent event) {
    _lastLocal = event.localPosition;
    final (x, y, right) = _cellAt(event.localPosition);
    final held = _held;
    if (held != null) {
      if (_lastCell != (x, y)) {
        _lastCell = (x, y);
        _report(MouseAction.motion, held, x, y);
      }
      return;
    }
    if (!_selecting) return;
    _dragged = true;
    if (_lastSelected != (x, y, right)) {
      _lastSelected = (x, y, right);
      widget.session.select('update', x: x, y: y, right: right).ignore();
    }
    _autoScrollFor(event.localPosition);
  }

  /// Dragging past the top or bottom scrolls the scrollback under the selection.
  void _autoScrollFor(Offset local) {
    final top = widget.padding.top;
    final bottom = _viewport.height - widget.padding.bottom;
    final by = local.dy < top
        ? 1 + ((top - local.dy) / _look.cellHeight).floor()
        : local.dy > bottom
        ? -1 - ((local.dy - bottom) / _look.cellHeight).floor()
        : 0;
    if (by == 0) {
      _autoScroll?.cancel();
      _autoScroll = null;
      return;
    }
    _autoScroll ??= Timer.periodic(const Duration(milliseconds: 50), (_) {
      final local = _lastLocal;
      if (local == null || !_selecting) return;
      final (x, y, right) = _cellAt(local);
      widget.session.scrollLines(by.clamp(-10, 10));
      widget.session.select('update', x: x, y: y, right: right).ignore();
    });
  }

  void _up(PointerUpEvent event) {
    final held = _held;
    if (held != null) {
      final (x, y, _) = _cellAt(event.localPosition);
      _held = null;
      _report(MouseAction.release, held, x, y);
      return;
    }
    if (!_selecting) return;
    _selecting = false;
    _autoScroll?.cancel();
    _autoScroll = null;
    if (!_dragged && _clicks == 1) {
      // A click without a drag only moves the focus: it leaves no selection.
      widget.session.selectionRow = null;
      widget.session.select('clear').ignore();
      return;
    }
    // The finished selection becomes the primary one, pasted by the middle button.
    widget.session.selectionText().then((text) {
      if (text != null) PrimarySelection.text = text;
    });
  }

  void _hover(PointerHoverEvent event) {
    _lastLocal = event.localPosition;
    final (x, y, _) = _cellAt(event.localPosition);
    if (widget.openLinks && _meta() && y < _grid.lines.length) {
      final link = linkAt(_grid.lines[y], y, x);
      widget.decor.update(link: link?.span, clearLink: link == null);
    } else if (widget.decor.link != null) {
      widget.decor.update(clearLink: true);
    }
    if (_reporting && !_shift() && _lastCell != (x, y)) {
      _lastCell = (x, y);
      _report(MouseAction.motion, MouseButton.none, x, y);
    }
  }

  double _wheelRemainder = 0;

  void _signal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final dy = event.scrollDelta.dy;
    if (dy == 0) return;
    final modes = _grid.modes;
    final reporting = _reporting && !_shift();
    final arrows = !modes.mouse && modes.altScreen && modes.alternateScroll;
    if (!reporting && !arrows) return;
    // Whole lines: a wheel notch is a few lines, a trackpad's pixels add up.
    _wheelRemainder += dy / _look.cellHeight;
    var lines = _wheelRemainder.truncate();
    if (lines == 0) lines = dy > 0 ? 1 : -1;
    _wheelRemainder -= _wheelRemainder.truncate();
    _wheel(-lines, event.localPosition);
  }

  /// Wheel turns of [lines] (positive: up) to the program: reports, or arrow keys.
  void _wheel(int lines, Offset local) {
    final modes = _grid.modes;
    if (lines == 0) return;
    if (_reporting && !_shift()) {
      final (x, y, _) = _cellAt(local);
      final button = lines > 0 ? MouseButton.wheelUp : MouseButton.wheelDown;
      for (var i = 0; i < lines.abs().clamp(1, 20); i++) {
        _report(MouseAction.press, button, x, y);
      }
    } else {
      widget.session.write(encodeWheelAsArrows(modes, lines));
    }
  }

  double _panRemainder = 0;

  void _pan(PointerPanZoomUpdateEvent event) {
    final modes = _grid.modes;
    final reporting = _reporting && !_shift();
    final arrows = !modes.mouse && modes.altScreen && modes.alternateScroll;
    if (!reporting && !arrows) return;
    _panRemainder += event.panDelta.dy / _look.cellHeight;
    final lines = _panRemainder.truncate();
    if (lines == 0) return;
    _panRemainder -= lines;
    _wheel(lines, event.localPosition);
  }

  // ---- build ------------------------------------------------------------------------

  bool get _wheelGoesToProgram {
    final modes = _grid.modes;
    return (modes.mouse && widget.mouseReporting) ||
        (modes.altScreen && modes.alternateScroll);
  }

  @override
  Widget build(BuildContext context) {
    final look = _look;
    final text = terminalTextStyle(look.fontSize, family: look.fontFamily);
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _key,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = Size(
            box.maxWidth.isFinite ? box.maxWidth : 0,
            box.maxHeight.isFinite ? box.maxHeight : 0,
          );
          _layout(size);
          final extra = _grid.history * look.cellHeight;
          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _down,
            onPointerMove: _move,
            onPointerUp: _up,
            onPointerHover: _hover,
            onPointerSignal: _signal,
            onPointerPanZoomUpdate: _pan,
            child: ListenableBuilder(
              listenable: widget.decor,
              builder: (context, child) => MouseRegion(
                cursor: widget.decor.link != null
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.text,
                child: child,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: size,
                        painter: GridPainter(
                          _grid,
                          colors: look.colors,
                          style: text,
                          cellWidth: look.cellWidth,
                          cellHeight: look.cellHeight,
                          padding: widget.padding,
                          cache: _cache,
                          decor: widget.decor,
                          selectionColor: look.selection,
                          findColor: look.find,
                          currentFindColor: look.currentFind,
                          markColor: look.mark,
                          boldFace: look.boldFace,
                        ),
                      ),
                    ),
                  ),
                  AmalfiScrollbar(
                    key: const ValueKey('scroller'),
                    child: SingleChildScrollView(
                      controller: _scroll,
                      physics: _wheelGoesToProgram
                          ? const NeverScrollableScrollPhysics()
                          : const ClampingScrollPhysics(),
                      child: SizedBox(
                        height: size.height + extra,
                        width: size.width,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
