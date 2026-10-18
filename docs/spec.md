# Terminal: specification

Terminal runs the user's login shell (or `-e program args…`) on a pseudo-terminal of the Silica
embedder and shows it in a character grid. Measurements come from TE-01 (silica-reference#75);
until they arrive, the values in `lib/src/style.dart` are provisional.

## Window

- Full-size content (`SilicaWindow.setFullSizeContent`): a title band at the top, 32 pt
  (provisional), where Ossido puts the window buttons; the empty band moves the window
  (`WindowDragArea`).
- Title, centred in the band: the title set by the program (OSC 0/2) or the name of the shell,
  then the size in cells: "bash — 80×24". The same text goes to the window title
  (`SystemChrome.setApplicationSwitcherDescription`). Inactive window: a lighter title.
- Tab bar under the band from two tabs, 26 pt (provisional): one cell per tab, the current one
  highlighted, a click selects.
- Find bar under the tab bar while finding.
- The grid fills the rest with 6 / 4 pt of padding (provisional). The emulator follows the
  layout: every size change resizes the pseudo-terminal (rows, columns and pixels).
- Profiles: dark text on white in the light appearance, light text on `#1e1e1e` in the dark
  one (provisional, our own palette); JetBrains Mono 12 pt, line height 1.2.
- First window: 640 × 420 pt (the `--size` of the `.desktop` entry, about 80 × 24 cells).

## Emulator

The embedder emulates the terminal (alacritty_terminal on a thread of its own, `silica/pty`
with `grid: true`) and sends the rows that changed once per frame; Terminal paints them. VT100 to
xterm sequences, 256 colours and true colour, alternate screen, bracketed paste, OSC 0/2 titles,
OSC 4/10/11/12 colours (the profile's), OSC 7 directory, OSC 8 links, OSC 52 clipboard, OSC 133
prompt marks, the xterm title stack, synchronized updates; 10 000 lines of scrollback by default
(a profile setting). What the engine does differently from the specifications:
[conformance.md](conformance.md). Output is decoded as UTF-8 in the embedder.

## Process

- `spawn` with the current grid size; `TERM_PROGRAM=Silica Terminal` in the environment.
- When the process exits, a dimmed line says how ("The process exited with code 0.") and the
  tab keeps its output; keys are no longer sent.
- Outside Silica the channel is missing: the grid says the terminal needs the Silica desktop.
- Closing a tab closes its pseudo-terminal (SIGHUP); closing the last tab closes the window.

## Commands

| Command | Shortcut | What |
| --- | --- | --- |
| `terminal.new_tab` | ⌘T | a new tab after the current one, with a new shell |
| `terminal.close_tab` | ⌘W | closes the current tab and its process |
| `terminal.next_tab` | ⌃⇥ | the next tab |
| `terminal.previous_tab` | ⌃⇧⇥ | the previous tab |
| `terminal.find` | ⌘F | the find bar: matches highlighted, Enter / ⇧Enter next and previous, Esc closes |
| `terminal.copy` | ⌘C, ⌃⇧C | copies the selection |
| `terminal.paste` | ⌘V, ⌃⇧V | pastes (bracketed when the program asks for it) |
| `terminal.select_all` | ⌘A | selects the scrollback and the screen |
| `terminal.find_next` | ⌘G | the next match (while the find bar is open) |
| `terminal.find_previous` | ⇧⌘G | the previous match |
| `terminal.hide_find` | ⇧⌘F | closes the find bar |
| `terminal.use_selection_for_find` | ⌘E | the selected text becomes the query and the find bar opens |
| `terminal.scroll_top` / `terminal.scroll_bottom` | ⌘↖ / ⌘↘ | scroll to the start of the scrollback / to the end |
| `terminal.page_up` / `terminal.page_down` | ⌘⇞ / ⌘⇟ | scroll one page |
| `terminal.line_up` / `terminal.line_down` | ⌥⌘⇞ / ⌥⌘⇟ | scroll one line |

⌘ is the Logo key. Plain ⌃C and ⌃V go to the program. The ⌘ shortcuts are the menu bar's
(`SilicaMenuBar`; the grid runs them too, because it takes keys before the window does); ⌃⇥ and
⌃⇧⇥ switch tabs and ⌃⇧C / ⌃⇧V copy and paste in addition.

## Menus

Published to Silica's menu bar, as measured in TE-01. Only items that work are drawn; what the
desktop cannot serve is left out (see "Not offered" below). With several windows the one that
has the keyboard owns the bar.

- **Terminal** (app menu): About Terminal, Settings… ⌘, then the system items.
- **Shell**: New Window and New Tab ⌘N / ⌘T (each with a submenu of the profiles; ⌃⌘ keeps the
  command), New Command… ⇧⌘N, New Remote Connection… ⇧⌘K (`ssh`), Close Tab / Close Window ⌘W
  (asks per the profile), Close All ⌥⌘W, Use Settings as Default, Show Inspector ⌘I, Edit Title
  ⇧⌘I, Reset ⌥⌘R, Hard Reset ⌃⌥⌘R.
- **Edit**: Copy, Paste, Paste Escaped Text ⌃⌘V, Paste Selection ⇧⌘V (and escaped), Select All,
  Select Between Marks ⇧⌘A; Marks (automatic prompt marks, Mark ⌘U, Remove Mark ⇧⌘U); Navigate
  (previous and next mark ⌘↑ ⌘↓); Clear to Previous Mark ⌘L, Clear to Start ⌘K, Clear Screen
  ⌃⌘L; Find (Find…, Next, Previous, Hide Find Bar, Use Selection for Find, Jump to
  Selection ⌘J); Use Option as Meta Key ⌥⌘O. Undo, Redo and Cut are disabled: a terminal has none.
- **View**: Show / Hide Tab Bar ⇧⌘T, Hide / Show Marks, Allow Mouse Reporting ⌘R, Split Pane
  ⌘D / Close Split Pane ⇧⌘D, Default Font Size ⌘0, Bigger ⌘+, Smaller ⌘−, scrolling (top, bottom,
  page, line), Full Screen from the system.
- **Window**: Show Previous / Next Tab, Move Tab to New Window, Merge All Windows, Open Window
  Group, Save Windows as Group…, then the system part of the bar.
- **Help**: Open man Page for Selection ⌃⌘?, Search man Page Index for Selection (a tab runs
  `man`).

Not offered, each with its reason in the issues of the repository: Open…, Export Settings…,
Export Text As…, Print (no file dialog or print service), Copy Special (the clipboard carries
plain text), Bookmarks and Select to Mark, Show Colors, Edit Background Color, Num Lock, Fill
Screen, Remove Excess Lines, Show All Tabs, Show / Hide Alternate Screen, Secure Keyboard Entry.

## Pseudo-terminal channel

`silica/pty`, JSONMethodCodec, implemented by the embedder of silica-desktop (issue #17):

The protocol is documented in `docs/protocols.md` of silica-desktop (grid sessions, scrolling,
selection, search, marks, split views). Terminal uses `spawn {grid: true, …}`, `grid` frames,
`exit`, and the calls `write`, `resize`, `signal`, `close`, `busy`, `cwd`, `scroll`, `select`,
`selectionText`, `search`, `mark`, `clear`, `reset`, `configure`, `clipboard`, `split`.
