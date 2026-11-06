import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/widgets/scroll_when_short.dart';

void main() {
  testWidgets('the_child_keeps_its_state_when_the_height_crosses_the_minimum', (
    t,
  ) async {
    final pages = PageController();
    addTearDown(pages.dispose);
    Future<void> pumpAt(double height) => t.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: height,
            child: ScrollWhenShort(
              minHeight: 480,
              child: PageView(
                controller: pages,
                children: const [Text('first'), Text('second')],
              ),
            ),
          ),
        ),
      ),
    );

    await pumpAt(600);
    expect(find.byType(SingleChildScrollView), findsNothing);
    pages.jumpToPage(1);
    await t.pump();
    expect(find.text('second'), findsOneWidget);

    // Squeezed below the minimum: it scrolls, on the same page.
    await pumpAt(400);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('second'), findsOneWidget);
    expect(find.text('first'), findsNothing);

    // And back.
    await pumpAt(600);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.text('second'), findsOneWidget);
  });
}
