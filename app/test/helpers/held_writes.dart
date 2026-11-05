import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/features/apps/domain/app_entry.dart';

import 'in_memory_device_repository.dart';
import 'in_memory_shortcut_repository.dart';

/// A shortcut store whose writes wait for [gate], then fail: a write still
/// running when the user leaves the screen.
class HeldShortcutRepository extends InMemoryShortcutRepository {
  /// Creates the store, holding [initial].
  HeldShortcutRepository([super.initial]);

  /// Completing it makes every write fail.
  final Completer<void> gate = Completer<void>();

  @override
  Future<bool> add(AppEntry app) async {
    await gate.future;
    throw StateError('disk full');
  }

  @override
  Future<void> update(AppEntry app) async {
    await gate.future;
    throw StateError('disk full');
  }

  @override
  Future<void> remove(String package) async {
    await gate.future;
    throw StateError('disk full');
  }
}

/// A TV store whose writes wait for [gate], then fail.
class HeldDeviceRepository extends InMemoryDeviceRepository {
  /// Creates the store, holding [initial].
  HeldDeviceRepository([super.initial]);

  /// Completing it makes every write fail.
  final Completer<void> gate = Completer<void>();

  @override
  Future<void> setNickname(String serviceName, String? nickname) async {
    await gate.future;
    throw StateError('disk full');
  }

  @override
  Future<void> delete(String serviceName) async {
    await gate.future;
    throw StateError('disk full');
  }
}

/// Leaves the current screen for the Settings hub, so its widget is gone
/// while the app, and any snackbar messenger it took, is still there.
Future<void> leaveScreen(WidgetTester t) async {
  ProviderScope.containerOf(
    t.element(find.byType(MaterialApp)),
  ).read(appRouterProvider).go(AppRoutes.settings);
  await t.pumpAndSettle();
}
