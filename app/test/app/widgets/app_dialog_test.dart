import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/app/widgets/app_dialog.dart';

import '../../helpers/a11y.dart';
import '../../helpers/pump_app.dart';

const _actions = [
  AppDialogAction<String>(label: 'Cancel', value: 'c'),
  AppDialogAction<String>(label: 'Delete', value: 'd', isDestructive: true),
];

class _Opener extends StatelessWidget {
  const _Opener({
    required this.onResult,
    required this.title,
    required this.message,
    required this.actions,
  });

  final void Function(String?) onResult;
  final String title;
  final String message;
  final List<AppDialogAction<String>> actions;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () async {
        final r = await showAppDialog<String>(
          context: context,
          title: title,
          message: message,
          actions: actions,
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
  String title = 'Remove TV',
  String message = 'This forgets the TV.',
  List<AppDialogAction<String>> actions = _actions,
}) async {
  await pumpApp(
    t,
    _Opener(
      onResult: onResult,
      title: title,
      message: message,
      actions: actions,
    ),
    brightness: brightness,
    textScale: textScale,
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('returns_tapped_action_value', (t) async {
    String? result = 'unset';
    await _open(t, (r) => result = r);
    expect(find.text('Remove TV'), findsOneWidget);
    expect(find.text('This forgets the TV.'), findsOneWidget);
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();
    expect(result, 'd');
    expect(find.byType(AppDialog<String>), findsNothing);
  });

  testWidgets('barrier_dismiss_returns_null', (t) async {
    String? result = 'unset';
    await _open(t, (r) => result = r);
    await t.tapAt(const Offset(5, 5));
    await t.pumpAndSettle();
    expect(result, isNull);
    expect(find.byType(AppDialog<String>), findsNothing);
  });

  testWidgets('dark_dialog_uses_surface_token_not_white', (t) async {
    await _open(t, (_) {}, brightness: Brightness.dark);
    final m = t.widget<Material>(
      find
          .descendant(
            of: find.byType(AppDialog<String>),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(m.color, AppColors.dark.surface);
  });

  testWidgets('destructive_action_uses_danger_text_colour', (t) async {
    await _open(t, (_) {});
    final colour = t
        .widget<TextButton>(find.widgetWithText(TextButton, 'Delete'))
        .style!
        .foregroundColor!
        .resolve({});
    expect(colour, AppColors.light.dangerText);
  });

  testWidgets('primary_action_is_a_filled_button', (t) async {
    await _open(
      t,
      (_) {},
      actions: const [
        AppDialogAction<String>(label: 'Cancel', value: 'c'),
        AppDialogAction<String>(label: 'Pair', value: 'p', isPrimary: true),
      ],
    );
    expect(find.widgetWithText(FilledButton, 'Pair'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
  });

  testWidgets('app_dialog_reflows_at_200_percent_text', (t) async {
    await _open(
      t,
      (_) {},
      textScale: 2,
      title: 'A rather long dialog title that must wrap onto several lines',
      message:
          'A long message that explains what will happen when the user '
          'confirms this action, long enough to wrap many times at 200%.',
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('dialog_names_its_route_with_the_title', (t) async {
    final handle = t.ensureSemantics();
    try {
      await _open(t, (_) {});
      final named = allSemanticsNodes(t).where((n) {
        final flags = n.getSemanticsData().flagsCollection;
        return flags.scopesRoute && flags.namesRoute;
      }).toList();
      expect(named, hasLength(1));
      expect(named.single.label, 'Remove TV');
      // The title and the message are still read as their own lines.
      expect(find.bySemanticsLabel('This forgets the TV.'), findsOneWidget);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('dialog_body_is_at_least_288dp_wide_on_a_320dp_screen', (
    t,
  ) async {
    t.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await _open(t, (_) {}, textScale: 2);
    final surface = find
        .descendant(
          of: find.byType(AppDialog<String>),
          matching: find.byType(Material),
        )
        .first;
    expect(t.getSize(surface).width, greaterThanOrEqualTo(288));
    expect(t.getRect(surface).left, greaterThanOrEqualTo(16));
    expect(t.getRect(surface).right, lessThanOrEqualTo(320 - 16));
    expect(t.takeException(), isNull);
  });

  testWidgets('wide_screens_keep_the_40dp_dialog_inset', (t) async {
    t.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await _open(t, (_) {});
    final surface = find
        .descendant(
          of: find.byType(AppDialog<String>),
          matching: find.byType(Material),
        )
        .first;
    expect(t.getRect(surface).left, 40);
    expect(t.getRect(surface).right, 390 - 40);
  });

  testWidgets('reduce_motion_opens_and_closes_the_dialog_in_one_frame', (
    t,
  ) async {
    await pumpApp(
      t,
      const _Opener(
        onResult: _ignore,
        title: 'Remove TV',
        message: 'This forgets the TV.',
        actions: _actions,
      ),
      disableAnimations: true,
    );
    await t.tap(find.text('open'));
    await t.pump();
    final dialog = find.byType(AppDialog<String>);
    expect(dialog, findsOneWidget);
    expect(ModalRoute.of(t.element(dialog))!.animation!.value, 1);
    expect(t.hasRunningAnimations, isFalse);

    await t.tap(find.text('Cancel'));
    await t.pump();
    expect(dialog, findsNothing);
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('with_motion_the_dialog_animates_in', (t) async {
    await pumpApp(
      t,
      const _Opener(
        onResult: _ignore,
        title: 'Remove TV',
        message: 'This forgets the TV.',
        actions: _actions,
      ),
    );
    await t.tap(find.text('open'));
    await t.pump();
    final dialog = find.byType(AppDialog<String>);
    expect(dialog, findsOneWidget);
    expect(ModalRoute.of(t.element(dialog))!.animation!.value, lessThan(1));
    expect(t.hasRunningAnimations, isTrue);
    await t.pumpAndSettle();
    expect(ModalRoute.of(t.element(dialog))!.animation!.value, 1);
  });
}

void _ignore(String? _) {}
