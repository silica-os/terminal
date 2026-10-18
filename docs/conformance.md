# Escape sequence conformance

The grid engine is `alacritty_terminal` in the embedder. Its wiring and behaviour are checked by
`crates/embedder/src/termgrid/conformance.rs` in silica-desktop: about 45 fixed-output tests that
feed a byte script and compare the screen, the cursor, the attributes and the replies. The cases
are written from ECMA-48 and ECMA-35, the xterm control sequences and the DEC VT100 / VT220
manuals, in the groups that vttest and esctest test. vttest and esctest were not available to run,
and no code or text of either was used; the groups below are the ones their menus and modules name.

| Group (vttest menu) | Result |
| --- | --- |
| 1 Cursor movement: CUP, HVP, CUU/CUD/CUF/CUB, CHA, VPA, HPA, HPR, VPR, CNL, CPL, IND, NEL, RI, DECSC/DECRC, CSI s/u, autowrap and DECAWM, tabs (HTS, TBC, CHT, CBT) | pass |
| 2 Screen features: DECSTBM, SU/SD, origin mode, SGR (attributes, 8/16/256/true colour, colon forms), erasing with the background colour | pass |
| 3 Character sets: DEC special graphics in G0 and G1, SO/SI, UTF-8 (combining, wide, invalid, split) | pass |
| 4 Double-size lines (DECDHL, DECDWL) | not implemented by the engine: drawn at normal size |
| 5 Keyboard | keys are encoded by the app (`test/keys_test.dart`) |
| 6 Reports: DA, DA2, DSR, CPR, DECRQM, window operations 14/16/18, title stack 22/23 | pass (16 t added) |
| 7 VT52 mode | not implemented by the engine |
| 8 Insert and delete: ICH, DCH, ECH, EL, ED, IL, DL, IRM, REP, DECALN | pass (DCH and ED 1 fixed) |
| 9 Known bugs of terminals (wrap, tab and scroll corner cases) | pass |
| 10 Reset: RIS, DECSTR | pass (DECSTR added) |
| 11 Non-VT100: alternate screen 47 / 1047 / 1049, bracketed paste, mouse modes, cursor shapes, OSC | pass (47 and 1047 added) |
| Robustness: malformed and unknown sequences, CAN/SUB, ESC inside a sequence, sequences cut by the end of a read, binary garbage, a one-column terminal | pass (see below) |
| Resizing: reflow of wrapped lines, height changes, alternate screen not reflowed | pass, one deviation |

## What was wrong and is worked around

Found by the suite; the embedder repairs each in `TermGrid::csi`:

- **DCH** with a count past the end of the line erased cells before the cursor.
- **ED 1** (erase from the start of the screen) left the first row alone when the cursor was on the second.
- Leaving **origin mode** did not move the cursor home.
- **Modes 47 and 1047** did nothing; they now work as 1049.
- **DECSTR** (soft reset) was ignored.
- **CSI 16 t** (cell size) was not answered; the cell size also feeds `CSI 14 t`.
- A **wide character in a one-column terminal** panics the engine: the grid is two columns at least, and a
  panic of the parser thread now resets the screen instead of ending the terminal.
- A CSI cut in two by the end of a read is held until it is whole.
- Programs asking for colours (OSC 4, 10, 11, 12) were answered with fixed colours; they hear the
  profile's, which the app sends.

## Deviations that stay

- DECDWL / DECDHL, VT52 mode and DECCOLM are not implemented (the window sets the size).
- DECSCNM (reverse screen) is not reported to the app.
- CPR in origin mode reports the absolute row, where xterm reports it relative to the region.
- After narrowing the window the reflowed lines that no longer fit above the cursor go to the
  scrollback although blank rows remain below it. Nothing is lost.

`deviations()` in the suite asserts these as they are, so that a new version of the engine that
changes one is noticed.
