import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Lo mínimo para volver a levantar el mismo `ChatHostServer` (mismo
/// código, mismo nombre) si este dispositivo está siendo anfitrión de
/// una sala *ahora mismo* — a diferencia de `RoomHistoryStore` (un log
/// histórico de salas pasadas), esto es un flag vivo: existe sólo
/// mientras la sala sigue activa en este dispositivo.
class HostSessionSnapshot {
  final String code;
  final String roomName;
  final String hostDisplayName;

  const HostSessionSnapshot({
    required this.code,
    required this.roomName,
    required this.hostDisplayName,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'roomName': roomName,
        'hostDisplayName': hostDisplayName,
      };

  factory HostSessionSnapshot.fromJson(Map<String, dynamic> json) => HostSessionSnapshot(
        code: json['code'] as String,
        roomName: json['roomName'] as String,
        hostDisplayName: json['hostDisplayName'] as String,
      );
}

/// Es lo que hace posible recuperar la sala solo al volver a abrir la
/// app después de un cierre a la fuerza (swipe desde Recientes) — Android
/// no deja sobrevivir eso a ningún proceso (ni a Kena ni a ninguna otra
/// app), así que el servidor efectivamente muere con el proceso. Lo que
/// sí se puede hacer es que la app, al arrancar de nuevo, vea que
/// *seguía* siendo anfitrión y levante el mismo servidor con el mismo
/// código antes de mostrar cualquier otra pantalla — para el resto de
/// los participantes, que ya están reintentando solos por código
/// (`ChatClientConnection._searchByCode`), esto se ve igual que
/// cualquier corte-y-vuelta (`RootScreen` → `_tryResumeHostSession`).
class HostSessionStore {
  static const _key = 'kena.liveHostSession';

  static Future<void> save(HostSessionSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(snapshot.toJson()));
  }

  static Future<HostSessionSnapshot?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return HostSessionSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
