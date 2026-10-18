// The Terminal window on the Amalfi kit (`App · Terminal`): the 32 pt title band (the window
// controls sit in it, the empty band moves the window), the 36 pt tab bar always visible, the
// 32 pt find bar that grows the window, and the character grid in a 12 pt padding with an
// overlay scroll bar.
//
// Commands (docs/spec.md) are the items of the menus published to Silica's menu bar (menus()):
// terminal.new_tab ⌘T, terminal.close_tab ⌘W, terminal.next_tab ⌃⇥, terminal.previous_tab ⌃⇧⇥,
// terminal.find ⌘F, terminal.copy ⌘C, terminal.paste ⌘V, terminal.select_all ⌘A and the scroll
// and find commands (⌘ is the Logo key; Ctrl+Shift+C/V copy and paste too).

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'app.dart';
import 'grid.dart';
import 'inspector.dart';
import 'l10n.dart';
import 'links.dart';
import 'pty.dart';
import 'session.dart';
import 'settings.dart';
import 'settings_window.dart';
import 'style.dart';
import 'terminal_view.dart';

class _StepTabIntent extends Intent {
  const _StepTabIntent(this.by);
  final int by;
}

/// The window commands that work inside the grid (which takes every other key for the
/// program) besides the menu bar's: switching tabs with Ctrl. The Logo-key shortcuts (⌘T, ⌘W,
/// ⌘F…) are the menu bar's (`SilicaMenuBar` binds them).
const Map<ShortcutActivator, Intent> windowShortcuts = {
  SingleActivator(LogicalKeyboardKey.tab, control: true): _StepTabIntent(1),
  SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true):
      _StepTabIntent(-1),
};

class TerminalWindow extends StatefulWidget {
  const TerminalWindow({
    super.key,
    required this.app,
    this.seed = const WindowSeed(),
    this.onLastTabClosed,
    this.onTitle,
  });

  final TerminalApp app;

  /// What the window opens with: a profile, a command, a directory, or tabs moved here.
  final WindowSeed seed;

  /// The last tab was closed (the app closes its window).
  final VoidCallback? onLastTabClosed;

  /// The window title changed (windows other than the main one set it themselves).
  final void Function(String title)? onTitle;

  @override
  State<TerminalWindow> createState() => TerminalWindowState();
}

/// A tab: its session and what the view shows besides the rows.
class _Tab {
  _Tab(this.session) : decor = GridDecor();
  final TerminalSession session;
  final GridDecor decor;
  final FocusNode focus = FocusNode(debugLabel: 'grid');

  /// A bell rang while the tab was in the background.
  bool belled = false;

  /// The tab shows two views of its session (View › Split Pane).
  bool split = false;
  final GridDecor splitDecor = GridDecor();
  final FocusNode splitFocus = FocusNode(debugLabel: 'split');

  /// The tab title set by the user (Edit Title); null: the program's.
  String? customTitle;
  VoidCallback? bellListener;

  void dispose() {
    decor.dispose();
    focus.dispose();
    splitDecor.dispose();
    splitFocus.dispose();
  }
}

/// A tab in the bar: its session and how far in it is (0 → 1 entering, 1 → 0 closing).
class _TabSlot {
  _TabSlot(this.tab, this.presence);
  final _Tab tab;
  final AnimationController presence;
  bool closing = false;
}

/// A question the window asks with a text field (New Command, Edit Title…).
class _Prompt {
  _Prompt({
    required this.title,
    required this.message,
    required this.confirm,
    required this.onSubmit,
    this.placeholder,
    String initial = '',
  }) : controller = TextEditingController(text: initial);
  final String title;
  final String message;
  final String confirm;
  final String? placeholder;
  final TextEditingController controller;
  final void Function(String text) onSubmit;
}

class TerminalWindowState extends State<TerminalWindow>
    with TickerProviderStateMixin {
  final List<_Tab> _tabs = [];
  int _current = 0;

  /// The tabs drawn in the bar, closing ones included until they have shrunk away.
  final List<_TabSlot> _slots = [];

  bool _finding = false;
  final TextEditingController _query = TextEditingController();
  late final FocusNode _queryFocus = FocusNode(onKeyEvent: _findKey);
  List<FindMatch> _matches = const [];
  int _match = 0;
  Timer? _refind;

  /// The tab waiting for the answer of the "terminate running processes?" alert.
  _Tab? _confirming;

  /// The answer to the same alert asked for the whole window (its close button, Logo+W).
  Completer<bool>? _confirmingWindow;
  _Prompt? _prompt;
  bool _showTabBar = true;

  /// The font size set with Bigger and Smaller; null: the profile's.
  double? _fontSize;

  TerminalApp get _app => widget.app;
  TerminalSettings get _settings => _app.settings;

  bool _windowActive = _isActive(WidgetsBinding.instance.lifecycleState);
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onStateChange: (state) {
      final active = _isActive(state);
      if (active == _windowActive) return;
      setState(() => _windowActive = active);
      if (_tabs.isNotEmpty) _tab.decor.update(active: active);
      // An inactive window shows a hollow cursor and a grey selection.
      if (active) {
        _app.claimMenus(this);
        if (!_finding && _prompt == null) _tab.focus.requestFocus();
      }
    },
  );

  StreamSubscription<SilicaDragEvent>? _drops;

  static bool _isActive(AppLifecycleState? state) =>
      state == null || state == AppLifecycleState.resumed;

  /// The tabs, in order (tests).
  List<TerminalSession> get tabs => [for (final t in _tabs) t.session];
  int get current => _current;
  TerminalSession get session => _tabs[_current].session;
  _Tab get _tab => _tabs[_current];

  /// The decoration of the current tab's view (tests).
  GridDecor get decor => _tab.decor;

  /// The font size in effect.
  double get fontSize => _fontSize ?? _profile.fontSize;

  /// The profile of the current tab.
  TerminalProfile get _profile =>
      _tabs.isEmpty ? _settings.defaultProfile : session.profile;

  /// The id of this window's view, if it is built.
  int? get viewIdOrNull => mounted ? View.maybeOf(context)?.viewId : null;

  @override
  void initState() {
    super.initState();
    _lifecycle;
    _app.windows.add(this);
    _app.active ??= this;
    _app.menuOwner.addListener(_ownerChanged);
    if (_app.menuOwner.value == null) _app.menuOwner.value = this;
    _settings.addListener(_settingsChanged);
    PrimarySelection.listenable.addListener(_changed);
    SilicaWindows.onMainCloseRequested = requestCloseWindow;
    _drops = SilicaDrag.events.listen(_drag);
    if (widget.seed.sessions.isNotEmpty) {
      for (final s in widget.seed.sessions) {
        adopt(s);
      }
    } else {
      _openTab(
        profile: widget.seed.profile,
        command: widget.seed.command,
        cwd: widget.seed.cwd ?? _app.cwd,
        animate: false,
      );
    }
  }

  @override
  void dispose() {
    _app.windows.remove(this);
    _app.menuOwner.removeListener(_ownerChanged);
    _app.releaseMenus(this);
    if (_app.active == this) {
      _app.active = _app.windows.isEmpty ? null : _app.windows.first;
    }
    _settings.removeListener(_settingsChanged);
    PrimarySelection.listenable.removeListener(_changed);
    if (SilicaWindows.onMainCloseRequested == requestCloseWindow) {
      SilicaWindows.onMainCloseRequested = null;
    }
    _drops?.cancel();
    _refind?.cancel();
    _lifecycle.dispose();
    for (final tab in _tabs) {
      _detach(tab);
      tab.session.dispose();
      tab.dispose();
    }
    for (final slot in _slots) {
      slot.presence.dispose();
    }
    _query.dispose();
    _queryFocus.dispose();
    _prompt?.controller.dispose();
    super.dispose();
  }

  void _ownerChanged() {
    if (!mounted) return;
    // Another window may let go of the menu bar while the tree is being built or torn down.
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.transientCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  void _settingsChanged() {
    if (!mounted) return;
    // A profile changed in the settings reaches the tabs that use it.
    for (final tab in _tabs) {
      final fresh = _settings.profileById(tab.session.profile.id);
      if (fresh != null && fresh != tab.session.profile) {
        tab.session.apply(fresh);
      }
      tab.session.allowClipboard(
        write: _settings.clipboardWrite,
        read: _settings.clipboardRead,
      );
    }
    setState(() {});
  }

  // ---- tabs -------------------------------------------------------------------------

  /// Opens a new tab after the current one and makes it current: with [profile] (the
  /// default one otherwise), in the directory of the current tab if the settings say so.
  Future<void> newTab({
    TerminalProfile? profile,
    List<String>? command,
    String? cwd,
  }) async {
    var directory = cwd;
    if (directory == null &&
        _tabs.isNotEmpty &&
        _settings.newTabDirectory == NewDirectory.sameAsCurrent) {
      directory = session.grid.cwd;
      if (directory == null && session.started && !session.ended) {
        final current = session;
        directory = await current.workingDirectory();
        if (!mounted) return;
      }
    }
    _openTab(
      profile: profile ?? (_tabs.isEmpty ? null : _profileForNewTab()),
      command: command ?? _app.command,
      cwd: directory ?? _app.cwd,
    );
  }

  /// A new tab uses the profile of the current one (the settings: same profile).
  TerminalProfile _profileForNewTab() =>
      _settings.profileById(session.profile.id) ?? _settings.defaultProfile;

  TerminalSession _makeSession({
    TerminalProfile? profile,
    List<String>? command,
    String? cwd,
  }) => TerminalSession(
    pty: _app.pty,
    command: command,
    cwd: cwd,
    shellName: command?.first.split('/').last ?? _app.shellName,
    profile: profile ?? _settings.defaultProfile,
    clipboardWrite: _settings.clipboardWrite,
    clipboardRead: _settings.clipboardRead,
    onExit: _exited,
  );

  void _openTab({
    TerminalProfile? profile,
    List<String>? command,
    String? cwd,
    bool animate = true,
  }) {
    final session = _makeSession(
      profile: profile,
      command: command ?? _app.command,
      cwd: cwd,
    );
    _insert(session, animate: animate && _tabs.isNotEmpty);
  }

  /// Takes a running session into this window (a tab moved here).
  void adopt(TerminalSession session) {
    _insert(session, animate: _tabs.isNotEmpty);
  }

  void _insert(TerminalSession session, {required bool animate}) {
    // A tab that arrives from another window shows one view: its split starts again.
    if (session.split != null) session.closeSplit();
    final tab = _Tab(session);
    tab.bellListener = () => _belled(tab);
    tab.focus.addListener(() {
      if (tab.focus.hasFocus && mounted) _app.claimMenus(this);
    });
    session.grid.bells.addListener(tab.bellListener!);
    session.addListener(_changed);
    session.grid.addListener(_gridChanged);
    // The new tab slides in from the right and settles in ~550 ms.
    final presence = AnimationController(
      vsync: this,
      duration: tabEnter,
      reverseDuration: tabExit,
    );
    setState(() {
      final at = _tabs.isEmpty ? 0 : _current + 1;
      final after = _tabs.isEmpty ? null : _tabs[_current];
      _tabs.insert(at, tab);
      _current = at;
      final slotAt = after == null
          ? _slots.length
          : _slots.indexWhere((s) => s.tab == after) + 1;
      _slots.insert(slotAt.clamp(0, _slots.length), _TabSlot(tab, presence));
    });
    if (animate) {
      presence.forward();
    } else {
      presence.value = 1;
    }
    tab.decor.update(active: _windowActive);
    _endFind();
  }

  void _detach(_Tab tab) {
    final listener = tab.bellListener;
    if (listener != null) tab.session.grid.bells.removeListener(listener);
    tab.session.removeListener(_changed);
    tab.session.grid.removeListener(_gridChanged);
  }

  /// Gives up a tab without ending it (it moves to another window).
  TerminalSession release(TerminalSession session) {
    final i = _tabs.indexWhere((t) => t.session == session);
    if (i < 0) return session;
    final tab = _tabs.removeAt(i);
    _detach(tab);
    for (final slot in _slots.where((s) => s.tab == tab).toList()) {
      _slots.remove(slot);
      slot.presence.dispose();
    }
    tab.dispose();
    if (_tabs.isEmpty) {
      widget.onLastTabClosed?.call();
    } else {
      setState(() => _current = _current.clamp(0, _tabs.length - 1));
    }
    return session;
  }

  /// Closes a tab (and its process); the last one closes the window.
  void closeTab([int? index]) {
    final i = index ?? _current;
    if (i < 0 || i >= _tabs.length) return;
    final tab = _tabs.removeAt(i);
    _detach(tab);
    tab.session.dispose();
    // The closed tab shrinks away in ~500 ms while the others grow.
    for (final slot in _slots.where((s) => s.tab == tab).toList()) {
      slot.closing = true;
      slot.presence.reverse().whenCompleteOrCancel(() {
        if (!mounted) return;
        setState(() => _slots.remove(slot));
        slot.presence.dispose();
      });
    }
    if (_tabs.isEmpty) {
      widget.onLastTabClosed?.call();
      setState(() {});
      return;
    }
    setState(() => _current = _current.clamp(0, _tabs.length - 1));
    _endFind();
    _tab.belled = false;
  }

  /// The shell of a session ended: closes the tab if the profile says so.
  void _exited(TerminalSession session, SessionExit exit) {
    final i = _tabs.indexWhere((t) => t.session == session);
    if (i < 0) return;
    final close = switch (session.profile.closeOnExit) {
      CloseOnExit.close => true,
      CloseOnExit.closeIfClean => exit.clean,
      CloseOnExit.keep => false,
    };
    if (close) closeTab(i);
  }

  /// Whether closing needs the user's word: per the profile, always, never, or when a
  /// program other than the shell runs in the tab.
  Future<bool> _needsAsk(_Tab tab) async {
    if (tab.session.ended) return false;
    switch (tab.session.profile.askBeforeClosing) {
      case AskBeforeClosing.always:
        return true;
      case AskBeforeClosing.never:
        return false;
      case AskBeforeClosing.running:
        return tab.session.hasForegroundProcess();
    }
  }

  /// Closes a tab like the × and ⌘W do: asks first ("Do you want to terminate running
  /// processes in this tab?") when the profile says so.
  Future<void> requestCloseTab([int? index]) async {
    final i = index ?? _current;
    if (i < 0 || i >= _tabs.length) return;
    if (_confirming != null || _confirmingWindow != null) return;
    final tab = _tabs[i];
    if (await _needsAsk(tab)) {
      if (!mounted || !_tabs.contains(tab)) return;
      setState(() => _confirming = tab);
      return;
    }
    if (mounted && _tabs.contains(tab)) closeTab(_tabs.indexOf(tab));
  }

  /// The window is closing (the close button, Logo+W): true to let it close. When any tab
  /// needs asking about, asks first ("Do you want to terminate running processes in this
  /// window?") and keeps the window open if the answer is no.
  Future<bool> requestCloseWindow() async {
    if (_confirming != null || _confirmingWindow != null) return false;
    var ask = false;
    for (final tab in List.of(_tabs)) {
      if (await _needsAsk(tab)) {
        ask = true;
        break;
      }
    }
    if (!ask || !mounted) return true;
    final answer = Completer<bool>();
    setState(() => _confirmingWindow = answer);
    return answer.future;
  }

  void _answerClose(bool terminate) {
    final window = _confirmingWindow;
    if (window != null) {
      setState(() => _confirmingWindow = null);
      window.complete(terminate);
      if (!terminate && !_finding) _tab.focus.requestFocus();
      return;
    }
    final tab = _confirming;
    setState(() => _confirming = null);
    if (terminate && tab != null && _tabs.contains(tab)) {
      closeTab(_tabs.indexOf(tab));
    }
    if (!_finding && _tabs.isNotEmpty) _tab.focus.requestFocus();
  }

  Widget _confirmOverlay() => Positioned.fill(
    key: const ValueKey('close confirmation'),
    child: ColoredBox(
      // Assumption: not measured (the kit draws no scrim behind an app's alert).
      color: const Color(0x33000000),
      child: Center(
        child: AmalfiAlert(
          title: _confirmingWindow != null
              ? l10n.closeWindowConfirmTitle
              : l10n.closeTabConfirmTitle,
          message: _confirmingWindow != null
              ? l10n.closeWindowConfirmMessage
              : l10n.closeTabConfirmMessage,
          actions: [
            AmalfiPushButton(
              label: l10n.cancel,
              onPressed: () => _answerClose(false),
            ),
            AmalfiPushButton(
              label: l10n.terminate,
              variant: AmalfiPushButtonVariant.destructive,
              onPressed: () => _answerClose(true),
            ),
          ],
        ),
      ),
    ),
  );

  void selectTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    setState(() => _current = index);
    _tab.belled = false;
    _tab.decor.update(active: _windowActive);
    _endFind();
    _tab.focus.requestFocus();
  }

  void _step(int by) {
    if (_tabs.length < 2) return;
    selectTab((_current + by) % _tabs.length);
  }

  // ---- bells and drops --------------------------------------------------------------

  DateTime? _lastNotified;

  void _belled(_Tab tab) {
    if (!mounted) return;
    final profile = tab.session.profile;
    final background = !_windowActive || tab != _tab;
    if (background && profile.bellNotify) {
      if (tab != _tab) setState(() => tab.belled = true);
      final now = DateTime.now();
      // One notification per few seconds, not one per bell of a loop.
      if (_lastNotified == null ||
          now.difference(_lastNotified!) > const Duration(seconds: 5)) {
        _lastNotified = now;
        _app.system
            .notify(l10n.appTitle, l10n.bellNotification(tab.session.title))
            .ignore();
      }
    }
  }

  /// Files dropped on the window: their quoted paths are typed into the current tab.
  void _drag(SilicaDragEvent event) {
    if (event is! SilicaDrop || !_windowActive || _tabs.isEmpty) return;
    typePaths([for (final uri in event.uris) uri.toString()]);
  }

  /// Types the (shell-quoted) paths of `file://` URIs into the current tab.
  void typePaths(Iterable<String> uris) {
    final text = quotedPaths(uris);
    if (text.isEmpty) return;
    session.write('$text ');
  }

  // ---- title ------------------------------------------------------------------------

  bool _hadSelection = false;

  void _gridChanged() {
    if (!mounted) return;
    // Copy and the find items follow the selection of the current tab.
    final has = _tabs.isNotEmpty && session.grid.selection.isNotEmpty;
    if (has != _hadSelection) {
      _hadSelection = has;
      _changed();
    }
    if (!_finding) return;
    // Output moves the matches: look again once it settles.
    _refind?.cancel();
    _refind = Timer(const Duration(milliseconds: 250), () {
      if (mounted && _finding) _runFind(keep: true);
    });
    _refreshHits();
  }

  void _changed() {
    if (!mounted) return;
    // A resize arrives during layout (the view measures the grid): rebuild after the frame.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _changed());
      return;
    }
    setState(() {});
    if (_tabs.isNotEmpty) {
      SystemChrome.setApplicationSwitcherDescription(
        ApplicationSwitcherDescription(label: _title),
      ).ignore();
      widget.onTitle?.call(_title);
    }
  }

  /// The title of a tab: the one the user gave, else the program's (with the directory if the
  /// profile shows it).
  String _tabTitle(_Tab tab) =>
      tab.customTitle ??
      (tab.session.profile.titleShowsDirectory
          ? tab.session.titleWithDirectory(_app.system.home)
          : tab.session.title);

  String get _title {
    final s = session;
    final base = _tabTitle(_tab);
    if (!_profile.titleShowsSize) return base;
    return l10n.windowTitle(base, s.grid.cols, s.grid.rows);
  }

  // ---- find -------------------------------------------------------------------------

  /// The find bar adds 32 pt to the window, the grid keeps its size (terminal.md › Find bar).
  void _growBy(double by) {
    final size = MediaQuery.maybeSizeOf(context);
    if (size == null) return;
    SilicaWindow.setSize(
      Size(size.width, size.height + by),
      viewId: View.maybeOf(context)?.viewId ?? 0,
    ).ignore();
  }

  void _startFind() {
    if (!_finding) _growBy(findBarHeight);
    setState(() => _finding = true);
    _queryFocus.requestFocus();
    _runFind();
  }

  void _endFind() {
    _refind?.cancel();
    if (_tabs.isNotEmpty) _tab.decor.update(hits: const []);
    if (!_finding) return;
    _growBy(-findBarHeight);
    setState(() {
      _finding = false;
      _matches = const [];
    });
    if (_tabs.isNotEmpty) _tab.focus.requestFocus();
  }

  int _findRun = 0;

  /// Looks for the query in the whole buffer. [step] moves to the next or previous match;
  /// without it the match nearest to the bottom is the current one. [keep] searches again
  /// without moving the view or the current match.
  Future<void> _runFind({int step = 0, bool keep = false}) async {
    if (_tabs.isEmpty) return;
    final run = ++_findRun;
    final tab = _tab;
    final found = await tab.session.find(_query.text);
    if (!mounted || run != _findRun || tab != _tab) return;
    setState(() {
      _matches = found;
      if (found.isEmpty) {
        _match = 0;
      } else if (keep) {
        _match = _match.clamp(0, found.length - 1);
      } else {
        _match = step == 0 ? found.length - 1 : (_match + step) % found.length;
      }
    });
    if (!keep && found.isNotEmpty) {
      tab.session.scrollToRow(found[_match].firstRow);
    }
    _refreshHits();
  }

  void _stepFind(int step) {
    if (_matches.isEmpty) {
      unawaited(_runFind());
      return;
    }
    setState(() => _match = (_match + step) % _matches.length);
    session.scrollToRow(_matches[_match].firstRow);
    _refreshHits();
  }

  /// The matches on screen, for the painter.
  void _refreshHits() {
    if (_tabs.isEmpty) return;
    final top = session.topRow;
    final rows = session.grid.rows;
    final hits = <RowHit>[];
    for (var i = 0; i < _matches.length; i++) {
      for (final (row, x0, x1) in _matches[i].pieces) {
        final y = row - top;
        if (y >= 0 && y < rows)
          hits.add(RowHit(y, x0, x1, current: i == _match));
      }
    }
    _tab.decor.update(hits: hits);
  }

  /// Esc closes the find bar, Enter and Shift+Enter step through the matches.
  KeyEventResult _findKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _endFind();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _stepFind(HardwareKeyboard.instance.isShiftPressed ? -1 : 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Find › Use Selection for Find: the selected text becomes the query.
  Future<void> _useSelectionForFind() async {
    final text = await session.selectionText();
    if (text == null || !mounted) return;
    _query.text = text.split('\n').first;
    _startFind();
  }

  // ---- actions ----------------------------------------------------------------------

  Future<void> _jumpToSelection() async {
    final row = session.selectionRow;
    if (row != null) session.scrollToRow(row);
  }

  void _setFontSize(double size) {
    setState(
      () => _fontSize = size.clamp(fontSizeSteps.first, fontSizeSteps.last),
    );
  }

  void _stepFontSize(int by) {
    final now = fontSize;
    if (by > 0) {
      final next = fontSizeSteps.where((s) => s > now + 0.01);
      if (next.isNotEmpty) _setFontSize(next.first);
    } else {
      final next = fontSizeSteps.where((s) => s < now - 0.01);
      if (next.isNotEmpty) _setFontSize(next.last);
    }
  }

  void _resetFontSize() => setState(() => _fontSize = null);

  /// Opens a new window with [profile] (the default one otherwise); where the system opens
  /// no windows, a tab.
  Future<void> newWindow({
    TerminalProfile? profile,
    List<String>? command,
    String? cwd,
  }) async {
    var directory = cwd;
    if (directory == null &&
        _tabs.isNotEmpty &&
        _settings.newWindowDirectory == NewDirectory.sameAsCurrent) {
      directory = await session.workingDirectory();
    }
    final opened = await _app.openWindow(
      WindowSeed(
        profile: profile ?? _settings.defaultProfile,
        command: command ?? _app.command,
        cwd: directory,
      ),
    );
    if (!opened && mounted) {
      await newTab(profile: profile, command: command, cwd: directory);
    }
  }

  /// View › Split Pane: two views of the session, the lower one the live screen, the upper
  /// one a scrollback to look at while the shell works. The window grows to keep the rows.
  void splitPane() {
    if (_tabs.isEmpty || _tab.split) return;
    _growBy(splitGrow);
    session.beginSplit();
    setState(() => _tab.split = true);
  }

  /// View › Close Split Pane.
  void closeSplitPane() {
    if (_tabs.isEmpty || !_tab.split) return;
    _growBy(-splitGrow);
    session.closeSplit();
    setState(() => _tab.split = false);
    _tab.focus.requestFocus();
  }

  /// Moves the current tab to a window of its own.
  Future<void> moveTabToNewWindow() async {
    if (_tabs.length < 2) return;
    final moved = session;
    final opened = await _app.openWindow(WindowSeed(sessions: [moved]));
    if (opened && mounted) release(moved);
  }

  /// Brings the tabs of every other window into this one.
  void mergeAllWindows() {
    for (final other in List.of(_app.windows)) {
      if (other == this || !other.mounted) continue;
      for (final tab in List.of(other.tabs)) {
        other.release(tab);
        adopt(tab);
      }
    }
  }

  /// The tab, the window and the app's windows as a group the settings can reopen.
  void saveWindowGroup(String name) {
    final windows = <WindowGroupWindow>[];
    for (final w in _app.windows) {
      if (!w.mounted) continue;
      windows.add(
        WindowGroupWindow([
          for (final t in w._tabs)
            WindowGroupTab(
              profile: t.session.profile.id,
              cwd: t.session.grid.cwd ?? t.session.cwd,
              command: t.session.command,
            ),
        ]),
      );
    }
    _settings.saveWindowGroup(WindowGroup(name, windows));
  }

  /// Opens the windows of a saved group.
  Future<void> openWindowGroup(WindowGroup group) async {
    var first = true;
    for (final window in group.windows) {
      if (window.tabs.isEmpty) continue;
      final head = window.tabs.first;
      final profile = _settings.profileById(head.profile);
      final opened = first && _tabs.isNotEmpty
          ? await _app.openWindow(
              WindowSeed(
                profile: profile,
                command: head.command,
                cwd: head.cwd,
              ),
            )
          : await _app.openWindow(
              WindowSeed(
                profile: profile,
                command: head.command,
                cwd: head.cwd,
              ),
            );
      first = false;
      if (!opened) {
        await newTab(profile: profile, command: head.command, cwd: head.cwd);
      }
      // The other tabs of the window open as tabs of the new one when it is up.
      if (window.tabs.length > 1) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final target = _app.windows.isEmpty ? this : _app.windows.last;
        for (final t in window.tabs.skip(1)) {
          if (target.mounted) {
            await target.newTab(
              profile: _settings.profileById(t.profile),
              command: t.command,
              cwd: t.cwd,
            );
          }
        }
      }
    }
  }

  void _openLink(String target) {
    _app.system.open(target).ignore();
  }

  Future<void> _manPage(String Function(String word) command) async {
    final text = await session.selectionText();
    final word = text?.trim().split(RegExp(r'\s+')).first ?? '';
    if (word.isEmpty || !mounted) return;
    // Only man page names: no shell syntax goes through.
    if (!RegExp(r'^[A-Za-z0-9_.+:-]+$').hasMatch(word)) return;
    await newTab(command: ['/bin/sh', '-c', command(word)]);
  }

  void _showPrompt(_Prompt prompt) {
    _prompt?.controller.dispose();
    setState(() => _prompt = prompt);
  }

  void _submitPrompt() {
    final prompt = _prompt;
    if (prompt == null) return;
    final text = prompt.controller.text.trim();
    setState(() => _prompt = null);
    prompt.controller.dispose();
    if (text.isNotEmpty) prompt.onSubmit(text);
    if (_tabs.isNotEmpty) _tab.focus.requestFocus();
  }

  void _cancelPrompt() {
    final prompt = _prompt;
    setState(() => _prompt = null);
    prompt?.controller.dispose();
    if (_tabs.isNotEmpty) _tab.focus.requestFocus();
  }

  Widget _promptOverlay() {
    final prompt = _prompt!;
    return Positioned.fill(
      key: const ValueKey('prompt'),
      child: ColoredBox(
        color: const Color(0x33000000),
        child: Center(
          child: AmalfiAlert(
            title: prompt.title,
            message: prompt.message,
            accessory: AmalfiTextField(
              key: const ValueKey('prompt field'),
              controller: prompt.controller,
              placeholder: prompt.placeholder,
              autofocus: true,
              width: 280,
              onSubmitted: (_) => _submitPrompt(),
            ),
            actions: [
              AmalfiPushButton(label: l10n.cancel, onPressed: _cancelPrompt),
              AmalfiPushButton(
                label: prompt.confirm,
                variant: AmalfiPushButtonVariant.primary,
                onPressed: _submitPrompt,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _askNewCommand() => _showPrompt(
    _Prompt(
      title: l10n.newCommand.replaceAll('…', ''),
      message: l10n.newCommandMessage,
      placeholder: l10n.commandPlaceholder,
      confirm: l10n.run,
      onSubmit: (text) => newWindow(command: ['/bin/sh', '-c', text]),
    ),
  );

  void _askRemoteConnection() => _showPrompt(
    _Prompt(
      title: l10n.newRemoteConnection.replaceAll('…', ''),
      message: l10n.newRemoteMessage,
      placeholder: l10n.serverPlaceholder,
      confirm: l10n.connect,
      onSubmit: (text) {
        // `ssh` takes one destination: a host, user@host, or a ssh:// URL.
        if (text.startsWith('-') || text.contains(RegExp(r'\s'))) return;
        newWindow(command: ['ssh', text]);
      },
    ),
  );

  void _askTitle() => _showPrompt(
    _Prompt(
      title: l10n.editTitle.replaceAll('…', ''),
      message: l10n.editTitleMessage,
      initial: _tab.customTitle ?? '',
      confirm: l10n.ok,
      onSubmit: (text) {
        setState(() => _tab.customTitle = text);
        _changed();
      },
    ),
  );

  void _askGroupName() => _showPrompt(
    _Prompt(
      title: l10n.saveWindowsAsGroup.replaceAll('…', ''),
      message: l10n.saveGroupMessage,
      placeholder: l10n.groupNamePlaceholder,
      confirm: l10n.save,
      onSubmit: saveWindowGroup,
    ),
  );

  bool _settingsSheet = false;

  /// Terminal › Settings… (⌘,): a window of its own; where Silica opens none, a sheet over
  /// this one.
  Future<void> _openSettings() async {
    final opened = await TerminalSettingsWindow.open(context, _app);
    if (!opened && mounted) setState(() => _settingsSheet = true);
  }

  Widget _settingsOverlay() => Positioned.fill(
    key: const ValueKey('settings sheet'),
    child: ColoredBox(
      color: const Color(0x33000000),
      child: Center(
        child: LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth.clamp(0, settingsWindowSize.width);
            final height = box.maxHeight.clamp(0, settingsWindowSize.height);
            return SizedBox(
              width: width.toDouble(),
              height: height.toDouble(),
              child: Stack(
                children: [
                  Positioned.fill(child: TerminalSettingsView(app: _app)),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: AmalfiPushButton(
                      key: const ValueKey('settings close'),
                      label: l10n.findDone,
                      size: AmalfiControlSize.small,
                      onPressed: () => setState(() => _settingsSheet = false),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );

  bool _about = false;
  bool _inspecting = false;

  void _openAbout() => setState(() => _about = true);

  Widget _aboutOverlay() => Positioned.fill(
    key: const ValueKey('about'),
    child: ColoredBox(
      color: const Color(0x33000000),
      child: Center(
        child: AmalfiAlert(
          title: l10n.appTitle,
          message: l10n.aboutMessage(appVersion),
          actions: [
            AmalfiPushButton(
              label: l10n.ok,
              variant: AmalfiPushButtonVariant.primary,
              onPressed: () => setState(() => _about = false),
            ),
          ],
        ),
      ),
    ),
  );

  /// The inspector (⌘I): a utility window; where Silica opens none, a panel in this one.
  Future<void> _showInspector() async {
    if (_inspecting) return;
    final opened = await InspectorPanel.open(context, this);
    if (!opened && mounted) setState(() => _inspecting = true);
  }

  // ---- build ------------------------------------------------------------------------

  TerminalLook _look(TerminalProfile profile) {
    final base = profileOf(context);
    final colors = profile.scheme == 'default'
        ? base.grid
        : (extraProfiles[profile.scheme] ?? base.grid);
    session.setTheme(
      PtyTheme(
        foreground: colors.foreground.toARGB32() & 0xffffff,
        background: colors.background.toARGB32() & 0xffffff,
        cursor: colors.cursor.toARGB32() & 0xffffff,
        ansi: [
          for (var i = 0; i < 16; i++) colors.indexed(i).toARGB32() & 0xffffff,
        ],
      ),
    );
    return TerminalLook(
      colors: colors,
      selection: _windowActive ? colors.selection : base.inactiveSelection,
      find: base.findMatch,
      currentFind: colors.selection,
      mark: AmalfiTheme.of(context).colors.textTertiary,
      fontSize: _fontSize ?? profile.fontSize,
      fontFamily: profile.fontFamily,
      boldFace: profile.boldText,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    if (_tabs.isEmpty) {
      return ColoredBox(color: colors.surfaceWindow);
    }
    final tab = _tab;
    final profile = tab.session.profile;
    final content = Actions(
      actions: {
        _StepTabIntent: CallbackAction<_StepTabIntent>(
          onInvoke: (intent) => _step(intent.by),
        ),
      },
      child: Shortcuts(
        shortcuts: windowShortcuts,
        child: AmalfiWindow(
          // The compositor draws the window shadow.
          shadow: false,
          active: _windowActive,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _titleBand(colors),
              if (_showTabBar) _tabBar(colors),
              if (_finding) _findBar(colors, profileOf(context)),
              Expanded(child: _panes(tab, profile, colors)),
            ],
          ),
        ),
      ),
    );
    final body =
        _confirming == null &&
            _confirmingWindow == null &&
            _prompt == null &&
            !_about &&
            !_settingsSheet &&
            !_inspecting
        ? content
        : Stack(
            fit: StackFit.expand,
            children: [
              content,
              if (_inspecting)
                Positioned(
                  key: const ValueKey('inspector panel'),
                  top: chromeHeight,
                  right: 12,
                  child: InspectorView(
                    window: this,
                    onClose: () => setState(() => _inspecting = false),
                  ),
                ),
              if (_about) _aboutOverlay(),
              if (_settingsSheet) _settingsOverlay(),
              if (_prompt != null)
                _promptOverlay()
              else if (_confirming != null || _confirmingWindow != null)
                _confirmOverlay(),
            ],
          );
    // Only the window that owns the menu bar builds one; the body keeps its state either way.
    final keyed = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _app.claimMenus(this),
      child: KeyedSubtree(key: _bodyKey, child: body),
    );
    return _app.menuOwner.value == this
        ? SilicaMenuBar(
            menus: menus(AppLocalizations.of(context)),
            child: keyed,
          )
        : keyed;
  }

  final GlobalKey _bodyKey = GlobalKey();

  Widget _view(_Tab tab, TerminalProfile profile, {required int view}) =>
      TerminalView(
        key: ValueKey(view == 1 ? 'split view' : 'view'),
        session: tab.session,
        look: _look(profile),
        focusNode: view == 1 ? tab.splitFocus : tab.focus,
        decor: (view == 1 ? tab.splitDecor : tab.decor)
          ..update(
            showMarks: profile.showMarks && _settings.autoMarkPrompts,
            active: _windowActive,
          ),
        view: view,
        autofocus: view == 0,
        padding: gridPadding,
        optionAsMeta: profile.optionAsMeta,
        mouseReporting: _settings.mouseReporting,
        openLinks: _settings.openLinks,
        onKeyEvent: _logoKey,
        onOpenLink: _openLink,
        onContextMenu: _contextMenu,
      );

  /// The grid, or two views of the session divided by the splitter.
  Widget _panes(_Tab tab, TerminalProfile profile, AmalfiColors colors) {
    if (!tab.split) {
      return KeyedSubtree(
        key: ObjectKey(tab.session),
        child: _view(tab, profile, view: 0),
      );
    }
    return KeyedSubtree(
      key: ObjectKey(tab.session),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _view(tab, profile, view: 1)),
          _splitter(colors),
          Expanded(child: _view(tab, profile, view: 0)),
        ],
      ),
    );
  }

  Widget _splitter(AmalfiColors colors) => SizedBox(
    key: const ValueKey('splitter'),
    height: splitterHeight,
    child: Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: colors.surfaceSunken)),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 1,
          child: ColoredBox(color: colors.lineSeparator),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 1,
          child: ColoredBox(color: colors.lineSeparator),
        ),
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.textTertiary,
              borderRadius: BorderRadius.circular(splitterDot / 2),
            ),
            child: const SizedBox.square(dimension: splitterDot),
          ),
        ),
      ],
    ),
  );

  /// ⌘ belongs to the app, never to the program: the grid takes the key first, so the menu
  /// bar's shortcuts are run here (the bar binds them for the rest of the window). Also the
  /// keys of the window that have no menu item: ⌘1…⌘9 select a tab, Ctrl+Shift+C and V
  /// copy and paste.
  KeyEventResult _logoKey(FocusNode node, KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.tab &&
        keyboard.isControlPressed &&
        !keyboard.isMetaPressed &&
        !keyboard.isAltPressed) {
      _step(keyboard.isShiftPressed ? -1 : 1);
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        keyboard.isControlPressed &&
        keyboard.isShiftPressed &&
        !keyboard.isMetaPressed) {
      if (event.logicalKey == LogicalKeyboardKey.keyC) {
        session.copy().ignore();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyV) {
        session.paste().ignore();
        return KeyEventResult.handled;
      }
    }
    if (!keyboard.isMetaPressed) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      final digit = _digit(event.logicalKey);
      if (digit != null &&
          !keyboard.isShiftPressed &&
          !keyboard.isAltPressed &&
          !keyboard.isControlPressed) {
        selectTab(digit == 9 ? _tabs.length - 1 : digit - 1);
        return KeyEventResult.handled;
      }
      final bindings = silicaMenuShortcuts(menus(AppLocalizations.of(context)));
      for (final entry in bindings.entries) {
        if (entry.key.accepts(event, keyboard)) {
          entry.value();
          break;
        }
      }
    }
    return KeyEventResult.handled;
  }

  static int? _digit(LogicalKeyboardKey key) {
    const keys = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    final i = keys.indexOf(key);
    return i < 0 ? null : i + 1;
  }

  void _contextMenu(Offset position) {
    final l = AppLocalizations.of(context);
    unawaited(
      showAmalfiMenu(
        context: context,
        position: position,
        entries: [
          AmalfiMenuAction(
            l.copy,
            shortcut: '⌘C',
            enabled: session.grid.selection.isNotEmpty,
            onSelected: () => session.copy().ignore(),
          ),
          AmalfiMenuAction(
            l.paste,
            shortcut: '⌘V',
            onSelected: () => session.paste().ignore(),
          ),
          AmalfiMenuAction(
            l.selectAll,
            shortcut: '⌘A',
            onSelected: () => session.select('all').ignore(),
          ),
          const AmalfiMenuDivider(),
          AmalfiMenuAction(
            l.clearToStart,
            shortcut: '⌘K',
            onSelected: () => session.clear('toStart').ignore(),
          ),
        ],
      ),
    );
  }

  /// The profile the menus offer first: the default one.
  List<TerminalProfile> get _profiles => _settings.profiles;

  /// The menus in Silica's menu bar (silica-desktop#25; terminal.md › Menus): the app menu,
  /// Shell, Edit, View, Window and Help. What the app cannot do is not shown; see
  /// docs/spec.md › Menus.
  List<PlatformMenuItem> menus(AppLocalizations l) {
    SingleActivator cmd(
      LogicalKeyboardKey key, {
      bool shift = false,
      bool alt = false,
      bool ctrl = false,
    }) =>
        SingleActivator(key, meta: true, shift: shift, alt: alt, control: ctrl);
    PlatformMenuItemGroup group(List<PlatformMenuItem> members) =>
        PlatformMenuItemGroup(members: members);

    final empty = _tabs.isEmpty;
    final hasSelection = !empty && session.grid.selection.isNotEmpty;
    final tabs = _tabs.length;
    final canFind = _finding && _matches.isNotEmpty;
    final profile = _settings.defaultProfile;
    final pageUp = LogicalKeyboardKey.pageUp;
    final pageDown = LogicalKeyboardKey.pageDown;

    /// "New Window/Tab" with its submenu of profiles: the plain shortcut uses the default.
    SilicaMenu opener({
      required String label,
      required String withProfile,
      required String sameCommand,
      required LogicalKeyboardKey key,
      required void Function(TerminalProfile) open,
      required VoidCallback sameOpen,
    }) => SilicaMenu(
      label: label,
      menus: [
        group([
          SilicaMenuItem(
            label: withProfile,
            shortcut: cmd(key),
            onSelected: () => open(profile),
          ),
          SilicaMenuItem(
            label: sameCommand,
            shortcut: cmd(key, ctrl: true),
            onSelected: sameOpen,
          ),
        ]),
        group([
          for (final p in _profiles)
            SilicaMenuItem(label: p.name, onSelected: () => open(p)),
        ]),
      ],
    );

    return [
      SilicaMenus.app(
        l.appTitle,
        onAbout: _openAbout,
        onSettings: () => unawaited(_openSettings()),
      ),
      SilicaMenu(
        label: l.menuShell,
        menus: [
          group([
            opener(
              label: l.newWindow,
              withProfile: l.newWindowWithProfile(profile.name),
              sameCommand: l.newWindowSameCommand,
              key: LogicalKeyboardKey.keyN,
              open: (p) => unawaited(newWindow(profile: p)),
              sameOpen: () => unawaited(
                newWindow(
                  profile: empty ? null : session.profile,
                  command: empty ? null : session.command,
                ),
              ),
            ),
            opener(
              label: l.newTab,
              withProfile: l.newTabWithProfile(profile.name),
              sameCommand: l.newTabSameCommand,
              key: LogicalKeyboardKey.keyT,
              open: (p) => unawaited(newTab(profile: p)),
              sameOpen: () => unawaited(
                newTab(
                  profile: empty ? null : session.profile,
                  command: empty ? null : session.command,
                ),
              ),
            ),
            SilicaMenuItem(
              label: l.newCommand,
              shortcut: cmd(LogicalKeyboardKey.keyN, shift: true),
              onSelected: _askNewCommand,
            ),
            SilicaMenuItem(
              label: l.newRemoteConnection,
              shortcut: cmd(LogicalKeyboardKey.keyK, shift: true),
              onSelected: _askRemoteConnection,
            ),
          ]),
          group([
            // ⌘W closes the tab, and the window with the last one (as asked about running
            // programs); a system Close item would end the window without asking.
            SilicaMenuItem(
              label: tabs > 1 ? l.closeTab : l.closeWindow,
              shortcut: cmd(LogicalKeyboardKey.keyW),
              onSelected: () => unawaited(requestCloseTab()),
            ),
            SilicaMenuItem.closeAll(label: l.closeAll),
          ]),
          group([
            SilicaMenuItem(
              label: l.useSettingsAsDefault,
              enabled: !empty,
              onSelected: () => _settings.setDefaultProfile(session.profile.id),
            ),
          ]),
          group([
            SilicaMenuItem(
              label: l.showInspector,
              shortcut: cmd(LogicalKeyboardKey.keyI),
              enabled: !empty,
              onSelected: _showInspector,
            ),
            SilicaMenuItem(
              label: l.editTitle,
              shortcut: cmd(LogicalKeyboardKey.keyI, shift: true),
              enabled: !empty,
              onSelected: _askTitle,
            ),
          ]),
          group([
            SilicaMenuItem(
              label: l.reset,
              shortcut: cmd(LogicalKeyboardKey.keyR, alt: true),
              enabled: !empty,
              onSelected: () => session.reset(),
            ),
            SilicaMenuItem(
              label: l.hardReset,
              shortcut: cmd(LogicalKeyboardKey.keyR, alt: true, ctrl: true),
              enabled: !empty,
              onSelected: () => session.reset(hard: true),
            ),
          ]),
        ],
      ),
      SilicaMenu(
        label: l.menuEdit,
        menus: [
          group([
            const SilicaMenuItem(role: SilicaMenuItemRole.undo, enabled: false),
            const SilicaMenuItem(role: SilicaMenuItemRole.redo, enabled: false),
          ]),
          group([
            const SilicaMenuItem(role: SilicaMenuItemRole.cut, enabled: false),
            SilicaMenuItem(
              role: SilicaMenuItemRole.copy,
              shortcut: cmd(LogicalKeyboardKey.keyC),
              enabled: hasSelection,
              onSelected: () => session.copy().ignore(),
            ),
            SilicaMenuItem(
              role: SilicaMenuItemRole.paste,
              shortcut: cmd(LogicalKeyboardKey.keyV),
              enabled: !empty,
              onSelected: () => session.paste().ignore(),
            ),
            SilicaMenuItem(
              label: l.pasteEscaped,
              shortcut: cmd(LogicalKeyboardKey.keyV, ctrl: true),
              enabled: !empty,
              onSelected: () => session.paste(escaped: true).ignore(),
            ),
            SilicaMenuItem(
              label: l.pasteSelection,
              shortcut: cmd(LogicalKeyboardKey.keyV, shift: true),
              enabled: !empty && PrimarySelection.text != null,
              onSelected: () => session.pastePrimary(),
            ),
            SilicaMenuItem(
              label: l.pasteSelectionEscaped,
              shortcut: cmd(LogicalKeyboardKey.keyV, ctrl: true, shift: true),
              enabled: !empty && PrimarySelection.text != null,
              onSelected: () => session.pastePrimary(escaped: true),
            ),
            SilicaMenuItem(
              role: SilicaMenuItemRole.selectAll,
              shortcut: cmd(LogicalKeyboardKey.keyA),
              enabled: !empty,
              onSelected: () => session.select('all').ignore(),
            ),
            SilicaMenuItem(
              label: l.selectBetweenMarks,
              shortcut: cmd(LogicalKeyboardKey.keyA, shift: true),
              enabled: !empty,
              onSelected: () => session.select('marks').ignore(),
            ),
          ]),
          group([
            SilicaMenu(
              label: l.marks,
              menus: [
                group([
                  SilicaMenuItem(
                    label: l.autoMarkPrompts,
                    checked: _settings.autoMarkPrompts,
                    onSelected: () => _settings.set(
                      autoMarkPrompts: !_settings.autoMarkPrompts,
                    ),
                  ),
                ]),
                group([
                  SilicaMenuItem(
                    label: l.mark,
                    shortcut: cmd(LogicalKeyboardKey.keyU),
                    enabled: !empty,
                    onSelected: () => session.mark().ignore(),
                  ),
                  SilicaMenuItem(
                    label: l.removeMark,
                    shortcut: cmd(LogicalKeyboardKey.keyU, shift: true),
                    enabled: !empty,
                    onSelected: () => session.mark(add: false).ignore(),
                  ),
                ]),
              ],
            ),
            SilicaMenu(
              label: l.navigate,
              menus: [
                SilicaMenuItem(
                  label: l.previousMark,
                  shortcut: cmd(LogicalKeyboardKey.arrowUp),
                  enabled: !empty,
                  onSelected: () => session.scrollTo('previousPrompt'),
                ),
                SilicaMenuItem(
                  label: l.nextMark,
                  shortcut: cmd(LogicalKeyboardKey.arrowDown),
                  enabled: !empty,
                  onSelected: () => session.scrollTo('nextPrompt'),
                ),
              ],
            ),
          ]),
          group([
            SilicaMenuItem(
              label: l.clearToPreviousMark,
              shortcut: cmd(LogicalKeyboardKey.keyL),
              enabled: !empty,
              onSelected: () => session.clear('toMark').ignore(),
            ),
            SilicaMenuItem(
              label: l.clearToStart,
              shortcut: cmd(LogicalKeyboardKey.keyK),
              enabled: !empty,
              onSelected: () => session.clear('toStart').ignore(),
            ),
          ]),
          group([
            SilicaMenuItem(
              label: l.clearScreen,
              shortcut: cmd(LogicalKeyboardKey.keyL, ctrl: true),
              enabled: !empty,
              onSelected: () => session.clear('screen').ignore(),
            ),
          ]),
          group([
            SilicaMenu(
              label: l.find,
              menus: [
                group([
                  SilicaMenuItem(
                    label: l.findEllipsis,
                    shortcut: cmd(LogicalKeyboardKey.keyF),
                    enabled: !empty,
                    onSelected: _startFind,
                  ),
                  SilicaMenuItem(
                    label: l.findNextItem,
                    shortcut: cmd(LogicalKeyboardKey.keyG),
                    enabled: canFind,
                    onSelected: () => _stepFind(1),
                  ),
                  SilicaMenuItem(
                    label: l.findPreviousItem,
                    shortcut: cmd(LogicalKeyboardKey.keyG, shift: true),
                    enabled: canFind,
                    onSelected: () => _stepFind(-1),
                  ),
                ]),
                group([
                  SilicaMenuItem(
                    label: l.hideFindBar,
                    shortcut: cmd(LogicalKeyboardKey.keyF, shift: true),
                    enabled: _finding,
                    onSelected: _endFind,
                  ),
                ]),
                group([
                  SilicaMenuItem(
                    label: l.useSelectionForFind,
                    shortcut: cmd(LogicalKeyboardKey.keyE),
                    enabled: hasSelection,
                    onSelected: () => unawaited(_useSelectionForFind()),
                  ),
                  SilicaMenuItem(
                    label: l.jumpToSelection,
                    shortcut: cmd(LogicalKeyboardKey.keyJ),
                    enabled: !empty && session.selectionRow != null,
                    onSelected: () => unawaited(_jumpToSelection()),
                  ),
                ]),
              ],
            ),
          ]),
          group([
            SilicaMenuItem(
              label: l.optionAsMeta,
              shortcut: cmd(LogicalKeyboardKey.keyO, alt: true),
              checked: !empty && _profile.optionAsMeta,
              enabled: !empty,
              onSelected: () => _settings.updateProfile(
                _profile.copyWith(optionAsMeta: !_profile.optionAsMeta),
              ),
            ),
          ]),
        ],
      ),
      SilicaMenu(
        label: l.menuView,
        menus: [
          group([
            SilicaMenuItem(
              label: _showTabBar ? l.hideTabBar : l.showTabBar,
              shortcut: cmd(LogicalKeyboardKey.keyT, shift: true),
              onSelected: () => setState(() => _showTabBar = !_showTabBar),
            ),
            SilicaMenuItem(
              label: _settings.autoMarkPrompts && _profile.showMarks
                  ? l.hideMarks
                  : l.showMarks,
              enabled: !empty,
              onSelected: () => _settings.updateProfile(
                _profile.copyWith(showMarks: !_profile.showMarks),
              ),
            ),
          ]),
          group([
            SilicaMenuItem(
              label: l.allowMouseReporting,
              shortcut: cmd(LogicalKeyboardKey.keyR),
              checked: _settings.mouseReporting,
              onSelected: () =>
                  _settings.set(mouseReporting: !_settings.mouseReporting),
            ),
          ]),
          group([
            SilicaMenuItem(
              label: l.splitPane,
              shortcut: cmd(LogicalKeyboardKey.keyD),
              enabled: !empty && !_tab.split,
              onSelected: splitPane,
            ),
            SilicaMenuItem(
              label: l.closeSplitPane,
              shortcut: cmd(LogicalKeyboardKey.keyD, shift: true),
              enabled: !empty && _tab.split,
              onSelected: closeSplitPane,
            ),
          ]),
          group([
            SilicaMenuItem(
              label: l.defaultFontSize,
              shortcut: cmd(LogicalKeyboardKey.digit0),
              enabled: !empty,
              onSelected: _resetFontSize,
            ),
            SilicaMenuItem(
              label: l.fontBigger,
              shortcut: const CharacterActivator('+', meta: true),
              enabled: !empty,
              onSelected: () => _stepFontSize(1),
            ),
            SilicaMenuItem(
              label: l.fontSmaller,
              shortcut: const CharacterActivator('-', meta: true),
              enabled: !empty,
              onSelected: () => _stepFontSize(-1),
            ),
          ]),
          group([
            SilicaMenuItem(
              label: l.scrollToTop,
              shortcut: cmd(LogicalKeyboardKey.home),
              enabled: !empty,
              onSelected: () => session.scrollTo('top'),
            ),
            SilicaMenuItem(
              label: l.scrollToBottom,
              shortcut: cmd(LogicalKeyboardKey.end),
              enabled: !empty,
              onSelected: () => session.scrollTo('bottom'),
            ),
          ]),
          group([
            SilicaMenuItem(
              label: l.pageUp,
              shortcut: cmd(pageUp),
              enabled: !empty,
              onSelected: () => session.scrollPage(1),
            ),
            SilicaMenuItem(
              label: l.pageDown,
              shortcut: cmd(pageDown),
              enabled: !empty,
              onSelected: () => session.scrollPage(-1),
            ),
          ]),
          group([
            SilicaMenuItem(
              label: l.lineUp,
              shortcut: cmd(pageUp, alt: true),
              enabled: !empty,
              onSelected: () => session.scrollLines(1),
            ),
            SilicaMenuItem(
              label: l.lineDown,
              shortcut: cmd(pageDown, alt: true),
              enabled: !empty,
              onSelected: () => session.scrollLines(-1),
            ),
          ]),
          group([SilicaMenuItem.system(SilicaMenuItemRole.fullScreen)]),
        ],
      ),
      SilicaMenus.window(
        l.menuWindow,
        items: [
          group([
            SilicaMenuItem(
              label: l.showPreviousTab,
              shortcut: const SingleActivator(
                LogicalKeyboardKey.tab,
                control: true,
                shift: true,
              ),
              enabled: tabs > 1,
              onSelected: () => _step(-1),
            ),
            SilicaMenuItem(
              label: l.showNextTab,
              shortcut: const SingleActivator(
                LogicalKeyboardKey.tab,
                control: true,
              ),
              enabled: tabs > 1,
              onSelected: () => _step(1),
            ),
            SilicaMenuItem(
              label: l.moveTabToNewWindow,
              enabled: tabs > 1,
              onSelected: () => unawaited(moveTabToNewWindow()),
            ),
            SilicaMenuItem(
              label: l.mergeAllWindows,
              enabled: _app.windows.length > 1,
              onSelected: mergeAllWindows,
            ),
          ]),
          group([
            SilicaMenu(
              label: l.openWindowGroup,
              enabled: _settings.windowGroups.isNotEmpty,
              menus: [
                for (final g in _settings.windowGroups)
                  SilicaMenuItem(
                    label: g.name,
                    onSelected: () => unawaited(openWindowGroup(g)),
                  ),
              ],
            ),
            SilicaMenuItem(
              label: l.saveWindowsAsGroup,
              onSelected: _askGroupName,
            ),
          ]),
        ],
      ),
      SilicaMenus.help(
        l.menuHelp,
        items: [
          group([
            SilicaMenuItem(
              label: l.openManPage,
              shortcut: const CharacterActivator(
                '?',
                meta: true,
                control: true,
              ),
              enabled: hasSelection,
              onSelected: () => unawaited(_manPage((w) => 'man -- $w')),
            ),
            SilicaMenuItem(
              label: l.searchManIndex,
              shortcut: const CharacterActivator(
                "'",
                meta: true,
                control: true,
                alt: true,
              ),
              enabled: hasSelection,
              onSelected: () => unawaited(_manPage((w) => 'man -k -- $w')),
            ),
          ]),
        ],
      ),
    ];
  }

  /// The title band: the centred title (headline); the window controls are the compositor's.
  Widget _titleBand(AmalfiColors colors) => WindowDragArea(
    child: SizedBox(
      key: const ValueKey('title band'),
      height: titleBarHeight,
      child: Stack(
        children: [
          Positioned(
            left: titleInset,
            right: titleInset,
            top:
                (titleBarHeight - (AmalfiType.headlineToken.lineHeight ?? 18)) /
                2,
            child: Text(
              _title,
              key: const ValueKey('title'),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AmalfiType.headline(
                color: _windowActive ? colors.textPrimary : colors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  /// The tab bar (kit `Apps/Terminal/Tab Bar *`): 36 pt, tabs 28 pt from x +8 sharing the
  /// width, the round 28 pt "+" 8 pt from the right edge, the separator on the last point.
  Widget _tabBar(AmalfiColors colors) => SizedBox(
    key: const ValueKey('tab bar'),
    height: tabBarHeight,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: tabBarLeft,
          right: newTabRight + newTabSide + tabsToNewTab - tabGap,
          top: tabTop,
          height: tabHeight,
          child: AnimatedBuilder(
            animation: Listenable.merge([for (final s in _slots) s.presence]),
            builder: (context, _) =>
                LayoutBuilder(builder: (context, box) => _tabRow(box.maxWidth)),
          ),
        ),
        Positioned(
          right: newTabRight,
          top: newTabTop,
          width: newTabSide,
          height: newTabSide,
          child: AmalfiIconButton(
            key: const ValueKey('new tab'),
            icon: const AmalfiGlyph(AmalfiGlyphs.plus),
            onPressed: () => unawaited(newTab()),
            semanticLabel: l10n.newTab,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 1,
          child: ColoredBox(color: colors.lineSeparator),
        ),
      ],
    ),
  );

  Widget _tabRow(double width) {
    const curve = Curves.easeOutCubic;
    final weights = [
      for (final slot in _slots) curve.transform(slot.presence.value),
    ];
    final total = weights.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return const SizedBox.shrink();
    final widths = tabWidths(
      width: width,
      weights: weights,
      selected: [
        for (final slot in _slots)
          _tabs.indexOf(slot.tab) == _current && !slot.closing,
      ].indexOf(true),
    );
    return Row(
      children: [
        for (var i = 0; i < _slots.length; i++)
          SizedBox(width: widths[i], child: _tabWidget(_slots[i])),
      ],
    );
  }

  /// One tab (`AmalfiTab`: the selected one raised, the × on the selected and the hovered
  /// one), [tabGap] kept at its trailing side.
  Widget _tabWidget(_TabSlot slot) {
    final index = _tabs.indexOf(slot.tab);
    final selected = index == _current && !slot.closing;
    final title = _tabTitle(slot.tab);
    return ClipRect(
      child: Padding(
        padding: const EdgeInsets.only(right: tabGap),
        child: AmalfiTab(
          key: index < 0 ? null : ValueKey('tab $index'),
          label: slot.tab.belled ? '• $title' : title,
          selected: selected,
          width: null,
          closeLabel: l10n.closeTab,
          onSelect: index < 0 ? null : () => selectTab(index),
          onClose: index < 0 || slot.closing
              ? null
              : () => requestCloseTab(index),
        ),
      ),
    );
  }

  /// The find bar (kit `Apps/Terminal/Find Bar`, 32 pt): the search field (small, 480 in a
  /// 640 window) at x +8, the previous/next segments 56 x 24 and "Done" 56 x 24, the match
  /// count before the segments, the separator on the last point.
  Widget _findBar(AmalfiColors colors, Profile profile) {
    final status = _query.text.isEmpty
        ? ''
        : _matches.isEmpty
        ? l10n.findNoMatches
        : l10n.findMatches(_match + 1, _matches.length);
    return SizedBox(
      key: const ValueKey('find bar'),
      height: findBarHeight,
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, box) {
              // 16 between the field and the segments, 20 before "Done", 4 at the edge.
              const fixed =
                  findFieldLeft +
                  16 +
                  findSegmentsWidth +
                  20 +
                  findDoneWidth +
                  findRight;
              final room = box.maxWidth - fixed - (status.isEmpty ? 0 : 96);
              final field = room.clamp(80.0, findFieldWidth).toDouble();
              return Padding(
                padding: const EdgeInsets.only(left: findFieldLeft, top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AmalfiSearchField(
                      key: const ValueKey('find field'),
                      controller: _query,
                      focusNode: _queryFocus,
                      placeholder: l10n.find,
                      size: AmalfiFieldSize.small,
                      width: field,
                      onChanged: (_) => _runFind(),
                      semanticLabel: l10n.find,
                    ),
                    const SizedBox(width: 16),
                    if (status.isNotEmpty)
                      SizedBox(
                        width: 96,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            status,
                            key: const ValueKey('find status'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AmalfiType.caption(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    SizedBox(
                      width: findSegmentsWidth,
                      height: findControlHeight,
                      child: AmalfiActionSegments(
                        size: AmalfiControlSize.small,
                        segments: [
                          AmalfiSegment.icon(
                            const AmalfiGlyph(AmalfiGlyphs.chevronLeft),
                            semanticLabel: l10n.findPrevious,
                          ),
                          AmalfiSegment.icon(
                            const AmalfiGlyph(AmalfiGlyphs.chevronRight),
                            semanticLabel: l10n.findNext,
                          ),
                        ],
                        onPressed: (i) => _stepFind(i == 0 ? -1 : 1),
                      ),
                    ),
                    const SizedBox(width: 20),
                    AmalfiPushButton(
                      key: const ValueKey('find done'),
                      label: l10n.findDone,
                      size: AmalfiControlSize.small,
                      onPressed: _endFind,
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 1,
            child: ColoredBox(color: colors.lineSeparator),
          ),
        ],
      ),
    );
  }
}
