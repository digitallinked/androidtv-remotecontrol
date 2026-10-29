import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/config/service_config.dart';
import 'package:tv_remote/core/firebase/firebase_bootstrap.dart';

void main() {
  const enabled = ServiceConfig(firebaseEnabled: true);

  test('not_enabled_never_touches_firebase', () async {
    var calls = 0;

    final status = await initializeFirebase(
      ServiceConfig.none,
      initializeApp: () async => calls++,
    );

    expect(status, FirebaseStatus.notConfigured);
    expect(calls, 0);
  });

  test('a_throwing_init_is_unavailable', () async {
    final status = await initializeFirebase(
      enabled,
      initializeApp: () async => throw PlatformException(code: 'no-app'),
    );

    expect(status, FirebaseStatus.unavailable);
  });

  test('a_hanging_init_times_out', () {
    fakeAsync((async) {
      FirebaseStatus? status;
      unawaited(
        initializeFirebase(
          enabled,
          initializeApp: () => Completer<void>().future,
        ).then((s) => status = s),
      );

      async.elapse(const Duration(seconds: 4));
      expect(status, isNull);
      // Inside the 5 s startup step: a hang ends here, not in the step.
      async.elapse(const Duration(milliseconds: 600));
      expect(status, FirebaseStatus.unavailable);
    });
  });

  test('a_good_init_is_ready', () async {
    var calls = 0;

    final status = await initializeFirebase(
      enabled,
      initializeApp: () async => calls++,
    );

    expect(status, FirebaseStatus.ready);
    expect(calls, 1);
  });
}
