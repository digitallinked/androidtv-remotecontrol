import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'not_connected_notices.g.dart';

/// Counts the presses that were refused because the TV isn't connected; the
/// remote screen shows the "Not connected" snackbar for each bump.
@Riverpod(keepAlive: true)
class NotConnectedNotices extends _$NotConnectedNotices {
  @override
  int build() => 0;

  /// Records one more refused command.
  void notify() => state++;
}
