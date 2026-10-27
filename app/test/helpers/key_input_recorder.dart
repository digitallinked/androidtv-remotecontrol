import 'package:tv_remote/features/apps/domain/app_entry.dart';
import 'package:tv_remote/features/remote/application/key_input.dart';

/// A [RemoteInput] for widget tests that records what the widgets call.
///
/// While [connected] is false, or when [budget] has run out, `tap`, `launch`
/// and `typeText` record nothing, return false and count in [refused], like
/// `RemoteActions` refusing a command. `holdStart` and `holdEnd` always
/// record: releasing a key is never refused.
class KeyInputRecorder implements RemoteInput {
  /// Whether commands are accepted.
  bool connected = true;

  /// Calls in order: `tap:<code>`, `holdStart:<code>`, `holdEnd:<code>`,
  /// `launch:<package>` and `text:<text>`.
  final List<String> calls = [];

  /// How many commands were refused: while not [connected], or once [budget]
  /// ran out.
  int refused = 0;

  /// When non-null, how many more `tap`, `launch` and `typeText` calls are
  /// accepted; at 0 they are refused (counted in [refused], not recorded).
  int? budget;

  @override
  bool tap(int keyCode) => _command('tap:$keyCode');

  @override
  void holdStart(int keyCode) => calls.add('holdStart:$keyCode');

  @override
  void holdEnd(int keyCode) => calls.add('holdEnd:$keyCode');

  @override
  bool launch(AppEntry app) => _command('launch:${app.package}');

  @override
  bool typeText(String text) => _command('text:$text');

  bool _command(String call) {
    if (!connected || budget == 0) {
      refused++;
      return false;
    }
    if (budget != null) budget = budget! - 1;
    calls.add(call);
    return true;
  }
}
