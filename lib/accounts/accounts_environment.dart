import 'data/group_repository.dart';
import 'data/user_repository.dart';
import 'domain/models/auth_provider_type.dart';
import 'domain/providers/billing_service.dart';
import 'domain/providers/social_auth_provider.dart';
import 'domain/providers/verification_provider.dart';

/// Único lugar que decide qué implementación real usa cada pieza
/// desacoplada de `accounts/` — hoy, sólo mocks/almacenamiento local
/// (ver brief: "arquitectura de código, sin conexiones reales").
///
/// Para conectar servicios reales más adelante, esto es lo único que
/// hay que tocar: reemplazar cada mock acá por su implementación real
/// (`TwilioVerifyProvider`, un `SocialAuthProvider` con el SDK
/// correspondiente, `AppleIapBillingService`/`GooglePlayBillingService`,
/// y un `UserRepository`/`GroupRepository` que hablen con un backend en
/// vez de `SharedPreferences`). Ningún controller ni pantalla debería
/// necesitar cambiar.
class AccountsEnvironment {
  AccountsEnvironment._();

  static final UserRepository userRepository = LocalUserRepository();
  static final GroupRepository groupRepository = LocalGroupRepository();

  static final VerificationProvider verificationProvider = MockVerificationProvider();

  static final Map<AuthProviderType, SocialAuthProvider> socialProviders = {
    AuthProviderType.google: MockSocialAuthProvider(AuthProviderType.google),
    AuthProviderType.apple: MockSocialAuthProvider(AuthProviderType.apple),
    AuthProviderType.facebook: MockSocialAuthProvider(AuthProviderType.facebook),
  };

  static final BillingService billingService = MockBillingService();
}
