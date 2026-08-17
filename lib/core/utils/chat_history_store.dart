import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../protocol/chat_message.dart';

/// Guarda el log de mensajes de la ÚLTIMA sala en la que estuviste,
/// localmente, para no perderlo si la app se cierra o se va a segundo
/// plano y la mata el sistema — hoy eso lo perdía todo (ver ROADMAP.md
/// → "Persistir el chat localmente entre sesiones").
///
/// Guarda un solo "último snapshot" (no un historial de salas — Kena
/// no tiene "Mis salas", ver ROADMAP.md): si volvés a entrar a una sala
/// con el mismo código que el snapshot guardado, se restaura; si el
/// código no coincide, se ignora (era de otra sala).
class ChatHistoryStore {
  ChatHistoryStore._();

  static const _key = 'kena.lastChatHistory';

  /// Techo razonable para no dejar crecer el almacenamiento local sin
  /// límite en una sesión de chat larga — se queda con los más
  /// recientes.
  static const maxMessages = 400;

  static Future<void> save({
    required String code,
    required String roomName,
    required List<ChatMessage> messages,
  }) async {
    final trimmed =
        messages.length > maxMessages ? messages.sublist(messages.length - maxMessages) : messages;
    final payload = jsonEncode({
      'code': code,
      'roomName': roomName,
      'messages': trimmed.map((m) => m.toJson()).toList(),
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, payload);
  }

  /// Devuelve el log guardado sólo si es de una sala con este mismo
  /// código — un snapshot de otra sala anterior no tiene sentido
  /// mostrarlo acá.
  static Future<List<ChatMessage>> loadForCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const [];
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['code'] != code) return const [];
      final list = (json['messages'] as List<dynamic>).cast<Map<String, dynamic>>();
      return list.map(ChatMessage.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
