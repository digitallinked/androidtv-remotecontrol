import 'dart:convert';
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

    test('parses_enter_and_delete', () {
      expect(parseKeyName('Enter'), 66);
      expect(parseKeyName('delete'), 67);
    });

    test('lists the valid names', () {
      expect(validKeyNames(), contains('volumeup'));
    });
  });

  group('parseHoldMillis', () {
    test('parses_hold_millis_in_range', () {
      expect(parseHoldMillis('800'), 800);
      expect(parseHoldMillis('1'), 1);
      expect(parseHoldMillis('30000'), 30000);
      for (final raw in ['0', '-1', 'abc', '30001', '', '1.5']) {
        expect(parseHoldMillis(raw), isNull, reason: raw);
      }
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

    test('a_failed_write_never_leaves_a_partial_identity', () async {
      final file = cliIdentityFile(home: dir.path);

      await expectLater(
        loadOrCreateIdentity(
          file,
          writeFile: (tmp, contents) async {
            await tmp.writeAsString(
              contents.substring(0, contents.length ~/ 2),
            );
            throw const FileSystemException('disk full');
          },
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(file.existsSync(), isFalse);
    });

    test('a_leftover_temp_file_is_replaced', () async {
      final file = cliIdentityFile(home: dir.path);
      final tmp = File('${file.path}.tmp')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('stale half-written identity');

      final created = await loadOrCreateIdentity(file);

      expect(tmp.existsSync(), isFalse);
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(json['certificatePem'], created.certificatePem);
      expect(json['privateKeyPem'], created.privateKeyPem);
    });

    test('an_existing_identity_is_never_rewritten', () async {
      final file = cliIdentityFile(home: dir.path);
      final created = await loadOrCreateIdentity(file);
      final before = file.readAsStringSync();
      var writes = 0;

      final loaded = await loadOrCreateIdentity(
        file,
        writeFile: (tmp, contents) async => writes++,
      );

      expect(writes, 0);
      expect(loaded.publicParts.modulus, created.publicParts.modulus);
      expect(file.readAsStringSync(), before);
    });
  });
}
