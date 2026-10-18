// Terminal › Settings… (⌘,; docs/spec/settings.md, ST-APPSET-05…07) on the Amalfi design
// (silica-desktop docs/design/amalfi/terminal-settings.md): a window of 800 × 680 with the
// Segmented Control, Icon + Label under the title bar (General, Profiles, Window Groups,
// Encodings), regular controls, padding 24. Profiles has the list of profiles on the left and,
// on the right, the sub-tabs Text, Window, Tab, Shell, Keyboard and Advanced (a six text segment
// control, 80 per segment).

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'app.dart';
import 'l10n.dart';
import 'settings.dart';
import 'style.dart';

/// The window of the settings.
const Size settingsWindowSize = Size(800, 680);

/// The height of a row of the profile list.
const double profileRowHeight = 44;

/// Padding of the window's content.
const double _padding = 24;

/// The label cell of the General and Window Groups panes, and its gap to the control.
const double _generalLabel = 160;
const double _labelGap = 12;

/// The label cell of the profile pane.
const double _profileLabel = 128;

/// A regular control and the gap between rows of controls.
const double _control = 28;
const double _rowGap = 12;

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
          // The title bar keeps the window controls only; the pane switcher sits under it.
          const SizedBox(height: AmalfiToolbarMetrics.toolbarHeight),
          Center(
            child: AmalfiIconLabelSegmentedControl(
              key: const ValueKey('settings tabs'),
              tabs: [
                AmalfiIconLabelSegment(
                  label: l10n.settingsGeneral,
                  symbol: 'gear',
                ),
                AmalfiIconLabelSegment(
                  label: l10n.settingsProfiles,
                  symbol: 'terminal',
                ),
                AmalfiIconLabelSegment(
                  label: l10n.settingsWindowGroups,
                  symbol: 'window-stack',
                ),
                AmalfiIconLabelSegment(
                  label: l10n.settingsEncodings,
                  symbol: 'globe',
                ),
              ],
              selected: _tab.index,
              onChanged: (i) => setState(() => _tab = SettingsTab.values[i]),
            ),
          ),
          const SizedBox(height: 20),
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
    final groups = s.windowGroups;
    final launch =
        s.launchGroup != null && groups.any((g) => g.name == s.launchGroup)
        ? s.launchGroup
        : null;
    final custom = s.shellCommand.isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(_padding, 0, _padding, _padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Section(l10n.settingsSectionWindowsTabs),
          _Box(
            children: [
              _Row(
                l10n.settingsOnLaunch,
                AmalfiPopUpButton<String?>(
                  key: const ValueKey('on launch'),
                  width: 240,
                  semanticLabel: l10n.settingsOnLaunch,
                  items: [
                    AmalfiPopUpItem<String?>(
                      value: null,
                      label: l10n.settingsLaunchNewWindow,
                    ),
                    for (final g in groups)
                      AmalfiPopUpItem<String?>(
                        value: g.name,
                        label: l10n.settingsLaunchGroup(g.name),
                      ),
                  ],
                  value: launch,
                  onChanged: (v) => s.set(launchGroup: v),
                ),
                width: _generalLabel,
              ),
              const SizedBox(height: _rowGap),
              _Row(
                l10n.settingsDefaultProfile,
                AmalfiPopUpButton<String>(
                  key: const ValueKey('default profile'),
                  width: 140,
                  semanticLabel: l10n.settingsDefaultProfile,
                  items: [
                    for (final p in s.profiles)
                      AmalfiPopUpItem(value: p.id, label: p.name),
                  ],
                  value: s.defaultProfile.id,
                  onChanged: (id) => s.setDefaultProfile(id),
                ),
                width: _generalLabel,
              ),
              const SizedBox(height: _rowGap),
              _Row(
                l10n.settingsShellNewWindows,
                Row(
                  spacing: 8,
                  children: [
                    AmalfiPopUpButton<bool>(
                      key: const ValueKey('shell for new windows'),
                      width: 200,
                      semanticLabel: l10n.settingsShellNewWindows,
                      items: [
                        AmalfiPopUpItem(
                          value: false,
                          label: l10n.settingsShellDefault,
                        ),
                        AmalfiPopUpItem(
                          value: true,
                          label: l10n.settingsShellCommand,
                        ),
                      ],
                      value: custom,
                      // A command needs a program: start from the usual one.
                      onChanged: (v) => s.set(shellCommand: v ? '/bin/sh' : ''),
                    ),
                    if (custom)
                      _TextBox(
                        key: const ValueKey('shell command'),
                        text: s.shellCommand,
                        placeholder: l10n.settingsShellCommandPlaceholder,
                        width: 240,
                        onChanged: (v) => s.set(shellCommand: v.trim()),
                      ),
                  ],
                ),
                width: _generalLabel,
              ),
              const SizedBox(height: _rowGap),
              _Row(
                l10n.settingsNewWindows,
                _directory(
                  s.newWindowDirectory,
                  (v) => s.set(newWindowDirectory: v),
                  l10n.settingsNewWindows,
                ),
                width: _generalLabel,
              ),
              const SizedBox(height: _rowGap),
              _Row(
                l10n.settingsNewTabs,
                _directory(
                  s.newTabDirectory,
                  (v) => s.set(newTabDirectory: v),
                  l10n.settingsNewTabs,
                ),
                width: _generalLabel,
              ),
              const SizedBox(height: _rowGap),
              _Check(
                l10n.settingsTabSwitchingCheck,
                s.tabSwitching,
                (v) => s.set(tabSwitching: v),
                label: l10n.settingsTabSwitching,
                width: _generalLabel,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Section(l10n.settingsSectionPrograms),
          _Box(
            children: [
              _Check(
                l10n.settingsMouseReporting,
                s.mouseReporting,
                (v) => s.set(mouseReporting: v),
                label: l10n.settingsMouseLabel,
                width: _generalLabel,
              ),
              const SizedBox(height: 8),
              _Check(
                l10n.settingsOpenLinks,
                s.openLinks,
                (v) => s.set(openLinks: v),
                label: l10n.settingsLinksLabel,
                width: _generalLabel,
              ),
              const SizedBox(height: 8),
              _Check(
                l10n.settingsAutoMark,
                s.autoMarkPrompts,
                (v) => s.set(autoMarkPrompts: v),
                label: l10n.settingsPromptsLabel,
                width: _generalLabel,
              ),
              const SizedBox(height: 8),
              _Check(
                l10n.settingsClipboardWrite,
                s.clipboardWrite,
                (v) => s.set(clipboardWrite: v),
                label: l10n.settingsClipboard,
                width: _generalLabel,
              ),
              _Check(
                l10n.settingsClipboardRead,
                s.clipboardRead,
                (v) => s.set(clipboardRead: v),
                width: _generalLabel,
              ),
              _Note(l10n.settingsClipboardNote, indent: _generalLabel),
            ],
          ),
        ],
      ),
    );
  }

  Widget _directory(
    NewDirectory value,
    ValueChanged<NewDirectory> onChanged,
    String label,
  ) => AmalfiPopUpButton<NewDirectory>(
    width: 240,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(_padding, 0, _padding, _padding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 24,
        children: [
          SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: _boxDecoration(colors),
                    child: ListView(
                      key: const ValueKey('profile list'),
                      padding: const EdgeInsets.all(4),
                      children: [
                        for (final p in s.profiles) _profileRow(p, colors),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  spacing: 8,
                  children: [
                    AmalfiPushButton(
                      key: const ValueKey('duplicate profile'),
                      label: l10n.settingsDuplicate,
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
                      onPressed: s.profiles.length > 1
                          ? () {
                              s.removeProfile(profile.id);
                              setState(() => _selected = null);
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: AmalfiSegmentedControl(
                    key: const ValueKey('profile tabs'),
                    textItemWidth: 80,
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
                const SizedBox(height: 12),
                Expanded(
                  child: DecoratedBox(
                    decoration: _boxDecoration(colors),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _profilePane(profile),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileRow(TerminalProfile p, AmalfiColors colors) {
    final selected = p.id == _profile.id;
    final scheme = p.scheme == 'default' ? null : extraProfiles[p.scheme];
    final background =
        (p.backgroundColor != null ? Color(p.backgroundColor!) : null) ??
        scheme?.background ??
        colors.surfaceWindow;
    final foreground =
        (p.textColor != null ? Color(p.textColor!) : null) ??
        scheme?.foreground ??
        colors.textPrimary;
    return GestureDetector(
      key: ValueKey('profile ${p.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selected = p.id),
      child: Container(
        height: profileRowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: selected
            ? AmalfiShapeDecoration(
                color: colors.accentAmalfiSoft,
                shape: const AmalfiSmoothBorder(radius: 8),
              )
            : null,
        child: Row(
          spacing: 12,
          children: [
            Container(
              key: ValueKey('profile preview ${p.id}'),
              width: 40,
              height: 28,
              alignment: Alignment.center,
              decoration: AmalfiShapeDecoration(
                color: background,
                shape: AmalfiSmoothBorder(
                  radius: 6,
                  side: BorderSide(
                    color: colors.lineBorder,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
              ),
              child: Text(
                '\$ _',
                style: TextStyle(
                  fontFamily: terminalFontFamily,
                  fontSize: 12,
                  height: 16 / 12,
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
                style: selected
                    ? AmalfiType.headline(color: colors.textPrimary)
                    : AmalfiType.body(color: colors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const double _gap = _rowGap;

  Widget _profilePane(TerminalProfile p) {
    void edit(TerminalProfile next) => _s.updateProfile(next);
    const w = _profileLabel;
    const space = SizedBox(height: _gap);
    return switch (_profileTab) {
      ProfileTab.text => _text(p, edit),
      ProfileTab.window => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Row(
            l10n.profileColumns,
            AmalfiStepperField(
              key: const ValueKey('columns'),
              value: p.columns.toDouble(),
              min: minimumColumns.toDouble(),
              max: 300,
              onChanged: (v) => edit(p.copyWith(columns: v.round())),
              semanticLabel: l10n.profileColumns,
            ),
            width: w,
          ),
          space,
          _Row(
            l10n.profileRows,
            AmalfiStepperField(
              key: const ValueKey('rows'),
              value: p.rows.toDouble(),
              min: minimumRows.toDouble(),
              max: 100,
              onChanged: (v) => edit(p.copyWith(rows: v.round())),
              semanticLabel: l10n.profileRows,
            ),
            width: w,
          ),
          space,
          _Check(
            l10n.profileTitleSize,
            p.titleShowsSize,
            (v) => edit(p.copyWith(titleShowsSize: v)),
            label: l10n.profileTitleLabel,
            width: w,
          ),
          _Check(
            l10n.profileTitleProcess,
            p.titleShowsProcess,
            null,
            key: const ValueKey('title process'),
            width: w,
          ),
          const SizedBox(height: 8),
          _Check(
            l10n.profileRestoreText,
            p.restoreText,
            null,
            key: const ValueKey('restore text'),
            label: l10n.profileRestoreLabel,
            width: w,
          ),
          space,
          _Row(
            l10n.profileRestoreLines,
            Row(
              spacing: 8,
              children: [
                AmalfiStepperField(
                  key: const ValueKey('restore lines'),
                  value: p.restoreLines.toDouble(),
                  min: 0,
                  max: 1000000,
                  step: 1000,
                  fieldWidth: 80,
                  onChanged: null,
                  semanticLabel: l10n.profileRestoreLines,
                ),
                _Unit(l10n.profileLinesUnit),
              ],
            ),
            width: w,
          ),
          _Note(l10n.profileNotYetNote, indent: w),
        ],
      ),
      ProfileTab.tab => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Check(
            l10n.profileTitleDirectory,
            p.titleShowsDirectory,
            (v) => edit(p.copyWith(titleShowsDirectory: v)),
            label: l10n.profileTitleLabel,
            width: w,
          ),
          const SizedBox(height: 8),
          _Check(
            l10n.profileShowMarks,
            p.showMarks,
            (v) => edit(p.copyWith(showMarks: v)),
            label: l10n.profileMarksLabel,
            width: w,
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
              width: 280,
              onChanged: (v) => edit(p.copyWith(startupCommand: v)),
            ),
            width: w,
          ),
          space,
          _Row(
            l10n.profileWhenExits,
            AmalfiPopUpButton<CloseOnExit>(
              key: const ValueKey('close on exit'),
              width: 280,
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
            width: w,
          ),
          space,
          _LabelCell(
            l10n.profileAskBeforeClosing,
            width: w,
            top: true,
            child: AmalfiRadioGroup<AskBeforeClosing>(
              key: const ValueKey('ask before closing'),
              value: p.askBeforeClosing,
              onChanged: (v) => edit(p.copyWith(askBeforeClosing: v)),
              options: [
                AmalfiRadioOption(
                  value: AskBeforeClosing.always,
                  label: l10n.askAlways,
                ),
                AmalfiRadioOption(
                  value: AskBeforeClosing.never,
                  label: l10n.askNever,
                ),
                AmalfiRadioOption(
                  value: AskBeforeClosing.running,
                  label: l10n.askRunning,
                ),
              ],
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
            label: l10n.profileKeyboard,
            width: w,
          ),
          _Note(l10n.profileOptionNote, indent: w),
        ],
      ),
      ProfileTab.advanced => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Row(
            l10n.profileScrollback,
            AmalfiPopUpButton<bool>(
              key: const ValueKey('scrollback mode'),
              width: 140,
              semanticLabel: l10n.profileScrollback,
              items: [
                AmalfiPopUpItem(value: true, label: l10n.scrollbackLimited),
                AmalfiPopUpItem(value: false, label: l10n.scrollbackUnlimited),
              ],
              value: p.scrollbackLimited,
              onChanged: (v) => edit(p.copyWith(scrollbackLimited: v)),
            ),
            width: w,
          ),
          if (p.scrollbackLimited) ...[
            space,
            _Row(
              l10n.profileScrollbackLines,
              Row(
                spacing: 8,
                children: [
                  AmalfiStepperField(
                    key: const ValueKey('scrollback lines'),
                    value: p.scrollbackLines.toDouble(),
                    min: 0,
                    max: 100000,
                    step: 1000,
                    fieldWidth: 80,
                    onChanged: (v) =>
                        edit(p.copyWith(scrollbackLines: v.round())),
                    semanticLabel: l10n.profileScrollbackLines,
                  ),
                  _Unit(l10n.profileLinesUnit),
                ],
              ),
              width: w,
            ),
          ],
          const SizedBox(height: 8),
          _Check(
            l10n.profileBellVisual,
            p.bellVisual,
            (v) => edit(p.copyWith(bellVisual: v)),
            label: l10n.profileBell,
            width: w,
          ),
          _Check(
            l10n.profileBellNotify,
            p.bellNotify,
            (v) => edit(p.copyWith(bellNotify: v)),
            width: w,
          ),
        ],
      ),
    };
  }

  /// The colour the profile shows for one of the five wells: its own, else the scheme's.
  Color _wellColor(int? own, Color Function(GridColors) of, TerminalProfile p) {
    if (own != null) return Color(own);
    final base = p.scheme == 'default'
        ? profileOf(context).grid
        : (extraProfiles[p.scheme] ?? profileOf(context).grid);
    return of(base);
  }

  Widget _text(TerminalProfile p, void Function(TerminalProfile) edit) {
    const w = _profileLabel;
    const space = SizedBox(height: _gap);
    Widget well(
      String caption,
      int? own,
      Color Function(GridColors) of,
      TerminalProfile Function(int?) set,
      String key,
    ) => SizedBox(
      width: 64,
      child: Column(
        spacing: 2,
        children: [
          AmalfiColorWell(
            key: ValueKey('$key ${p.id}'),
            style: AmalfiColorWellStyle.minimal,
            color: _wellColor(own, of, p),
            panelTitle: l10n.profileColorPanel,
            semanticLabel: caption,
            onChanged: (c) => edit(set(c.toARGB32())),
          ),
          Text(
            caption,
            maxLines: 1,
            style: AmalfiType.caption(
              color: AmalfiTheme.of(context).colors.textSecondary,
            ),
          ),
        ],
      ),
    );
    return Column(
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
          width: w,
        ),
        space,
        _Row(
          l10n.profileScheme,
          AmalfiPopUpButton<String>(
            key: const ValueKey('scheme'),
            width: 256,
            semanticLabel: l10n.profileScheme,
            items: [
              AmalfiPopUpItem(value: 'default', label: l10n.schemeDefault),
              for (final name in extraProfiles.keys)
                AmalfiPopUpItem(value: name, label: _titleCase(name)),
            ],
            value: p.scheme,
            // A new scheme brings its own colours: the edits of the old one go.
            onChanged: (v) => edit(
              p.copyWith(
                scheme: v,
                backgroundColor: null,
                textColor: null,
                boldColor: null,
                selectionColor: null,
                cursorColor: null,
              ),
            ),
          ),
          width: w,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: w + _labelGap),
          child: Row(
            children: [
              well(
                l10n.profileColorBackground,
                p.backgroundColor,
                (c) => c.background,
                (v) => p.copyWith(backgroundColor: v),
                'color background',
              ),
              well(
                l10n.profileColorText,
                p.textColor,
                (c) => c.foreground,
                (v) => p.copyWith(textColor: v),
                'color text',
              ),
              well(
                l10n.profileColorBold,
                p.boldColor,
                (c) => c.bold,
                (v) => p.copyWith(boldColor: v),
                'color bold',
              ),
              well(
                l10n.profileColorSelection,
                p.selectionColor,
                (c) => c.selection,
                (v) => p.copyWith(selectionColor: v),
                'color selection',
              ),
              well(
                l10n.profileColorCursor,
                p.cursorColor,
                (c) => c.cursor,
                (v) => p.copyWith(cursorColor: v),
                'color cursor',
              ),
            ],
          ),
        ),
        space,
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
          width: w,
        ),
        space,
        _Row(
          l10n.profileFontSize,
          Row(
            spacing: 8,
            children: [
              AmalfiStepperField(
                key: const ValueKey('font size'),
                value: p.fontSize,
                min: fontSizeSteps.first,
                max: fontSizeSteps.last,
                onChanged: (v) =>
                    edit(p.copyWith(fontSize: _snapFontSize(v, p.fontSize))),
                semanticLabel: l10n.profileFontSize,
              ),
              _Unit(l10n.profilePointsUnit),
            ],
          ),
          width: w,
        ),
        space,
        _Check(
          l10n.profileBoldText,
          p.boldText,
          (v) => edit(p.copyWith(boldText: v)),
          label: l10n.profileText,
          width: w,
        ),
        _Check(
          l10n.profileAntialias,
          p.antialias,
          null,
          key: const ValueKey('antialias'),
          width: w,
        ),
        _Check(
          l10n.profileBlinkingText,
          p.blinkingText,
          null,
          key: const ValueKey('blinking text'),
          width: w,
        ),
        _Check(
          l10n.profileAnsiColors,
          p.ansiColors,
          (v) => edit(p.copyWith(ansiColors: v)),
          width: w,
        ),
        _Check(
          l10n.profileBrightBold,
          p.brightBold,
          (v) => edit(p.copyWith(brightBold: v)),
          width: w,
        ),
        space,
        _Row(
          l10n.profileCursor,
          AmalfiPopUpButton<CursorStyleChoice>(
            key: const ValueKey('cursor'),
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
          width: w,
        ),
        _Check(
          l10n.profileCursorBlink,
          p.cursorBlink,
          (v) => edit(p.copyWith(cursorBlink: v)),
          width: w,
        ),
        _Note(l10n.profileNotYetNote, indent: w),
      ],
    );
  }

  /// The font size steps (8 9 10 … 48): the stepper's value moves to the step it points at.
  static double _snapFontSize(double v, double current) {
    if (v > current) {
      return fontSizeSteps.firstWhere(
        (s) => s >= v,
        orElse: () => fontSizeSteps.last,
      );
    }
    if (v < current) {
      return fontSizeSteps.lastWhere(
        (s) => s <= v,
        orElse: () => fontSizeSteps.first,
      );
    }
    return current;
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(_padding, 0, _padding, _padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Section(l10n.settingsSavedGroups),
          if (groups.isEmpty)
            _Note(l10n.settingsNoGroups, indent: 0)
          else
            DecoratedBox(
              decoration: _boxDecoration(colors),
              child: Column(
                key: const ValueKey('group list'),
                children: [
                  for (var i = 0; i < groups.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ColoredBox(
                          color: colors.lineSeparator,
                          child: const SizedBox(
                            height: 1,
                            width: double.infinity,
                          ),
                        ),
                      ),
                    SizedBox(
                      height: 44,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.settingsGroupSummary(
                                  groups[i].name,
                                  groups[i].windows.length,
                                ),
                                style: AmalfiType.body(
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                            AmalfiPushButton(
                              key: ValueKey('remove group ${groups[i].name}'),
                              label: l10n.settingsRemove,
                              onPressed: () =>
                                  _s.removeWindowGroup(groups[i].name),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _encodings(AmalfiColors colors) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(_padding, 0, _padding, _padding),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(l10n.settingsCharacterEncoding),
        _Box(
          children: [
            _Check(
              l10n.settingsUtf8,
              true,
              null,
              key: const ValueKey('utf8'),
              label: l10n.settingsEncodings,
              width: _generalLabel,
            ),
            _Note(l10n.settingsEncodingsNote, indent: _generalLabel),
          ],
        ),
      ],
    ),
  );
}

// Layout pieces ---------------------------------------------------------------------------

ShapeDecoration _boxDecoration(AmalfiColors colors) => AmalfiShapeDecoration(
  color: colors.surfaceSidebar,
  shape: const AmalfiSmoothBorder(radius: 12),
);

/// A section title (`Headline/Secondary`, 24 tall: the box follows 24 below its top).
class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    return SizedBox(
      height: 24,
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          text,
          style: AmalfiType.headline(color: colors.textSecondary),
        ),
      ),
    );
  }
}

/// The `Surface/Sidebar` box of a section: radius 12, 12 above and below, 16 beside.
class _Box extends StatelessWidget {
  const _Box({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: _boxDecoration(AmalfiTheme.of(context).colors),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

/// A label cell (right-aligned `Body/Primary`), 12 to the control.
class _LabelCell extends StatelessWidget {
  const _LabelCell(
    this.label, {
    required this.width,
    required this.child,
    this.top = false,
  });
  final String label;
  final double width;
  final Widget child;

  /// Whether the label sits at the top of a tall control (radios) instead of its middle.
  final bool top;

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    return Row(
      crossAxisAlignment: top
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: width,
          height: top ? _control : null,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              label,
              maxLines: 1,
              textAlign: TextAlign.right,
              style: AmalfiType.body(color: colors.textPrimary),
            ),
          ),
        ),
        const SizedBox(width: _labelGap),
        Flexible(
          child: Align(alignment: Alignment.centerLeft, child: child),
        ),
      ],
    );
  }
}

/// A row of a 28 pt control with its label.
class _Row extends StatelessWidget {
  const _Row(this.label, this.control, {required this.width});
  final String label;
  final Widget control;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _control,
    child: _LabelCell(label, width: width, child: control),
  );
}

/// A checkbox with its label in a 28 pt slot; [label] fills the label cell (first of a group).
/// [onChanged] null: disabled.
class _Check extends StatelessWidget {
  const _Check(
    this.text,
    this.value,
    this.onChanged, {
    super.key,
    this.label = '',
    required this.width,
  });
  final String text;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _control,
    child: _LabelCell(
      label,
      width: width,
      child: AmalfiCheckbox(
        value: value,
        label: text,
        semanticLabel: text,
        onChanged: onChanged,
      ),
    ),
  );
}

/// A unit after a field ("pt", "lines").
class _Unit extends StatelessWidget {
  const _Unit(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AmalfiType.body(color: AmalfiTheme.of(context).colors.textPrimary),
  );
}

/// A note under the control it explains (`Caption/Secondary`), [indent] pt from the label
/// cell's left edge: aligned with the control's label text.
class _Note extends StatelessWidget {
  const _Note(this.text, {required this.indent});
  final String text;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    return Padding(
      padding: EdgeInsets.only(
        top: 2,
        left: indent == 0 ? 0 : indent + _labelGap + 28,
      ),
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
    size: AmalfiFieldSize.regular,
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
