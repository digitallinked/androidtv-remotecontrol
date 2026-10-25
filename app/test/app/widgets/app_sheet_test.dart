import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_sheet.dart';

import '../../helpers/pump_app.dart';

class _Opener extends StatelessWidget {
  const _Opener({required this.onResult, required this.body});

  final void Function(String?) onResult;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () async {
        final r = await showAppSheet<String>(
          context: context,
          title: 'Sheet title',
          builder: (_) => body,
        );
        onResult(r);
      },
      child: const Text('open'),
    );
  }
}

Future<void> _open(
  WidgetTester t,
  void Function(String?) onResult, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Widget body = const Text('Sheet body'),
}) async {
  await pumpApp(
    t,
    _Opener(onResult: onResult, body: body),
    brightness: brightness,
    textScale: textScale,
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('close_button_pops_with_null', (t) async {
    String? result = 'unset';
    await _open(t, (r) => result = r);
    expect(find.text('Sheet title'), findsOneWidget);
    expect(find.text('Sheet body'), findsOneWidget);
    final size = t.getSize(find.byTooltip('Close'));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle();
    expect(find.text('Sheet title'), findsNothing);
    expect(result, isNull);
  });

  testWidgets('swipe_down_dismisses', (t) async {
    await _open(t, (_) {});
    await t.fling(find.text('Sheet title'), const Offset(0, 600), 2000);
    await t.pumpAndSettle();
    expect(find.text('Sheet title'), findsNothing);
  });

  for (final b in Brightness.values) {
    testWidgets('sheet_has_28dp_top_radius_and_surface_colour_${b.name}', (
      t,
    ) async {
      await _open(t, (_) {}, brightness: b);
      final sheet = t.widget<BottomSheet>(find.byType(BottomSheet));
      final theme = Theme.of(t.element(find.byType(BottomSheet)));
      final shape = sheet.shape ?? theme.bottomSheetTheme.shape;
      expect(
        shape,
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
      );
      final colours = b == Brightness.dark ? AppColors.dark : AppColors.light;
      expect(
        sheet.backgroundColor ?? theme.bottomSheetTheme.backgroundColor,
        colours.surface,
      );
    });
  }

  testWidgets('app_sheet_reflows_at_200_percent_text', (t) async {
    await _open(
      t,
      (_) {},
      textScale: 2,
      body: Column(
        children: [for (var i = 0; i < 40; i++) Text('Line $i of content')],
      ),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('sheet_body_stays_above_the_keyboard', (t) async {
    // Physical pixels: 300 logical.
    t.view.viewInsets = FakeViewPadding(bottom: 300 * t.view.devicePixelRatio);
    addTearDown(t.view.resetViewInsets);
    await _open(t, (_) {}, body: const TextField());

    final screenBottom = t.view.physicalSize.height / t.view.devicePixelRatio;
    expect(
      t.getBottomLeft(find.byType(TextField)).dy,
      lessThanOrEqualTo(screenBottom - 300),
    );
  });
}
