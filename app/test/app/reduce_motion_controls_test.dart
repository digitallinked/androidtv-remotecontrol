import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';

import '../helpers/ink_features.dart';
import '../helpers/pump_router_app.dart';
import '../helpers/toggle_position.dart';

/// One 60 Hz frame.
const _frame = Duration(milliseconds: 16);

/// Taps [f] and draws the frame that handles the tap. A transition starts in
/// that frame and is drawn at its start, so the test can then check what the
/// next frame shows.
Future<void> _tapAndDrawTheStartFrame(WidgetTester t, Finder f) async {
  await t.tap(f);
  await t.pump();
}

/// Ruling P8-R7: under the platform's reduce-motion flag (Remove animations
/// on Android, Reduce Motion on iOS) Flutter scales every default
/// `AnimationController` by 0.05, so a control's transition is over by the
/// next 60 Hz frame and no in-between position is ever drawn. These tests
/// prove it for the three controls decision #47 deferred.
void main() {
  /// Turns on the platform flag for the rest of the test.
  void reduceMotionFromThePlatform(WidgetTester t) {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  /// Draws the next frame and checks that nothing is still moving. The
  /// rows' ink is transparent under reduce motion, and its fade isn't motion
  /// anyone can see (decision #47).
  Future<void> frameDone(WidgetTester t, String what) async {
    await t.pump(_frame);
    expectNoVisibleInk(t, what);
    expect(t.hasRunningAnimations, isFalse, reason: '$what still moves');
  }

  final haptics = find.widgetWithText(SwitchListTile, 'Vibrate on key press');

  Future<void> pumpRemoteBehaviour(WidgetTester t) async {
    await pumpRouterApp(t, initialLocation: AppRoutes.settingsRemoteBehaviour);
    expect(togglePosition(t, haptics), 1, reason: 'haptics start on');
  }

  testWidgets('switch_settles_within_one_frame', (t) async {
    reduceMotionFromThePlatform(t);
    await pumpRemoteBehaviour(t);
    await _tapAndDrawTheStartFrame(t, haptics);
    expect(togglePosition(t, haptics), 1, reason: 'drawn at its start');
    await frameDone(t, 'the switch');
    expect(togglePosition(t, haptics), 0, reason: 'the thumb is at off');
  });

  final dark = find.ancestor(
    of: find.text('Dark'),
    matching: find.byWidgetPredicate((w) => w is RadioListTile),
  );

  testWidgets('radio_settles_within_one_frame', (t) async {
    reduceMotionFromThePlatform(t);
    await pumpRouterApp(t, initialLocation: AppRoutes.settingsAppearance);
    expect(togglePosition(t, dark), 0, reason: 'Dark starts unchosen');
    await _tapAndDrawTheStartFrame(t, dark);
    expect(togglePosition(t, dark), 0, reason: 'drawn at its start');
    await frameDone(t, 'the radio');
    expect(togglePosition(t, dark), 1, reason: 'the dot is in');
  });

  testWidgets('text_field_focus_settles_within_one_frame', (t) async {
    reduceMotionFromThePlatform(t);
    await pumpRouterApp(t, initialLocation: AppRoutes.apps);
    final resting = _labelTop(t);
    await _tapAndDrawTheStartFrame(t, find.byType(TextField));
    expect(
      t.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    // The label floats up and the border thickens.
    expect(t.hasRunningAnimations, isTrue, reason: 'the focus transition');
    await frameDone(t, 'the search field');
    // And it ended where focus puts it: the label floated up to the border,
    // exactly where it rests once everything has settled.
    final floated = _labelTop(t);
    expect(floated, lessThan(resting - 8));
    await t.pumpAndSettle();
    expect(_labelTop(t), floated);
  });

  testWidgets('with_motion_the_switch_animates', (t) async {
    await pumpRemoteBehaviour(t);
    await _tapAndDrawTheStartFrame(t, haptics);
    await t.pump(_frame);
    // The thumb is still on its way: these tests can see motion.
    expect(t.hasRunningAnimations, isTrue);
    expect(togglePosition(t, haptics), inExclusiveRange(0, 1));
  });

  testWidgets('with_motion_the_radio_animates', (t) async {
    await pumpRouterApp(t, initialLocation: AppRoutes.settingsAppearance);
    await _tapAndDrawTheStartFrame(t, dark);
    await t.pump(_frame);
    expect(t.hasRunningAnimations, isTrue);
    expect(togglePosition(t, dark), inExclusiveRange(0, 1));
  });

  testWidgets('with_motion_the_text_field_focus_animates', (t) async {
    await pumpRouterApp(t, initialLocation: AppRoutes.apps);
    final resting = _labelTop(t);
    await _tapAndDrawTheStartFrame(t, find.byType(TextField));
    await t.pump(_frame);
    // The decorator's 167 ms transition is still on its way: the label is
    // between where it rests and where it floats.
    expect(t.hasRunningAnimations, isTrue);
    final moving = _labelTop(t);
    await t.pumpAndSettle();
    expect(moving, lessThan(resting));
    expect(moving, greaterThan(_labelTop(t)));
  });
}

/// The top of the Apps search field's label, which floats up on focus.
double _labelTop(WidgetTester t) => t.getRect(find.text('Search apps')).top;
