import 'auth_provider_type.dart';

/// Identidad de cuenta de Kena — distinta de `KenaProfile`
/// (`core/utils/profile_store.dart`), que es el nombre/avatar *local a
/// un dispositivo* sin cuenta. `AppUser` es la identidad que junta
/// grupos y membresías entre dispositivos: sólo tiene sentido una vez
/// que existe un backend real detrás (ver `UserRepository`) — hoy esa
/// capa está mockeada/local, así que `AppUser` vive únicamente en este
/// dispositivo, pero el modelo ya está preparado para eso.
class AppUser {
  final String id;
  final String firstName;
  final String lastName;

  /// `null` si entró por teléfono y no hay email disponible.
  final String? email;

  /// `null` si entró por login social sin compartir el teléfono.
  final String? phone;

  /// `null` si no hay foto de perfil (login por teléfono, o el
  /// proveedor social no la compartió).
  final String? avatarUrl;

  final AuthProviderType authProvider;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.authProvider,
    required this.createdAt,
    this.email,
    this.phone,
    this.avatarUrl,
  });

  String get fullName => [firstName, lastName].where((s) => s.isNotEmpty).join(' ');

  AppUser copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? avatarUrl,
  }) =>
      AppUser(
        id: id,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        authProvider: authProvider,
        createdAt: createdAt,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'avatarUrl': avatarUrl,
        'authProvider': authProvider.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        authProvider: AuthProviderType.values.firstWhere(
          (p) => p.name == json['authProvider'],
          orElse: () => AuthProviderType.phone,
        ),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}
