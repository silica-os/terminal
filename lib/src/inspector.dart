// The inspector (⌘I; docs/spec/inspector.md): the facts of the current tab and its window.
// A utility window of 281 pt; where Silica opens none, the same panel floats over the window.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';
import 'session.dart';
import 'window.dart';

/// The version shown in About and the inspector.
const String appVersion = '0.1.0';

/// Width of the panel (measured: 281).
const double inspectorWidth = 281;

abstract final class InspectorPanel {
  /// Opens the inspector in its own window; false where windows cannot be opened.
  static Future<bool> open(
    BuildContext context,
    TerminalWindowState window,
  ) async {
    final opened = await SilicaWindows.openWindow(
      title: l10n.inspectorTitle,
      size: const Size(inspectorWidth, 340),
      kind: SilicaWindowKind.utility,
      parent: View.maybeOf(context)?.viewId,
      builder: (context) => InspectorView(window: window),
    );
    return opened != null;
  }
}

/// The facts: updates as the tab changes.
class InspectorView extends StatelessWidget {
  const InspectorView({super.key, required this.window, this.onClose});

  final TerminalWindowState window;

  /// Closes the panel when it floats over the window.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    return ListenableBuilder(
      listenable: window.tabs.isEmpty
          ? Listenable.merge(const [])
          : Listenable.merge([window.session, window.session.grid]),
      builder: (context, _) {
        if (window.tabs.isEmpty) return const SizedBox.shrink();
        final s = window.session;
        final rows = <(String, String)>[
          (l10n.inspectorTitleRow, s.title),
          (l10n.inspectorSize, '${s.grid.cols} × ${s.grid.rows}'),
          (l10n.inspectorProfile, s.profile.name),
          (l10n.inspectorDirectory, s.grid.cwd ?? l10n.inspectorUnknown),
          (
            l10n.inspectorCommand,
            s.command?.join(' ') ?? l10n.inspectorLoginShell,
          ),
          (l10n.inspectorStatus, _status(s)),
        ];
        return Container(
          key: const ValueKey('inspector'),
          width: inspectorWidth,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceWindow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.lineSeparator),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (label, value) in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AmalfiType.caption(color: colors.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AmalfiType.body(color: colors.textPrimary),
                      ),
                    ],
                  ),
                ),
              if (onClose != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: AmalfiPushButton(
                    key: const ValueKey('inspector close'),
                    label: l10n.findDone,
                    size: AmalfiControlSize.small,
                    onPressed: onClose,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _status(TerminalSession s) {
    final exit = s.exit;
    if (exit == null)
      return s.ended ? l10n.inspectorNotStarted : l10n.inspectorRunning;
    return exit.signal != null
        ? l10n.processKilled(exit.signal!)
        : l10n.processExited(exit.code ?? 0);
  }
}
