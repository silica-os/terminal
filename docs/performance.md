# Performance under heavy output

These measurements decide how Terminal renders. The question was whether a Flutter front end can stay responsive when a program floods it with output. The verdict is at the end.

## Setup

- **Session:** headless Ossido on one machine (XPS 15 9530, 20 threads). Rendering is CPU-only for every terminal.
- **Builds:** release (`cargo xtask bundle --release`, AOT Dart, release engine).
- **Terminal grid:**
  - Silica's Terminal: 263 × 65 cells (window 1880 × 1000).
  - ptyxis (VTE 0.8x, GTK 4), as the native reference: 238 × 56 cells, maximised in the same session. foot and alacritty are not installed on the host.
- **Wall time:** the shell measures it inside each terminal. The pty applies backpressure, so the producer only finishes when the terminal has consumed the output.
- **Frames:** `perf.frames` gives the intervals between the window's commits during the run. 16.7 ms is 60 Hz.
- **Ctrl+C:** the delay from Ctrl+C, pressed during a `yes` flood, until `yes` is gone.

| Workload | Data |
|---|---|
| `seq 1 2000000` | 13.9 MB, short lines |
| `cat` of a 200 MB text file | 200 MB, ~110-column lines |
| `yes \| head -n 5000000` | 10 MB, 1-column lines |
| truecolor | 300 full 80 × 23 frames of 24-bit background gradients (11 MB of SGR) |

## Results

| | xterm.dart (old) | Grid: Rust emulation, Flutter painting | ptyxis (VTE) |
|---|---|---|---|
| `seq`, wall | 4.13 s | **0.55 s** | 1.08 s |
| `seq`, frame p50 / p99 | 32 / 53 ms | **17 / 36 ms** | 17 / 600 ms |
| `cat` 200 MB, wall | 55.0 s (3.6 MB/s) | **3.55 s (56 MB/s)** | 3.55 s (56 MB/s) |
| `cat`, frame p50 / p99 | 17 / 42 ms | **17 / 38 ms** | 21 / 75 ms |
| `yes`, wall | 3.93 s | **1.48 s** | 2.08 s |
| truecolor, wall | 2.53 s | **0.37 s** | 0.66 s |
| truecolor, frame p50 / p99 | 29 / 56 ms | **17 / 44 ms** | 18 / 599 ms |
| Ctrl+C during a flood | 725 ms | **110 ms** | 28 ms |
| RSS after the runs | 435 MiB | 380 MiB | 298 MiB |

Notes on the table:
- **The old path with larger pty messages:** raising the old path's pty messages from 64 KB to 512 KB per frame made its throughput look like the grid's: `cat` took 7.3 s. But the UI froze for the whole run (3 frames in 7 s). The Dart UI thread was busy parsing in xterm.dart. That configuration is not used.
- **The `yes` row:** every visible row of the grid holds "y", so after the first frame nothing visible changes. The grid sends no rows and the window does not commit, which is correct. That's why this row has no frame times.
- **Grid variance:** over three runs, `cat` was 2.3–3.6 s. The faster runs used a 4 MB pending window instead of 1 MB.

## What changed

The cost was never Flutter's painting. It was the emulator: xterm.dart parses escape sequences and keeps its buffer on Dart's UI thread, so parsing and painting compete for the same thread. The grid path splits the work differently:

1. **Rust parses.** The embedder's `silica/pty` with `spawn {grid: true}` runs `alacritty_terminal` on a parser thread of its own. The program's output never crosses the platform channel as bytes.
2. **Only changed rows are sent.** At most once per frame, the app receives the visible rows that really changed, as runs of text with the same attributes. Rows identical to the last ones sent are skipped, and so are cursor-only damages.
3. **Fair locking.** The parser parses in 16 KB slices and gives way to the frame between slices. The std `Mutex` is not fair, so the frame signals that it is waiting.
4. **One painter.** On the Flutter side, one `CustomPainter` draws backgrounds, one `ui.Paragraph` per row, and the cursor. Paragraphs are cached by row content in an LRU, so rows that only scrolled are not laid out again. There is no widget per cell or per row.
5. **Backpressure.** Reading from the pty pauses while more than 1 MB is waiting for the parser.

Two things remain slower than VTE:
- **Ctrl+C latency:** 110 ms against 28 ms. The key goes through the Flutter UI thread and the platform channel, and the measurement polls every 50 ms.
- **Memory:** about 80 MiB more, mostly the Flutter engine.

## Verdict

**Flutter is acceptable as Silica's UI stack, including for Terminal**, provided terminal emulation runs in Rust and Flutter only paints. With that split, Terminal:
- matches VTE's throughput on large output (56 MB/s);
- beats it on short-line and colour-heavy output;
- keeps steadier frames during floods (p99 under 45 ms, where ptyxis showed 600 ms stalls);
- stays interruptible.

The bottleneck found was xterm.dart's design: a Dart-side parser on the UI thread. It is not the toolkit. Moving the whole UI to Rust is not justified by these numbers.

The grid engine is now the only engine: Terminal no longer depends on xterm.dart, and the features that were left behind (scrollback viewing, selection, search, mouse reporting, the OSC sequences, the split view) run on it.

## Headless benchmarks of the finished engine

The VM run above measured the whole path. These two benchmarks measure the halves separately, without a display, so that they can be repeated (i9-13900H, 20 threads; the Rust numbers are a release build, the Dart numbers the JIT build `flutter test` uses, so they are upper bounds for the AOT app).

**Engine** (`cargo test --release -p silica-embedder --lib bench_flood -- --ignored --nocapture`, `crates/embedder/src/termgrid.rs`): the real parser thread is fed 64 KB chunks of a flood while the test takes a frame every 16.7 ms and asks the grid something every millisecond, as a key, a click or the wheel would.

| Flood | Size | Parse | Frame (build + encode) p50 / p99 | Frame size | Wait for the grid p50 / p99 / max |
|---|---|---|---|---|---|
| `seq 1 10000000` | 89 MB | 127 MB/s | 0.24 / 0.36 ms | 2.1 KB | 0.05 / 0.12 / 0.26 ms |
| `yes` (5 M lines) | 15 MB | 129 MB/s | 0.17 / 5.6 ms | 0.1 KB | 0.04 / 0.13 / 7.7 ms |
| `cat` of 100 MB of text | 90 MB | 134 MB/s | 0.29 / 0.35 ms | 6.2 KB | 0.09 / 0.16 / 0.67 ms |
| colour, an SGR per word | 91 MB | 110 MB/s | 0.34 / 0.55 ms | 8.1 KB | 0.08 / 0.18 / 0.41 ms |

(The 7.7 ms maximum of `yes` is the first frame after the parser started, not a steady stall.) The pty cannot deliver more than the 56 MB/s measured above, so the parser has about twice the headroom.

**Painter and view** (`test/perf_test.dart`): a 60 × 200 grid in which every row is new in every frame, the worst case of a flood; `jsonDecode` of the message, `GridState.apply`, and layout plus paint of the rows.

| Step | p50 | p99 |
|---|---|---|
| Decode the frame | 0.05 ms | |
| Build the rows | 0.01 ms | |
| Lay out and paint 60 rows | 2.0 ms | 5.2 ms |
| UI thread per frame, all of it | 2.1 ms | 7.5 ms (max 10 ms) |
| A whole frame through the widget (61 × 205) | 2.2 ms | 3.0 ms |
| A key pressed between flooded frames, to the pty | 0.39 ms | 1.05 ms |

All 120 keys sent during the flood reached the pty. The frame budget is 16.7 ms: the UI thread is busy about 13% of it in the worst case, a key waits at most for the frame being built (about 10 ms in the JIT build), and the embedder's grid answers calls in under 0.2 ms at the 99th percentile during a flood.

**Verdict**: the Flutter front end keeps up with `yes`, `cat` of a large file and `seq 1e7` without dropping input or freezing; the limit is the pty, not the engine and not the painter. Moving the front end to Rust is not needed. What is left unmeasured here is the GPU side of painting a frame, which the VM numbers above cover (frame p99 38 ms during `cat`, steady 60 Hz on short lines).
