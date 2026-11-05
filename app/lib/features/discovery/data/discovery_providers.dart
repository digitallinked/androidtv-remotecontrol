import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/crash/crash_reporter.dart';
import 'package:tv_remote/core/crash/error_handlers.dart';
import 'package:tv_remote/core/tv/host_resolver.dart';
import 'package:tv_remote/features/discovery/data/nsd_tv_discovery.dart';

part 'discovery_providers.g.dart';

/// Creates the platform TV discovery. Tests override it with a fake.
@Riverpod(keepAlive: true)
TvDiscoveryFactory tvDiscoveryFactory(Ref ref) => NsdTvDiscovery.new;

/// Finds a saved TV's current address by its mDNS service name.
@Riverpod(keepAlive: true)
HostResolver hostResolver(Ref ref) =>
    (name) => resolveHostByServiceName(
      ref.read(tvDiscoveryFactoryProvider),
      name,
      onError: (error, stack) => unawaited(
        safeRecordError(
          ref.read(crashReporterProvider),
          error,
          stack,
          reason: 'host lookup',
        ),
      ),
    );
