import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
  ];

  /// Name of the app, in the window title and the Dock.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get appTitle;

  /// Window title: the running program or the title it set, then the size in character cells.
  ///
  /// In en, this message translates to:
  /// **'{title} — {columns}×{rows}'**
  String windowTitle(String title, int columns, int rows);

  /// Command and button that opens a new tab.
  ///
  /// In en, this message translates to:
  /// **'New Tab'**
  String get newTab;

  /// Command and button that closes the current tab.
  ///
  /// In en, this message translates to:
  /// **'Close Tab'**
  String get closeTab;

  /// Title of the alert shown when closing a tab whose shell runs another program.
  ///
  /// In en, this message translates to:
  /// **'Do you want to terminate running processes in this tab?'**
  String get closeTabConfirmTitle;

  /// Message of that alert.
  ///
  /// In en, this message translates to:
  /// **'Closing this tab will terminate the running processes in it.'**
  String get closeTabConfirmMessage;

  /// Title of the alert shown when closing a window with a tab whose shell runs another program.
  ///
  /// In en, this message translates to:
  /// **'Do you want to terminate running processes in this window?'**
  String get closeWindowConfirmTitle;

  /// Message of that alert.
  ///
  /// In en, this message translates to:
  /// **'Closing this window will terminate the running processes in it.'**
  String get closeWindowConfirmMessage;

  /// Destructive button of that alert.
  ///
  /// In en, this message translates to:
  /// **'Terminate'**
  String get terminate;

  /// Button that dismisses an alert without acting.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Shown in the terminal area when the app runs outside Silica, where the pseudo-terminal channel is missing.
  ///
  /// In en, this message translates to:
  /// **'The terminal needs the Silica desktop: its pseudo-terminal service is not available here.'**
  String get noPty;

  /// Shown when the shell process cannot be started.
  ///
  /// In en, this message translates to:
  /// **'Could not start the shell: {error}'**
  String spawnFailed(String error);

  /// Shown at the end of the output when the shell exits.
  ///
  /// In en, this message translates to:
  /// **'The process exited with code {code}.'**
  String processExited(int code);

  /// Shown when the shell is ended by a signal.
  ///
  /// In en, this message translates to:
  /// **'The process was ended by signal {signal}.'**
  String processKilled(int signal);

  /// Placeholder of the find field.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get find;

  /// Position of the current match among all matches of the find field.
  ///
  /// In en, this message translates to:
  /// **'{current} of {count}'**
  String findMatches(int current, int count);

  /// The find field found nothing.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get findNoMatches;

  /// Button of the find bar that selects the previous match.
  ///
  /// In en, this message translates to:
  /// **'Previous match'**
  String get findPrevious;

  /// Button of the find bar that selects the next match.
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get findNext;

  /// Button that closes the find bar.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get findDone;

  /// Menu bar: the Shell menu.
  ///
  /// In en, this message translates to:
  /// **'Shell'**
  String get menuShell;

  /// Menu bar: the Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get menuEdit;

  /// Menu bar: the View menu.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get menuView;

  /// Menu bar: the Window menu.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get menuWindow;

  /// Menu bar: the Help menu.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get menuHelp;

  /// App menu item.
  ///
  /// In en, this message translates to:
  /// **'Secure Keyboard Entry'**
  String get secureKeyboardEntry;

  /// Shell menu: submenu.
  ///
  /// In en, this message translates to:
  /// **'New Window'**
  String get newWindow;

  /// Shell menu: new window with the default profile.
  ///
  /// In en, this message translates to:
  /// **'New Window with Profile - {profile}'**
  String newWindowWithProfile(String profile);

  /// Shell menu.
  ///
  /// In en, this message translates to:
  /// **'New Window with Same Command'**
  String get newWindowSameCommand;

  /// Shell menu: new tab with the default profile.
  ///
  /// In en, this message translates to:
  /// **'New Tab with Profile - {profile}'**
  String newTabWithProfile(String profile);

  /// Shell menu.
  ///
  /// In en, this message translates to:
  /// **'New Tab with Same Command'**
  String get newTabSameCommand;

  /// Shell menu.
  ///
  /// In en, this message translates to:
  /// **'New Command…'**
  String get newCommand;

  /// Shell menu.
  ///
  /// In en, this message translates to:
  /// **'New Remote Connection…'**
  String get newRemoteConnection;

  /// Shell menu.
  ///
  /// In en, this message translates to:
  /// **'Open…'**
  String get open;

  /// Shell menu: closes the window when it has one tab.
  ///
  /// In en, this message translates to:
  /// **'Close Window'**
  String get closeWindow;

  /// Shell menu.
  ///
  /// In en, this message translates to:
  /// **'Close All'**
  String get closeAll;

  /// Shell menu.
  ///
  /// In en, this message translates to:
  /// **'Use Settings as Default'**
  String get useSettingsAsDefault;

  /// Shell menu.
  ///
  /// In en, this message translates to:
  /// **'Export Settings…'**
  String get exportSettings;

  /// Shell menu.
  ///
  /// In en, this message translates to:
  /// **'Export Text As…'**
  String get exportText;

  /// Shell menu.
  ///
  /// In en, this message translates to:
  /// **'Export Selected Text As…'**
  String get exportSelectedText;

  /// Shell menu.
  ///
  /// In en, this message translates to:
  /// **'Show Inspector'**
  String get showInspector;

  /// Shell menu.
  ///
  /// In en, this message translates to:
  /// **'Edit Title'**
  String get editTitle;

  /// Shell menu.
  ///
  /// In en, this message translates to:
  /// **'Edit Background Color'**
  String get editBackgroundColor;

  /// Shell menu: resets the terminal.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// Shell menu.
  ///
  /// In en, this message translates to:
  /// **'Hard Reset'**
  String get hardReset;

  /// Shell menu.
  ///
  /// In en, this message translates to:
  /// **'Print Selection…'**
  String get printSelection;

  /// Shell menu.
  ///
  /// In en, this message translates to:
  /// **'Print…'**
  String get print;

  /// Edit menu: submenu.
  ///
  /// In en, this message translates to:
  /// **'Copy Special'**
  String get copySpecial;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Copy Without Background Color'**
  String get copyWithoutBackground;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Copy Text Only'**
  String get copyTextOnly;

  /// Edit menu: heading of the styles.
  ///
  /// In en, this message translates to:
  /// **'Style for Copy Command'**
  String get copyStyle;

  /// Edit menu: copy style that follows the profile.
  ///
  /// In en, this message translates to:
  /// **'Terminal Settings (default)'**
  String get terminalSettingsDefault;

  /// Edit menu: copy style.
  ///
  /// In en, this message translates to:
  /// **'Text Only'**
  String get plainText;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Paste Escaped Text'**
  String get pasteEscaped;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Paste Selection'**
  String get pasteSelection;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Paste Selection Escaped'**
  String get pasteSelectionEscaped;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Select Between Marks'**
  String get selectBetweenMarks;

  /// Edit menu: submenu.
  ///
  /// In en, this message translates to:
  /// **'Marks'**
  String get marks;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Automatically Mark Prompt Lines'**
  String get autoMarkPrompts;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Mark Line and Start New Line'**
  String get markLineAndNewline;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Start New Line Without Marking'**
  String get newlineWithoutMark;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Mark'**
  String get mark;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Mark as Bookmark'**
  String get markAsBookmark;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Remove Mark'**
  String get removeMark;

  /// Edit menu: submenu.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Insert Bookmark'**
  String get insertBookmark;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Insert Bookmark with Name…'**
  String get insertNamedBookmark;

  /// Edit menu: empty list of bookmarks.
  ///
  /// In en, this message translates to:
  /// **'No Bookmarks'**
  String get noBookmarks;

  /// Edit menu: submenu.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get navigate;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Go to Previous Mark'**
  String get previousMark;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Select to Previous Mark'**
  String get selectToPreviousMark;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Go to Next Mark'**
  String get nextMark;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Select to Next Mark'**
  String get selectToNextMark;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Go to Previous Bookmark'**
  String get previousBookmark;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Select to Previous Bookmark'**
  String get selectToPreviousBookmark;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Go to Next Bookmark'**
  String get nextBookmark;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Select to Next Bookmark'**
  String get selectToNextBookmark;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Clear to Previous Mark'**
  String get clearToPreviousMark;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Clear to Previous Bookmark'**
  String get clearToPreviousBookmark;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Clear to Start'**
  String get clearToStart;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Remove Excess Lines'**
  String get removeExcessLines;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Clear Screen'**
  String get clearScreen;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Fill Screen'**
  String get fillScreen;

  /// Edit menu, Find submenu: opens the find bar.
  ///
  /// In en, this message translates to:
  /// **'Find…'**
  String get findEllipsis;

  /// Edit menu, Find submenu.
  ///
  /// In en, this message translates to:
  /// **'Find Next'**
  String get findNextItem;

  /// Edit menu, Find submenu.
  ///
  /// In en, this message translates to:
  /// **'Find Previous'**
  String get findPreviousItem;

  /// Edit menu, Find submenu: selects all matches.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get findSelectAll;

  /// Edit menu, Find submenu.
  ///
  /// In en, this message translates to:
  /// **'Select All in Selection'**
  String get findSelectAllInSelection;

  /// Edit menu, Find submenu.
  ///
  /// In en, this message translates to:
  /// **'Hide Find Bar'**
  String get hideFindBar;

  /// Edit menu, Find submenu.
  ///
  /// In en, this message translates to:
  /// **'Use Selection for Find'**
  String get useSelectionForFind;

  /// Edit menu, Find submenu.
  ///
  /// In en, this message translates to:
  /// **'Jump to Selection'**
  String get jumpToSelection;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Show Colors'**
  String get showColors;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Use Option as Meta Key'**
  String get optionAsMeta;

  /// Edit menu.
  ///
  /// In en, this message translates to:
  /// **'Num Lock'**
  String get numLock;

  /// View menu.
  ///
  /// In en, this message translates to:
  /// **'Show All Tabs'**
  String get showAllTabs;

  /// View menu.
  ///
  /// In en, this message translates to:
  /// **'Show Tab Bar'**
  String get showTabBar;

  /// View menu.
  ///
  /// In en, this message translates to:
  /// **'Hide Marks'**
  String get hideMarks;

  /// View menu.
  ///
  /// In en, this message translates to:
  /// **'Show Alternate Screen'**
  String get showAlternateScreen;

  /// View menu.
  ///
  /// In en, this message translates to:
  /// **'Hide Alternate Screen'**
  String get hideAlternateScreen;

  /// View menu.
  ///
  /// In en, this message translates to:
  /// **'Allow Mouse Reporting'**
  String get allowMouseReporting;

  /// View menu.
  ///
  /// In en, this message translates to:
  /// **'Split Pane'**
  String get splitPane;

  /// View menu.
  ///
  /// In en, this message translates to:
  /// **'Close Split Pane'**
  String get closeSplitPane;

  /// View menu.
  ///
  /// In en, this message translates to:
  /// **'Default Font Size'**
  String get defaultFontSize;

  /// View menu.
  ///
  /// In en, this message translates to:
  /// **'Bigger'**
  String get fontBigger;

  /// View menu.
  ///
  /// In en, this message translates to:
  /// **'Smaller'**
  String get fontSmaller;

  /// View menu.
  ///
  /// In en, this message translates to:
  /// **'Scroll to Top'**
  String get scrollToTop;

  /// View menu.
  ///
  /// In en, this message translates to:
  /// **'Scroll to Bottom'**
  String get scrollToBottom;

  /// View menu: scrolls one page up.
  ///
  /// In en, this message translates to:
  /// **'Page Up'**
  String get pageUp;

  /// View menu: scrolls one page down.
  ///
  /// In en, this message translates to:
  /// **'Page Down'**
  String get pageDown;

  /// View menu: scrolls one line up.
  ///
  /// In en, this message translates to:
  /// **'Line Up'**
  String get lineUp;

  /// View menu: scrolls one line down.
  ///
  /// In en, this message translates to:
  /// **'Line Down'**
  String get lineDown;

  /// Window menu.
  ///
  /// In en, this message translates to:
  /// **'Show Previous Tab'**
  String get showPreviousTab;

  /// Window menu.
  ///
  /// In en, this message translates to:
  /// **'Show Next Tab'**
  String get showNextTab;

  /// Window menu.
  ///
  /// In en, this message translates to:
  /// **'Move Tab to New Window'**
  String get moveTabToNewWindow;

  /// Window menu.
  ///
  /// In en, this message translates to:
  /// **'Merge All Windows'**
  String get mergeAllWindows;

  /// Window menu: submenu.
  ///
  /// In en, this message translates to:
  /// **'Open Window Group'**
  String get openWindowGroup;

  /// Window menu.
  ///
  /// In en, this message translates to:
  /// **'No Window Groups'**
  String get noWindowGroups;

  /// Window menu.
  ///
  /// In en, this message translates to:
  /// **'Save Windows as Group…'**
  String get saveWindowsAsGroup;

  /// Help menu.
  ///
  /// In en, this message translates to:
  /// **'Open man Page for Selection'**
  String get openManPage;

  /// Help menu.
  ///
  /// In en, this message translates to:
  /// **'Search man Page Index for Selection'**
  String get searchManIndex;

  /// Body of the About alert.
  ///
  /// In en, this message translates to:
  /// **'Version {version}. The terminal of Silica. Free software under the MIT and Apache 2.0 licenses.'**
  String aboutMessage(String version);

  /// Option of "Ask before closing": always ask.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get askAlways;

  /// Option of "Ask before closing": never ask.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get askNever;

  /// Option of "Ask before closing": ask only when a program runs in the tab.
  ///
  /// In en, this message translates to:
  /// **'Only if there are processes other than the login shell'**
  String get askRunning;

  /// Desktop notification when a background tab rings the terminal bell.
  ///
  /// In en, this message translates to:
  /// **'{title} rang the bell.'**
  String bellNotification(String title);

  /// Placeholder of the field of New Command.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get commandPlaceholder;

  /// Button of the New Remote Connection alert.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// Context menu item that copies the selection.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// Context menu item that pastes the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// Context menu item that selects all the text.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// Cursor shape: a vertical bar.
  ///
  /// In en, this message translates to:
  /// **'Bar'**
  String get cursorBar;

  /// Cursor shape: the whole cell.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get cursorBlock;

  /// Cursor shape: a line under the cell.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get cursorUnderline;

  /// Explanation in the Edit Title alert.
  ///
  /// In en, this message translates to:
  /// **'The title replaces the one the program sets, for this tab.'**
  String get editTitleMessage;

  /// Option "when the shell exits": close the window or tab.
  ///
  /// In en, this message translates to:
  /// **'Close the window'**
  String get exitClose;

  /// Option "when the shell exits".
  ///
  /// In en, this message translates to:
  /// **'Close if the shell exited cleanly'**
  String get exitCloseIfClean;

  /// Option "when the shell exits": keep the window.
  ///
  /// In en, this message translates to:
  /// **'Don\'t close'**
  String get exitKeep;

  /// Placeholder of the name of a window group.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupNamePlaceholder;

  /// View menu item that hides the tab bar.
  ///
  /// In en, this message translates to:
  /// **'Hide Tab Bar'**
  String get hideTabBar;

  /// Inspector: the program of the tab.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get inspectorCommand;

  /// Inspector: the working directory.
  ///
  /// In en, this message translates to:
  /// **'Directory'**
  String get inspectorDirectory;

  /// Inspector: no command, the login shell runs.
  ///
  /// In en, this message translates to:
  /// **'The login shell'**
  String get inspectorLoginShell;

  /// Inspector: the tab has no process.
  ///
  /// In en, this message translates to:
  /// **'Not running'**
  String get inspectorNotStarted;

  /// Inspector: the profile of the tab.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get inspectorProfile;

  /// Inspector: the process runs.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get inspectorRunning;

  /// Inspector: columns and rows.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get inspectorSize;

  /// Inspector: whether the process runs or how it ended.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get inspectorStatus;

  /// Title of the inspector window.
  ///
  /// In en, this message translates to:
  /// **'Inspector'**
  String get inspectorTitle;

  /// Inspector: the title of the tab.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get inspectorTitleRow;

  /// Inspector: the directory is not known.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get inspectorUnknown;

  /// Explanation in the New Command alert.
  ///
  /// In en, this message translates to:
  /// **'The command runs in a new window.'**
  String get newCommandMessage;

  /// Explanation in the New Remote Connection alert.
  ///
  /// In en, this message translates to:
  /// **'A host, user@host or a ssh:// address. The connection opens in a new window.'**
  String get newRemoteMessage;

  /// Button that confirms an alert.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Tab of the profile settings.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get profileAdvanced;

  /// Profile setting.
  ///
  /// In en, this message translates to:
  /// **'Ask before closing'**
  String get profileAskBeforeClosing;

  /// Heading of the bell settings.
  ///
  /// In en, this message translates to:
  /// **'Bell'**
  String get profileBell;

  /// Profile setting.
  ///
  /// In en, this message translates to:
  /// **'Notify when a background tab rings the bell'**
  String get profileBellNotify;

  /// Profile setting.
  ///
  /// In en, this message translates to:
  /// **'Flash the window for the bell'**
  String get profileBellVisual;

  /// Profile setting.
  ///
  /// In en, this message translates to:
  /// **'Use the bold face for bold text'**
  String get profileBoldText;

  /// Profile setting: the width of new windows in characters.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get profileColumns;

  /// Profile setting.
  ///
  /// In en, this message translates to:
  /// **'Cursor'**
  String get profileCursor;

  /// Profile setting.
  ///
  /// In en, this message translates to:
  /// **'Blink the cursor'**
  String get profileCursorBlink;

  /// Profile setting: the name of a monospaced font.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get profileFont;

  /// Profile setting.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get profileFontSize;

  /// Tab of the profile settings.
  ///
  /// In en, this message translates to:
  /// **'Keyboard'**
  String get profileKeyboard;

  /// Profile setting.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileName;

  /// Explanation of Use Option as Meta Key.
  ///
  /// In en, this message translates to:
  /// **'Option sends Escape before the key, as programs such as Emacs and readline expect.'**
  String get profileOptionNote;

  /// Profile setting: the height of new windows in lines.
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get profileRows;

  /// Profile setting: the color scheme.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get profileScheme;

  /// Heading of the scrollback settings.
  ///
  /// In en, this message translates to:
  /// **'Scrollback'**
  String get profileScrollback;

  /// Profile setting: limited or unlimited scrollback.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get profileScrollbackKeep;

  /// Profile setting: how many lines of scrollback.
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get profileScrollbackLines;

  /// Tab of the profile settings.
  ///
  /// In en, this message translates to:
  /// **'Shell'**
  String get profileShell;

  /// Profile setting.
  ///
  /// In en, this message translates to:
  /// **'Show prompt marks'**
  String get profileShowMarks;

  /// Profile setting: a command typed into the shell when it starts.
  ///
  /// In en, this message translates to:
  /// **'Run at start'**
  String get profileStartup;

  /// Placeholder of that field.
  ///
  /// In en, this message translates to:
  /// **'A command'**
  String get profileStartupPlaceholder;

  /// Tab of the profile settings.
  ///
  /// In en, this message translates to:
  /// **'Tab'**
  String get profileTab;

  /// Tab of the profile settings.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get profileText;

  /// Profile setting.
  ///
  /// In en, this message translates to:
  /// **'Show the directory in the title'**
  String get profileTitleDirectory;

  /// Profile setting.
  ///
  /// In en, this message translates to:
  /// **'Show the size in the window title'**
  String get profileTitleSize;

  /// Profile setting.
  ///
  /// In en, this message translates to:
  /// **'When the shell exits'**
  String get profileWhenExits;

  /// Tab of the profile settings.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get profileWindow;

  /// Button of the New Command alert.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get run;

  /// Button of the Save Windows as Group alert.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Explanation in the Save Windows as Group alert.
  ///
  /// In en, this message translates to:
  /// **'The open windows and their tabs are saved under this name.'**
  String get saveGroupMessage;

  /// Color scheme that follows the light or dark appearance.
  ///
  /// In en, this message translates to:
  /// **'Default (follows the appearance)'**
  String get schemeDefault;

  /// Scrollback: a number of lines.
  ///
  /// In en, this message translates to:
  /// **'Limited'**
  String get scrollbackLimited;

  /// Scrollback: as many lines as fit in memory.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get scrollbackUnlimited;

  /// Placeholder of the field of New Remote Connection.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get serverPlaceholder;

  /// General setting.
  ///
  /// In en, this message translates to:
  /// **'Mark prompts automatically'**
  String get settingsAutoMark;

  /// Heading of the clipboard settings.
  ///
  /// In en, this message translates to:
  /// **'Clipboard'**
  String get settingsClipboard;

  /// Explanation of the clipboard settings.
  ///
  /// In en, this message translates to:
  /// **'Programs ask with the OSC 52 escape sequence. Reading stays off unless you allow it.'**
  String get settingsClipboardNote;

  /// General setting.
  ///
  /// In en, this message translates to:
  /// **'Allow programs to read the clipboard'**
  String get settingsClipboardRead;

  /// General setting.
  ///
  /// In en, this message translates to:
  /// **'Allow programs to write to the clipboard'**
  String get settingsClipboardWrite;

  /// Name of a duplicated profile.
  ///
  /// In en, this message translates to:
  /// **'{name} copy'**
  String settingsCopyName(String name);

  /// A profile in the list, marked as the default one.
  ///
  /// In en, this message translates to:
  /// **'{name} (default)'**
  String settingsDefaultMark(String name);

  /// General setting.
  ///
  /// In en, this message translates to:
  /// **'Default profile'**
  String get settingsDefaultProfile;

  /// Button that duplicates the selected profile.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get settingsDuplicate;

  /// Tab of the settings.
  ///
  /// In en, this message translates to:
  /// **'Encodings'**
  String get settingsEncodings;

  /// Content of the Encodings tab.
  ///
  /// In en, this message translates to:
  /// **'Terminal speaks Unicode (UTF-8) with programs. Other encodings are not offered.'**
  String get settingsEncodingsNote;

  /// Tab of the settings.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// A saved window group in the list.
  ///
  /// In en, this message translates to:
  /// **'{name} — {count, plural, =1{1 window} other{{count} windows}}'**
  String settingsGroupSummary(String name, int count);

  /// Where new windows or tabs start.
  ///
  /// In en, this message translates to:
  /// **'The home folder'**
  String get settingsHome;

  /// General setting.
  ///
  /// In en, this message translates to:
  /// **'Report mouse events to programs that ask for them'**
  String get settingsMouseReporting;

  /// General setting.
  ///
  /// In en, this message translates to:
  /// **'New tabs open in'**
  String get settingsNewTabs;

  /// General setting.
  ///
  /// In en, this message translates to:
  /// **'New windows open in'**
  String get settingsNewWindows;

  /// Shown in the Window Groups tab when there are none.
  ///
  /// In en, this message translates to:
  /// **'No window groups yet. Use Window › Save Windows as Group to make one.'**
  String get settingsNoGroups;

  /// General setting.
  ///
  /// In en, this message translates to:
  /// **'Command-click opens links'**
  String get settingsOpenLinks;

  /// Tab of the settings.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get settingsProfiles;

  /// Button that removes a profile or a window group.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get settingsRemove;

  /// Where new windows or tabs start.
  ///
  /// In en, this message translates to:
  /// **'The folder of the current tab'**
  String get settingsSameDirectory;

  /// Title of the settings window.
  ///
  /// In en, this message translates to:
  /// **'Terminal Settings'**
  String get settingsTitle;

  /// Tab of the settings.
  ///
  /// In en, this message translates to:
  /// **'Window Groups'**
  String get settingsWindowGroups;

  /// View menu item that shows the prompt marks.
  ///
  /// In en, this message translates to:
  /// **'Show Marks'**
  String get showMarks;

  /// Settings: row choosing what a launch opens.
  ///
  /// In en, this message translates to:
  /// **'On launch, open'**
  String get settingsOnLaunch;

  /// Settings: launch opens a new window.
  ///
  /// In en, this message translates to:
  /// **'A new window'**
  String get settingsLaunchNewWindow;

  /// Settings: launch opens this saved window group.
  ///
  /// In en, this message translates to:
  /// **'Window group “{name}”'**
  String settingsLaunchGroup(String name);

  /// Settings: row choosing the program of new windows.
  ///
  /// In en, this message translates to:
  /// **'Shell for new windows'**
  String get settingsShellNewWindows;

  /// Settings: the login shell runs in new windows.
  ///
  /// In en, this message translates to:
  /// **'Default login shell'**
  String get settingsShellDefault;

  /// Settings: new windows run a command.
  ///
  /// In en, this message translates to:
  /// **'A command'**
  String get settingsShellCommand;

  /// Settings: placeholder of the shell command field.
  ///
  /// In en, this message translates to:
  /// **'A program, such as /bin/zsh'**
  String get settingsShellCommandPlaceholder;

  /// Settings: row label of the tab shortcuts.
  ///
  /// In en, this message translates to:
  /// **'Tab switching'**
  String get settingsTabSwitching;

  /// Settings: checkbox for the tab shortcuts.
  ///
  /// In en, this message translates to:
  /// **'⌘1 to ⌘9 select tabs'**
  String get settingsTabSwitchingCheck;

  /// Settings: section title.
  ///
  /// In en, this message translates to:
  /// **'Windows and tabs'**
  String get settingsSectionWindowsTabs;

  /// Settings: section title.
  ///
  /// In en, this message translates to:
  /// **'Programs'**
  String get settingsSectionPrograms;

  /// Settings: row label of mouse reporting.
  ///
  /// In en, this message translates to:
  /// **'Mouse'**
  String get settingsMouseLabel;

  /// Settings: row label of command-click on links.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get settingsLinksLabel;

  /// Settings: row label of prompt marks.
  ///
  /// In en, this message translates to:
  /// **'Prompts'**
  String get settingsPromptsLabel;

  /// Settings: section title of the Window Groups pane.
  ///
  /// In en, this message translates to:
  /// **'Saved window groups'**
  String get settingsSavedGroups;

  /// Settings: section title of the Encodings pane.
  ///
  /// In en, this message translates to:
  /// **'Character encoding'**
  String get settingsCharacterEncoding;

  /// Settings: the one encoding.
  ///
  /// In en, this message translates to:
  /// **'Unicode (UTF-8)'**
  String get settingsUtf8;

  /// Profile colour well caption.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get profileColorBackground;

  /// Profile colour well caption.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get profileColorText;

  /// Profile colour well caption.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get profileColorBold;

  /// Profile colour well caption.
  ///
  /// In en, this message translates to:
  /// **'Selection'**
  String get profileColorSelection;

  /// Profile colour well caption.
  ///
  /// In en, this message translates to:
  /// **'Cursor'**
  String get profileColorCursor;

  /// Title of the colour panel.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get profileColorPanel;

  /// Profile Text: checkbox.
  ///
  /// In en, this message translates to:
  /// **'Antialias text'**
  String get profileAntialias;

  /// Profile Text: checkbox.
  ///
  /// In en, this message translates to:
  /// **'Allow blinking text'**
  String get profileBlinkingText;

  /// Profile Text: checkbox.
  ///
  /// In en, this message translates to:
  /// **'Display ANSI colors'**
  String get profileAnsiColors;

  /// Profile Text: checkbox.
  ///
  /// In en, this message translates to:
  /// **'Use bright colors for bold text'**
  String get profileBrightBold;

  /// Profile row label.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get profileTitleLabel;

  /// Profile Tab: row label.
  ///
  /// In en, this message translates to:
  /// **'Marks'**
  String get profileMarksLabel;

  /// Profile Window: checkbox.
  ///
  /// In en, this message translates to:
  /// **'Show the running process and its arguments'**
  String get profileTitleProcess;

  /// Profile Window: row label.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get profileRestoreLabel;

  /// Profile Window: checkbox.
  ///
  /// In en, this message translates to:
  /// **'Restore the text when the window reopens'**
  String get profileRestoreText;

  /// Profile Window: row label.
  ///
  /// In en, this message translates to:
  /// **'Lines to restore'**
  String get profileRestoreLines;

  /// Unit after a number of lines.
  ///
  /// In en, this message translates to:
  /// **'lines'**
  String get profileLinesUnit;

  /// Unit after a font size.
  ///
  /// In en, this message translates to:
  /// **'pt'**
  String get profilePointsUnit;

  /// Profile: note under the controls that do nothing yet.
  ///
  /// In en, this message translates to:
  /// **'Antialiasing, blinking text, the process title and restoring text need support from the emulator and are not available yet.'**
  String get profileNotYetNote;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
