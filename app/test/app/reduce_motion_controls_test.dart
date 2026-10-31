import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/router.dart';

import '../helpers/ink_features.dart';
import '../helpers/pump_router_app.dart';

/// One 60 Hz frame.
const _frame = Duration(milliseconds: 16);

/// How far the toggle (switch thumb or radio dot) inside [f] has moved
/// towards "on": 0 is off, 1 is on.
double _togglePosition(WidgetTester t, Finder f) => find
    .descendant(of: f, matching: find.byWidgetPredicate((_) => true))
    .evaluate()
    .whereType<StatefulElement>()
    .map((e) => e.state)
    .whereType<ToggleableStateMixin>()
    .single
    .position
    .value;

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
    expect(_togglePosition(t, haptics), 1, reason: 'haptics start on');
  }

  testWidgets('switch_settles_within_one_frame', (t) async {
    reduceMotionFromThePlatform(t);
    await pumpRemoteBehaviour(t);
    await _tapAndDrawTheStartFrame(t, haptics);
    expect(_togglePosition(t, haptics), 1, reason: 'drawn at its start');
    await frameDone(t, 'the switch');
    expect(_togglePosition(t, haptics), 0, reason: 'the thumb is at off');
  });

  testWidgets('radio_settles_within_one_frame', (t) async {
    reduceMotionFromThePlatform(t);
    await pumpRouterApp(t, initialLocation: AppRoutes.settingsAppearance);
    final dark = find.ancestor(
      of: find.text('Dark'),
      matching: find.byWidgetPredicate((w) => w is RadioListTile),
    );
    expect(_togglePosition(t, dark), 0, reason: 'Dark starts unchosen');
    await _tapAndDrawTheStartFrame(t, dark);
    expect(_togglePosition(t, dark), 0, reason: 'drawn at its start');
    await frameDone(t, 'the radio');
    expect(_togglePosition(t, dark), 1, reason: 'the dot is in');
  });

  testWidgets('text_field_focus_settles_within_one_frame', (t) async {
    reduceMotionFromThePlatform(t);
    await pumpRouterApp(t, initialLocation: AppRoutes.apps);
    await _tapAndDrawTheStartFrame(t, find.byType(TextField));
    expect(
      t.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    // The label floats up and the border thickens.
    expect(t.hasRunningAnimations, isTrue, reason: 'the focus transition');
    await frameDone(t, 'the search field');
  });

  testWidgets('with_motion_the_switch_animates', (t) async {
    await pumpRemoteBehaviour(t);
    await _tapAndDrawTheStartFrame(t, haptics);
    await t.pump(_frame);
    // The thumb is still on its way: these tests can see motion.
    expect(t.hasRunningAnimations, isTrue);
    expect(_togglePosition(t, haptics), inExclusiveRange(0, 1));
  });
}
