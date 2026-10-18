import 'package:flutter_test/flutter_test.dart';
import 'package:terminal/src/grid.dart';

// The same frame is asserted by `the_frame_contract_with_the_app` in the embedder
// (crates/embedder/src/termgrid/conformance.rs of silica-desktop): if the message changes,
// one of the two tests breaks.
const frame = <String, Object?>{
  'id': 5,
  'cols': 20,
  'rows': 3,
  'full': true,
  'lines': [
    {
      'y': 0,
      'runs': [
        ['\$ ls ', -1, -1, 0, 5],
        ['red', 16777217, -1, 1, 3],
        [' ', -1, -1, 0, 1],
        ['link', -1, -1, 0, 4, 'https://example.org'],
      ],
    },
    {'y': 1, 'runs': []},
    {'y': 2, 'runs': []},
  ],
  'cursor': {
    'x': 13,
    'y': 0,
    'visible': true,
    'shape': 'block',
    'blink': false,
  },
  'modes': 2060,
  'scroll': {'offset': 0, 'history': 0},
  'selection': [
    [0, 0, 3],
  ],
  'marks': [0],
  'cwd': '/home/me/src',
  'bell': true,
  'clipboard': [
    {'set': 'hi', 'selection': false},
  ],
};

void main() {
  test('the frame of the embedder is read as the embedder wrote it', () {
    final state = GridState();
    final clips = <ClipboardRequest>[];
    state.onClipboard = clips.add;
    state.apply(frame);
    expect((state.cols, state.rows), (20, 3));
    expect(state.lines[0].text, '\$ ls red link');
    expect(state.lines[0].runs[1].fg, paletteBase + 1);
    expect(state.lines[0].runs[1].bold, isTrue);
    expect(state.lines[0].runs[3].link, 'https://example.org');
    expect(state.lines[0].cells, 13);
    expect((state.cursorX, state.cursorY, state.cursorShape), (13, 0, 'block'));
    expect(state.modes.mouse, isTrue);
    expect(state.modes.sgrMouse, isTrue);
    expect(state.modes.alternateScroll, isTrue);
    expect(state.modes.mouseDrag, isFalse);
    expect(state.selection, [const RowSpan(0, 0, 3)]);
    expect(state.marks, [0]);
    expect(state.cwd, '/home/me/src');
    expect(state.bells.value, 1);
    expect(clips.single.text, 'hi');
    expect((state.offset, state.history), (0, 0));
  });
}
