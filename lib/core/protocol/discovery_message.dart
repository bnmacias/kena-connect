import 'dart:convert';

/// Mensajes del protocolo de descubrimiento (UDP broadcast), separado del
/// protocolo de chat: un cliente pregunta "¿hay algún host?" (DISCOVER) y
/// cada host que escucha responde con su nombre y puerto (ANNOUNCE).
enum DiscoveryMessageType { discover, announce }

extension _DiscoveryMessageTypeCodec on DiscoveryMessageType {
  String toWire() => this == DiscoveryMessageType.discover ? 'DISCOVER' : 'ANNOUNCE';
}

class DiscoveryMessage {
  static const int protocolVersion = 1;

  /// Puerto UDP fijo en el que los hosts escuchan pedidos de descubrimiento.
  /// Distinto del puerto del servidor de chat (que puede variar).
  static const int discoveryPort = 45892;

  final int version;
  final DiscoveryMessageType type;
  final String hostName;
  final int chatPort;

  DiscoveryMessage({
    required this.type,
    required this.hostName,
    required this.chatPort,
    this.version = protocolVersion,
  });

  Map<String, dynamic> toJson() => {
        'v': version,
        'type': type.toWire(),
        'hostName': hostName,
        'chatPort': chatPort,
      };

  String encode() => jsonEncode(toJson());

  /// A diferencia de ChatMessage.decode, acá devolvemos null en vez de
  /// lanzar: en la red UDP local puede llegar cualquier basura y no
  /// queremos que un paquete inesperado tire abajo el listener.
  static DiscoveryMessage? tryDecode(List<int> bytes) {
    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final typeWire = json['type'] as String?;
      if (typeWire != 'DISCOVER' && typeWire != 'ANNOUNCE') return null;
      return DiscoveryMessage(
        version: json['v'] is int ? json['v'] as int : protocolVersion,
        type: typeWire == 'DISCOVER' ? DiscoveryMessageType.discover : DiscoveryMessageType.announce,
        hostName: json['hostName'] as String? ?? '?',
        chatPort: json['chatPort'] is int ? json['chatPort'] as int : 0,
      );
    } catch (_) {
      return null;
    }
  }
}
