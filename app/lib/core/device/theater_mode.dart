import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/app_theme.dart';
import 'package:tv_remote/core/device/screen_services.dart';

/// Dims the screen after a while without a touch (Ruling P4-R14).
///
/// After [idle] with no touch on [child], the app's brightness drops to
/// [dimLevel] and [child] switches to the extra-dark theater theme. The next
/// touch only wakes the screen: the whole gesture it starts goes to an
/// invisible cover, never to a control underneath.
///
/// The idle timer only runs while [enabled], this page is the current route
/// (an open sheet pauses it), the app is resumed and no screen reader is on.
/// Losing any of that, or leaving the screen, restores the brightness.
class TheaterMode extends ConsumerStatefulWidget {
  /// Creates the Theater Mode scope.
  const TheaterMode({
    required this.enabled,
    required this.child,
    this.idle = const Duration(seconds: 30),
    this.dimLevel = 0.05,
    super.key,
  });

  /// Whether the user switched Theater Mode on (the setting).
  final bool enabled;

  /// The page content.
  final Widget child;

  /// How long without a touch before the screen dims.
  final Duration idle;

  /// The brightness while dimmed, from 0 to 1.
  final double dimLevel;

  @override
  ConsumerState<TheaterMode> createState() => _TheaterModeState();
}

class _TheaterModeState extends ConsumerState<TheaterMode> {
  late final ScreenDimmer _dimmer = ref.read(screenDimmerProvider);
  late final AppLifecycleListener _lifecycle;
  ThemeData? _theaterTheme;

  Timer? _timer;
  bool _dimmed = false;
  bool _resumed = true;
  bool _routeCurrent = true;
  bool _screenReader = false;

  @override
  void initState() {
    super.initState();
    _resumed = _isResumed(WidgetsBinding.instance.lifecycleState);
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _resumed = _isResumed(state);
        // Not in a build: a change may dim or restore, which repaints.
        setState(_update);
      },
    );
  }

  static bool _isResumed(AppLifecycleState? state) =>
      state == null || state == AppLifecycleState.resumed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeCurrent = ModalRoute.isCurrentOf(context) ?? true;
    _screenReader = MediaQuery.accessibleNavigationOf(context);
    _update();
  }

  @override
  void didUpdateWidget(TheaterMode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idle != widget.idle) _stopTimer();
    _update();
  }

  bool get _shouldRun =>
      widget.enabled && _routeCurrent && _resumed && !_screenReader;

  /// Starts or stops the idle timer, and wakes the screen when the run
  /// conditions are gone. Called from builds and callbacks alike, so it never
  /// repaints by itself.
  void _update() {
    if (_shouldRun) {
      if (!_dimmed && _timer == null) _startTimer();
      return;
    }
    _stopTimer();
    if (_dimmed) _wake();
  }

  void _startTimer() {
    _timer = Timer(widget.idle, () {
      _timer = null;
      if (!mounted || !_shouldRun) return;
      setState(() => _dimmed = true);
      unawaited(_dimmer.dim(widget.dimLevel));
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Back to normal brightness and theme. Does not start the timer.
  void _wake() {
    _dimmed = false;
    unawaited(_dimmer.restore());
  }

  /// The wake touch: brighten and start counting again.
  void _onWakeTouch() {
    if (!_dimmed) return;
    setState(() {
      _wake();
      _update();
    });
  }

  /// A touch on the bright screen: the idle time starts over.
  void _onTouch(PointerDownEvent _) {
    if (_timer == null) return;
    _stopTimer();
    _startTimer();
  }

  @override
  void dispose() {
    _stopTimer();
    _lifecycle.dispose();
    if (_dimmed) {
      _dimmed = false;
      unawaited(_dimmer.restore());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The same widgets in the same places whether dimmed or not, so the
    // screen keeps its state across a dim.
    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onTouch,
          child: Theme(
            data: _dimmed
                ? (_theaterTheme ??= buildTheaterTheme())
                : Theme.of(context),
            child: widget.child,
          ),
        ),
        if (_dimmed)
          Positioned.fill(
            child: Semantics(
              container: true,
              label: l10n.theaterWakeLabel,
              onTap: _onWakeTouch,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // Whichever gesture the first touch turns into, it ends here.
                onTapDown: (_) => _onWakeTouch(),
                onPanDown: (_) => _onWakeTouch(),
                onLongPressDown: (_) => _onWakeTouch(),
              ),
            ),
          ),
      ],
    );
  }
}
