// Terminal › Settings… (⌘,; docs/spec/settings.md, ST-APPSET-05…07): a window of 671 × 628 with
// the tabs General, Profiles, Window Groups and Encodings. Profiles has a list on the left
// (rows 45 pt) and, on the right, the sub-tabs Text, Window, Tab, Shell, Keyboard and Advanced.
// Control sizes inside the tabs were not measured: the Amalfi controls at their small size.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'app.dart';
import 'l10n.dart';
import 'settings.dart';
import 'style.dart';

/// The window of the settings.
const Size settingsWindowSize = Size(671, 628);

/// The height of a row of the profile list.
const double profileRowHeight = 45;

abstract final class TerminalSettingsWindow {
  static SilicaWindowController? _window;

  /// Opens the settings in a window (one for the app); false where windows cannot be opened.
  static Future<bool> open(BuildContext context, TerminalApp app) async {
    final existing = _window;
    if (existing != null && existing.isOpen) return true;
    final window = await SilicaWindows.openWindow(
      title: l10n.settingsTitle,
      size: settingsWindowSize,
      minSize: settingsWindowSize,
      maxSize: settingsWindowSize,
      toolbarHeight: AmalfiToolbarMetrics.toolbarHeight,
      builder: (context) => TerminalSettingsView(app: app),
    );
    if (window == null) return false;
    _window = window;
    unawaited(window.closed.then((_) => _window = null));
    return true;
  }
}

enum SettingsTab { general, profiles, windowGroups, encodings }

enum ProfileTab { text, window, tab, shell, keyboard, advanced }

/// The settings: reads and writes [TerminalSettings] as the user changes things.
class TerminalSettingsView extends StatefulWidget {
  const TerminalSettingsView({
    super.key,
    required this.app,
    this.initial = SettingsTab.general,
  });

  final TerminalApp app;
  final SettingsTab initial;

  @override
  State<TerminalSettingsView> createState() => _TerminalSettingsViewState();
}

class _TerminalSettingsViewState extends State<TerminalSettingsView> {
  late SettingsTab _tab = widget.initial;
  ProfileTab _profileTab = ProfileTab.text;
  String? _selected;

  TerminalSettings get _s => widget.app.settings;

  @override
  void initState() {
    super.initState();
    _s.addListener(_changed);
  }

  @override
  void dispose() {
    _s.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  TerminalProfile get _profile =>
      _s.profileById(_selected ?? '') ?? _s.defaultProfile;

  @override
  Widget build(BuildContext context) => _OverlayRoot(child: _content(context));

  Widget _content(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    return ColoredBox(
      color: colors.surfaceWindow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: AmalfiToolbarMetrics.toolbarHeight,
            child: Center(
              child: AmalfiSegmentedControl(
                key: const ValueKey('settings tabs'),
                segments: [
                  AmalfiSegment.text(l10n.settingsGeneral),
                  AmalfiSegment.text(l10n.settingsProfiles),
                  AmalfiSegment.text(l10n.settingsWindowGroups),
                  AmalfiSegment.text(l10n.settingsEncodings),
                ],
                selected: {_tab.index},
                size: AmalfiControlSize.small,
                onChanged: (s) =>
                    setState(() => _tab = SettingsTab.values[s.first]),
              ),
            ),
          ),
          Expanded(
            child: switch (_tab) {
              SettingsTab.general => _general(colors),
              SettingsTab.profiles => _profiles(colors),
              SettingsTab.windowGroups => _groups(colors),
              SettingsTab.encodings => _encodings(colors),
            },
          ),
        ],
      ),
    );
  }

  // ---- General ----------------------------------------------------------------------

  Widget _general(AmalfiColors colors) {
    final s = _s;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Row(
            l10n.settingsDefaultProfile,
            AmalfiPopUpButton<String>(
              key: const ValueKey('default profile'),
              size: AmalfiControlSize.small,
              width: 180,
              semanticLabel: l10n.settingsDefaultProfile,
              items: [
                for (final p in s.profiles)
                  AmalfiPopUpItem(value: p.id, label: p.name),
              ],
              value: s.defaultProfile.id,
              onChanged: (id) => s.setDefaultProfile(id),
            ),
          ),
          _Row(
            l10n.settingsNewWindows,
            _directory(
              s.newWindowDirectory,
              (v) => s.set(newWindowDirectory: v),
              l10n.settingsNewWindows,
            ),
          ),
          _Row(
            l10n.settingsNewTabs,
            _directory(
              s.newTabDirectory,
              (v) => s.set(newTabDirectory: v),
              l10n.settingsNewTabs,
            ),
          ),
          const SizedBox(height: 12),
          _Check(
            l10n.settingsMouseReporting,
            s.mouseReporting,
            (v) => s.set(mouseReporting: v),
          ),
          _Check(
            l10n.settingsOpenLinks,
            s.openLinks,
            (v) => s.set(openLinks: v),
          ),
          _Check(
            l10n.settingsAutoMark,
            s.autoMarkPrompts,
            (v) => s.set(autoMarkPrompts: v),
          ),
          const SizedBox(height: 12),
          _Heading(l10n.settingsClipboard),
          _Check(
            l10n.settingsClipboardWrite,
            s.clipboardWrite,
            (v) => s.set(clipboardWrite: v),
          ),
          _Check(
            l10n.settingsClipboardRead,
            s.clipboardRead,
            (v) => s.set(clipboardRead: v),
          ),
          _Note(l10n.settingsClipboardNote),
        ],
      ),
    );
  }

  Widget _directory(
    NewDirectory value,
    ValueChanged<NewDirectory> onChanged,
    String label,
  ) => AmalfiPopUpButton<NewDirectory>(
    size: AmalfiControlSize.small,
    width: 220,
    semanticLabel: label,
    items: [
      AmalfiPopUpItem(value: NewDirectory.home, label: l10n.settingsHome),
      AmalfiPopUpItem(
        value: NewDirectory.sameAsCurrent,
        label: l10n.settingsSameDirectory,
      ),
    ],
    value: value,
    onChanged: onChanged,
  );

  // ---- Profiles ---------------------------------------------------------------------

  Widget _profiles(AmalfiColors colors) {
    final s = _s;
    final profile = _profile;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 200,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  key: const ValueKey('profile list'),
                  children: [
                    for (final p in s.profiles) _profileRow(p, colors),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  spacing: 8,
                  children: [
                    AmalfiPushButton(
                      key: const ValueKey('duplicate profile'),
                      label: l10n.settingsDuplicate,
                      size: AmalfiControlSize.small,
                      onPressed: () {
                        final copy = s.duplicateProfile(
                          profile,
                          l10n.settingsCopyName(profile.name),
                        );
                        setState(() => _selected = copy.id);
                      },
                    ),
                    AmalfiPushButton(
                      key: const ValueKey('remove profile'),
                      label: l10n.settingsRemove,
                      size: AmalfiControlSize.small,
                      onPressed: s.profiles.length > 1
                          ? () {
                              s.removeProfile(profile.id);
                              setState(() => _selected = null);
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ColoredBox(
          color: colors.lineSeparator,
          child: const SizedBox(width: 1),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: AmalfiSegmentedControl(
                    key: const ValueKey('profile tabs'),
                    size: AmalfiControlSize.small,
                    segments: [
                      AmalfiSegment.text(l10n.profileText),
                      AmalfiSegment.text(l10n.profileWindow),
                      AmalfiSegment.text(l10n.profileTab),
                      AmalfiSegment.text(l10n.profileShell),
                      AmalfiSegment.text(l10n.profileKeyboard),
                      AmalfiSegment.text(l10n.profileAdvanced),
                    ],
                    selected: {_profileTab.index},
                    onChanged: (v) => setState(
                      () => _profileTab = ProfileTab.values[v.first],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: _profilePane(profile),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _profileRow(TerminalProfile p, AmalfiColors colors) {
    final selected = p.id == _profile.id;
    final scheme = p.scheme == 'default' ? null : extraProfiles[p.scheme];
    final background = scheme?.background ?? colors.surfaceWindow;
    final foreground = scheme?.foreground ?? colors.textPrimary;
    return GestureDetector(
      key: ValueKey('profile ${p.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selected = p.id),
      child: Container(
        height: profileRowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: selected ? colors.accentAmalfiSoft : null,
        child: Row(
          spacing: 10,
          children: [
            Container(
              width: 40,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: colors.lineSeparator),
              ),
              child: Text(
                '\$ _',
                style: TextStyle(
                  fontFamily: terminalFontFamily,
                  fontSize: 9,
                  color: foreground,
                ),
              ),
            ),
            Expanded(
              child: Text(
                p.id == _s.defaultProfile.id
                    ? l10n.settingsDefaultMark(p.name)
                    : p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AmalfiType.body(color: colors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profilePane(TerminalProfile p) {
    void edit(TerminalProfile next) => _s.updateProfile(next);
    return switch (_profileTab) {
      ProfileTab.text => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Row(
            l10n.profileName,
            _TextBox(
              key: ValueKey('name ${p.id}'),
              text: p.name,
              width: 200,
              onChanged: (v) {
                if (v.trim().isNotEmpty) edit(p.copyWith(name: v.trim()));
              },
            ),
          ),
          _Row(
            l10n.profileScheme,
            AmalfiPopUpButton<String>(
              key: const ValueKey('scheme'),
              size: AmalfiControlSize.small,
              width: 200,
              semanticLabel: l10n.profileScheme,
              items: [
                AmalfiPopUpItem(value: 'default', label: l10n.schemeDefault),
                for (final name in extraProfiles.keys)
                  AmalfiPopUpItem(value: name, label: _titleCase(name)),
              ],
              value: p.scheme,
              onChanged: (v) => edit(p.copyWith(scheme: v)),
            ),
          ),
          _Row(
            l10n.profileFont,
            _TextBox(
              key: ValueKey('font ${p.id}'),
              text: p.fontFamily,
              width: 200,
              onChanged: (v) {
                if (v.trim().isNotEmpty) edit(p.copyWith(fontFamily: v.trim()));
              },
            ),
          ),
          _Row(
            l10n.profileFontSize,
            AmalfiStepper(
              key: const ValueKey('font size'),
              size: AmalfiControlSize.small,
              value: p.fontSize,
              min: fontSizeSteps.first,
              max: fontSizeSteps.last,
              onChanged: (v) => edit(p.copyWith(fontSize: v)),
              semanticLabel: l10n.profileFontSize,
            ),
          ),
          _Check(
            l10n.profileBoldText,
            p.boldText,
            (v) => edit(p.copyWith(boldText: v)),
          ),
          _Row(
            l10n.profileCursor,
            AmalfiPopUpButton<CursorStyleChoice>(
              key: const ValueKey('cursor'),
              size: AmalfiControlSize.small,
              width: 140,
              semanticLabel: l10n.profileCursor,
              items: [
                AmalfiPopUpItem(
                  value: CursorStyleChoice.block,
                  label: l10n.cursorBlock,
                ),
                AmalfiPopUpItem(
                  value: CursorStyleChoice.underline,
                  label: l10n.cursorUnderline,
                ),
                AmalfiPopUpItem(
                  value: CursorStyleChoice.beam,
                  label: l10n.cursorBar,
                ),
              ],
              value: p.cursor,
              onChanged: (v) => edit(p.copyWith(cursor: v)),
            ),
          ),
          _Check(
            l10n.profileCursorBlink,
            p.cursorBlink,
            (v) => edit(p.copyWith(cursorBlink: v)),
          ),
        ],
      ),
      ProfileTab.window => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Row(
            l10n.profileColumns,
            AmalfiStepper(
              key: const ValueKey('columns'),
              size: AmalfiControlSize.small,
              value: p.columns.toDouble(),
              min: minimumColumns.toDouble(),
              max: 300,
              onChanged: (v) => edit(p.copyWith(columns: v.round())),
              semanticLabel: l10n.profileColumns,
            ),
          ),
          _Row(
            l10n.profileRows,
            AmalfiStepper(
              key: const ValueKey('rows'),
              size: AmalfiControlSize.small,
              value: p.rows.toDouble(),
              min: minimumRows.toDouble(),
              max: 100,
              onChanged: (v) => edit(p.copyWith(rows: v.round())),
              semanticLabel: l10n.profileRows,
            ),
          ),
          _Check(
            l10n.profileTitleSize,
            p.titleShowsSize,
            (v) => edit(p.copyWith(titleShowsSize: v)),
          ),
        ],
      ),
      ProfileTab.tab => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Check(
            l10n.profileTitleDirectory,
            p.titleShowsDirectory,
            (v) => edit(p.copyWith(titleShowsDirectory: v)),
          ),
          _Check(
            l10n.profileShowMarks,
            p.showMarks,
            (v) => edit(p.copyWith(showMarks: v)),
          ),
        ],
      ),
      ProfileTab.shell => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Row(
            l10n.profileStartup,
            _TextBox(
              key: ValueKey('startup ${p.id}'),
              text: p.startupCommand,
              placeholder: l10n.profileStartupPlaceholder,
              width: 240,
              onChanged: (v) => edit(p.copyWith(startupCommand: v)),
            ),
          ),
          _Row(
            l10n.profileWhenExits,
            AmalfiPopUpButton<CloseOnExit>(
              key: const ValueKey('close on exit'),
              size: AmalfiControlSize.small,
              width: 240,
              semanticLabel: l10n.profileWhenExits,
              items: [
                AmalfiPopUpItem(
                  value: CloseOnExit.close,
                  label: l10n.exitClose,
                ),
                AmalfiPopUpItem(
                  value: CloseOnExit.closeIfClean,
                  label: l10n.exitCloseIfClean,
                ),
                AmalfiPopUpItem(value: CloseOnExit.keep, label: l10n.exitKeep),
              ],
              value: p.closeOnExit,
              onChanged: (v) => edit(p.copyWith(closeOnExit: v)),
            ),
          ),
          _Row(
            l10n.profileAskBeforeClosing,
            AmalfiPopUpButton<AskBeforeClosing>(
              key: const ValueKey('ask before closing'),
              size: AmalfiControlSize.small,
              width: 240,
              semanticLabel: l10n.profileAskBeforeClosing,
              items: [
                AmalfiPopUpItem(
                  value: AskBeforeClosing.always,
                  label: l10n.askAlways,
                ),
                AmalfiPopUpItem(
                  value: AskBeforeClosing.never,
                  label: l10n.askNever,
                ),
                AmalfiPopUpItem(
                  value: AskBeforeClosing.running,
                  label: l10n.askRunning,
                ),
              ],
              value: p.askBeforeClosing,
              onChanged: (v) => edit(p.copyWith(askBeforeClosing: v)),
            ),
          ),
        ],
      ),
      ProfileTab.keyboard => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Check(
            l10n.optionAsMeta,
            p.optionAsMeta,
            (v) => edit(p.copyWith(optionAsMeta: v)),
          ),
          _Note(l10n.profileOptionNote),
        ],
      ),
      ProfileTab.advanced => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Heading(l10n.profileScrollback),
          _Row(
            l10n.profileScrollbackKeep,
            AmalfiPopUpButton<bool>(
              key: const ValueKey('scrollback mode'),
              size: AmalfiControlSize.small,
              width: 140,
              semanticLabel: l10n.profileScrollbackKeep,
              items: [
                AmalfiPopUpItem(value: true, label: l10n.scrollbackLimited),
                AmalfiPopUpItem(value: false, label: l10n.scrollbackUnlimited),
              ],
              value: p.scrollbackLimited,
              onChanged: (v) => edit(p.copyWith(scrollbackLimited: v)),
            ),
          ),
          if (p.scrollbackLimited)
            _Row(
              l10n.profileScrollbackLines,
              AmalfiStepper(
                key: const ValueKey('scrollback lines'),
                size: AmalfiControlSize.small,
                value: p.scrollbackLines.toDouble(),
                min: 0,
                max: 100000,
                step: 1000,
                onChanged: (v) => edit(p.copyWith(scrollbackLines: v.round())),
                semanticLabel: l10n.profileScrollbackLines,
              ),
            ),
          const SizedBox(height: 12),
          _Heading(l10n.profileBell),
          _Check(
            l10n.profileBellVisual,
            p.bellVisual,
            (v) => edit(p.copyWith(bellVisual: v)),
          ),
          _Check(
            l10n.profileBellNotify,
            p.bellNotify,
            (v) => edit(p.copyWith(bellNotify: v)),
          ),
        ],
      ),
    };
  }

  static String _titleCase(String name) => name.isEmpty
      ? name
      : name
            .split(' ')
            .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
            .join(' ');

  // ---- Window Groups and Encodings --------------------------------------------------

  Widget _groups(AmalfiColors colors) {
    final groups = _s.windowGroups;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: groups.isEmpty
          ? Center(child: _Note(l10n.settingsNoGroups))
          : ListView(
              key: const ValueKey('group list'),
              children: [
                for (final g in groups)
                  SizedBox(
                    height: profileRowHeight,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.settingsGroupSummary(g.name, g.windows.length),
                            style: AmalfiType.body(color: colors.textPrimary),
                          ),
                        ),
                        AmalfiPushButton(
                          key: ValueKey('remove group ${g.name}'),
                          label: l10n.settingsRemove,
                          size: AmalfiControlSize.small,
                          onPressed: () => _s.removeWindowGroup(g.name),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _encodings(AmalfiColors colors) => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(child: _Note(l10n.settingsEncodingsNote)),
  );
}

// Rows -------------------------------------------------------------------------------------

class _Row extends StatelessWidget {
  const _Row(this.label, this.control);
  final String label;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 190,
            child: Text(
              label,
              maxLines: 2,
              style: AmalfiType.body(color: colors.textPrimary),
            ),
          ),
          Flexible(
            child: Align(alignment: Alignment.centerLeft, child: control),
          ),
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check(this.label, this.value, this.onChanged);
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        spacing: 8,
        children: [
          AmalfiCheckbox(
            value: value,
            size: AmalfiControlSize.small,
            semanticLabel: label,
            onChanged: onChanged,
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(!value),
              child: Text(
                label,
                style: AmalfiType.body(color: colors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: AmalfiType.headline(color: colors.textPrimary)),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 26),
      child: Text(text, style: AmalfiType.caption(color: colors.textSecondary)),
    );
  }
}

/// A text field that keeps its own controller, so typing does not reset the caret when the
/// settings change under it.
class _TextBox extends StatefulWidget {
  const _TextBox({
    super.key,
    required this.text,
    required this.onChanged,
    this.placeholder,
    this.width = 200,
  });

  final String text;
  final String? placeholder;
  final double width;
  final ValueChanged<String> onChanged;

  @override
  State<_TextBox> createState() => _TextBoxState();
}

class _TextBoxState extends State<_TextBox> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AmalfiTextField(
    controller: _controller,
    placeholder: widget.placeholder,
    size: AmalfiFieldSize.small,
    width: widget.width,
    onChanged: widget.onChanged,
  );
}

/// An [Overlay] for the pop-up menus of the controls: a window of its own has none.
class _OverlayRoot extends StatefulWidget {
  const _OverlayRoot({required this.child});
  final Widget child;

  @override
  State<_OverlayRoot> createState() => _OverlayRootState();
}

class _OverlayRootState extends State<_OverlayRoot> {
  late final OverlayEntry _entry = OverlayEntry(builder: (_) => widget.child);

  @override
  void didUpdateWidget(_OverlayRoot old) {
    super.didUpdateWidget(old);
    _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    _entry.remove();
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}
