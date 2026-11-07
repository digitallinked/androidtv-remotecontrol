import 'dart:async';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'phone_country.g.dart';

/// The native channel that reports the phone's country (`MainActivity.kt`,
/// `AppDelegate.swift`).
const MethodChannel regionChannel = MethodChannel(
  'com.digitallinked.atvremote/region',
);

/// How long startup waits for the native answer.
const Duration phoneCountryTimeout = Duration(seconds: 1);

final RegExp _countryCode = RegExp(r'^[A-Za-z]{2}$');

/// The country the phone is in, in upper case, or `null` when it can't say.
///
/// The language list doesn't tell: a phone in Malaysia set to British English
/// reports `en-GB` there, and would be offered British apps. Android answers
/// with the SIM's country, then the network's; iOS with the Region setting.
/// Neither needs a permission, and the answer never leaves the phone.
///
/// Every failure is `null`, which falls back to the language list: this only
/// picks the default apps, so it must never stop the app from starting.
Future<String?> readPhoneCountry({
  MethodChannel channel = regionChannel,
  Duration timeout = phoneCountryTimeout,
}) async {
  try {
    final country = await channel
        .invokeMethod<String>('phoneCountry')
        .timeout(timeout);
    if (country == null || !_countryCode.hasMatch(country)) return null;
    return country.toUpperCase();
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  } on TimeoutException {
    return null;
  }
}

/// [readPhoneCountry]'s answer, read once at startup (`bootstrap`).
@Riverpod(keepAlive: true)
String? phoneCountry(Ref ref) => null;
