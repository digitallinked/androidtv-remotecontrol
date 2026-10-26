import 'package:atv_remote/src/identity.dart';

/// An identity whose PEM strings `SecurityContext` cannot load (for example
/// storage handed back corrupt data that bypassed `ClientIdentity.fromPem`).
class UnloadableIdentity implements ClientIdentity {
  /// Wraps [_real], keeping its public key parts but not its PEM strings.
  UnloadableIdentity(this._real);

  final ClientIdentity _real;

  @override
  String get certificatePem => 'not a certificate';

  @override
  String get privateKeyPem => 'not a key';

  @override
  RsaPublicParts get publicParts => _real.publicParts;
}
