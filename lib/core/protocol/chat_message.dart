import 'dart:convert';
import 'dart:math';

/// Tipos de mensaje soportados por el protocolo de chat de una sala.
///
/// `roster`, `roomClosed` y `hostTransferOffer` son mensajes de control
/// que emite el anfitrión (no un participante): `roster` sincroniza la
/// lista de miembros a todos cada vez que cambia, `roomClosed` avisa
/// antes de cerrar la sala para que los participantes vean un mensaje
/// claro en vez de un corte de socket sin explicación, y
/// `hostTransferOffer` es un mensaje privado al participante elegido
/// para que continúe la sala como nuevo anfitrión.
///
/// `typing` es un mensaje de control efímero (nunca se guarda en el log
/// de mensajes) que cualquiera puede emitir: `text` lleva `"1"` (empezó
/// a escribir) o `"0"` (dejó de escribir), y `recipientId` funciona
/// igual que en un mensaje normal (`null` = hilo General, con valor =
/// hilo privado con ese destinatario).
///
/// `edited`/`deletedForEveryone` referencian a otro mensaje por
/// [ChatMessage.targetId] (su [ChatMessage.id]) — nunca se guardan como
/// una fila propia en el log, mutan la fila del mensaje original en
/// quien las procesa (ver `NotifyingRoomSession`/`ChatThreadScreen`).
/// Van dirigidas al mismo `recipientId` que el mensaje original, para
/// que sólo quien podía ver ese mensaje se entere de que cambió. Borrar
/// "sólo para mí" no tiene tipo de mensaje propio — no sale a la red,
/// es puramente local (ver `RoomSession.hideMessageLocally`).
///
/// `delivered`/`read` son acuses de recibo — igual que `edited`, van
/// dirigidas puntualmente a quien mandó el mensaje original
/// ([ChatMessage.recipientId] = ese remitente, sin importar si el
/// mensaje original era General o privado) y lo referencian por
/// [ChatMessage.targetId]. Las genera automáticamente la capa de red
/// apenas un mensaje llega a un dispositivo (`delivered`) o cuando el
/// usuario efectivamente lo ve en pantalla (`read`, ver
/// `NotifyingRoomSession`) — nunca las arma la UI a mano.
enum MessageType {
  join,
  message,
  presence,
  leave,
  roster,
  roomClosed,
  hostTransferOffer,
  typing,
  edited,
  deletedForEveryone,
  delivered,
  read,
}

/// Estado de entrega tal como lo ve el dispositivo que mandó el
/// mensaje — nunca viaja por la red (ver [ChatMessage.deliveryStatus]);
/// lo que sí viaja son los acuses (`MessageType.delivered`/`.read`) que
/// lo actualizan. `delivered` = al menos un destinatario lo recibió;
/// `read` = al menos un destinatario lo tuvo abierto en pantalla. Para
/// un chat General con varios participantes esto es deliberadamente
/// "el mejor estado visto" y no "todos" (como si fuera un chat 1 a 1):
/// suficiente para esta app, sin necesitar rastrear un estado por
/// destinatario.
enum MessageDeliveryStatus { sending, sent, delivered, read, failed }

/// Orden de "qué tan avanzado" está un estado de entrega — permite que
/// un acuse que llega fuera de orden (por ejemplo, un `delivered` que
/// llega después de que ya había llegado un `read` de otro destinatario)
/// nunca haga retroceder el tilde ya mostrado.
int deliveryStatusRank(MessageDeliveryStatus? status) {
  switch (status) {
    case null:
    case MessageDeliveryStatus.sending:
      return 0;
    case MessageDeliveryStatus.sent:
      return 1;
    case MessageDeliveryStatus.delivered:
      return 2;
    case MessageDeliveryStatus.read:
      return 3;
    case MessageDeliveryStatus.failed:
      return -1;
  }
}

extension _MessageTypeCodec on MessageType {
  String toWire() => name.toUpperCase();
}

MessageType _messageTypeFromWire(String? wire) {
  return MessageType.values.firstWhere(
    (t) => t.toWire() == wire,
    orElse: () => MessageType.message,
  );
}

String _generateId(String senderId, int timestamp) =>
    '$senderId-$timestamp-${Random.secure().nextInt(1 << 31)}';

/// Mensaje del protocolo, versionado para poder evolucionar el formato
/// sin romper compatibilidad entre dispositivos de distintas versiones.
class ChatMessage {
  static const int protocolVersion = 2;

  final int version;
  final MessageType type;
  final String senderId;
  final String senderName;

  /// Mutable a propósito: una edición (`MessageType.edited`) mutan el
  /// texto de la fila ya existente en el log en vez de agregar una fila
  /// nueva — ver `NotifyingRoomSession`/`ChatThreadScreen`.
  String? text;
  final int timestamp;

  /// Identificador estable de ESTE mensaje — lo que permite que una
  /// edición/borrado posterior lo referencie sin ambigüedad (antes no
  /// existía: no había forma de decir "el mensaje tal" sin depender de
  /// posición en una lista, frágil ante reordenamientos/duplicados).
  final String id;

  /// Sólo en `MessageType.edited`/`deletedForEveryone`: el [id] del
  /// mensaje al que se refiere esta edición/borrado.
  final String? targetId;

  /// `true` si este mensaje fue editado — se muestra como una etiqueta
  /// discreta ("editado") junto a la hora, igual que WhatsApp/Telegram,
  /// para no esconder que el contenido cambió.
  bool edited;

  /// `null` = mensaje del chat General (todos lo ven).
  /// Si tiene valor, es un mensaje privado dirigido puntualmente a ese
  /// `senderId` (el anfitrión lo reenvía sólo a ese destinatario, nunca
  /// al resto de la sala).
  final String? recipientId;

  /// Sólo local: nunca se serializa ni viaja por la red. Mutable a
  /// propósito — permite actualizar el mismo objeto en memoria (mismo
  /// mensaje que ya está en el log/la UI) de `sending` a `sent`/`failed`
  /// sin tener que reconciliar listas por id. `null` en un mensaje
  /// recibido (no tiene sentido "estado de entrega" de lo que mandó
  /// otro).
  MessageDeliveryStatus? deliveryStatus;

  ChatMessage({
    required this.type,
    required this.senderId,
    required this.senderName,
    this.text,
    this.recipientId,
    this.targetId,
    this.edited = false,
    int? timestamp,
    String? id,
    this.version = protocolVersion,
  })  : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch,
        id = id ?? _generateId(senderId, timestamp ?? DateTime.now().millisecondsSinceEpoch);

  /// Un mensaje (de chat o de control) es privado si tiene destinatario.
  bool get isPrivate => recipientId != null;

  Map<String, dynamic> toJson() => {
        'v': version,
        'type': type.toWire(),
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        if (text != null) 'text': text,
        if (recipientId != null) 'recipientId': recipientId,
        if (targetId != null) 'targetId': targetId,
        if (edited) 'edited': true,
        'ts': timestamp,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final ts = json['ts'] is int ? json['ts'] as int : DateTime.now().millisecondsSinceEpoch;
    final senderId = json['senderId'] as String? ?? '';
    return ChatMessage(
      version: json['v'] is int ? json['v'] as int : protocolVersion,
      type: _messageTypeFromWire(json['type'] as String?),
      // Compatibilidad con historial guardado antes de que existiera
      // `id` (ChatHistoryStore) — se sintetiza uno estable a partir de
      // remitente+hora en vez de romper la carga.
      id: json['id'] as String? ?? _generateId(senderId, ts),
      senderId: senderId,
      senderName: json['senderName'] as String? ?? '?',
      text: json['text'] as String?,
      recipientId: json['recipientId'] as String?,
      targetId: json['targetId'] as String?,
      edited: json['edited'] as bool? ?? false,
      timestamp: ts,
    );
  }

  String encode() => jsonEncode(toJson());

  static ChatMessage decode(String raw) =>
      ChatMessage.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
