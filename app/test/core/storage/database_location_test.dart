import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/storage/database_location.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Answers [storageChannel] with [answer] and records every call.
  List<MethodCall> mockStorage(Object? Function(MethodCall call) answer) {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(storageChannel, (call) async {
      calls.add(call);
      return answer(call);
    });
    addTearDown(() => messenger.setMockMethodCallHandler(storageChannel, null));
    return calls;
  }

  test('android_uses_drifts_default_directory', () {
    expect(databaseDirectoryFor(TargetPlatform.android), isNull);
  });

  test('ios_database_opens_in_the_backup_excluded_directory', () async {
    final calls = mockStorage((_) => '/x/Application Support/Database');

    final directory = databaseDirectoryFor(TargetPlatform.iOS);

    expect(directory, isNotNull);
    expect(await directory!(), '/x/Application Support/Database');
    expect(calls, hasLength(1));
    expect(calls.single.method, 'backupExcludedDatabaseDirectory');
  });

  test(
    'ios_without_an_excluded_directory_never_falls_back_to_documents',
    () async {
      mockStorage((_) => throw PlatformException(code: 'storage'));
      await expectLater(
        databaseDirectoryFor(TargetPlatform.iOS)!(),
        throwsStateError,
      );

      final calls = mockStorage((_) => null);
      await expectLater(
        databaseDirectoryFor(TargetPlatform.iOS)!(),
        throwsStateError,
      );
      expect(calls, hasLength(1));
    },
  );
}
