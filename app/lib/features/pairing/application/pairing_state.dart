import 'package:flutter/foundation.dart' show immutable;
import 'package:tv_remote/core/storage/app_database.dart';

/// Why pairing ended without a paired TV. The screen turns each kind into a
/// message and the action that fits.
enum PairingErrorKind {
  /// The TV couldn't be reached.
  cantReachTv,

  /// The TV was reached but stopped answering.
  tvDidNotRespond,

  /// The TV refused the code.
  codeRejectedByTv,

  /// The TV sent something unexpected.
  pairingError,

  /// This phone's secure connection data couldn't be prepared.
  identityUnavailable,

  /// Pairing worked but the TV couldn't be saved.
  saveFailed,
}

/// Where pairing with a TV stands.
@immutable
sealed class PairingState {
  /// Creates a state.
  const PairingState();
}

/// Connecting to the TV and waiting for it to show the code.
final class PairingStarting extends PairingState {
  /// Creates the state.
  const PairingStarting();

  @override
  bool operator ==(Object other) => other is PairingStarting;

  @override
  int get hashCode => (PairingStarting).hashCode;

  @override
  String toString() => 'PairingStarting';
}

/// The TV shows a code and the user may enter it.
final class PairingWaitingForCode extends PairingState {
  /// Creates the state.
  const PairingWaitingForCode({
    required this.secondsLeft,
    this.codeMismatch = false,
  });

  /// Seconds until the code expires.
  final int secondsLeft;

  /// Whether the last code failed its checksum, so the user should enter it
  /// again.
  final bool codeMismatch;

  @override
  bool operator ==(Object other) =>
      other is PairingWaitingForCode &&
      other.secondsLeft == secondsLeft &&
      other.codeMismatch == codeMismatch;

  @override
  int get hashCode =>
      Object.hash(PairingWaitingForCode, secondsLeft, codeMismatch);

  @override
  String toString() =>
      'PairingWaitingForCode($secondsLeft, mismatch: $codeMismatch)';
}

/// The code was sent and the TV is checking it.
final class PairingVerifying extends PairingState {
  /// Creates the state.
  const PairingVerifying();

  @override
  bool operator ==(Object other) => other is PairingVerifying;

  @override
  int get hashCode => (PairingVerifying).hashCode;

  @override
  String toString() => 'PairingVerifying';
}

/// Nobody entered a code in time.
final class PairingCodeExpired extends PairingState {
  /// Creates the state.
  const PairingCodeExpired();

  @override
  bool operator ==(Object other) => other is PairingCodeExpired;

  @override
  int get hashCode => (PairingCodeExpired).hashCode;

  @override
  String toString() => 'PairingCodeExpired';
}

/// The TV is paired and saved.
final class PairingSucceeded extends PairingState {
  /// Creates the state.
  const PairingSucceeded(this.device);

  /// The saved TV.
  final SavedDevice device;

  @override
  bool operator ==(Object other) =>
      other is PairingSucceeded && other.device == device;

  @override
  int get hashCode => Object.hash(PairingSucceeded, device);

  @override
  String toString() => 'PairingSucceeded';
}

/// Pairing ended with an error.
final class PairingFailed extends PairingState {
  /// Creates the state.
  const PairingFailed(this.kind);

  /// What went wrong.
  final PairingErrorKind kind;

  @override
  bool operator ==(Object other) =>
      other is PairingFailed && other.kind == kind;

  @override
  int get hashCode => Object.hash(PairingFailed, kind);

  @override
  String toString() => 'PairingFailed(${kind.name})';
}
