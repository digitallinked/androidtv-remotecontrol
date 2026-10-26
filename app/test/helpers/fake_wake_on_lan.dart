import 'package:tv_remote/core/wake/wake_on_lan_service.dart';

/// A [WakeOnLanService] that records what it was asked to wake instead of
/// sending packets.
class FakeWakeOnLan implements WakeOnLanService {
  /// The calls to [wake], in order.
  final List<(String mac, String? tvHost)> wakes = [];

  /// What [wake] returns: whether a packet "went out".
  bool result = true;

  /// When set, [wake] waits for it before it returns (a slow lookup).
  Future<void>? gate;

  @override
  Future<bool> wake({required String mac, String? tvHost}) async {
    wakes.add((mac, tvHost));
    await gate;
    return result;
  }
}
