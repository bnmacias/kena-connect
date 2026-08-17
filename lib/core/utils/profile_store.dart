import 'package:shared_preferences/shared_preferences.dart';

/// Identidad local del usuario: nombre + color de avatar. No requiere
/// cuenta ni login — vive sólo en este dispositivo. Una cuenta Kena
/// (sincronizada, con más de un dispositivo) queda para más adelante.
class KenaProfile {
  final String name;
  final int avatarColorIndex;

  const KenaProfile({required this.name, required this.avatarColorIndex});

  static const empty = KenaProfile(name: '', avatarColorIndex: 0);

  KenaProfile copyWith({String? name, int? avatarColorIndex}) => KenaProfile(
        name: name ?? this.name,
        avatarColorIndex: avatarColorIndex ?? this.avatarColorIndex,
      );
}

class ProfileStore {
  static const _nameKey = 'kena.profile.name';
  static const _avatarKey = 'kena.profile.avatarColorIndex';

  static Future<KenaProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    return KenaProfile(
      name: prefs.getString(_nameKey) ?? '',
      avatarColorIndex: prefs.getInt(_avatarKey) ?? 0,
    );
  }

  static Future<void> save(KenaProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, profile.name);
    await prefs.setInt(_avatarKey, profile.avatarColorIndex);
  }
}
