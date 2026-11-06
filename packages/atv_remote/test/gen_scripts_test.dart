import 'dart:io';

import 'package:test/test.dart';

String _script(String name) => File('../../tool/$name').readAsStringSync();

void main() {
  test('gen_scripts_record_the_protoc_release_and_plugin_version', () {
    final ps1 = _script('gen_proto.ps1');
    final sh = _script('gen_proto.sh');
    for (final (name, script) in [('ps1', ps1), ('sh', sh)]) {
      expect(script, contains('36.2'), reason: name);
      expect(script, contains('releases/tag/v36.2'), reason: name);
      expect(script, contains('protoc_plugin 25.1.0'), reason: name);
    }
    expect(ps1, contains('protoc-36.2-win64.zip'));
    expect(sh, contains('protoc-36.2-linux-x86_64.zip'));
    expect(sh, contains('protoc-36.2-osx-universal_binary.zip'));
  });

  test('gen_scripts_warn_on_another_protoc_version', () {
    for (final name in ['gen_proto.ps1', 'gen_proto.sh']) {
      final script = _script(name);
      expect(script, contains('--version'), reason: name);
      expect(script, contains('libprotoc 36.2'), reason: name);
      expect(
        script,
        contains('the generated code was made with libprotoc 36.2'),
        reason: name,
      );
    }
  });
}
