// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Terminal';

  @override
  String windowTitle(String title, int columns, int rows) {
    return '$title — $columns×$rows';
  }

  @override
  String get newTab => 'New Tab';

  @override
  String get closeTab => 'Close Tab';

  @override
  String get closeTabConfirmTitle =>
      'Do you want to terminate running processes in this tab?';

  @override
  String get closeTabConfirmMessage =>
      'Closing this tab will terminate the running processes in it.';

  @override
  String get closeWindowConfirmTitle =>
      'Do you want to terminate running processes in this window?';

  @override
  String get closeWindowConfirmMessage =>
      'Closing this window will terminate the running processes in it.';

  @override
  String get terminate => 'Terminate';

  @override
  String get cancel => 'Cancel';

  @override
  String get noPty =>
      'The terminal needs the Silica desktop: its pseudo-terminal service is not available here.';

  @override
  String spawnFailed(String error) {
    return 'Could not start the shell: $error';
  }

  @override
  String processExited(int code) {
    return 'The process exited with code $code.';
  }

  @override
  String processKilled(int signal) {
    return 'The process was ended by signal $signal.';
  }

  @override
  String get find => 'Find';

  @override
  String findMatches(int current, int count) {
    return '$current of $count';
  }

  @override
  String get findNoMatches => 'No matches';

  @override
  String get findPrevious => 'Previous match';

  @override
  String get findNext => 'Next match';

  @override
  String get findDone => 'Done';

  @override
  String get menuShell => 'Shell';

  @override
  String get menuEdit => 'Edit';

  @override
  String get menuView => 'View';

  @override
  String get menuWindow => 'Window';

  @override
  String get menuHelp => 'Help';

  @override
  String get secureKeyboardEntry => 'Secure Keyboard Entry';

  @override
  String get newWindow => 'New Window';

  @override
  String newWindowWithProfile(String profile) {
    return 'New Window with Profile - $profile';
  }

  @override
  String get newWindowSameCommand => 'New Window with Same Command';

  @override
  String newTabWithProfile(String profile) {
    return 'New Tab with Profile - $profile';
  }

  @override
  String get newTabSameCommand => 'New Tab with Same Command';

  @override
  String get newCommand => 'New Command…';

  @override
  String get newRemoteConnection => 'New Remote Connection…';

  @override
  String get open => 'Open…';

  @override
  String get closeWindow => 'Close Window';

  @override
  String get closeAll => 'Close All';

  @override
  String get useSettingsAsDefault => 'Use Settings as Default';

  @override
  String get exportSettings => 'Export Settings…';

  @override
  String get exportText => 'Export Text As…';

  @override
  String get exportSelectedText => 'Export Selected Text As…';

  @override
  String get showInspector => 'Show Inspector';

  @override
  String get editTitle => 'Edit Title';

  @override
  String get editBackgroundColor => 'Edit Background Color';

  @override
  String get reset => 'Reset';

  @override
  String get hardReset => 'Hard Reset';

  @override
  String get printSelection => 'Print Selection…';

  @override
  String get print => 'Print…';

  @override
  String get copySpecial => 'Copy Special';

  @override
  String get copyWithoutBackground => 'Copy Without Background Color';

  @override
  String get copyTextOnly => 'Copy Text Only';

  @override
  String get copyStyle => 'Style for Copy Command';

  @override
  String get terminalSettingsDefault => 'Terminal Settings (default)';

  @override
  String get plainText => 'Text Only';

  @override
  String get pasteEscaped => 'Paste Escaped Text';

  @override
  String get pasteSelection => 'Paste Selection';

  @override
  String get pasteSelectionEscaped => 'Paste Selection Escaped';

  @override
  String get selectBetweenMarks => 'Select Between Marks';

  @override
  String get marks => 'Marks';

  @override
  String get autoMarkPrompts => 'Automatically Mark Prompt Lines';

  @override
  String get markLineAndNewline => 'Mark Line and Start New Line';

  @override
  String get newlineWithoutMark => 'Start New Line Without Marking';

  @override
  String get mark => 'Mark';

  @override
  String get markAsBookmark => 'Mark as Bookmark';

  @override
  String get removeMark => 'Remove Mark';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get insertBookmark => 'Insert Bookmark';

  @override
  String get insertNamedBookmark => 'Insert Bookmark with Name…';

  @override
  String get noBookmarks => 'No Bookmarks';

  @override
  String get navigate => 'Navigate';

  @override
  String get previousMark => 'Go to Previous Mark';

  @override
  String get selectToPreviousMark => 'Select to Previous Mark';

  @override
  String get nextMark => 'Go to Next Mark';

  @override
  String get selectToNextMark => 'Select to Next Mark';

  @override
  String get previousBookmark => 'Go to Previous Bookmark';

  @override
  String get selectToPreviousBookmark => 'Select to Previous Bookmark';

  @override
  String get nextBookmark => 'Go to Next Bookmark';

  @override
  String get selectToNextBookmark => 'Select to Next Bookmark';

  @override
  String get clearToPreviousMark => 'Clear to Previous Mark';

  @override
  String get clearToPreviousBookmark => 'Clear to Previous Bookmark';

  @override
  String get clearToStart => 'Clear to Start';

  @override
  String get removeExcessLines => 'Remove Excess Lines';

  @override
  String get clearScreen => 'Clear Screen';

  @override
  String get fillScreen => 'Fill Screen';

  @override
  String get findEllipsis => 'Find…';

  @override
  String get findNextItem => 'Find Next';

  @override
  String get findPreviousItem => 'Find Previous';

  @override
  String get findSelectAll => 'Select All';

  @override
  String get findSelectAllInSelection => 'Select All in Selection';

  @override
  String get hideFindBar => 'Hide Find Bar';

  @override
  String get useSelectionForFind => 'Use Selection for Find';

  @override
  String get jumpToSelection => 'Jump to Selection';

  @override
  String get showColors => 'Show Colors';

  @override
  String get optionAsMeta => 'Use Option as Meta Key';

  @override
  String get numLock => 'Num Lock';

  @override
  String get showAllTabs => 'Show All Tabs';

  @override
  String get showTabBar => 'Show Tab Bar';

  @override
  String get hideMarks => 'Hide Marks';

  @override
  String get showAlternateScreen => 'Show Alternate Screen';

  @override
  String get hideAlternateScreen => 'Hide Alternate Screen';

  @override
  String get allowMouseReporting => 'Allow Mouse Reporting';

  @override
  String get splitPane => 'Split Pane';

  @override
  String get closeSplitPane => 'Close Split Pane';

  @override
  String get defaultFontSize => 'Default Font Size';

  @override
  String get fontBigger => 'Bigger';

  @override
  String get fontSmaller => 'Smaller';

  @override
  String get scrollToTop => 'Scroll to Top';

  @override
  String get scrollToBottom => 'Scroll to Bottom';

  @override
  String get pageUp => 'Page Up';

  @override
  String get pageDown => 'Page Down';

  @override
  String get lineUp => 'Line Up';

  @override
  String get lineDown => 'Line Down';

  @override
  String get showPreviousTab => 'Show Previous Tab';

  @override
  String get showNextTab => 'Show Next Tab';

  @override
  String get moveTabToNewWindow => 'Move Tab to New Window';

  @override
  String get mergeAllWindows => 'Merge All Windows';

  @override
  String get openWindowGroup => 'Open Window Group';

  @override
  String get noWindowGroups => 'No Window Groups';

  @override
  String get saveWindowsAsGroup => 'Save Windows as Group…';

  @override
  String get openManPage => 'Open man Page for Selection';

  @override
  String get searchManIndex => 'Search man Page Index for Selection';

  @override
  String aboutMessage(String version) {
    return 'Version $version. The terminal of Silica. Free software under the MIT and Apache 2.0 licenses.';
  }

  @override
  String get askAlways => 'Always';

  @override
  String get askNever => 'Never';

  @override
  String get askRunning =>
      'Only if there are processes other than the login shell';

  @override
  String bellNotification(String title) {
    return '$title rang the bell.';
  }

  @override
  String get commandPlaceholder => 'Command';

  @override
  String get connect => 'Connect';

  @override
  String get copy => 'Copy';

  @override
  String get paste => 'Paste';

  @override
  String get selectAll => 'Select All';

  @override
  String get cursorBar => 'Bar';

  @override
  String get cursorBlock => 'Block';

  @override
  String get cursorUnderline => 'Underline';

  @override
  String get editTitleMessage =>
      'The title replaces the one the program sets, for this tab.';

  @override
  String get exitClose => 'Close the window';

  @override
  String get exitCloseIfClean => 'Close if the shell exited cleanly';

  @override
  String get exitKeep => 'Don\'t close';

  @override
  String get groupNamePlaceholder => 'Group name';

  @override
  String get hideTabBar => 'Hide Tab Bar';

  @override
  String get inspectorCommand => 'Command';

  @override
  String get inspectorDirectory => 'Directory';

  @override
  String get inspectorLoginShell => 'The login shell';

  @override
  String get inspectorNotStarted => 'Not running';

  @override
  String get inspectorProfile => 'Profile';

  @override
  String get inspectorRunning => 'Running';

  @override
  String get inspectorSize => 'Size';

  @override
  String get inspectorStatus => 'Status';

  @override
  String get inspectorTitle => 'Inspector';

  @override
  String get inspectorTitleRow => 'Title';

  @override
  String get inspectorUnknown => 'Unknown';

  @override
  String get newCommandMessage => 'The command runs in a new window.';

  @override
  String get newRemoteMessage =>
      'A host, user@host or a ssh:// address. The connection opens in a new window.';

  @override
  String get ok => 'OK';

  @override
  String get profileAdvanced => 'Advanced';

  @override
  String get profileAskBeforeClosing => 'Ask before closing';

  @override
  String get profileBell => 'Bell';

  @override
  String get profileBellNotify => 'Notify when a background tab rings the bell';

  @override
  String get profileBellVisual => 'Flash the window for the bell';

  @override
  String get profileBoldText => 'Use the bold face for bold text';

  @override
  String get profileColumns => 'Columns';

  @override
  String get profileCursor => 'Cursor';

  @override
  String get profileCursorBlink => 'Blink the cursor';

  @override
  String get profileFont => 'Font';

  @override
  String get profileFontSize => 'Font size';

  @override
  String get profileKeyboard => 'Keyboard';

  @override
  String get profileName => 'Name';

  @override
  String get profileOptionNote =>
      'Option sends Escape before the key, as programs such as Emacs and readline expect.';

  @override
  String get profileRows => 'Rows';

  @override
  String get profileScheme => 'Colors';

  @override
  String get profileScrollback => 'Scrollback';

  @override
  String get profileScrollbackKeep => 'Keep';

  @override
  String get profileScrollbackLines => 'Lines';

  @override
  String get profileShell => 'Shell';

  @override
  String get profileShowMarks => 'Show prompt marks';

  @override
  String get profileStartup => 'Run at start';

  @override
  String get profileStartupPlaceholder => 'A command';

  @override
  String get profileTab => 'Tab';

  @override
  String get profileText => 'Text';

  @override
  String get profileTitleDirectory => 'Show the directory in the title';

  @override
  String get profileTitleSize => 'Show the size in the window title';

  @override
  String get profileWhenExits => 'When the shell exits';

  @override
  String get profileWindow => 'Window';

  @override
  String get run => 'Run';

  @override
  String get save => 'Save';

  @override
  String get saveGroupMessage =>
      'The open windows and their tabs are saved under this name.';

  @override
  String get schemeDefault => 'Default (follows the appearance)';

  @override
  String get scrollbackLimited => 'Limited';

  @override
  String get scrollbackUnlimited => 'Unlimited';

  @override
  String get serverPlaceholder => 'Server';

  @override
  String get settingsAutoMark => 'Mark prompts automatically';

  @override
  String get settingsClipboard => 'Clipboard';

  @override
  String get settingsClipboardNote =>
      'Programs ask with the OSC 52 escape sequence. Reading stays off unless you allow it.';

  @override
  String get settingsClipboardRead => 'Allow programs to read the clipboard';

  @override
  String get settingsClipboardWrite =>
      'Allow programs to write to the clipboard';

  @override
  String settingsCopyName(String name) {
    return '$name copy';
  }

  @override
  String settingsDefaultMark(String name) {
    return '$name (default)';
  }

  @override
  String get settingsDefaultProfile => 'Default profile';

  @override
  String get settingsDuplicate => 'Duplicate';

  @override
  String get settingsEncodings => 'Encodings';

  @override
  String get settingsEncodingsNote =>
      'Terminal speaks Unicode (UTF-8) with programs. Other encodings are not offered.';

  @override
  String get settingsGeneral => 'General';

  @override
  String settingsGroupSummary(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count windows',
      one: '1 window',
    );
    return '$name — $_temp0';
  }

  @override
  String get settingsHome => 'The home folder';

  @override
  String get settingsMouseReporting =>
      'Report mouse events to programs that ask for them';

  @override
  String get settingsNewTabs => 'New tabs open in';

  @override
  String get settingsNewWindows => 'New windows open in';

  @override
  String get settingsNoGroups =>
      'No window groups yet. Use Window › Save Windows as Group to make one.';

  @override
  String get settingsOpenLinks => 'Command-click opens links';

  @override
  String get settingsProfiles => 'Profiles';

  @override
  String get settingsRemove => 'Remove';

  @override
  String get settingsSameDirectory => 'The folder of the current tab';

  @override
  String get settingsTitle => 'Terminal Settings';

  @override
  String get settingsWindowGroups => 'Window Groups';

  @override
  String get showMarks => 'Show Marks';

  @override
  String get settingsOnLaunch => 'On launch, open';

  @override
  String get settingsLaunchNewWindow => 'A new window';

  @override
  String settingsLaunchGroup(String name) {
    return 'Window group “$name”';
  }

  @override
  String get settingsShellNewWindows => 'Shell for new windows';

  @override
  String get settingsShellDefault => 'Default login shell';

  @override
  String get settingsShellCommand => 'A command';

  @override
  String get settingsShellCommandPlaceholder => 'A program, such as /bin/zsh';

  @override
  String get settingsTabSwitching => 'Tab switching';

  @override
  String get settingsTabSwitchingCheck => '⌘1 to ⌘9 select tabs';

  @override
  String get settingsSectionWindowsTabs => 'Windows and tabs';

  @override
  String get settingsSectionPrograms => 'Programs';

  @override
  String get settingsMouseLabel => 'Mouse';

  @override
  String get settingsLinksLabel => 'Links';

  @override
  String get settingsPromptsLabel => 'Prompts';

  @override
  String get settingsSavedGroups => 'Saved window groups';

  @override
  String get settingsCharacterEncoding => 'Character encoding';

  @override
  String get settingsUtf8 => 'Unicode (UTF-8)';

  @override
  String get profileColorBackground => 'Background';

  @override
  String get profileColorText => 'Text';

  @override
  String get profileColorBold => 'Bold';

  @override
  String get profileColorSelection => 'Selection';

  @override
  String get profileColorCursor => 'Cursor';

  @override
  String get profileColorPanel => 'Colors';

  @override
  String get profileAntialias => 'Antialias text';

  @override
  String get profileBlinkingText => 'Allow blinking text';

  @override
  String get profileAnsiColors => 'Display ANSI colors';

  @override
  String get profileBrightBold => 'Use bright colors for bold text';

  @override
  String get profileTitleLabel => 'Title';

  @override
  String get profileMarksLabel => 'Marks';

  @override
  String get profileTitleProcess =>
      'Show the running process and its arguments';

  @override
  String get profileRestoreLabel => 'Restore';

  @override
  String get profileRestoreText => 'Restore the text when the window reopens';

  @override
  String get profileRestoreLines => 'Lines to restore';

  @override
  String get profileLinesUnit => 'lines';

  @override
  String get profilePointsUnit => 'pt';

  @override
  String get profileNotYetNote =>
      'Antialiasing, blinking text, the process title and restoring text need support from the emulator and are not available yet.';
}
