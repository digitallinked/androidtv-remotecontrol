import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_sheet.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/features/keyboard/text_edit_planner.dart';
import 'package:tv_remote/features/remote/application/key_input.dart';

/// Opens the keyboard sheet for typing on the TV.
///
/// Does nothing while the sheet is already open ([KeyboardSheet.isOpen]).
/// Completes when the sheet has closed. Text goes to [input] after a
/// [debounce] pause (Ruling P4-R12); [mode] is the text strategy.
Future<void> showKeyboardSheet(
  BuildContext context, {
  required RemoteInput input,
  ImeTextMode mode = kImeTextMode,
  Duration debounce = const Duration(milliseconds: 150),
}) async {
  if (KeyboardSheet.isOpen) return;
  // Covers the gap between this call and the sheet's initState.
  final opening = Object();
  KeyboardSheet._opening = opening;
  try {
    await showAppSheet<void>(
      context: context,
      title: AppLocalizations.of(context).keyboardTitle,
      builder: (_) =>
          KeyboardSheet(input: input, mode: mode, debounce: debounce),
    );
  } finally {
    // Only this call's own claim: a newer sheet has its own.
    if (identical(KeyboardSheet._opening, opening)) {
      KeyboardSheet._opening = null;
    }
  }
}

/// The content of the keyboard sheet: a text field whose changes are sent to
/// the TV as they are typed, plus Enter, Clear and "Open search on TV".
///
/// Open it with [showKeyboardSheet]. Nothing is queued while the TV is not
/// connected; in replace mode the next edit after a reconnect sends the whole
/// field, so the TV catches up.
class KeyboardSheet extends ConsumerStatefulWidget {
  /// Creates the sheet content.
  const KeyboardSheet({
    required this.input,
    this.mode = kImeTextMode,
    this.debounce = const Duration(milliseconds: 150),
    super.key,
  });

  /// Where text and keys go.
  final RemoteInput input;

  /// How typed text reaches the TV.
  final ImeTextMode mode;

  /// How long the field must rest before its text is sent.
  final Duration debounce;

  /// The mounted sheet whose route has not been popped, if any.
  static _KeyboardSheetState? _active;

  /// A [showKeyboardSheet] call that has not built its sheet yet.
  static Object? _opening;

  /// Whether a keyboard sheet is open (from [showKeyboardSheet] until its
  /// route pops), so the screen doesn't open a second one. A sheet that is
  /// still playing its exit animation no longer counts, and its disposal never
  /// affects a newer sheet.
  static bool get isOpen => _active != null || _opening != null;

  @override
  ConsumerState<KeyboardSheet> createState() => _KeyboardSheetState();
}

class _KeyboardSheetState extends ConsumerState<KeyboardSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _timer;

  /// What the TV's field holds, as far as we know.
  String _sent = '';

  /// The last command was refused. This also catches a stale `RemoteActions`
  /// (disposed by a TV switch) that refuses while the provider says
  /// connected.
  bool _refused = false;
  bool _closing = false;
  ModalRoute<dynamic>? _route;

  RemoteInput get _input => widget.input;

  @override
  void initState() {
    super.initState();
    KeyboardSheet._active = this;
    KeyboardSheet._opening = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_route != null) return;
    // The route's future completes on pop, before the exit animation ends:
    // from then on a new sheet may open.
    _route = ModalRoute.of(context);
    unawaited(_route?.popped.then((_) => _release()));
  }

  void _release() {
    if (identical(KeyboardSheet._active, this)) KeyboardSheet._active = null;
  }

  @override
  void dispose() {
    _release();
    _closing = true;
    if (_timer?.isActive ?? false) _flush();
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    setState(() {});
    _timer?.cancel();
    _timer = Timer(widget.debounce, _flush);
  }

  /// Sends what changed since the last successful send. Returns whether the
  /// TV's field now matches the phone's.
  bool _flush() {
    _timer?.cancel();
    _timer = null;
    final text = _controller.text;
    final edits = planTextEdit(sent: _sent, next: text, mode: widget.mode);
    for (final edit in edits) {
      final ok = switch (edit) {
        SendText(:final text) => _input.typeText(text),
        DeleteChars(:final count) => _deleteTimes(count),
      };
      if (!ok) {
        _noteRefused(refused: true);
        return false;
      }
    }
    _sent = text;
    if (edits.isNotEmpty) _noteRefused(refused: false);
    return true;
  }

  bool _deleteTimes(int count) {
    for (var i = 0; i < count; i++) {
      if (!_input.tap(KeyCodes.delete)) return false;
    }
    return true;
  }

  void _noteRefused({required bool refused}) {
    if (_closing || !mounted || _refused == refused) return;
    setState(() => _refused = refused);
  }

  void _clear() {
    _controller.clear();
    setState(() {});
    _flush();
  }

  void _openTvSearch() {
    _noteRefused(refused: !_input.tap(KeyCodes.search));
  }

  void _enter() {
    _flush();
    final sent = _input.tap(KeyCodes.enter);
    if (sent && mounted) {
      _closeSheet();
    } else {
      _noteRefused(refused: true);
    }
  }

  /// Closes this sheet's own route, never whatever is on top of it.
  void _closeSheet() {
    final route = _route;
    if (route == null) return;
    final navigator = Navigator.of(context);
    if (route.isCurrent) {
      navigator.pop();
    } else if (route.isActive) {
      navigator.removeRoute(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.appColors;
    // A reconnect starts over: a stale refusal must not outlive it. (A stale
    // `RemoteActions` sets the flag again on its next refused send.)
    ref.listen(connectionStateProvider, (_, next) {
      if (!next.isLoading && next.value?.status == ConnectionStatus.connected) {
        _noteRefused(refused: false);
      }
    });
    final connection = ref.watch(connectionStateProvider);
    final connected =
        !connection.isLoading &&
        connection.value?.status == ConnectionStatus.connected;
    final showNotConnected = !connected || _refused;
    const buttonSize = Size(0, AppSizes.touchMin);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showNotConnected)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.m),
            child: Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.link_off, color: colors.dangerText),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      l10n.keyboardNotConnected,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.dangerText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Text(
          l10n.keyboardTvHint,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        TextField(
          controller: _controller,
          autofocus: true,
          autocorrect: false,
          // enableSuggestions stays at its default (true): suggestions help.
          // The user may type a TV password: don't let the IME learn from it.
          enableIMEPersonalizedLearning: false,
          textInputAction: TextInputAction.send,
          decoration: InputDecoration(
            labelText: l10n.keyboardFieldLabel,
            hintText: l10n.keyboardHint,
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: l10n.keyboardClear,
                    constraints: const BoxConstraints.tightFor(
                      width: AppSizes.touchMin,
                      height: AppSizes.touchMin,
                    ),
                    onPressed: _clear,
                  ),
          ),
          onChanged: _onChanged,
          // Keep focus on Send: the default would drop the keyboard. Enter
          // closes the sheet itself when it was sent.
          onEditingComplete: () {},
          onSubmitted: (_) => _enter(),
        ),
        const SizedBox(height: AppSpacing.m),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: [
            TextButton.icon(
              style: TextButton.styleFrom(minimumSize: buttonSize),
              icon: const Icon(Icons.search),
              label: Text(l10n.keyboardOpenTvSearch),
              onPressed: _openTvSearch,
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: buttonSize),
              icon: const Icon(Icons.keyboard_return),
              label: Text(l10n.keyEnter),
              onPressed: _enter,
            ),
          ],
        ),
      ],
    );
  }
}
