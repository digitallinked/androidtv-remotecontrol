// Renders the release documents with the owner's values (Ruling P9-R11).
//
// Run from `app/`:
//
//   dart tool/fill_release_docs.dart [--allow-missing] [--root <repo>]
//
// Every `docs/release/**/*.md` is copied to `<root>/build/release-docs/`
// (git-ignored) with each `{{TOKEN}}` replaced by its value from
// `docs/release/placeholders.json`. The documents in `docs/` are never
// changed. A token without a usable value stays as `{{TOKEN}}` and is listed;
// the script then exits 1 unless `--allow-missing` is given.
import 'dart:convert';
import 'dart:io';

/// What [fillReleaseDocs] did.
final class FillResult {
  /// Creates a result.
  const FillResult({required this.written, required this.missing});

  /// The rendered files, sorted by path, all under the output directory.
  final List<File> written;

  /// The tokens used in some document that were left unfilled: no value
  /// (`null`), a value the release check refuses, or no entry at all.
  final Set<String> missing;
}

/// A `{{...}}` token; the name is trimmed, so `{{ A }}` means `A`.
final RegExp _token = RegExp(r'\{\{([^{}]*)\}\}');

/// Whether [value] is one of today's placeholders, which the release check
/// refuses (`placeholder-links`, `app-store-id`): an `example.com` address,
/// or an App Store id of only zeros. Such a value is never written into a
/// rendered document; its token stays and is listed as missing.
bool isPlaceholderValue(String value) =>
    value.contains('example.com') || RegExp(r'^0+$').hasMatch(value);

/// Renders every `docs/release/**/*.md` under [root] into [out], keeping the
/// relative paths, with the values of `docs/release/placeholders.json`.
///
/// [out] is emptied first, so running twice gives the same tree and a
/// document that was removed leaves no stale copy. Throws an
/// [ArgumentError] when [out] is [root], contains it, or lies inside
/// `<root>/docs`.
Future<FillResult> fillReleaseDocs({
  required Directory root,
  required Directory out,
}) async {
  final rootUri = _dirUri(root);
  final docsUri = rootUri.resolve('docs/');
  final outUri = _dirUri(out);
  if (_within(rootUri, outUri)) {
    throw ArgumentError.value(out.path, 'out', 'must not contain the repo');
  }
  if (_within(outUri, docsUri)) {
    throw ArgumentError.value(out.path, 'out', 'must not be inside docs/');
  }

  final releaseUri = docsUri.resolve('release/');
  final values = _usableValues(
    File.fromUri(releaseUri.resolve('placeholders.json')),
  );

  final outDir = Directory.fromUri(outUri);
  if (outDir.existsSync()) outDir.deleteSync(recursive: true);

  final docs =
      Directory.fromUri(releaseUri)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final written = <File>[];
  final missing = <String>{};
  for (final doc in docs) {
    // listSync builds each path on the release directory's, so the prefix
    // matches exactly.
    final relative = doc.absolute.uri.normalizePath().path.substring(
      releaseUri.path.length,
    );
    final text = doc.readAsStringSync().replaceAllMapped(_token, (m) {
      final name = m[1]!.trim();
      final value = values[name];
      if (value != null) return value;
      missing.add(name);
      return m[0]!;
    });
    final target = File.fromUri(outUri.resolve(relative));
    target.parent.createSync(recursive: true);
    target.writeAsStringSync(text);
    written.add(target);
  }
  return FillResult(written: written, missing: missing);
}

/// The tokens of [file] whose value can go into a document.
Map<String, String> _usableValues(File file) {
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw FormatException('${file.path} is not a JSON object.');
  }
  return {
    for (final MapEntry(:key, :value) in decoded.entries)
      if (value case {'value': final String v} when !isPlaceholderValue(v))
        key: v,
  };
}

/// [dir] as an absolute, normalised directory URI (ending in `/`).
Uri _dirUri(Directory dir) {
  final uri = dir.absolute.uri.normalizePath();
  return uri.path.endsWith('/') ? uri : uri.replace(path: '${uri.path}/');
}

/// Whether directory [inner] is [outer] or lies inside it. Windows paths
/// compare without case.
bool _within(Uri inner, Uri outer) {
  var a = inner.path;
  var b = outer.path;
  if (Platform.isWindows) {
    a = a.toLowerCase();
    b = b.toLowerCase();
  }
  return a.startsWith(b);
}

const _usage =
    'Usage: dart tool/fill_release_docs.dart [--allow-missing] '
    '[--root <repo>]';

/// Renders the documents into `<root>/build/release-docs/`. Exit code 0
/// when every used token was filled (or `--allow-missing`), 1 when some
/// were not, 64 for bad arguments.
Future<void> main(List<String> args) async {
  var allowMissing = false;
  String? rootPath;
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--allow-missing') {
      allowMissing = true;
    } else if (arg == '--root' && i + 1 < args.length) {
      rootPath = args[++i];
    } else {
      stderr
        ..writeln('Unexpected argument "$arg".')
        ..writeln(_usage);
      exitCode = 64;
      return;
    }
  }
  final root = rootPath != null
      ? Directory(rootPath).absolute
      : File.fromUri(Platform.script).parent.parent.parent;
  final out = Directory.fromUri(_dirUri(root).resolve('build/release-docs/'));
  final result = await fillReleaseDocs(root: root, out: out);
  stdout.writeln(
    'Wrote ${result.written.length} document(s) to ${out.path}.',
  );
  if (result.missing.isEmpty) {
    stdout.writeln('Every token was filled.');
    exitCode = 0;
    return;
  }
  final names = result.missing.toList()..sort();
  stdout.writeln(
    'Unfilled tokens (set them in docs/release/placeholders.json):',
  );
  for (final name in names) {
    stdout.writeln('  $name');
  }
  if (allowMissing) {
    stdout.writeln('--allow-missing: the documents keep these tokens.');
    exitCode = 0;
  } else {
    stdout.writeln('${names.length} token(s) unfilled.');
    exitCode = 1;
  }
}
