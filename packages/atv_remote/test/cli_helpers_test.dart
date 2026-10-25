import 'dart:io';

import 'package:atv_remote/atv_remote.dart';
import 'package:atv_remote/src/cli/identity_store.dart';
import 'package:atv_remote/src/cli/key_names.dart';
import 'package:test/test.dart';

void main() {
  group('parseKeyName', () {
    test('is case-insensitive', () {
      expect(parseKeyName('home'), KeyCodes.home);
      expect(parseKeyName('DpadUp'), KeyCodes.dpadUp);
      expect(parseKeyName('VOLUMEUP'), KeyCodes.volumeUp);
      expect(parseKeyName('playPause'), KeyCodes.playPause);
    });

    test('maps digits', () {
      expect(parseKeyName('0'), KeyCodes.digit(0));
      expect(parseKeyName('9'), KeyCodes.digit(9));
    });

    test('returns null for unknown names', () {
      expect(parseKeyName('nope'), isNull);
      expect(parseKeyName('10'), isNull);
      expect(parseKeyName(''), isNull);
    });

    test('lists the valid names', () {
      expect(validKeyNames(), contains('volumeup'));
    });
  });

  group('identity store', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('atv_cli_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('creates then reloads the same identity', () async {
      final file = cliIdentityFile(home: dir.path);
      expect(file.path, endsWith('identity.json'));

      final created = await loadOrCreateIdentity(file);
      expect(file.existsSync(), isTrue);
      final loaded = await loadOrCreateIdentity(file);

      expect(loaded.certificatePem, created.certificatePem);
      expect(loaded.privateKeyPem, created.privateKeyPem);
    });

    test('does not overwrite a corrupt file', () async {
      final file = cliIdentityFile(home: dir.path)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('garbage');

      await expectLater(loadOrCreateIdentity(file), throwsA(anything));
      expect(file.readAsStringSync(), 'garbage');
    });
  });
}
