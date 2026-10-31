import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/device/modal_route_tracker.dart';

/// A popup route that is never shown: the tracker only looks at its type.
class _Popup extends PopupRoute<void> {
  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => const SizedBox.shrink();
}

/// A page route, which never counts as a modal.
class _Page extends PageRouteBuilder<void> {
  _Page() : super(pageBuilder: (_, _, _) => const SizedBox.shrink());
}

void main() {
  test('counts_open_popup_routes_only', () {
    final tracker = ModalRouteTracker();
    addTearDown(tracker.dispose);
    var changes = 0;
    tracker.addListener(() => changes++);
    final first = _Popup();
    final second = _Popup();

    tracker.didPush(_Page(), null);
    expect(tracker.modalOpen, isFalse);
    tracker
      ..didPush(first, null)
      ..didPush(second, first);
    expect(tracker.modalOpen, isTrue);
    tracker.didPop(second, first);
    expect(tracker.modalOpen, isTrue);
    tracker.didRemove(first, null);
    expect(tracker.modalOpen, isFalse);
    tracker.didReplace(newRoute: _Popup(), oldRoute: _Page());
    expect(tracker.modalOpen, isTrue);
    // Listeners hear only when "a modal is open" flips.
    expect(changes, 3);
  });

  testWidgets('a_change_during_a_build_is_dropped_once_disposed', (t) async {
    final tracker = ModalRouteTracker();
    var heard = false;
    tracker.addListener(() => heard = true);
    await t.pumpWidget(
      Builder(
        builder: (_) {
          // During a build the tracker waits for the end of the frame to
          // notify; it is disposed before that.
          tracker
            ..didPush(_Popup(), null)
            ..dispose();
          return const SizedBox.shrink();
        },
      ),
    );
    await t.pump();
    expect(t.takeException(), isNull);
    expect(heard, isFalse);
  });
}
