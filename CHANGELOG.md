# Changelog

## Unreleased

- Settings on the Amalfi design (800 × 680): the Segmented Control, Icon + Label for the four
  panes, regular controls, ten presets as real profiles with 40 × 28 previews, radio buttons for
  "Ask before closing", editable scheme colours. New settings that work: On launch (a saved window
  group), Shell for new windows, Tab switching (⌘1 to ⌘9), Display ANSI colors, Use bright colors
  for bold text. Antialias text, Allow blinking text, the process in the title and restoring the
  text are stored and shown disabled until the emulator can serve them.
- The emulator is the embedder's grid engine (alacritty_terminal in Rust); xterm.dart is gone.
  Flutter paints the rows of a session. Scrollback viewing with the measured scroller, mouse
  selection (character, word, line, rectangle), primary selection, mouse reporting (X10,
  normal, button, any; SGR and UTF-8; Shift selects), focus reports, Command+click on URLs and
  OSC 8 links, file drops, the bell (flash and notification), font zoom, OSC 7 (new tabs open
  where the shell is), OSC 52 (reading off by default), OSC 133 marks (jump, Select Between
  Marks, Clear to Previous Mark), split view, new windows, window groups, Move Tab to New
  Window, Merge All Windows, the inspector, About, and Settings (General, Profiles, Window
  Groups, Encodings). Menu items the desktop cannot serve are no longer drawn disabled.
  Conformance: docs/conformance.md. Performance: docs/performance.md.

- Closing the window (Logo+W, the close button) with a program running in any tab asks first:
  "Do you want to terminate running processes in this window?" (silica_ui 0.35.0
  `SilicaWindows.onMainCloseRequested`; needs silica-desktop with `closeRequested` for the main
  window).

- Menus in Silica's menu bar (silica_ui 0.34.0 `SilicaMenuBar`, silica-menu-v1): Terminal, Shell,
  Edit, View, Window and Help as measured in TE-01. New Tab, Close Tab, Copy, Paste, Select All,
  Find (next, previous, hide, use selection), scrolling and tab switching are wired; the items
  whose feature does not exist yet are shown disabled. The ⌘ shortcuts are bound by the menu
  bar, also while the grid has the keyboard.

## 0.1.0 · 2026-10-14

- First version: the login shell on the `silica/pty` pseudo-terminal of the Silica embedder,
  xterm.dart as the emulator, title with the program and the size, tabs, find, copy and paste,
  light and dark profiles, English and Italian. Geometry and colours are provisional until
  TE-01 is measured.
