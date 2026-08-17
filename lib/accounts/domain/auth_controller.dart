import 'dart:math';

import 'package:flutter/foundation.dart';

import '../accounts_environment.dart';
import '../data/user_repository.dart';
import 'models/app_user.dart';
import 'models/auth_provider_type.dart';

/// Sesión de cuenta activa — mismo patrón que `KenaThemeController`
/// (`ValueNotifier` singleton): cualquier pantalla puede escucharlo,
/// `value == null` significa "sin sesión iniciada".
class AuthController extends ValueNotifier<AppUser?> {
  AuthController._({UserRepository? userRepository}) : _users = userRepository ?? AccountsEnvironment.userRepository, super(null);

  static final AuthController instance = AuthController._();

  final UserRepository _users;

  bool get isSignedIn => value != null;

  /// Restaura la sesión guardada, si había una — se llama una vez al
  /// entrar al flujo de cuentas (no en el arranque general de la app:
  /// a diferencia del tema, tener sesión iniciada no es necesario para
  /// usar el chat local de siempre).
  Future<void> load() async {
    value = await _users.currentUser();
  }

  Future<AppUser> signInWithSocial(AuthProviderType provider) async {
    final social = AccountsEnvironment.socialProviders[provider];
    if (social == null) {
      throw StateError('No hay SocialAuthProvider configurado para $provider.');
    }
    final result = await social.signIn();
    if (result == null) {
      throw StateError('El usuario canceló el login con $provider.');
    }
    final user = AppUser(
      id: result.providerUserId,
      firstName: result.firstName,
      lastName: result.lastName,
      email: result.email,
      avatarUrl: result.avatarUrl,
      authProvider: provider,
      createdAt: DateTime.now(),
    );
    await _users.save(user);
    value = user;
    return user;
  }

  Future<void> sendPhoneCode(String phone) => AccountsEnvironment.verificationProvider.sendCode(phone);

  /// Verifica el código y, si es válido, crea (o recupera) la cuenta.
  /// [firstName] sólo hace falta la primera vez (ver brief, sección 2:
  /// "Número, OTP, Nombre").
  Future<AppUser> verifyPhoneCode(String phone, String code, {required String firstName}) async {
    final ok = await AccountsEnvironment.verificationProvider.verifyCode(phone, code);
    if (!ok) {
      throw const FormatException('Código incorrecto o vencido.');
    }
    final existing = await _users.currentUser();
    final user = (existing != null && existing.phone == phone)
        ? existing
        : AppUser(
            id: 'phone-${Random.secure().nextInt(1 << 31)}-${DateTime.now().microsecondsSinceEpoch}',
            firstName: firstName,
            lastName: '',
            phone: phone,
            authProvider: AuthProviderType.phone,
            createdAt: DateTime.now(),
          );
    await _users.save(user);
    value = user;
    return user;
  }

  Future<void> signOut() async {
    final provider = value?.authProvider;
    if (provider != null) {
      await AccountsEnvironment.socialProviders[provider]?.signOut();
    }
    await _users.clear();
    value = null;
  }
}
