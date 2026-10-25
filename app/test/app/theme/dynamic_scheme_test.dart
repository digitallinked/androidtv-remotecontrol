import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as mu;
import 'package:tv_remote/app/theme/dynamic_scheme.dart';

void _expectSameRoles(ColorScheme actual, mu.ColorScheme source) {
  expect(actual.brightness, source.brightness);
  expect(actual.primary, source.primary);
  expect(actual.onPrimary, source.onPrimary);
  expect(actual.primaryContainer, source.primaryContainer);
  expect(actual.onPrimaryContainer, source.onPrimaryContainer);
  expect(actual.primaryFixed, source.primaryFixed);
  expect(actual.primaryFixedDim, source.primaryFixedDim);
  expect(actual.onPrimaryFixed, source.onPrimaryFixed);
  expect(actual.onPrimaryFixedVariant, source.onPrimaryFixedVariant);
  expect(actual.secondary, source.secondary);
  expect(actual.onSecondary, source.onSecondary);
  expect(actual.secondaryContainer, source.secondaryContainer);
  expect(actual.onSecondaryContainer, source.onSecondaryContainer);
  expect(actual.secondaryFixed, source.secondaryFixed);
  expect(actual.secondaryFixedDim, source.secondaryFixedDim);
  expect(actual.onSecondaryFixed, source.onSecondaryFixed);
  expect(actual.onSecondaryFixedVariant, source.onSecondaryFixedVariant);
  expect(actual.tertiary, source.tertiary);
  expect(actual.onTertiary, source.onTertiary);
  expect(actual.tertiaryContainer, source.tertiaryContainer);
  expect(actual.onTertiaryContainer, source.onTertiaryContainer);
  expect(actual.tertiaryFixed, source.tertiaryFixed);
  expect(actual.tertiaryFixedDim, source.tertiaryFixedDim);
  expect(actual.onTertiaryFixed, source.onTertiaryFixed);
  expect(actual.onTertiaryFixedVariant, source.onTertiaryFixedVariant);
  expect(actual.error, source.error);
  expect(actual.onError, source.onError);
  expect(actual.errorContainer, source.errorContainer);
  expect(actual.onErrorContainer, source.onErrorContainer);
  expect(actual.surface, source.surface);
  expect(actual.onSurface, source.onSurface);
  expect(actual.surfaceDim, source.surfaceDim);
  expect(actual.surfaceBright, source.surfaceBright);
  expect(actual.surfaceContainerLowest, source.surfaceContainerLowest);
  expect(actual.surfaceContainerLow, source.surfaceContainerLow);
  expect(actual.surfaceContainer, source.surfaceContainer);
  expect(actual.surfaceContainerHigh, source.surfaceContainerHigh);
  expect(actual.surfaceContainerHighest, source.surfaceContainerHighest);
  expect(actual.onSurfaceVariant, source.onSurfaceVariant);
  expect(actual.outline, source.outline);
  expect(actual.outlineVariant, source.outlineVariant);
  expect(actual.shadow, source.shadow);
  expect(actual.scrim, source.scrim);
  expect(actual.inverseSurface, source.inverseSurface);
  expect(actual.onInverseSurface, source.onInverseSurface);
  expect(actual.inversePrimary, source.inversePrimary);
  expect(actual.surfaceTint, source.surfaceTint);
}

void main() {
  const seed = Color(0xFF6C8CFF);

  test('null_scheme_stays_null', () {
    expect(colorSchemeFromDynamic(null), isNull);
  });

  for (final brightness in Brightness.values) {
    test('converts_every_role_for_${brightness.name}', () {
      final source = mu.ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      );

      _expectSameRoles(colorSchemeFromDynamic(source)!, source);
    });
  }
}
