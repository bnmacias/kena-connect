import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/app_user.dart';

/// Persistencia de [AppUser] — desacoplada de dónde vive de verdad
/// (hoy: sólo este dispositivo, vía `SharedPreferences`; el día que
/// haya backend, la cuenta pasa a sincronizarse entre dispositivos sin
/// que `AuthController` tenga que cambiar, sólo la implementación de
/// esta interfaz).
abstract class UserRepository {
  Future<AppUser?> currentUser();
  Future<void> save(AppUser user);
  Future<void> clear();
}

class LocalUserRepository implements UserRepository {
  static const _key = 'kena.accounts.user';

  @override
  Future<AppUser?> currentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(user.toJson()));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
