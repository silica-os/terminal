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
    String? id,
  }) => TerminalProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    scheme: scheme ?? this.scheme,
    fontFamily: fontFamily ?? this.fontFamily,
    fontSize: fontSize ?? this.fontSize,
    cursor: cursor ?? this.cursor,
    cursorBlink: cursorBlink ?? this.cursorBlink,
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
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'scheme': scheme,
    'fontFamily': fontFamily,
    'fontSize': fontSize,
    'cursor': cursor.name,
    'cursorBlink': cursorBlink,
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

/// The preferences, observable: the profiles, the default one and the general settings.
class TerminalSettings extends ChangeNotifier {
  TerminalSettings({
    SettingsStore? store,
    this.saveDelay = const Duration(milliseconds: 200),
  }) : _store = store ?? MemorySettingsStore();

  final SettingsStore _store;

  /// How long changes wait before they are written (zero: at the end of this turn).
  final Duration saveDelay;

  List<TerminalProfile> _profiles = const [basicProfile];
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
      if (profiles.isNotEmpty) _profiles = profiles;
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
  }

  Map<String, Object?> toJson() => {
    'version': 1,
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
  }) {
    this.newWindowDirectory = newWindowDirectory ?? this.newWindowDirectory;
    this.newTabDirectory = newTabDirectory ?? this.newTabDirectory;
    this.clipboardWrite = clipboardWrite ?? this.clipboardWrite;
    this.clipboardRead = clipboardRead ?? this.clipboardRead;
    this.mouseReporting = mouseReporting ?? this.mouseReporting;
    this.openLinks = openLinks ?? this.openLinks;
    this.autoMarkPrompts = autoMarkPrompts ?? this.autoMarkPrompts;
    _changed();
  }
}
