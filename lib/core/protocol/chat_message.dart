import 'dart:convert';

/// Tipos de mensaje soportados por el protocolo de FlightChat.
enum MessageType { join, message, presence, leave, ack }

extension _MessageTypeCodec on MessageType {
  String toWire() => name.toUpperCase();
}

MessageType _messageTypeFromWire(String? wire) {
  return MessageType.values.firstWhere(
    (t) => t.toWire() == wire,
    orElse: () => MessageType.message,
  );
}

/// Mensaje del protocolo, versionado para poder evolucionar el formato
/// sin romper compatibilidad entre host y clientes de distintas versiones.
class ChatMessage {
  static const int protocolVersion = 1;

  final int version;
  final MessageType type;
  final String senderId;
  final String senderName;
  final String? text;
  final int timestamp;

  ChatMessage({
    required this.type,
    required this.senderId,
    required this.senderName,
    this.text,
    int? timestamp,
    this.version = protocolVersion,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'v': version,
        'type': type.toWire(),
        'senderId': senderId,
        'senderName': senderName,
        if (text != null) 'text': text,
        'ts': timestamp,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        version: json['v'] is int ? json['v'] as int : protocolVersion,
        type: _messageTypeFromWire(json['type'] as String?),
        senderId: json['senderId'] as String? ?? '',
        senderName: json['senderName'] as String? ?? '?',
        text: json['text'] as String?,
        timestamp: json['ts'] is int
            ? json['ts'] as int
            : DateTime.now().millisecondsSinceEpoch,
      );

  String encode() => jsonEncode(toJson());

  static ChatMessage decode(String raw) =>
      ChatMessage.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
