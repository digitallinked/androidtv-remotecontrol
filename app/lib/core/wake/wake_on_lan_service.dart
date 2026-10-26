import 'dart:async';
import 'dart:io';

import 'package:atv_remote/atv_remote.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'wake_on_lan_service.g.dart';

/// Sends a Wake-on-LAN packet; the signature of [sendWakeOnLan], so tests can
/// substitute a recorder.
typedef WakeOnLanSender =
    Future<void> Function(
      String mac, {
      List<InternetAddress>? broadcastAddresses,
      int port,
    });

/// The broadcast addresses to try, in order and without duplicates: the
/// limited broadcast `255.255.255.255`, then [subnetBroadcast] (the Wi-Fi
/// subnet's broadcast) and the `/24` broadcast of [tvHost], each only when it
/// parses as IPv4.
List<InternetAddress> wakeOnLanTargets({
  String? subnetBroadcast,
  String? tvHost,
}) {
  final addresses = <String>['255.255.255.255'];
  final subnet = _ipv4(subnetBroadcast);
  if (subnet != null) addresses.add(subnet.address);
  final host = _ipv4(tvHost);
  if (host != null) {
    final octets = host.address.split('.');
    addresses.add('${octets[0]}.${octets[1]}.${octets[2]}.255');
  }
  return [
    for (final address in addresses.toSet()) InternetAddress(address),
  ];
}

InternetAddress? _ipv4(String? value) {
  if (value == null) return null;
  final address = InternetAddress.tryParse(value);
  return address != null && address.type == InternetAddressType.IPv4
      ? address
      : null;
}

/// Wakes a TV from standby by broadcasting a magic packet on the local
/// network. Never logs the MAC or any address.
class WakeOnLanService {
  /// Creates the service. `subnetBroadcast` defaults to the Wi-Fi subnet
  /// broadcast from `network_info_plus` (no location permission needed);
  /// `send` defaults to [sendWakeOnLan].
  WakeOnLanService({
    Future<String?> Function()? subnetBroadcast,
    this._send = sendWakeOnLan,
    this._lookupTimeout = const Duration(seconds: 2),
  }) : _subnetBroadcast = subnetBroadcast ?? NetworkInfo().getWifiBroadcast;

  final Future<String?> Function() _subnetBroadcast;
  final WakeOnLanSender _send;
  final Duration _lookupTimeout;

  /// Sends the magic packet for [mac] to the limited broadcast, the Wi-Fi
  /// subnet broadcast and the `/24` of [tvHost] (the TV's last known IP).
  /// [tvHost] is a bare IPv4 host such as `192.168.0.20`, not a service name
  /// like `manual:192.168.0.20`; anything else is ignored.
  ///
  /// Returns `true` once sent and `false` if the network refused it. Throws a
  /// [FormatException] for a malformed [mac], before anything is sent.
  Future<bool> wake({required String mac, String? tvHost}) async {
    buildMagicPacket(mac);
    final subnet = await _lookupSubnetBroadcast();
    try {
      await _send(
        mac,
        broadcastAddresses: wakeOnLanTargets(
          subnetBroadcast: subnet,
          tvHost: tvHost,
        ),
      );
      return true;
    } on SocketException {
      return false;
    } on OSError {
      return false;
    }
  }

  Future<String?> _lookupSubnetBroadcast() async {
    try {
      return await _subnetBroadcast().timeout(_lookupTimeout);
    } on Object {
      return null;
    }
  }
}

/// The app's [WakeOnLanService].
@Riverpod(keepAlive: true)
WakeOnLanService wakeOnLanService(Ref ref) => WakeOnLanService();
