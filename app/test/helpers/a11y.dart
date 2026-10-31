import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Checks what is on screen against Flutter's four accessibility guidelines,
/// in this order: text contrast, the Android (48 dp) and iOS (44 pt) tap
/// targets, and labelled tap targets. Semantics must be on (see
/// [withSemantics]).
Future<void> expectMeetsGuidelines(
  WidgetTester t, {
  required String reason,
}) async {
  for (final (name, guideline) in [
    ('text contrast', textContrastGuideline),
    ('Android tap targets', androidTapTargetGuideline),
    ('iOS tap targets', iOSTapTargetGuideline),
    ('labelled tap targets', labeledTapTargetGuideline),
  ]) {
    await expectLater(
      t,
      meetsGuideline(guideline),
      reason: '$reason: $name',
    );
  }
}

/// Runs [body] with semantics on and releases the handle however it ends.
///
/// The framework checks for live handles before any tear-down runs, so
/// `addTearDown(handle.dispose)` would come too late (learnings, Phase 6).
Future<T> withSemantics<T>(
  WidgetTester t,
  Future<T> Function() body,
) async {
  final handle = t.ensureSemantics();
  try {
    return await body();
  } finally {
    handle.dispose();
  }
}

/// Nothing overflowed or threw while the screen was laid out: a clipped
/// `RenderFlex` reports itself as an exception.
void expectNoClipping(WidgetTester t, {required String reason}) {
  expect(t.takeException(), isNull, reason: reason);
}

/// Every node of the semantics tree, depth first from the root of the
/// test's view. Semantics must be on.
List<SemanticsNode> allSemanticsNodes(WidgetTester t) {
  final nodes = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    nodes.add(node);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(t.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
  return nodes;
}
