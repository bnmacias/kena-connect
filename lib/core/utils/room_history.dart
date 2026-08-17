import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Un renglón de "Mis salas": una foto de una sala en la que este
/// dispositivo participó. Es histórico — no implica que la sala siga
/// activa (una sala vive mientras el anfitrión la sostiene, no hay
/// servidor central que la recuerde).
class RoomHistoryEntry {
  final String roomName;
  final String code;
  final bool wasHost;
  final int memberCount;
  final int timestampMs;

  const RoomHistoryEntry({
    required this.roomName,
    required this.code,
    required this.wasHost,
    required this.memberCount,
    required this.timestampMs,
  });

  Map<String, dynamic> toJson() => {
        'roomName': roomName,
        'code': code,
        'wasHost': wasHost,
        'memberCount': memberCount,
        'ts': timestampMs,
      };

  factory RoomHistoryEntry.fromJson(Map<String, dynamic> json) => RoomHistoryEntry(
        roomName: json['roomName'] as String? ?? '?',
        code: json['code'] as String? ?? '',
        wasHost: json['wasHost'] as bool? ?? false,
        memberCount: json['memberCount'] as int? ?? 1,
        timestampMs: json['ts'] as int? ?? 0,
      );
}

/// Historial local de salas ("Mis salas"). Vive sólo en este
/// dispositivo — no hay cuenta ni backend que lo sincronice todavía.
class RoomHistoryStore {
  static const _key = 'kena.room_history';
  static const _maxEntries = 30;

  static Future<List<RoomHistoryEntry>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    final entries = raw
        .map((e) {
          try {
            return RoomHistoryEntry.fromJson(jsonDecode(e) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<RoomHistoryEntry>()
        .toList();
    entries.sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    return entries;
  }

  static Future<void> record(RoomHistoryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await all();
    final updated = [entry, ...current.where((e) => e.code != entry.code)].take(_maxEntries).toList();
    await prefs.setStringList(_key, updated.map((e) => jsonEncode(e.toJson())).toList());
  }
}
