import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/theme/app_theme.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/features/keyboard/keyboard_sheet.dart';
import 'package:tv_remote/features/keyboard/text_edit_planner.dart';

import '../../helpers/key_input_recorder.dart';

const _connected = TvConnectionState(status: ConnectionStatus.connected);
const _offline = TvConnectionState(status: ConnectionStatus.offline);

void main() {
  late KeyInputRecorder rec;
  late StreamController<TvConnectionState> states;

  setUp(() {
    rec = KeyInputRecorder();
    states = StreamController<TvConnectionState>();
    addTearDown(states.close);
  });

  Future<void> pumpHost(
    WidgetTester t, {
    ImeTextMode mode = ImeTextMode.replaceField,
    double textScale = 1,
    Size? size,
  }) async {
    if (size != null) {
      t.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
    }
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          connectionStateProvider.overrideWith((ref) => states.stream),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildAppTheme(brightness: Brightness.light),
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: app!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showKeyboardSheet(context, input: rec, mode: mode),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(
    WidgetTester t, {
    TvConnectionState state = _connected,
    ImeTextMode mode = ImeTextMode.replaceField,
    double textScale = 1,
    Size? size,
  }) async {
    await pumpHost(t, mode: mode, textScale: textScale, size: size);
    states.add(state);
    await t.tap(find.text('Open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> type(WidgetTester t, String text) =>
      t.enterText(find.byType(TextField), text);

  Future<void> settleSheetClose(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  testWidgets('typing_sends_text_debounced', (t) async {
    await openSheet(t);
    for (final s in ['h', 'he', 'hel']) {
      await type(t, s);
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(rec.calls, isEmpty);
    await t.pump(const Duration(milliseconds: 150));
    expect(rec.calls, ['text:hel']);
  });

  testWidgets('enter_sends_66', (t) async {
    await openSheet(t);
    await t.tap(find.text('Enter'));
    await settleSheetClose(t);
    expect(rec.calls.last, 'tap:66');
    expect(find.byType(TextField), findsNothing);
    expect(KeyboardSheet.isOpen, isFalse);
  });

  testWidgets('enter_flushes_pending_text_before_enter_key', (t) async {
    await openSheet(t);
    await type(t, 'hi');
    await t.tap(find.text('Enter'));
    await settleSheetClose(t);
    expect(rec.calls, ['text:hi', 'tap:66']);
    // The cancelled debounce must not send again.
    await t.pump(const Duration(milliseconds: 300));
    expect(rec.calls, ['text:hi', 'tap:66']);
  });

  testWidgets('keyboard_action_send_acts_as_enter', (t) async {
    await openSheet(t);
    await type(t, 'hi');
    await t.testTextInput.receiveAction(TextInputAction.send);
    await settleSheetClose(t);
    expect(rec.calls, ['text:hi', 'tap:66']);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('enter_while_refused_keeps_the_sheet_open', (t) async {
    await openSheet(t);
    rec.connected = false;
    await type(t, 'hi');
    await t.tap(find.text('Enter'));
    await settleSheetClose(t);
    expect(rec.calls, isEmpty);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('clear_sends_an_empty_field_at_once', (t) async {
    await openSheet(t);
    await type(t, 'abc');
    await t.pump(const Duration(milliseconds: 200));
    expect(rec.calls, ['text:abc']);
    await t.tap(find.byTooltip('Clear'));
    await t.pump();
    expect(rec.calls.last, 'text:');
    expect(find.byTooltip('Clear'), findsNothing);
    await t.pump(const Duration(milliseconds: 300));
    expect(rec.calls, ['text:abc', 'text:']);
  });

  testWidgets('clear_button_only_shows_for_a_non_empty_field', (t) async {
    await openSheet(t);
    expect(find.byTooltip('Clear'), findsNothing);
    await type(t, 'a');
    await t.pump();
    expect(find.byTooltip('Clear'), findsOneWidget);
    expect(
      t.getSize(find.byTooltip('Clear')).shortestSide,
      greaterThanOrEqualTo(48),
    );
    await t.pump(const Duration(milliseconds: 200));
  });

  testWidgets('closing_the_sheet_flushes_pending_text', (t) async {
    await openSheet(t);
    await type(t, 'yo');
    await t.tap(find.byTooltip('Close'));
    await settleSheetClose(t);
    expect(rec.calls, ['text:yo']);
    expect(KeyboardSheet.isOpen, isFalse);
  });

  testWidgets('not_connected_shows_inline_message_and_sends_nothing', (
    t,
  ) async {
    rec.connected = false;
    await openSheet(t, state: _offline);
    expect(
      find.text("Not connected to your TV. What you type isn't sent."),
      findsOneWidget,
    );
    await type(t, 'abc');
    await t.pump(const Duration(milliseconds: 200));
    expect(rec.calls, isEmpty);
  });

  testWidgets('connected_hides_the_not_connected_message', (t) async {
    await openSheet(t);
    expect(find.textContaining('Not connected'), findsNothing);
    expect(
      find.text('Select a text field on the TV first, like the search box.'),
      findsOneWidget,
    );
  });

  testWidgets('message_follows_the_connection_state', (t) async {
    await openSheet(t);
    states.add(_offline);
    await t.pump();
    await t.pump();
    expect(find.textContaining('Not connected'), findsOneWidget);
    states.add(_connected);
    await t.pump();
    await t.pump();
    expect(find.textContaining('Not connected'), findsNothing);
  });

  testWidgets('a_refused_send_shows_the_message_even_if_state_says_connected', (
    t,
  ) async {
    // RemoteActions can be a stale, disposed instance after a TV switch: it
    // refuses silently while the provider already says connected.
    await openSheet(t);
    rec.connected = false;
    await type(t, 'ab');
    await t.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('Not connected'), findsOneWidget);
    rec.connected = true;
    await type(t, 'abc');
    await t.pump(const Duration(milliseconds: 200));
    expect(rec.calls, ['text:abc']);
    expect(find.textContaining('Not connected'), findsNothing);
  });

  testWidgets('reconnecting_then_typing_sends_the_whole_field', (t) async {
    rec.connected = false;
    await openSheet(t, state: _offline);
    await type(t, 'ab');
    await t.pump(const Duration(milliseconds: 200));
    expect(rec.calls, isEmpty);
    expect(rec.refused, 1);
    rec.connected = true;
    states.add(_connected);
    await t.pump();
    await type(t, 'abc');
    await t.pump(const Duration(milliseconds: 200));
    expect(rec.calls, ['text:abc']);
  });

  testWidgets('open_tv_search_sends_search_key', (t) async {
    await openSheet(t);
    await t.tap(find.text('Open search on TV'));
    await t.pump();
    expect(rec.calls, ['tap:84']);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('append_mode_uses_delete_keys', (t) async {
    await openSheet(t, mode: ImeTextMode.appendOnly);
    await type(t, 'abc');
    await t.pump(const Duration(milliseconds: 200));
    await type(t, 'ab');
    await t.pump(const Duration(milliseconds: 200));
    expect(rec.calls, ['text:abc', 'tap:67']);
  });

  testWidgets('field_is_configured_for_live_typing', (t) async {
    await openSheet(t);
    final field = t.widget<TextField>(find.byType(TextField));
    expect(field.autofocus, isTrue);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isTrue);
    expect(field.textInputAction, TextInputAction.send);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Start typing…'), findsOneWidget);
    expect(find.text('Type on your TV'), findsOneWidget);
  });

  testWidgets('sheet_is_open_flag_tracks_the_sheet', (t) async {
    await pumpHost(t);
    states.add(_connected);
    expect(KeyboardSheet.isOpen, isFalse);
    await t.tap(find.text('Open'));
    await t.pump();
    expect(KeyboardSheet.isOpen, isTrue);
    await t.pump(const Duration(milliseconds: 400));
    // A second open request while open does nothing.
    final context = t.element(find.byType(TextField));
    unawaited(showKeyboardSheet(context, input: rec));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(TextField), findsOneWidget);
    await t.tap(find.byTooltip('Close'));
    await settleSheetClose(t);
    expect(KeyboardSheet.isOpen, isFalse);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('keyboard_sheet_fits_320dp_at_200_percent_text', (t) async {
    await openSheet(t, textScale: 2, size: const Size(320, 568));
    await type(t, 'netflix');
    await t.pump(const Duration(milliseconds: 200));
    expect(t.takeException(), isNull);
    for (final label in ['Open search on TV', 'Enter']) {
      final rect = t.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
    }
    for (final finder in [
      find.widgetWithText(TextButton, 'Open search on TV'),
      find.widgetWithText(FilledButton, 'Enter'),
    ]) {
      expect(t.getSize(finder).height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('reopening_while_the_old_sheet_is_closing_keeps_one_sheet', (
    t,
  ) async {
    await openSheet(t);
    await t.tap(find.text('Enter'));
    // The route has popped (its future completed) but the exit animation
    // is still running, so the old sheet is still mounted.
    await t.pump();
    expect(KeyboardSheet.isOpen, isFalse);
    unawaited(
      showKeyboardSheet(t.element(find.text('Open')), input: rec),
    );
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(KeyboardSheet), findsOneWidget);
    expect(KeyboardSheet.isOpen, isTrue);
    // The old sheet's disposal must not clear the flag of the new one.
    await t.tap(find.byTooltip('Close'));
    await settleSheetClose(t);
    expect(KeyboardSheet.isOpen, isFalse);
    expect(find.byType(KeyboardSheet), findsNothing);
  });

  testWidgets('a_second_open_in_the_same_frame_is_ignored', (t) async {
    await pumpHost(t);
    states.add(_connected);
    final context = t.element(find.text('Open'));
    unawaited(showKeyboardSheet(context, input: rec));
    unawaited(showKeyboardSheet(context, input: rec));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(KeyboardSheet), findsOneWidget);
  });

  testWidgets('reconnecting_clears_a_stale_refusal', (t) async {
    await openSheet(t);
    rec.connected = false;
    await type(t, 'ab');
    await t.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('Not connected'), findsOneWidget);
    states.add(_offline);
    await t.pump();
    states.add(_connected);
    await t.pump();
    await t.pump();
    expect(find.textContaining('Not connected'), findsNothing);
  });

  testWidgets('enter_closes_only_the_keyboard_sheet', (t) async {
    await openSheet(t);
    // Something else ends up on top of the sheet.
    unawaited(
      showDialog<void>(
        context: t.element(find.byType(KeyboardSheet)),
        builder: (_) => const AlertDialog(title: Text('Other')),
      ),
    );
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    t.widget<TextField>(find.byType(TextField)).onSubmitted!('');
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.byType(KeyboardSheet), findsNothing);
    expect(find.text('Other'), findsOneWidget);
    expect(rec.calls, ['tap:66']);
  });

  testWidgets('personalised_learning_is_off_for_the_field', (t) async {
    await openSheet(t);
    final field = t.widget<TextField>(find.byType(TextField));
    expect(field.enableIMEPersonalizedLearning, isFalse);
  });

  testWidgets('closing_with_pending_text_sends_it_once_and_nothing_later', (
    t,
  ) async {
    await openSheet(t);
    await type(t, 'yo');
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.byTooltip('Close'));
    await settleSheetClose(t);
    expect(rec.calls, ['text:yo']);
    // The cancelled debounce must not fire after the sheet is gone (the
    // test binding also fails on a pending timer).
    await t.pump(const Duration(seconds: 1));
    expect(rec.calls, ['text:yo']);
    expect(t.takeException(), isNull);
  });

  testWidgets('append_mode_catches_up_after_a_refused_send', (t) async {
    await openSheet(t, mode: ImeTextMode.appendOnly);
    rec.connected = false;
    await type(t, 'abc');
    await t.pump(const Duration(milliseconds: 200));
    expect(rec.calls, isEmpty);
    rec.connected = true;
    await type(t, 'abcd');
    await t.pump(const Duration(milliseconds: 200));
    // Nothing was ever delivered, so the whole field goes out.
    expect(rec.calls, ['text:abcd']);
  });
}
