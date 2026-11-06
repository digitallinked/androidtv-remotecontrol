import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// R8 only runs in release builds, and nothing on the host runs one, so a rule
/// lost here shows up as a crash on launch on a phone (decision #55).
void main() {
  test('room_keeps_the_constructor_it_creates_its_database_with', () {
    final rules = File('android/app/proguard-rules.pro').readAsStringSync();
    expect(
      rules,
      matches(
        RegExp(
          r'-keep class \* extends androidx\.room\.RoomDatabase \{\s*'
          r'<init>\(\);\s*\}',
        ),
      ),
    );
  });
}
