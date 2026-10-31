import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// How far the one toggle (switch thumb or radio dot) inside [f] has moved
/// towards "on": 0 is off, 1 is on, in between while it animates.
double togglePosition(WidgetTester t, Finder f) => find
    .descendant(of: f, matching: find.byWidgetPredicate((_) => true))
    .evaluate()
    .whereType<StatefulElement>()
    .map((e) => e.state)
    .whereType<ToggleableStateMixin>()
    .single
    .position
    .value;
