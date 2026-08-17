import '../models/auth_provider_type.dart';

/// Lo que un login social entrega de una — nunca se le vuelve a pedir
/// al usuario (ver brief, sección 2: "No pedir datos nuevamente").
class SocialAuthResult {
  final String providerUserId;
  final String firstName;
  final String lastName;
  final String? email;
  final String? avatarUrl;

  const SocialAuthResult({
    required this.providerUserId,
    required this.firstName,
    required this.lastName,
    this.email,
    this.avatarUrl,
  });
}

/// Un proveedor de login social (Google/Apple/Facebook) — desacoplado a
/// propósito de los SDKs reales (`google_sign_in`, `sign_in_with_apple`,
/// `flutter_facebook_auth`), que todavía no están integrados. Agregar
/// el SDK real es implementar esta interfaz de nuevo; `AuthController`
/// y las pantallas no cambian.
abstract class SocialAuthProvider {
  AuthProviderType get type;

  /// `null` si el usuario canceló el flujo (no es un error).
  Future<SocialAuthResult?> signIn();

  Future<void> signOut();
}

/// Para desarrollo/demo sin credenciales reales de OAuth: devuelve un
/// perfil de prueba fijo al instante, sin abrir ningún navegador ni
/// SDK nativo. Integrar Google/Apple/Facebook de verdad significa
/// reemplazar esto por una implementación que use el SDK
/// correspondiente — nada más en la app debería tener que cambiar.
class MockSocialAuthProvider implements SocialAuthProvider {
  MockSocialAuthProvider(this.type);

  @override
  final AuthProviderType type;

  @override
  Future<SocialAuthResult?> signIn() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final label = switch (type) {
      AuthProviderType.google => 'Google',
      AuthProviderType.apple => 'Apple',
      AuthProviderType.facebook => 'Facebook',
      AuthProviderType.phone => 'Teléfono',
    };
    return SocialAuthResult(
      providerUserId: 'mock-${type.name}-${DateTime.now().millisecondsSinceEpoch}',
      firstName: 'Usuario',
      lastName: label,
      email: 'usuario.demo+${type.name}@kena.app',
      avatarUrl: null,
    );
  }

  @override
  Future<void> signOut() async {}
}
