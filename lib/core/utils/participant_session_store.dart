import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Análogo a `HostSessionStore`, pero para el lado participante: mientras
/// este dispositivo está conectado a una sala como participante (no
/// anfitrión), guarda el mínimo para reconectarse solo si la app se
/// cierra a la fuerza y se vuelve a abrir — código de sala + el nombre
/// con el que se había unido.
class ParticipantSessionSnapshot {
  final String code;
  final String yourName;

  const ParticipantSessionSnapshot({required this.code, required this.yourName});

  Map<String, dynamic> toJson() => {'code': code, 'yourName': yourName};

  factory ParticipantSessionSnapshot.fromJson(Map<String, dynamic> json) => ParticipantSessionSnapshot(
        code: json['code'] as String,
        yourName: json['yourName'] as String,
      );
}

class ParticipantSessionStore {
  static const _key = 'kena.liveParticipantSession';

  static Future<void> save(ParticipantSessionSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(snapshot.toJson()));
  }

  static Future<ParticipantSessionSnapshot?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return ParticipantSessionSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
