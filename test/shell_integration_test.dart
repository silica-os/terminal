import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final script = File('data/silica-terminal.sh').absolute.path;

  test('the script is valid bash and zsh syntax', () async {
    final bash = await Process.run('bash', ['-n', script]);
    expect(bash.exitCode, 0, reason: '${bash.stderr}');
    final zsh = await Process.run('zsh', [
      '-n',
      script,
    ]).onError((_, _) => ProcessResult(0, 0, '', ''));
    expect(zsh.exitCode, 0, reason: '${zsh.stderr}');
  }, skip: Platform.isLinux ? false : 'needs bash');

  Future<String> run(String body, {Map<String, String> env = const {}}) async {
    final result = await Process.run(
      'bash',
      ['--norc', '--noprofile', '-i', '-c', body],
      environment: {'HOME': '/tmp', 'TERM': 'dumb', ...env},
      includeParentEnvironment: false,
    );
    return result.stdout as String;
  }

  test('it does nothing outside Silica Terminal', () async {
    final out = await run(
      'source $script; echo "[\$PS1][\$PROMPT_COMMAND][\$PS0]"',
    );
    expect(out, isNot(contains('133')));
    expect(out.trim(), endsWith('[][]'));
  });

  test('the escape sequences are the ones the terminal reads', () async {
    final out = await run(
      'PS1="\\\$ "; source $script; cd "/tmp/my dir" 2>/dev/null || mkdir -p "/tmp/my dir" && cd "/tmp/my dir"; (exit 3); __silica_prompt; printf "\\n--\\n%s\\n--\\n%s\\n" "\$PS1" "\${PS0@Q}"',
      env: {'SILICA_TERMINAL': '1'},
    );
    // D with the status, then OSC 7 with the percent-encoded directory.
    expect(out, contains('\x1b]133;D;3\x07\x1b]7;file://'));
    expect(out, contains('/tmp/my%20dir\x07'));
    expect(out, contains(r'\[\e]133;A\a\]'));
    expect(out, contains(r'\[\e]133;B\a\]'));
    expect(
      out,
      contains(
        r'$'
        "'"
        r'\E]133;C\a',
      ),
    );
  });

  test('sourcing twice does not stack the hooks', () async {
    final out = await run(
      'PS1="\\\$ "; source $script; source $script; echo "[\$PROMPT_COMMAND]"',
      env: {'SILICA_TERMINAL': '1'},
    );
    expect(RegExp('__silica_prompt').allMatches(out).length, 1);
  });
}
