import 'package:tv_remote/features/apps/domain/app_entry.dart';

/// How long a holdable key must be pressed before it counts as a hold
/// (Ruling P4-R4).
const Duration kHoldThreshold = Duration(milliseconds: 300);

/// What key widgets call. Implemented by `RemoteActions`; tests use
/// `KeyInputRecorder`.
abstract interface class KeyInput {
  /// Presses and releases [keyCode]. Returns whether it was sent.
  bool tap(int keyCode);

  /// A press on [keyCode] became a hold.
  void holdStart(int keyCode);

  /// The hold on [keyCode] ended (always called once after [holdStart]).
  void holdEnd(int keyCode);
}

/// [KeyInput] plus app launches and text, for the quick-access row and the
/// keyboard.
abstract interface class RemoteInput implements KeyInput {
  /// Opens [app] on the TV. Returns whether it was sent.
  bool launch(AppEntry app);

  /// Replaces or extends the TV's focused text field (see the keyboard
  /// sheet). Returns whether it was sent.
  bool typeText(String text);
}
