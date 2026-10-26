import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tv_remote/app/l10n/app_localizations.dart';
import 'package:tv_remote/app/router.dart';
import 'package:tv_remote/app/theme/tokens.dart';
import 'package:tv_remote/features/discovery/presentation/widgets/troubleshooting_sheet.dart';
import 'package:tv_remote/features/pairing/application/pairing_controller.dart';
import 'package:tv_remote/features/pairing/application/pairing_state.dart';
import 'package:tv_remote/features/pairing/data/pairing_providers.dart';
import 'package:tv_remote/features/pairing/domain/pairing_code.dart';
import 'package:tv_remote/features/pairing/presentation/widgets/pairing_code_field.dart';

/// Pairs the phone with a TV: the TV shows a code and the user types it in.
///
/// [tv] comes with the route when the user picked a TV from a list. Without
/// it the screen looks the TV up by [serviceName].
class PairingScreen extends ConsumerWidget {
  /// Creates the screen for the TV called [serviceName].
  const PairingScreen({required this.serviceName, this.tv, super.key});

  /// The mDNS service name (or `manual:<ip>`) of the TV.
  final String serviceName;

  /// The TV to pair, when the route carried it.
  final DiscoveredTv? tv;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final known = tv;
    if (known != null) return _PairingBody(tv: known);

    final target = ref.watch(pairingTargetProvider(serviceName));
    final resolved = target.value;
    if (resolved != null) return _PairingBody(tv: resolved);
    if (target.isLoading && !target.hasError) {
      return _Page(
        child: _Message(progressLabel: l10n.pairStarting(serviceName.trim())),
      );
    }
    // Not found, or the look-up failed: the way out is the same.
    return _Page(
      child: _Message(
        title: l10n.pairNotFoundTitle,
        body: l10n.pairNotFoundBody,
        actions: [
          FilledButton(
            onPressed: () => context.go(AppRoutes.discover),
            child: Text(l10n.routeNotFoundAction),
          ),
        ],
      ),
    );
  }
}

class _PairingBody extends ConsumerWidget {
  const _PairingBody({required this.tv});

  final DiscoveredTv tv;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = pairingControllerProvider(tv);
    ref.listen(provider, (_, next) {
      if (next is PairingSucceeded) context.go(AppRoutes.remote);
    });
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final name = tv.displayName;

    void restart() => unawaited(controller.restart());

    Widget failure({
      required String title,
      required String body,
      required String action,
      bool troubleshooting = false,
    }) => _Message(
      title: title,
      body: body,
      actions: [
        FilledButton(onPressed: restart, child: Text(action)),
        if (troubleshooting)
          TextButton(
            onPressed: () => unawaited(showTroubleshootingSheet(context)),
            child: Text(l10n.pairTroubleshooting),
          ),
      ],
    );

    final body = switch (state) {
      PairingStarting() ||
      PairingSucceeded() => _Message(progressLabel: l10n.pairStarting(name)),
      PairingWaitingForCode() || PairingVerifying() => _CodeEntry(
        tvName: name,
        state: state,
        onSubmit: (code) => unawaited(controller.submit(code)),
      ),
      PairingCodeExpired() => _Message(
        title: l10n.pairExpiredTitle,
        body: l10n.pairExpiredBody,
        actions: [
          FilledButton(onPressed: restart, child: Text(l10n.pairNewCode)),
        ],
      ),
      PairingFailed(:final kind) => switch (kind) {
        PairingErrorKind.cantReachTv => failure(
          title: l10n.pairCantReachTitle(name),
          body: l10n.pairCantReachBody,
          action: l10n.pairTryAgain,
          troubleshooting: true,
        ),
        PairingErrorKind.tvDidNotRespond => failure(
          title: l10n.pairNoResponseTitle(name),
          body: l10n.pairCantReachBody,
          action: l10n.pairTryAgain,
          troubleshooting: true,
        ),
        PairingErrorKind.codeRejectedByTv => failure(
          title: l10n.pairRejectedTitle,
          body: l10n.pairRejectedBody,
          action: l10n.pairNewCode,
        ),
        PairingErrorKind.pairingError => failure(
          title: l10n.pairErrorTitle,
          body: l10n.pairErrorBody,
          action: l10n.pairTryAgain,
        ),
        PairingErrorKind.identityUnavailable => failure(
          title: l10n.pairIdentityTitle,
          body: l10n.pairErrorBody,
          action: l10n.pairTryAgain,
        ),
        PairingErrorKind.saveFailed => failure(
          title: l10n.pairSaveFailedTitle,
          body: l10n.pairErrorBody,
          action: l10n.pairTryAgain,
        ),
      },
    };
    return _Page(child: body);
  }
}

/// The app bar and the centred, scrolling body every state shares.
class _Page extends StatelessWidget {
  const _Page({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).pageTitlePair)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A spinner with a label, or a title and body with the actions that follow.
class _Message extends StatelessWidget {
  const _Message({
    this.title,
    this.body,
    this.progressLabel,
    this.actions = const [],
  });

  final String? title;
  final String? body;
  final String? progressLabel;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = context.appColors.textSecondary;
    final heading = title;
    final text = body;
    final progress = progressLabel;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.l,
      children: [
        if (progress != null) ...[
          const Center(child: CircularProgressIndicator()),
          Text(
            progress,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: secondary),
          ),
        ],
        if (heading != null)
          Text(
            heading,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
        if (text != null)
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: secondary),
          ),
        ...actions,
      ],
    );
  }
}

/// The code field with its instruction, countdown and Paste button.
class _CodeEntry extends StatefulWidget {
  const _CodeEntry({
    required this.tvName,
    required this.state,
    required this.onSubmit,
  });

  final String tvName;

  /// [PairingWaitingForCode] or [PairingVerifying].
  final PairingState state;
  final ValueChanged<String> onSubmit;

  @override
  State<_CodeEntry> createState() => _CodeEntryState();
}

class _CodeEntryState extends State<_CodeEntry> {
  final GlobalKey<PairingCodeFieldState> _field = GlobalKey();

  // Whether a code was sent and its verdict has not been shown yet.
  bool _submitted = false;

  static bool _isMismatch(PairingState state) =>
      state is PairingWaitingForCode && state.codeMismatch;

  @override
  void didUpdateWidget(_CodeEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A wrong code is emptied so the user starts over. The flag, not a change
    // of state, marks the verdict: a second wrong code can come back before a
    // frame shows the checking state in between.
    if (_submitted && _isMismatch(widget.state)) {
      _submitted = false;
      _field.currentState?.clear();
    }
  }

  void _submit(String code) {
    _submitted = true;
    widget.onSubmit(code);
  }

  Future<void> _paste() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final raw = data?.text ?? '';
    // Prose with a few hex letters in it must not become a code.
    final looksLikeCode = RegExp(r'^[0-9A-Fa-f\s-]+$').hasMatch(raw);
    final code = looksLikeCode ? normalizePairingCode(raw) : '';
    if (isCompletePairingCode(code)) {
      // Completing the text submits it, like typing the last character.
      _field.currentState?.setCode(code);
    } else {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.pairNothingToPaste)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final secondary = context.appColors.textSecondary;
    final state = widget.state;
    final verifying = state is PairingVerifying;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.l,
      children: [
        Text(
          l10n.pairEnterCode(widget.tvName),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        PairingCodeField(
          key: _field,
          enabled: !verifying,
          errorText: _isMismatch(state) ? l10n.pairCodeMismatch : null,
          onCompleted: _submit,
        ),
        if (state is PairingWaitingForCode)
          Text(
            l10n.pairExpiresIn(state.secondsLeft),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: AppSpacing.m,
            children: [
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              Flexible(
                child: Text(
                  l10n.pairVerifying,
                  style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
                ),
              ),
            ],
          ),
        TextButton.icon(
          onPressed: verifying ? null : () => unawaited(_paste()),
          icon: const Icon(Icons.content_paste),
          label: Text(l10n.pairPaste),
        ),
      ],
    );
  }
}
