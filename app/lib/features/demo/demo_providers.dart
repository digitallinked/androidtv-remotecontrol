import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/session/session_target.dart';
import 'package:tv_remote/features/demo/demo_remote_session.dart';

part 'demo_providers.g.dart';

/// Whether the simulated demo TV is the active target.
@riverpod
bool isDemoActive(Ref ref) => ref.watch(activeTargetProvider) is DemoTarget;

/// What the demo TV was last asked to do, then every new action; `null`
/// before the first one, and for a session that is not the demo TV.
///
/// This is the only place that checks the session's type: the rest of the UI
/// reads `RemoteSession.isDemo` and this provider.
@Riverpod(retry: noRetry)
Stream<DemoAction?> demoActivity(Ref ref) async* {
  final session = await ref.watch(remoteSessionProvider.future);
  if (session is! DemoRemoteSession) {
    yield null;
    return;
  }
  // Subscribes before it emits the last action, so none falls in between.
  yield* Stream<DemoAction?>.multi((listener) {
    final subscription = session.actions.listen(
      listener.add,
      onDone: listener.close,
    );
    listener
      ..add(session.lastAction)
      ..onCancel = subscription.cancel;
  });
}

/// Leaves demo mode and opens the list of TVs.
Future<void> leaveDemo(WidgetRef ref) async {
  ref.read(activeTargetProvider.notifier).clear();
  ref.read(appRouterProvider).go(AppRoutes.discover);
}
