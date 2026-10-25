import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/main.dart';

void main() {
  testWidgets('shows the placeholder title', (tester) async {
    await tester.pumpWidget(const TvRemoteApp());

    expect(find.text('TV Remote'), findsOneWidget);
  });
}
