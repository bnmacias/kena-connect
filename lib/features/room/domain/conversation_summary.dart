import '../../../core/protocol/chat_message.dart';
import 'room_session.dart';

/// Una fila de la bandeja de la sala: General, o la conversación
/// privada con un participante puntual.
class ConversationSummary {
  final String? peerId;
  final String title;
  final bool isHost;
  final ChatMessage? lastMessage;

  const ConversationSummary({
    required this.peerId,
    required this.title,
    required this.isHost,
    required this.lastMessage,
  });

  bool get isGeneral => peerId == null;
}

/// Deriva la lista de conversaciones (General + una por cada otro
/// participante) a partir del log de mensajes de la sesión. Es pura —
/// no guarda estado — así que se puede recalcular cada vez que cambian
/// los miembros o llega un mensaje nuevo.
List<ConversationSummary> buildConversationSummaries(RoomSession session) {
  ChatMessage? lastGeneral;
  final lastPrivate = <String, ChatMessage>{};

  for (final m in session.messageLog) {
    if (m.type != MessageType.message) continue;
    if (m.recipientId == null) {
      lastGeneral = m;
    } else {
      final peer = m.senderId == session.mySenderId ? m.recipientId! : m.senderId;
      lastPrivate[peer] = m;
    }
  }

  final others = session.members.where((m) => m.id != session.mySenderId).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  return [
    ConversationSummary(peerId: null, title: 'General', isHost: false, lastMessage: lastGeneral),
    for (final m in others)
      ConversationSummary(peerId: m.id, title: m.name, isHost: m.isHost, lastMessage: lastPrivate[m.id]),
  ];
}
