import 'dart:async';
import 'dart:io';

import 'package:atv_remote/atv_remote.dart';
import 'package:nsd/nsd.dart';

/// Starts browsing for [serviceType]; `startDiscovery` from `package:nsd`.
typedef NsdStart =
    Future<Discovery> Function(
      String serviceType, {
      bool autoResolve,
      IpLookupType ipLookupType,
    });

/// Stops a browse; `stopDiscovery` from `package:nsd`.
typedef NsdStop = Future<void> Function(Discovery discovery);

/// Finds Android TVs with the platform's mDNS service (`nsd`).
///
/// On Android the plugin holds the Wi-Fi multicast lock while a browse runs,
/// so this class has no native code of its own.
class NsdTvDiscovery implements TvDiscovery {
  /// Creates a discovery. The start and stop functions default to the plugin
  /// and are replaced in tests.
  NsdTvDiscovery({
    this._start = startDiscovery,
    this._stop = stopDiscovery,
  });

  /// The service types browsed, current generation first.
  static const List<String> serviceTypes = [
    '_androidtvremote2._tcp',
    '_androidtvremote._tcp',
  ];

  final NsdStart _start;
  final NsdStop _stop;
  final StreamController<List<DiscoveredTv>> _controller =
      StreamController<List<DiscoveredTv>>();
  final Map<String, Discovery> _active = {};
  final Map<String, ServiceListener> _listeners = {};
  bool _watching = false;
  Future<void>? _stopping;

  /// Starts browsing and returns the stream of known TVs. It emits an empty
  /// list first, then the merged list on every service found or lost.
  ///
  /// Can be called once per instance; a second call throws a [StateError].
  @override
  Stream<List<DiscoveredTv>> watch() {
    if (_watching) {
      throw StateError('NsdTvDiscovery.watch() can only be called once');
    }
    _watching = true;
    _controller.add(const []);
    unawaited(_begin());
    return _controller.stream;
  }

  Future<void> _begin() async {
    try {
      for (final type in serviceTypes) {
        final discovery = await _start(
          type,
          autoResolve: true,
          ipLookupType: IpLookupType.v4,
        );
        if (_stopping != null) {
          // stop() ran while this browse was starting.
          await _stopQuietly(discovery);
          return;
        }
        _active[type] = discovery;
        Future<void> onChange(Service service, ServiceStatus status) async =>
            _publish();
        _listeners[type] = onChange;
        discovery.addServiceListener(onChange);
      }
      // Services found before the listeners were attached.
      _publish();
    } on Object catch (error, stackTrace) {
      if (_stopping == null && !_controller.isClosed) {
        _controller.addError(error, stackTrace);
      }
      await stop();
    }
  }

  void _publish() {
    if (_stopping != null || _controller.isClosed) return;
    final byName = <String, DiscoveredTv>{};
    // The current-generation record wins over the legacy one with the same
    // name, so legacy goes in first and gets overwritten.
    for (final type in serviceTypes.reversed) {
      final discovery = _active[type];
      if (discovery == null) continue;
      for (final service in discovery.services) {
        final tv = _toTv(service, type);
        if (tv != null) byName[tv.serviceName] = tv;
      }
    }
    final v2 = byName.values.where((tv) => !tv.isLegacyService);
    final legacy = byName.values.where((tv) => tv.isLegacyService);
    _controller.add([...v2, ...legacy]);
  }

  DiscoveredTv? _toTv(Service service, String requestedType) {
    final name = service.name;
    final port = service.port;
    final host = _pickHost(service);
    if (name == null || port == null || host == null) return null;
    try {
      return parseServiceRecord(
        serviceType: service.type ?? requestedType,
        name: name,
        host: host,
        port: port,
      );
      // parseServiceRecord signals an unknown service type with an
      // ArgumentError.
      // ignore: avoid_catching_errors
    } on ArgumentError {
      return null;
    }
  }

  String? _pickHost(Service service) {
    for (final address in service.addresses ?? const <InternetAddress>[]) {
      if (address.type == InternetAddressType.IPv4) return address.address;
    }
    final host = service.host;
    return host == null || host.isEmpty ? null : host;
  }

  /// Stops every browse and closes the stream. Safe to call repeatedly.
  @override
  Future<void> stop() => _stopping ??= _doStop();

  Future<void> _doStop() async {
    for (final entry in _listeners.entries) {
      _active[entry.key]?.removeServiceListener(entry.value);
    }
    _listeners.clear();
    final started = _active.values.toList();
    _active.clear();
    for (final discovery in started) {
      await _stopQuietly(discovery);
    }
    await _controller.close();
  }

  Future<void> _stopQuietly(Discovery discovery) async {
    try {
      await _stop(discovery);
    } on Object {
      // Nothing to do if the platform refuses to stop a browse, and the
      // remaining browses must still be stopped.
    }
  }
}
