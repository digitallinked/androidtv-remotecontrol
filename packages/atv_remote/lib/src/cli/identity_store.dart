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

/// Writes [contents] to [file] and flushes it to disk before returning.
Future<void> writeFlushed(File file, String contents) async {
  await file.writeAsString(contents, flush: true);
}

/// Loads the identity stored in [file], creating and saving a new one when
/// the file does not exist.
///
/// A file that exists but cannot be parsed is an error (never overwritten):
/// replacing it would silently un-pair every TV. An existing file is never
/// written to.
///
/// A new identity is written atomically: [writeFile] writes `<file>.tmp`
/// (replacing any leftover one), which is then renamed onto [file]. A write
/// that fails, or is cut short, never leaves a partial [file] behind.
Future<ClientIdentity> loadOrCreateIdentity(
  File file, {
  Future<void> Function(File file, String contents) writeFile = writeFlushed,
}) async {
  if (file.existsSync()) return _readIdentity(file);
  final identity = ClientIdentity.generate(commonName: 'atv_cli');
  await file.parent.create(recursive: true);
  final tmp = File('${file.path}.tmp');
  try {
    await writeFile(
      tmp,
      jsonEncode({
        'certificatePem': identity.certificatePem,
        'privateKeyPem': identity.privateKeyPem,
      }),
    );
  } on Object {
    if (tmp.existsSync()) await tmp.delete();
    rethrow;
  }
  try {
    await tmp.rename(file.path);
  } on FileSystemException {
    // Some Windows setups can't rename onto an existing file. If another
    // process created it after our check, keep theirs and never overwrite it.
    if (!file.existsSync()) rethrow;
    await tmp.delete();
    return _readIdentity(file);
  }
  return identity;
}

Future<ClientIdentity> _readIdentity(File file) async {
  final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  return ClientIdentity.fromPem(
    certificatePem: json['certificatePem'] as String,
    privateKeyPem: json['privateKeyPem'] as String,
  );
}
