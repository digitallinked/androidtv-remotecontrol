import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A one-line label that shrinks to fit a narrow space, but never below the
/// size it has at 100% text.
///
/// At 100% it doesn't shrink at all. With larger text it shrinks at most
/// back to its 100% size; past that it ends in an ellipsis, like a long TV
/// name does. A plain `FittedBox` would shrink large text below the size
/// the user asked to make bigger (Phase 2 carry-over).
///
/// It reports intrinsic sizes, so it works inside a `SegmentedButton`.
class FittedLabel extends StatelessWidget {
  /// Creates a label for [text] in [style] (merged over the ambient
  /// `DefaultTextStyle`).
  const FittedLabel(this.text, {this.style, super.key});

  /// The label.
  final String text;

  /// Its style; `null` keeps the ambient one.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style).fontSize ?? 14;
    final growth = MediaQuery.textScalerOf(context).scale(base) / base;
    return _MinScaleFit(
      minScale: growth > 1 ? 1 / growth : 1,
      child: Text(
        text,
        style: style,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Scales its child down to fit, centred, but never below [minScale]: the
/// child is laid out at most `maxWidth / minScale` wide, so what doesn't fit
/// then is the child's to cut (with an ellipsis).
class _MinScaleFit extends SingleChildRenderObjectWidget {
  const _MinScaleFit({required this.minScale, required super.child});

  final double minScale;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMinScaleFit(minScale);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMinScaleFit renderObject,
  ) => renderObject.minScale = minScale;
}

class _RenderMinScaleFit extends RenderProxyBox {
  _RenderMinScaleFit(this._minScale);

  double _minScale;
  double get minScale => _minScale;
  set minScale(double value) {
    if (value == _minScale) return;
    _minScale = value;
    markNeedsLayout();
  }

  Matrix4 _transform = Matrix4.identity();
  double _scale = 1;

  BoxConstraints _childConstraints(BoxConstraints c) => BoxConstraints(
    maxWidth: c.hasBoundedWidth ? c.maxWidth / _minScale : double.infinity,
  );

  double _scaleFor(BoxConstraints c, Size child) {
    var scale = 1.0;
    if (c.hasBoundedWidth && child.width > c.maxWidth) {
      scale = c.maxWidth / child.width;
    }
    if (c.hasBoundedHeight && child.height * scale > c.maxHeight) {
      scale = c.maxHeight / child.height;
    }
    return math.max(scale, _minScale);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    final size = child.getDryLayout(_childConstraints(constraints));
    return constraints.constrain(size * _scaleFor(constraints, size));
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_childConstraints(constraints), parentUsesSize: true);
    _scale = _scaleFor(constraints, child.size);
    final scaled = child.size * _scale;
    size = constraints.constrain(scaled);
    _transform = Matrix4.identity()
      ..translateByDouble(
        (size.width - scaled.width) / 2,
        (size.height - scaled.height) / 2,
        0,
        1,
      )
      ..scaleByDouble(_scale, _scale, 1, 1);
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      (child?.getMinIntrinsicWidth(height) ?? 0) * _minScale;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      child?.getMaxIntrinsicWidth(height) ?? 0;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      (context, offset) => context.paintChild(child, offset),
      oldLayer: layer as TransformLayer?,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.multiply(_transform);
}
