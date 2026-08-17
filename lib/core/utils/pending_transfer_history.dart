import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../protocol/chat_message.dart';

/// Puente para un caso puntual que `ChatHistoryStore` no cubre: cuando
/// el anfitrión transfiere la sala a mano (ver
/// `RoomShellScreen._openTransferPicker`), el sucesor arranca una sala
/// nueva con otro código (mismo nombre — ver ROADMAP.md →
/// "Transferencia de anfitrión no es una migración en vivo"). Quien
/// transfirió, al volver a unirse a esa sala nueva como un participante
/// más, no tiene forma de que `ChatHistoryStore` (que sólo reconoce por
/// código) sepa que es la continuación de la conversación que ya tenía
/// en este mismo dispositivo — así que la perdía sin necesidad.
///
/// Este store guarda ese historial en el momento justo de transferir
/// (`roomName` + el log tal cual estaba) y se consume una sola vez
/// —coincida o no— la próxima vez que este dispositivo se une a
/// cualquier sala: si el nombre coincide y no pasó demasiado tiempo, se
/// lo entrega como punto de partida; si no, se descarta igual, para no
/// arrastrar una sala vieja para siempre ni terminar mezclando el
/// historial en una sala distinta que coincida de nombre por casualidad.
class PendingTransferHistoryStore {
  PendingTransferHistoryStore._();

  static const _key = 'kena.pendingTransferHistory';

  /// Más que esto y quien transfirió ya siguió con otra cosa — no tiene
  /// sentido seguir ofreciendo esta sala vieja como punto de partida.
  static const _maxAge = Duration(hours: 2);

  static Future<void> save({required String roomName, required List<ChatMessage> messages}) async {
    final payload = jsonEncode({
      'roomName': roomName,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
      'messages': messages.map((m) => m.toJson()).toList(),
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, payload);
  }

  /// Se consume una sola vez: devuelve los mensajes guardados sólo si
  /// [roomName] coincide y todavía está vigente; en cualquier otro caso
  /// (no coincide, venció, no había nada) igual borra el registro.
  static Future<List<ChatMessage>?> consumeIfMatches(String roomName) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    await prefs.remove(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['roomName'] != roomName) return null;
      final savedAt = DateTime.fromMillisecondsSinceEpoch(json['savedAt'] as int);
      if (DateTime.now().difference(savedAt) > _maxAge) return null;
      final list = (json['messages'] as List<dynamic>).cast<Map<String, dynamic>>();
      return list.map(ChatMessage.fromJson).toList();
    } catch (_) {
      return null;
    }
  }
}
