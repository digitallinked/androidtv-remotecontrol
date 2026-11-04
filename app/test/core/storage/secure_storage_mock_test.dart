import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// `flutter_test_config.dart` gives every test an empty in-memory secure
/// storage, so nothing one test writes is seen by the next (review Minor 3).
/// The two tests run in order: the first writes, the second must not see it.
void main() {
  const storage = FlutterSecureStorage();

  test('a_test_writes_to_secure_storage', () async {
    await storage.write(key: 'leak', value: 'from the first test');
    expect(await storage.read(key: 'leak'), 'from the first test');
  });

  test('the_next_test_starts_with_empty_secure_storage', () async {
    expect(await storage.read(key: 'leak'), isNull);
  });
}
