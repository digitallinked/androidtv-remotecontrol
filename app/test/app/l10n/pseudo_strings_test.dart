import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pseudo_localizations.dart';

// Apart from pseudo_localizations_test.dart, which generates the helper: a
// stale helper that no longer compiles fails here, and the generator can
// still rewrite it (`--update-goldens`).
void main() {
  test('pseudo_expands_and_marks_every_message', () {
    expect(pseudo('Next'), '⟦Ñéxt··⟧');
    final moved = PseudoLocalizations().manageAppsMoved('Netflix', 2, 5);
    expect(moved, contains('Netflix'));
    expect(moved, contains('2'));
    expect(moved, contains('5'));
    expect(moved, startsWith('⟦'));
    expect(moved, endsWith('⟧'));
    expect(PseudoLocalizations().statusConnected, pseudo('Connected'));
  });
}
