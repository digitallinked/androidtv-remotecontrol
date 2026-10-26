import 'package:flutter/widgets.dart';
import 'package:tv_remote/features/demo/presentation/demo_badge.dart';

/// The `MaterialApp.router` builder: everything that sits around every
/// screen. Today that is the demo-mode strip.
Widget buildAppShell(BuildContext context, Widget? child) =>
    DemoBadgeOverlay(child: child ?? const SizedBox.shrink());
