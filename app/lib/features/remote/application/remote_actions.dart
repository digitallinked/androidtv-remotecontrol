import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/analytics/analytics_guard.dart'
    show AnalyticsPolicyError;
import 'package:tv_remote/core/analytics/analytics_hooks.dart';
import 'package:tv_remote/core/haptics/haptics.dart';
import 'package:tv_remote/core/review/review_prompter.dart';
import 'package:tv_remote/core/session/remote_session.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/settings_controller.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/remote/application/key_input.dart';

part 'remote_actions.g.dart';

/// A command that `RemoteActions` sent to the TV, for the hook that Phase 6
/// attaches analytics and the review prompter to (Ruling P4-R17).
@immutable
sealed class RemoteActionEvent {
  const RemoteActionEvent();
}

/// A key press was sent. For a hold this is the first send only (its
/// direction is `startLong` with Smooth Press, `short` when repeating);
/// repeats and releases are not reported.
final class KeySent extends RemoteActionEvent {
  /// Creates the event.
  const KeySent(this.keyCode, this.direction);

  /// The Android key code that was sent.
  final int keyCode;

  /// How it was sent.
  final KeyDirection direction;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeySent &&
          other.keyCode == keyCode &&
          other.direction == direction;

  @override
  int get hashCode => Object.hash(keyCode, direction);

  @override
  String toString() => 'KeySent($keyCode, $direction)';
}

/// An app launch link was sent.
final class AppLaunched extends RemoteActionEvent {
  /// Creates the event.
  const AppLaunched(this.package);

  /// The application id of the launched app.
  final String package;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppLaunched && other.package == package;

  @override
  int get hashCode => package.hashCode;

  @override
  String toString() => 'AppLaunched($package)';
}

/// Text was sent to the TV. Carries the length only, never the text.
final class TextSent extends RemoteActionEvent {
  /// Creates the event.
  const TextSent(this.length);

  /// The number of UTF-16 code units sent.
  final int length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TextSent && other.length == length;

  @override
  int get hashCode => length.hashCode;

  @override
  String toString() => 'TextSent($length)';
}

/// Receives each command `RemoteActions` sent.
typedef RemoteActionListener = void Function(RemoteActionEvent event);

/// Where sent commands are reported: a fan-out to everything that follows
/// what the user does on the remote. That is analytics (key presses
/// sampled, app launches by catalogue package; typed text is never logged,
/// not even its length) and the review prompter, which counts every key
/// press (the demo's are ignored there).
@Riverpod(keepAlive: true)
RemoteActionListener remoteActionListener(Ref ref) {
  final analytics = ref.watch(analyticsHooksProvider);
  final review = ref.watch(reviewPrompterProvider.notifier);
  return (event) {
    switch (event) {
      case KeySent(:final keyCode):
        review.countPress();
        analytics.keySent(keyCode);
      case AppLaunched(:final package):
        analytics.appLaunched(package);
      case TextSent():
        break;
    }
  };
}

/// Counts the presses that were refused because the TV isn't connected; the
/// remote screen shows the "Not connected" snackbar for each bump.
@Riverpod(keepAlive: true)
class NotConnectedNotices extends _$NotConnectedNotices {
  @override
  int build() => 0;

  /// Records one more refused command.
  void notify() => state++;
}

/// Every press of a remote control goes through here: it sends the key,
/// handles holds (Smooth Press or repeat) with a stuck-key guard, fires the
/// haptics, and refuses commands while the TV isn't connected (Rulings
/// P4-R3, P4-R4, P4-R6).
///
/// An instance is tied to one session and one pair of settings; the provider
/// builds a new one when they change and disposes the old one, which
/// releases an active hold.
class RemoteActions implements RemoteInput {
  /// Creates the actions for `session`.
  ///
  /// `session` is `null` when there is no TV or the session is reloading (a
  /// TV switch): every command is then refused. `onRefused` is called for
  /// each refused command, `onSent` for each sent one.
  RemoteActions({
    required this._session,
    required this._smoothPress,
    required this._hapticsEnabled,
    required this._haptics,
    required this._onRefused,
    this._onSent,
    this._repeatInterval = const Duration(milliseconds: 120),
    this._maxHold = const Duration(seconds: 15),
  });

  /// The keys whose press can become a hold.
  static const Set<int> holdableKeys = {
    KeyCodes.dpadUp,
    KeyCodes.dpadDown,
    KeyCodes.dpadLeft,
    KeyCodes.dpadRight,
    KeyCodes.dpadCenter,
    KeyCodes.volumeUp,
    KeyCodes.volumeDown,
    KeyCodes.channelUp,
    KeyCodes.channelDown,
  };

  /// The holdable keys that repeat when Smooth Press is off. The centre key
  /// doesn't: its hold is a single press.
  static const Set<int> repeatableKeys = {
    KeyCodes.dpadUp,
    KeyCodes.dpadDown,
    KeyCodes.dpadLeft,
    KeyCodes.dpadRight,
    KeyCodes.volumeUp,
    KeyCodes.volumeDown,
    KeyCodes.channelUp,
    KeyCodes.channelDown,
  };

  final RemoteSession? _session;
  final bool _smoothPress;
  final bool _hapticsEnabled;
  final Haptics _haptics;
  final VoidCallback _onRefused;
  final RemoteActionListener? _onSent;
  final Duration _repeatInterval;
  final Duration _maxHold;

  int? _activeHold;
  Timer? _repeatTimer;
  Timer? _maxHoldTimer;
  bool _disposed = false;

  @override
  bool tap(int keyCode) {
    if (!_sendKey(keyCode, KeyDirection.short)) return false;
    if (keyCode == KeyCodes.power) {
      _heavy();
    } else {
      _light();
    }
    _report(KeySent(keyCode, KeyDirection.short));
    return true;
  }

  @override
  void holdStart(int keyCode) {
    if (_disposed) return;
    final smooth = _smoothPress;
    if (!holdableKeys.contains(keyCode) ||
        (keyCode == KeyCodes.dpadCenter && !smooth)) {
      tap(keyCode);
      return;
    }
    if (_activeHold != null) holdEnd(_activeHold!);
    final direction = smooth ? KeyDirection.startLong : KeyDirection.short;
    if (!_sendKey(keyCode, direction)) return;
    // Arm the guards before anything else can fail: the key is down on the TV.
    _activeHold = keyCode;
    _maxHoldTimer = Timer(_maxHold, () => holdEnd(keyCode));
    if (!smooth) {
      _repeatTimer = Timer.periodic(_repeatInterval, (_) => _repeat(keyCode));
    }
    _medium();
    _report(KeySent(keyCode, direction));
  }

  @override
  void holdEnd(int keyCode) {
    if (_activeHold != keyCode) return;
    _clearHold();
    if (!_smoothPress) return;
    try {
      _session?.sendKey(keyCode, direction: KeyDirection.endLong);
    } on NotConnectedException {
      // Best effort: the connection is gone, and the TV has no hold left.
    }
  }

  @override
  bool launch(AppEntry app) {
    if (!_guard(() => _session!.launchAppLink(app.launchLink))) return false;
    _light();
    _report(AppLaunched(app.package));
    return true;
  }

  @override
  bool typeText(String text) {
    if (!_guard(() => _session!.sendText(text))) return false;
    _report(TextSent(text.length));
    return true;
  }

  /// Releases an active hold and cancels the timers. Later calls do nothing
  /// and return `false`.
  void dispose() {
    if (_disposed) return;
    final hold = _activeHold;
    if (hold != null) holdEnd(hold);
    _disposed = true;
  }

  void _repeat(int keyCode) {
    try {
      _session!.sendKey(keyCode);
    } on NotConnectedException {
      _clearHold();
      _onRefused();
    }
  }

  void _clearHold() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _maxHoldTimer?.cancel();
    _maxHoldTimer = null;
    _activeHold = null;
  }

  bool _sendKey(int keyCode, KeyDirection direction) {
    // A programming error even while offline (Ruling P4-R3).
    if (!_disposed && !isSupportedKeyCode(keyCode)) {
      throw ArgumentError.value(keyCode, 'keyCode', 'Unknown Android key code');
    }
    return _guard(() => _session!.sendKey(keyCode, direction: direction));
  }

  /// Tells the listener; its failure must not undo a command that was sent.
  void _report(RemoteActionEvent event) {
    try {
      _onSent?.call(event);
      // A policy error is an Error on purpose (a programming mistake).
      // ignore: avoid_catching_errors
    } on AnalyticsPolicyError {
      // A bad analytics event is a programming error: debug builds (and so
      // the tests) must see it. A release build already dropped the event.
      if (kDebugMode) rethrow;
    } on Object catch (error) {
      // Analytics and counters are best effort. The event's fields and the
      // error's message are left out: they could hold what the user typed.
      if (kDebugMode) {
        debugPrint(
          'RemoteActions listener failed on ${event.runtimeType}: '
          '${error.runtimeType}',
        );
      }
    }
  }

  /// Runs [send] unless disposed or not connected; a refusal (also one that
  /// only the send itself notices) calls `onRefused` and returns `false`.
  bool _guard(void Function() send) {
    if (_disposed) return false;
    final session = _session;
    if (session == null ||
        session.current.status != ConnectionStatus.connected) {
      _onRefused();
      return false;
    }
    try {
      send();
    } on NotConnectedException {
      _onRefused();
      return false;
    }
    return true;
  }

  void _light() {
    if (_hapticsEnabled) unawaited(_haptics.light());
  }

  void _medium() {
    if (_hapticsEnabled) unawaited(_haptics.medium());
  }

  void _heavy() {
    if (_hapticsEnabled) unawaited(_haptics.heavy());
  }
}

/// The [RemoteActions] for the active TV and the current settings.
///
/// This provider is autoDispose: callers must watch it to keep it alive. A
/// disposed instance refuses silently (returns `false`, no notice), so code
/// that holds an instance across an async gap must use the return value.
///
/// Rebuilt when the session, Smooth Press or haptics change; the old instance
/// is disposed, which releases an active hold, so a settings change or a TV
/// switch in the middle of a hold never leaves a key stuck.
@riverpod
RemoteActions remoteActions(Ref ref) {
  final session = ref.watch(
    remoteSessionProvider.select(
      (s) => s.isLoading || s.hasError ? null : s.value,
    ),
  );
  final (smoothPress, hapticsEnabled) = ref.watch(
    settingsControllerProvider.select(
      (s) => (s.smoothPressEnabled, s.hapticsEnabled),
    ),
  );
  final haptics = ref.watch(hapticsProvider);
  final onSent = ref.watch(remoteActionListenerProvider);
  final notices = ref.read(notConnectedNoticesProvider.notifier);
  final actions = RemoteActions(
    session: session,
    smoothPress: smoothPress,
    hapticsEnabled: hapticsEnabled,
    haptics: haptics,
    onRefused: notices.notify,
    onSent: onSent,
  );
  ref.onDispose(actions.dispose);
  return actions;
}
