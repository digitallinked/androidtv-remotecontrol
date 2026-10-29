/// The string rules of Ruling P6-R6, shared by the analytics guard and by
/// Remote Config values that end up as analytics parameters.
library;

final RegExp _plain = RegExp(r'^[A-Za-z0-9_.]{1,100}$');
final RegExp _ipv4 = RegExp(r'(?<![0-9])\d{1,3}(?:\.\d{1,3}){3}(?![0-9])');
final RegExp _ipv6 = RegExp('[0-9A-Fa-f]{0,4}(?::[0-9A-Fa-f]{0,4}){2,}');
final RegExp _mac = RegExp(
  r'(?:[0-9A-Fa-f]{2}([:-])(?:[0-9A-Fa-f]{2}\1){4}[0-9A-Fa-f]{2})'
  r'|(?:[0-9A-Fa-f]{4}\.[0-9A-Fa-f]{4}\.[0-9A-Fa-f]{4})',
);
final RegExp _hexRun = RegExp('[0-9A-Fa-f]{12,}');

/// The reasons [value] is not a safe analytics string, without repeating
/// it; empty when it is fine.
///
/// A safe string is a plain token (letters, digits, `_` and `.`, up to 100
/// characters) that holds no IP or MAC address, no hex run of 12 or more, and
/// no `manual:`, `.local` or `_tcp`.
List<String> analyticsStringViolations(String value) => [
  if (_ipv4.hasMatch(value)) 'contains an IPv4 address',
  if (_ipv6.hasMatch(value)) 'contains an IPv6 address',
  if (_mac.hasMatch(value)) 'contains a MAC address',
  if (_hexRun.hasMatch(value)) 'contains a long hex run',
  if (value.contains('manual:')) 'contains a manual TV marker',
  if (value.contains('.local')) 'contains a host name',
  if (value.contains('_tcp')) 'contains a service name',
  if (!_plain.hasMatch(value)) 'is not a short plain token',
];
