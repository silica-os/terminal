// Terminal's preferences (docs/spec/settings.md): the profiles and the general settings, kept
// in `$XDG_CONFIG_HOME/terminal/settings.json` (private to the app). Reading is forgiving: a
// missing, damaged or newer file gives the defaults, and unknown keys are kept out of the way.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'style.dart';

/// What happens when the shell of a window or tab ends.
enum CloseOnExit {
  /// Close it.
  close,

  /// Close it when the shell exited cleanly (exit status 0).
  closeIfClean,

  /// Keep it, with a line saying how the process ended.
  keep,
}

/// When closing a tab or window asks first.
enum AskBeforeClosing {
  /// Always.
  always,

  /// Never.
  never,

  /// When a program other than the login shell runs in it.
  running,
}

/// The cursor drawn for programs that do not choose one.
enum CursorStyleChoice { block, underline, beam }

/// The most lines "unlimited" scrollback keeps (the grid's own limit).
const int unlimitedScrollback = 1000000;

const Object _keep = Object();

/// One profile: colours, font, cursor, window, tab, shell and keyboard.
@immutable
class TerminalProfile {
  const TerminalProfile({
    required this.id,
    required this.name,
    this.scheme = 'default',
    this.fontFamily = terminalFontFamily,
    this.fontSize = terminalFontSize,
    this.cursor = CursorStyleChoice.block,
    this.cursorBlink = false,
    this.opacity = 1,
    this.boldText = true,
    this.scrollbackLimited = true,
    this.scrollbackLines = 10000,
    this.closeOnExit = CloseOnExit.keep,
    this.askBeforeClosing = AskBeforeClosing.running,
    this.optionAsMeta = false,
    this.columns = defaultColumns,
    this.rows = defaultRows,
    this.startupCommand = '',
    this.showMarks = true,
    this.titleShowsSize = true,
    this.titleShowsDirectory = true,
    this.bellVisual = true,
    this.bellNotify = true,
    this.antialias = true,
    this.blinkingText = true,
    this.ansiColors = true,
    this.brightBold = false,
    this.titleShowsProcess = true,
    this.restoreText = true,
    this.restoreLines = 10000,
    this.backgroundColor,
    this.textColor,
    this.boldColor,
    this.selectionColor,
    this.cursorColor,
  });

  final String id;
  final String name;

  /// The colour scheme: `default` follows the appearance; the others are the names in
  /// [extraProfiles].
  final String scheme;
  final String fontFamily;
  final double fontSize;
  final CursorStyleChoice cursor;
  final bool cursorBlink;

  /// How opaque the background is, 0.3 to 1 (translucent profiles).
  final double opacity;
  final bool boldText;
  final bool scrollbackLimited;
  final int scrollbackLines;
  final CloseOnExit closeOnExit;
  final AskBeforeClosing askBeforeClosing;
  final bool optionAsMeta;
  final int columns;
  final int rows;

  /// A command typed into the shell when it starts (the Shell tab); empty: none.
  final String startupCommand;
  final bool showMarks;
  final bool titleShowsSize;
  final bool titleShowsDirectory;
  final bool bellVisual;
  final bool bellNotify;

  /// Text: antialiased glyphs (stored; the grid cannot switch it yet, see the Text pane).
  final bool antialias;

  /// Text: programs may blink text (stored; the emulator reports no blink attribute yet).
  final bool blinkingText;

  /// Text: show the ANSI colours programs ask for (off: every cell uses the text and background
  /// colours).
  final bool ansiColors;

  /// Text: bold text in one of the eight normal ANSI colours uses its bright colour.
  final bool brightBold;

  /// Window: the title shows the running process and its arguments (stored; the embedder
  /// reports no process name yet).
  final bool titleShowsProcess;

  /// Window: restore the text when the window reopens, and how many lines (stored; not done yet).
  final bool restoreText;
  final int restoreLines;

  /// The scheme's colours replaced by the user (ARGB, `0xAARRGGBB`); null: the scheme's own.
  final int? backgroundColor;
  final int? textColor;
  final int? boldColor;
  final int? selectionColor;
  final int? cursorColor;

  /// Lines the grid keeps above the screen.
  int get scrollback => scrollbackLimited
      ? scrollbackLines.clamp(0, unlimitedScrollback)
      : unlimitedScrollback;

  TerminalProfile copyWith({
    String? name,
    String? scheme,
    String? fontFamily,
    double? fontSize,
    CursorStyleChoice? cursor,
    bool? cursorBlink,
    double? opacity,
    bool? boldText,
    bool? scrollbackLimited,
    int? scrollbackLines,
    CloseOnExit? closeOnExit,
    AskBeforeClosing? askBeforeClosing,
    bool? optionAsMeta,
    int? columns,
    int? rows,
    String? startupCommand,
    bool? showMarks,
    bool? titleShowsSize,
    bool? titleShowsDirectory,
    bool? bellVisual,
    bool? bellNotify,
    bool? antialias,
    bool? blinkingText,
    bool? ansiColors,
    bool? brightBold,
    bool? titleShowsProcess,
    bool? restoreText,
    int? restoreLines,
    Object? backgroundColor = _keep,
    Object? textColor = _keep,
    Object? boldColor = _keep,
    Object? selectionColor = _keep,
    Object? cursorColor = _keep,
    String? id,
  }) => TerminalProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    scheme: scheme ?? this.scheme,
    fontFamily: fontFamily ?? this.fontFamily,
    fontSize: fontSize ?? this.fontSize,
    cursor: cursor ?? this.cursor,
    cursorBlink: cursorBlink ?? this.cursorBlink,
    opacity: opacity ?? this.opacity,
    boldText: boldText ?? this.boldText,
    scrollbackLimited: scrollbackLimited ?? this.scrollbackLimited,
    scrollbackLines: scrollbackLines ?? this.scrollbackLines,
    closeOnExit: closeOnExit ?? this.closeOnExit,
    askBeforeClosing: askBeforeClosing ?? this.askBeforeClosing,
    optionAsMeta: optionAsMeta ?? this.optionAsMeta,
    columns: columns ?? this.columns,
    rows: rows ?? this.rows,
    startupCommand: startupCommand ?? this.startupCommand,
    showMarks: showMarks ?? this.showMarks,
    titleShowsSize: titleShowsSize ?? this.titleShowsSize,
    titleShowsDirectory: titleShowsDirectory ?? this.titleShowsDirectory,
    bellVisual: bellVisual ?? this.bellVisual,
    bellNotify: bellNotify ?? this.bellNotify,
    antialias: antialias ?? this.antialias,
    blinkingText: blinkingText ?? this.blinkingText,
    ansiColors: ansiColors ?? this.ansiColors,
    brightBold: brightBold ?? this.brightBold,
    titleShowsProcess: titleShowsProcess ?? this.titleShowsProcess,
    restoreText: restoreText ?? this.restoreText,
    restoreLines: restoreLines ?? this.restoreLines,
    backgroundColor: identical(backgroundColor, _keep)
        ? this.backgroundColor
        : backgroundColor as int?,
    textColor: identical(textColor, _keep) ? this.textColor : textColor as int?,
    boldColor: identical(boldColor, _keep) ? this.boldColor : boldColor as int?,
    selectionColor: identical(selectionColor, _keep)
        ? this.selectionColor
        : selectionColor as int?,
    cursorColor: identical(cursorColor, _keep)
        ? this.cursorColor
        : cursorColor as int?,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'scheme': scheme,
    'fontFamily': fontFamily,
    'fontSize': fontSize,
    'cursor': cursor.name,
    'cursorBlink': cursorBlink,
    'opacity': opacity,
    'boldText': boldText,
    'scrollbackLimited': scrollbackLimited,
    'scrollbackLines': scrollbackLines,
    'closeOnExit': closeOnExit.name,
    'askBeforeClosing': askBeforeClosing.name,
    'optionAsMeta': optionAsMeta,
    'columns': columns,
    'rows': rows,
    'startupCommand': startupCommand,
    'showMarks': showMarks,
    'titleShowsSize': titleShowsSize,
    'titleShowsDirectory': titleShowsDirectory,
    'bellVisual': bellVisual,
    'bellNotify': bellNotify,
    'antialias': antialias,
    'blinkingText': blinkingText,
    'ansiColors': ansiColors,
    'brightBold': brightBold,
    'titleShowsProcess': titleShowsProcess,
    'restoreText': restoreText,
    'restoreLines': restoreLines,
    'backgroundColor': ?backgroundColor,
    'textColor': ?textColor,
    'boldColor': ?boldColor,
    'selectionColor': ?selectionColor,
    'cursorColor': ?cursorColor,
  };

  /// A profile from its JSON; null when it has no usable id and name. Bad values fall back to
  /// the defaults one by one.
  static TerminalProfile? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    if (id is! String || id.isEmpty || name is! String) return null;
    const base = TerminalProfile(id: '', name: '');
    T pick<T extends Enum>(List<T> values, Object? v, T fallback) =>
        values.firstWhere((e) => e.name == v, orElse: () => fallback);
    bool flag(String key, bool fallback) {
      final v = json[key];
      return v is bool ? v : fallback;
    }

    int count(String key, int fallback, int min, int max) {
      final v = json[key];
      return v is int ? v.clamp(min, max) : fallback;
    }

    int? colour(String key) {
      final v = json[key];
      return v is int ? v & 0xFFFFFFFF : null;
    }

    final size = json['fontSize'];
    final scheme = json['scheme'];
    return TerminalProfile(
      id: id,
      name: name,
      scheme:
          scheme is String &&
              (scheme == 'default' || extraProfiles.containsKey(scheme))
          ? scheme
          : 'default',
      fontFamily:
          json['fontFamily'] is String &&
              (json['fontFamily'] as String).isNotEmpty
          ? json['fontFamily'] as String
          : base.fontFamily,
      fontSize: size is num
          ? size.toDouble().clamp(fontSizeSteps.first, fontSizeSteps.last)
          : base.fontSize,
      cursor: pick(CursorStyleChoice.values, json['cursor'], base.cursor),
      cursorBlink: flag('cursorBlink', base.cursorBlink),
      opacity: json['opacity'] is num
          ? (json['opacity'] as num).toDouble().clamp(0.3, 1.0)
          : base.opacity,
      boldText: flag('boldText', base.boldText),
      scrollbackLimited: flag('scrollbackLimited', base.scrollbackLimited),
      scrollbackLines: count(
        'scrollbackLines',
        base.scrollbackLines,
        0,
        unlimitedScrollback,
      ),
      closeOnExit: pick(
        CloseOnExit.values,
        json['closeOnExit'],
        base.closeOnExit,
      ),
      askBeforeClosing: pick(
        AskBeforeClosing.values,
        json['askBeforeClosing'],
        base.askBeforeClosing,
      ),
      optionAsMeta: flag('optionAsMeta', base.optionAsMeta),
      columns: count('columns', base.columns, minimumColumns, 500),
      rows: count('rows', base.rows, minimumRows, 200),
      startupCommand: json['startupCommand'] is String
          ? json['startupCommand'] as String
          : '',
      showMarks: flag('showMarks', base.showMarks),
      titleShowsSize: flag('titleShowsSize', base.titleShowsSize),
      titleShowsDirectory: flag(
        'titleShowsDirectory',
        base.titleShowsDirectory,
      ),
      bellVisual: flag('bellVisual', base.bellVisual),
      bellNotify: flag('bellNotify', base.bellNotify),
      antialias: flag('antialias', base.antialias),
      blinkingText: flag('blinkingText', base.blinkingText),
      ansiColors: flag('ansiColors', base.ansiColors),
      brightBold: flag('brightBold', base.brightBold),
      titleShowsProcess: flag('titleShowsProcess', base.titleShowsProcess),
      restoreText: flag('restoreText', base.restoreText),
      restoreLines: count('restoreLines', base.restoreLines, 0, 1000000),
      backgroundColor: colour('backgroundColor'),
      textColor: colour('textColor'),
      boldColor: colour('boldColor'),
      selectionColor: colour('selectionColor'),
      cursorColor: colour('cursorColor'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TerminalProfile && mapEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}

/// A tab of a saved window group: what it ran and where.
@immutable
class WindowGroupTab {
  const WindowGroupTab({required this.profile, this.cwd, this.command});
  final String profile;
  final String? cwd;
  final List<String>? command;

  Map<String, Object?> toJson() => {
    'profile': profile,
    if (cwd != null) 'cwd': cwd,
    if (command != null) 'command': command,
  };

  static WindowGroupTab? fromJson(Object? json) {
    if (json is! Map || json['profile'] is! String) return null;
    final command = json['command'];
    return WindowGroupTab(
      profile: json['profile'] as String,
      cwd: json['cwd'] is String ? json['cwd'] as String : null,
      command:
          command is List &&
              command.every((e) => e is String) &&
              command.isNotEmpty
          ? command.cast<String>()
          : null,
    );
  }
}

/// A window of a group: its tabs.
@immutable
class WindowGroupWindow {
  const WindowGroupWindow(this.tabs);
  final List<WindowGroupTab> tabs;
}

/// Windows saved together (Window › Save Windows as Group…), opened again with one choice.
@immutable
class WindowGroup {
  const WindowGroup(this.name, this.windows);
  final String name;
  final List<WindowGroupWindow> windows;

  Map<String, Object?> toJson() => {
    'name': name,
    'windows': [
      for (final w in windows) [for (final t in w.tabs) t.toJson()],
    ],
  };

  static WindowGroup? fromJson(Object? json) {
    if (json is! Map || json['name'] is! String || json['windows'] is! List) {
      return null;
    }
    final windows = <WindowGroupWindow>[];
    for (final w in json['windows'] as List) {
      if (w is! List) continue;
      final tabs = [
        for (final t in w)
          if (WindowGroupTab.fromJson(t) case final tab?) tab,
      ];
      if (tabs.isNotEmpty) windows.add(WindowGroupWindow(tabs));
    }
    return windows.isEmpty
        ? null
        : WindowGroup(json['name'] as String, windows);
  }
}

/// The directory a new window or tab starts in.
enum NewDirectory { home, sameAsCurrent }

/// Where the preferences live: a file, or memory in tests.
abstract class SettingsStore {
  Future<String?> read();
  Future<void> write(String text);
}

/// `$XDG_CONFIG_HOME/terminal/settings.json`, written atomically.
class FileSettingsStore implements SettingsStore {
  FileSettingsStore([File? file]) : file = file ?? _default();

  final File file;

  static File _default() {
    final env = Platform.environment;
    final config = env['XDG_CONFIG_HOME'];
    final base = config != null && config.isNotEmpty
        ? config
        : '${env['HOME'] ?? '.'}/.config';
    return File('$base/terminal/settings.json');
  }

  @override
  Future<String?> read() async {
    try {
      return await file.readAsString();
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(String text) async {
    try {
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(text, flush: true);
      await temp.rename(file.path);
    } on Object {
      // A read-only home: the preferences last for this run.
    }
  }
}

class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([this.text]);
  String? text;
  int writes = 0;

  @override
  Future<String?> read() async => text;

  @override
  Future<void> write(String text) async {
    this.text = text;
    writes++;
  }
}

/// The profile every install starts with.
const TerminalProfile basicProfile = TerminalProfile(
  id: 'basic',
  name: 'Basic',
);

/// The profiles Terminal ships, besides Basic (which follows the appearance): own names and
/// own palettes (`extraProfiles` in style.dart).
const List<TerminalProfile> builtInProfiles = [
  TerminalProfile(id: 'slate', name: 'Slate', scheme: 'slate'),
  TerminalProfile(
    id: 'frost',
    name: 'Frost',
    scheme: 'frost',
    cursor: CursorStyleChoice.beam,
    opacity: 0.8,
  ),
  TerminalProfile(id: 'smoke', name: 'Smoke', scheme: 'smoke', opacity: 0.74),
  TerminalProfile(
    id: 'contrast',
    name: 'High Contrast',
    scheme: 'contrast',
    fontSize: 14,
    cursorBlink: true,
  ),
  TerminalProfile(
    id: 'phosphor',
    name: 'Phosphor',
    scheme: 'phosphor',
    cursorBlink: true,
  ),
  TerminalProfile(
    id: 'amber',
    name: 'Amber',
    scheme: 'amber',
    cursor: CursorStyleChoice.underline,
    cursorBlink: true,
  ),
  TerminalProfile(
    id: 'paper',
    name: 'Paper',
    scheme: 'paper',
    fontSize: 14,
    cursor: CursorStyleChoice.beam,
  ),
  TerminalProfile(id: 'lagoon', name: 'Lagoon', scheme: 'lagoon'),
  TerminalProfile(
    id: 'dune',
    name: 'Dune',
    scheme: 'dune',
    cursor: CursorStyleChoice.underline,
  ),
  TerminalProfile(
    id: 'manuscript',
    name: 'Manuscript',
    scheme: 'manuscript',
    fontSize: 14,
    cursor: CursorStyleChoice.beam,
  ),
];

/// The profiles of a fresh install: Basic first (the default), then the built-in ones.
const List<TerminalProfile> startingProfiles = [
  basicProfile,
  ...builtInProfiles,
];

/// The preferences, observable: the profiles, the default one and the general settings.
class TerminalSettings extends ChangeNotifier {
  TerminalSettings({
    SettingsStore? store,
    this.saveDelay = const Duration(milliseconds: 200),
  }) : _store = store ?? MemorySettingsStore();

  final SettingsStore _store;

  /// How long changes wait before they are written (zero: at the end of this turn).
  final Duration saveDelay;

  List<TerminalProfile> _profiles = startingProfiles;
  List<WindowGroup> _groups = const [];
  String _defaultId = 'basic';

  /// Where new windows and tabs start (General).
  NewDirectory newWindowDirectory = NewDirectory.home;
  NewDirectory newTabDirectory = NewDirectory.sameAsCurrent;

  /// Programs may write to the clipboard (OSC 52); reading it is off unless allowed here.
  bool clipboardWrite = true;
  bool clipboardRead = false;

  /// Reports mouse events to programs that ask for them (View › Allow Mouse Reporting).
  bool mouseReporting = true;

  /// Command+click opens links.
  bool openLinks = true;

  /// ⌘1 to ⌘9 select tabs.
  bool tabSwitching = true;

  /// The saved window group a launch opens; null: a new window with the default profile.
  String? launchGroup;

  /// The program new windows run instead of the login shell (split on spaces); empty: the
  /// login shell.
  String shellCommand = '';

  /// The text of the shell integration is offered to the shell (OSC 133 prompt marks).
  bool autoMarkPrompts = true;

  List<TerminalProfile> get profiles => List.unmodifiable(_profiles);

  /// The saved window groups.
  List<WindowGroup> get windowGroups => List.unmodifiable(_groups);

  TerminalProfile get defaultProfile =>
      profileById(_defaultId) ?? _profiles.first;

  TerminalProfile? profileById(String id) {
    for (final p in _profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Loads the saved preferences; the defaults when there are none.
  Future<void> load() async {
    final text = await _store.read();
    if (text == null) return;
    try {
      _apply(jsonDecode(text));
    } on Object {
      return;
    }
    notifyListeners();
  }

  void _apply(Object? json) {
    if (json is! Map) return;
    final list = json['profiles'];
    if (list is List) {
      final seen = <String>{};
      final profiles = [
        for (final p in list)
          if (TerminalProfile.fromJson(p) case final profile?
              when seen.add(profile.id))
            profile,
      ];
      if (profiles.isNotEmpty) {
        // A file saved before the built-in profiles existed gets them added once.
        if (json['builtIns'] != 1) {
          for (final built in builtInProfiles) {
            if (seen.add(built.id)) profiles.add(built);
          }
        }
        _profiles = profiles;
      }
    }
    final groups = json['windowGroups'];
    if (groups is List) {
      _groups = [
        for (final g in groups)
          if (WindowGroup.fromJson(g) case final group?) group,
      ];
    }
    final defaultId = json['defaultProfile'];
    if (defaultId is String && profileById(defaultId) != null)
      _defaultId = defaultId;
    T pick<T extends Enum>(List<T> values, Object? v, T fallback) =>
        values.firstWhere((e) => e.name == v, orElse: () => fallback);
    bool flag(String key, bool fallback) =>
        json[key] is bool ? json[key] as bool : fallback;
    newWindowDirectory = pick(
      NewDirectory.values,
      json['newWindowDirectory'],
      newWindowDirectory,
    );
    newTabDirectory = pick(
      NewDirectory.values,
      json['newTabDirectory'],
      newTabDirectory,
    );
    clipboardWrite = flag('clipboardWrite', clipboardWrite);
    clipboardRead = flag('clipboardRead', clipboardRead);
    mouseReporting = flag('mouseReporting', mouseReporting);
    openLinks = flag('openLinks', openLinks);
    autoMarkPrompts = flag('autoMarkPrompts', autoMarkPrompts);
    tabSwitching = flag('tabSwitching', tabSwitching);
    final group = json['launchGroup'];
    launchGroup = group is String && group.isNotEmpty ? group : null;
    final shell = json['shellCommand'];
    shellCommand = shell is String ? shell : '';
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'builtIns': 1,
    'defaultProfile': _defaultId,
    'profiles': [for (final p in _profiles) p.toJson()],
    'windowGroups': [for (final g in _groups) g.toJson()],
    'newWindowDirectory': newWindowDirectory.name,
    'newTabDirectory': newTabDirectory.name,
    'clipboardWrite': clipboardWrite,
    'clipboardRead': clipboardRead,
    'mouseReporting': mouseReporting,
    'openLinks': openLinks,
    'autoMarkPrompts': autoMarkPrompts,
    'tabSwitching': tabSwitching,
    if (launchGroup != null) 'launchGroup': launchGroup,
    'shellCommand': shellCommand,
  };

  /// Saves, soon (changes in a burst are written once).
  Timer? _saving;
  void _changed() {
    notifyListeners();
    if (saveDelay == Duration.zero) {
      scheduleMicrotask(flush);
      return;
    }
    _saving?.cancel();
    _saving = Timer(saveDelay, flush);
  }

  /// Writes the preferences now.
  Future<void> flush() {
    _saving?.cancel();
    _saving = null;
    return _store.write(const JsonEncoder.withIndent('  ').convert(toJson()));
  }

  @override
  void dispose() {
    _saving?.cancel();
    super.dispose();
  }

  // ---- changes ----------------------------------------------------------------------

  void setDefaultProfile(String id) {
    if (profileById(id) == null || id == _defaultId) return;
    _defaultId = id;
    _changed();
  }

  /// Replaces the profile with the same id.
  void updateProfile(TerminalProfile profile) {
    final i = _profiles.indexWhere((p) => p.id == profile.id);
    if (i < 0 || _profiles[i] == profile) return;
    _profiles = [..._profiles]..[i] = profile;
    _changed();
  }

  /// A copy of [profile] named "<name> copy"; returns it.
  TerminalProfile duplicateProfile(TerminalProfile profile, String name) {
    var n = 1;
    while (profileById('${profile.id}-$n') != null) {
      n++;
    }
    final copy = profile.copyWith(id: '${profile.id}-$n', name: name);
    _profiles = [..._profiles, copy];
    _changed();
    return copy;
  }

  /// Removes a profile; the last one cannot be removed.
  bool removeProfile(String id) {
    if (_profiles.length < 2 || profileById(id) == null) return false;
    _profiles = [
      for (final p in _profiles)
        if (p.id != id) p,
    ];
    if (_defaultId == id) _defaultId = _profiles.first.id;
    _changed();
    return true;
  }

  /// Saves a window group, replacing one with the same name.
  void saveWindowGroup(WindowGroup group) {
    _groups = [
      for (final g in _groups)
        if (g.name != group.name) g,
      group,
    ];
    _changed();
  }

  void removeWindowGroup(String name) {
    _groups = [
      for (final g in _groups)
        if (g.name != name) g,
    ];
    if (launchGroup == name) launchGroup = null;
    _changed();
  }

  /// Changes a general setting.
  void set({
    NewDirectory? newWindowDirectory,
    NewDirectory? newTabDirectory,
    bool? clipboardWrite,
    bool? clipboardRead,
    bool? mouseReporting,
    bool? openLinks,
    bool? autoMarkPrompts,
    bool? tabSwitching,
    Object? launchGroup = _keep,
    String? shellCommand,
  }) {
    this.newWindowDirectory = newWindowDirectory ?? this.newWindowDirectory;
    this.newTabDirectory = newTabDirectory ?? this.newTabDirectory;
    this.clipboardWrite = clipboardWrite ?? this.clipboardWrite;
    this.clipboardRead = clipboardRead ?? this.clipboardRead;
    this.mouseReporting = mouseReporting ?? this.mouseReporting;
    this.openLinks = openLinks ?? this.openLinks;
    this.autoMarkPrompts = autoMarkPrompts ?? this.autoMarkPrompts;
    this.tabSwitching = tabSwitching ?? this.tabSwitching;
    if (!identical(launchGroup, _keep))
      this.launchGroup = launchGroup as String?;
    this.shellCommand = shellCommand ?? this.shellCommand;
    _changed();
  }
}

extension TerminalSettingsShell on TerminalSettings {
  /// The program new windows run: [shellCommand] split on spaces; null: the login shell.
  List<String>? get shellForNewWindows {
    final parts = shellCommand.trim().split(RegExp(r'\s+'));
    return parts.first.isEmpty ? null : parts;
  }
}
