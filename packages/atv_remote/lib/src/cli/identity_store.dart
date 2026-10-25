import 'dart:convert';
import 'dart:io';

import 'package:atv_remote/src/identity.dart';

/// Where the CLI keeps its client identity: `<home>/.atv_cli/identity.json`.
///
/// [home] defaults to `USERPROFILE` on Windows and `HOME` elsewhere.
File cliIdentityFile({String? home, Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  final base = home ?? (Platform.isWindows ? env['USERPROFILE'] : env['HOME']);
  if (base == null || base.isEmpty) {
    throw StateError('Cannot find the home directory (USERPROFILE / HOME).');
  }
  final sep = Platform.pathSeparator;
  return File('$base$sep.atv_cli${sep}identity.json');
}

/// Loads the identity stored in [file], creating and saving a new one when
/// the file does not exist.
///
/// A file that exists but cannot be parsed is an error (never overwritten):
/// replacing it would silently un-pair every TV.
Future<ClientIdentity> loadOrCreateIdentity(File file) async {
  if (file.existsSync()) {
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return ClientIdentity.fromPem(
      certificatePem: json['certificatePem'] as String,
      privateKeyPem: json['privateKeyPem'] as String,
    );
  }
  final identity = ClientIdentity.generate(commonName: 'atv_cli');
  await file.parent.create(recursive: true);
  await file.writeAsString(
    jsonEncode({
      'certificatePem': identity.certificatePem,
      'privateKeyPem': identity.privateKeyPem,
    }),
  );
  return identity;
}
