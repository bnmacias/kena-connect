import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../protocol/chat_message.dart';
import '../protocol/roster.dart';
import '../utils/connection_code.dart';

/// Un dispositivo en la sala, tal como se muestra en el lobby y en la
/// lista de participantes: el anfitrión (este dispositivo) más cada
/// participante que se identificó con un mensaje de tipo `join`.
class RoomMember {
  final String id;
  final String name;
  final bool isHost;

  /// Orden de llegada asignado por el anfitrión (0 para el propio
  /// anfitrión). Es la base de la elección de sucesor en una migración
  /// automática de anfitrión — ver HOST_MIGRATION.md.
  final int joinOrder;

  const RoomMember({required this.id, required this.name, required this.isHost, this.joinOrder = 0});
}

/// Alguien pidió unirse a una sala que exige aprobación del anfitrión
/// (ver `ChatHostServer.requireApproval`) y todavía está esperando que
/// se acepte o se rechace su pedido — ver `ChatHostServer.acceptJoinRequest`/
/// `rejectJoinRequest`.
class PendingJoinRequest {
  final String connKey;
  final String senderId;
  final String senderName;

  const PendingJoinRequest({required this.connKey, required this.senderId, required this.senderName});
}

class _Connection {
  final WebSocketChannel channel;
  String? senderId;
  String? name;
  int joinOrder = 0;

  _Connection(this.channel);
}

/// Levanta un servidor WebSocket local para una sala y hace de relay de
/// mensajes entre los dispositivos conectados:
///  - mensajes generales (sin destinatario): a todos menos el que
///    los mandó;
///  - mensajes privados (con destinatario): únicamente al dispositivo
///    dueño de ese `senderId`, nunca al resto.
///
/// También mantiene la lista de miembros de la sala (a partir de los
/// `join`/`leave` del protocolo) y la sincroniza a todos los
/// dispositivos vía `MessageType.roster` para que la lista de
/// participantes se vea igual en cualquier dispositivo, no sólo en el
/// del anfitrión.
class ChatHostServer {
  static const int defaultPort = 8080;
  static const String hostSenderId = 'host';

  /// Cada cuánto el anfitrión manda un latido a todos — es lo que le
  /// permite a cada participante notar una degradación de la red antes
  /// de que el socket TCP subyacente llegue a cortarse solo (en redes
  /// móviles/Wi-Fi eso puede tardar minutos por el keepalive del SO).
  static const heartbeatInterval = Duration(seconds: 4);

  HttpServer? _server;
  Timer? _heartbeat;
  final Map<String, _Connection> _connections = {};
  final Map<String, _Connection> _bySenderId = {};
  final _messages = StreamController<ChatMessage>.broadcast();
  final _members = StreamController<List<RoomMember>>.broadcast();
  final _typing = StreamController<ChatMessage>.broadcast();
  int _nextJoinOrder = 1;

  /// Buffer acotado de mensajes de chat/edición/borrado que pasaron por
  /// este anfitrión (General y privados en los que participó, como
  /// remitente, destinatario, o relay entre otros dos) — permite
  /// reenviarle a alguien que se reconecta lo que se perdió mientras
  /// estuvo desconectado (ver [_replayMissed]). No es historial
  /// persistido (eso es [ChatHistoryStore], por dispositivo): esto vive
  /// sólo en memoria del anfitrión mientras la sala existe.
  final _recentMessages = <ChatMessage>[];
  static const _maxRecentMessages = 500;

  /// Cuándo se desconectó por última vez cada `senderId` visto — permite
  /// distinguir en `join` un ingreso nuevo (nada que reenviar) de una
  /// reconexión (reenviar lo que pasó desde ese momento). Se borra la
  /// entrada apenas se usa, para no arrastrarla para siempre.
  final Map<String, DateTime> _lastSeenAt = {};

  /// `true` mientras la sala exige que el anfitrión apruebe cada
  /// ingreso NUEVO antes de dejarlo participar (ver `start`) — corrige
  /// un bug real de seguridad reportado por uso: en una red compartida
  /// (por ejemplo, el wifi de un avión), cualquiera que detectara la
  /// sala entraba directo con un toque, sin que el anfitrión tuviera
  /// ninguna chance de decir que no. No aplica a reconexiones de
  /// alguien que ya había sido aceptado antes (ver `_lastSeenAt` en
  /// `_handleIncoming`) — sólo a caras nuevas.
  bool _requireApproval = false;

  /// Conexiones que ya mandaron `join` pero todavía esperan que el
  /// anfitrión decida — no son parte de la sala todavía: no aparecen en
  /// el roster, no reciben broadcasts, y cualquier mensaje que manden
  /// que no sea el `join` inicial se ignora (ver `_handleIncoming`).
  final Map<String, _Connection> _pending = {};
  final _joinRequests = StreamController<List<PendingJoinRequest>>.broadcast();

  String _roomName = '';
  String _hostDisplayName = '';
  late String code;

  Stream<ChatMessage> get messages => _messages.stream;
  Stream<List<RoomMember>> get membersStream => _members.stream;

  /// Pedidos de ingreso pendientes de aceptar/rechazar, en vivo — sólo
  /// tiene algo mientras `requireApproval` esté activo. Ver
  /// `acceptJoinRequest`/`rejectJoinRequest`.
  Stream<List<PendingJoinRequest>> get joinRequests => _joinRequests.stream;
  List<PendingJoinRequest> get pendingJoinRequests => [
        for (final entry in _pending.entries)
          PendingJoinRequest(connKey: entry.key, senderId: entry.value.senderId!, senderName: entry.value.name ?? '?'),
      ];

  /// Avisos efímeros de "está escribiendo" dirigidos al anfitrión (como
  /// destinatario de un privado, o como observador del General). Nunca
  /// pasa por [messages]: no es un mensaje de chat.
  Stream<ChatMessage> get typing => _typing.stream;
  int get connectedCount => _bySenderId.length;
  bool get isRunning => _server != null;
  String get roomName => _roomName;
  String get hostDisplayName => _hostDisplayName;

  List<RoomMember> get members => [
        RoomMember(id: hostSenderId, name: _hostDisplayName, isHost: true),
        for (final entry in _connections.entries)
          if (entry.value.senderId != null && !_pending.containsKey(entry.key))
            RoomMember(id: entry.value.senderId!, name: entry.value.name ?? '?', isHost: false, joinOrder: entry.value.joinOrder),
      ];

  Future<void> start({
    required String roomName,
    required String hostDisplayName,
    int port = defaultPort,
    String? code,
    bool requireApproval = false,
  }) async {
    if (_server != null) return;
    _roomName = roomName;
    _hostDisplayName = hostDisplayName;
    _requireApproval = requireApproval;
    this.code = code ?? generateConnectionCode();

    final handler = webSocketHandler((WebSocketChannel webSocket, String? protocol) {
      final connKey = '${DateTime.now().microsecondsSinceEpoch}';
      final conn = _Connection(webSocket);
      _connections[connKey] = conn;

      webSocket.stream.listen(
        (raw) => _handleIncoming(connKey, raw as String),
        onDone: () => _handleDisconnect(connKey),
        onError: (_) => _handleDisconnect(connKey),
      );
    });

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    _heartbeat = Timer.periodic(heartbeatInterval, (_) {
      final ping = ChatMessage(type: MessageType.presence, senderId: hostSenderId, senderName: _hostDisplayName);
      _broadcastToAll(ping.encode());
    });
  }

  void _handleIncoming(String connKey, String raw) {
    try {
      final incoming = ChatMessage.decode(raw);
      final conn = _connections[connKey];
      if (conn == null) return;

      // Todavía esperando que el anfitrión decida: no participa de la
      // sala en absoluto — ni manda ni recibe nada más que la eventual
      // respuesta a su `join` (ver `acceptJoinRequest`/`rejectJoinRequest`).
      if (_pending.containsKey(connKey) && incoming.type != MessageType.join) return;

      if (incoming.type == MessageType.join) {
        // Ya fue aceptado antes (se está reconectando, no es cara
        // nueva): entra directo, sin volver a pedir aprobación — si no,
        // cada corte de wifi obligaría al anfitrión a aprobar de nuevo a
        // gente que ya estaba en la sala.
        final isReconnection = _lastSeenAt.containsKey(incoming.senderId);
        if (_requireApproval && !isReconnection) {
          conn.senderId = incoming.senderId;
          conn.name = incoming.senderName;
          _pending[connKey] = conn;
          _joinRequests.add(pendingJoinRequests);
          return;
        }
        _admitMember(connKey, conn, incoming, raw);
        return;
      }

      if (incoming.type == MessageType.typing) {
        // Efímero a propósito: nunca entra al log de mensajes (no debe
        // aparecer en el chat ni afectar no-leídos/notificaciones).
        if (incoming.recipientId == null) {
          _broadcastToOthers(raw, exceptConnKey: connKey);
          _typing.add(incoming); // el anfitrión también mira el General.
        } else if (incoming.recipientId == hostSenderId) {
          _typing.add(incoming);
        } else {
          _bySenderId[incoming.recipientId]?.channel.sink.add(raw);
        }
        return;
      }

      // Acuses de entrega/lectura: siempre punto a punto hacia quien
      // mandó el mensaje original (ver ChatMessage.targetId), nunca un
      // broadcast — aunque el mensaje original haya sido General, el
      // acuse en sí sólo le interesa a su autor. Tiene que resolverse
      // ANTES del branch genérico de abajo, que si no los trataría como
      // "cualquier cosa que no sea mensaje/edición/borrado" y los
      // mandaría a todo el mundo.
      if (incoming.type == MessageType.delivered || incoming.type == MessageType.read) {
        if (incoming.recipientId == hostSenderId) {
          _messages.add(incoming);
        } else if (incoming.recipientId != null) {
          _bySenderId[incoming.recipientId]?.channel.sink.add(raw);
        }
        return;
      }

      // Una edición/borrado va dirigida al mismo destinatario que el
      // mensaje original (ver ChatMessage.targetId) — tiene que rutear
      // exactamente igual que un mensaje normal, no como un control
      // genérico de "se lo manda a todos" (si no, un privado editado se
      // filtraría a gente que nunca vio el mensaje original).
      if (incoming.type != MessageType.message &&
          incoming.type != MessageType.edited &&
          incoming.type != MessageType.deletedForEveryone) {
        // presence u otros mensajes de control que pudiera mandar un
        // participante: se tratan como generales.
        _messages.add(incoming);
        _broadcastToOthers(raw, exceptConnKey: connKey);
        return;
      }

      _recordRecent(incoming);

      if (incoming.recipientId == null) {
        // Chat General: todos lo ven.
        _messages.add(incoming);
        _broadcastToOthers(raw, exceptConnKey: connKey);
        // El anfitrión también es un destinatario más del General — si
        // el mensaje no es propio, acusa recibo como cualquier otro.
        if (incoming.type == MessageType.message) {
          sendReceipt(MessageType.delivered, targetId: incoming.id, toMemberId: incoming.senderId);
        }
        return;
      }

      // Privado: sólo lo ve su destinatario. Si el destinatario es el
      // propio anfitrión, además se lo mostramos a su UI.
      if (incoming.recipientId == hostSenderId) {
        _messages.add(incoming);
        if (incoming.type == MessageType.message) {
          sendReceipt(MessageType.delivered, targetId: incoming.id, toMemberId: incoming.senderId);
        }
        return;
      }
      _bySenderId[incoming.recipientId]?.channel.sink.add(raw);
    } catch (_) {
      // Mensaje malformado: se ignora (protocolo versionado en el futuro
      // podría loguear/ACKear el error en vez de descartar en silencio).
    }
  }

  /// Suma a [conn] como miembro real de la sala: le asigna orden de
  /// llegada, lo hace visible en el roster, y le reenvía lo que se haya
  /// perdido si esto era una reconexión — el mismo camino tanto para un
  /// `join` que entra directo (sala sin aprobación, o reconexión de
  /// alguien ya conocido) como para uno que el anfitrión acaba de
  /// aceptar a mano (ver [acceptJoinRequest]).
  void _admitMember(String connKey, _Connection conn, ChatMessage incoming, String raw) {
    conn.senderId = incoming.senderId;
    conn.name = incoming.senderName;
    conn.joinOrder = _nextJoinOrder++;
    _bySenderId[incoming.senderId] = conn;
    _messages.add(incoming);
    _broadcastToOthers(raw, exceptConnKey: connKey);
    _broadcastRoster();
    _replayMissed(incoming.senderId, conn);
  }

  /// El anfitrión acepta a alguien que estaba esperando aprobación —
  /// recién ahí pasa a ser parte de la sala de verdad.
  void acceptJoinRequest(String connKey) {
    final conn = _pending.remove(connKey);
    if (conn == null) return;
    _joinRequests.add(pendingJoinRequests);
    final joinMsg = ChatMessage(type: MessageType.join, senderId: conn.senderId!, senderName: conn.name!);
    _admitMember(connKey, conn, joinMsg, joinMsg.encode());
  }

  /// El anfitrión rechaza el pedido: nunca llegó a ser miembro (no hay
  /// roster ni "se unió" que deshacer), así que sólo le avisamos por qué
  /// y cerramos su conexión — reusa `roomClosed` en vez de un tipo de
  /// mensaje nuevo, ya sabe mostrar un motivo claro en vez de un corte
  /// de socket sin explicación (ver `ParticipantRoomSession`).
  void rejectJoinRequest(String connKey) {
    final conn = _pending.remove(connKey);
    if (conn == null) return;
    _joinRequests.add(pendingJoinRequests);
    final closed = ChatMessage(
      type: MessageType.roomClosed,
      senderId: hostSenderId,
      senderName: _hostDisplayName,
      text: 'El anfitrión no aceptó tu pedido para unirte a "$_roomName".',
    );
    conn.channel.sink.add(closed.encode());
    unawaited(conn.channel.sink.close());
  }

  void _handleDisconnect(String connKey) {
    // Si se fue (cerró la app, se le cortó la red) mientras esperaba
    // aprobación, no queda ningún pedido pendiente que mostrarle al
    // anfitrión.
    if (_pending.remove(connKey) != null) _joinRequests.add(pendingJoinRequests);
    final conn = _connections.remove(connKey);
    if (conn == null) return;

    // Si este mismo participante ya se había reconectado con un socket
    // nuevo (nuevo `join` reemplazó la entrada de `_bySenderId` por esa
    // conexión más reciente) antes de que este evento de desconexión
    // — del socket VIEJO — llegara a procesarse, hay que dejar esa
    // entrada más nueva intacta: si se borra igual sin este chequeo,
    // `sendPrivateFromHost`/los privados entrantes dejan de encontrar al
    // participante (`_bySenderId[toMemberId]` da `null`) aunque siga
    // conectado de verdad — el chat General no se nota porque no depende
    // de esta tabla. Por el mismo motivo, tampoco corresponde avisar
    // "se perdió la conexión" ni tocar el roster: el participante nunca
    // se fue, sólo se vio reflejado tarde un corte que ya se resolvió.
    final isCurrentConnection = conn.senderId == null || _bySenderId[conn.senderId] == conn;
    if (!isCurrentConnection) return;

    if (conn.senderId != null) {
      _bySenderId.remove(conn.senderId);
      _lastSeenAt[conn.senderId!] = DateTime.now();
    }

    final leave = ChatMessage(
      type: MessageType.leave,
      senderId: conn.senderId ?? connKey,
      senderName: conn.name ?? 'Alguien',
    );
    _messages.add(leave);
    _broadcastToAll(leave.encode());
    _broadcastRoster();
  }

  /// El anfitrión también puede escribir en el chat General: se emite
  /// localmente (para la propia UI) y se broadcastea a la sala. Siempre
  /// "sale" del dispositivo (a diferencia de un privado, no depende de
  /// que un destinatario puntual esté conectado ahora mismo).
  void sendGeneralFromHost(String text) {
    final message = ChatMessage(
      type: MessageType.message,
      senderId: hostSenderId,
      senderName: _hostDisplayName,
      text: text,
    )..deliveryStatus = MessageDeliveryStatus.sent;
    _recordRecent(message);
    _messages.add(message);
    _broadcastToAll(message.encode());
  }

  /// El anfitrión inicia/responde una conversación privada con un
  /// participante puntual. Si ese participante no está conectado ahora
  /// mismo, se marca `failed` en vez de desaparecer en silencio — el
  /// anfitrión no tiene cola de reintento propia (a diferencia de un
  /// participante, ver `ChatClientConnection._flushOutbox`): normalmente
  /// está conectado a sí mismo todo el tiempo que la sala existe.
  void sendPrivateFromHost(String text, {required String toMemberId}) {
    final recipient = _bySenderId[toMemberId];
    final message = ChatMessage(
      type: MessageType.message,
      senderId: hostSenderId,
      senderName: _hostDisplayName,
      text: text,
      recipientId: toMemberId,
    )..deliveryStatus = recipient == null ? MessageDeliveryStatus.failed : MessageDeliveryStatus.sent;
    _recordRecent(message);
    _messages.add(message);
    recipient?.channel.sink.add(message.encode());
  }

  /// Igual que [sendGeneralFromHost]/[sendPrivateFromHost] pero para una
  /// edición: [toMemberId] tiene que ser el mismo destinatario que tenía
  /// el mensaje original ([messageId]), o no le va a llegar a quien
  /// corresponde.
  void editMessageFromHost(String messageId, String newText, {String? toMemberId}) {
    final message = ChatMessage(
      type: MessageType.edited,
      senderId: hostSenderId,
      senderName: _hostDisplayName,
      text: newText,
      targetId: messageId,
      recipientId: toMemberId,
    );
    _recordRecent(message);
    _messages.add(message);
    if (toMemberId == null) {
      _broadcastToAll(message.encode());
    } else if (toMemberId != hostSenderId) {
      _bySenderId[toMemberId]?.channel.sink.add(message.encode());
    }
  }

  /// Borrado "para todos" — ver [editMessageFromHost] sobre el
  /// destinatario. Borrar "sólo para mí" nunca sale a la red (ver
  /// `RoomSession.hideMessageLocally`).
  void deleteMessageFromHost(String messageId, {String? toMemberId}) {
    final message = ChatMessage(
      type: MessageType.deletedForEveryone,
      senderId: hostSenderId,
      senderName: _hostDisplayName,
      targetId: messageId,
      recipientId: toMemberId,
    );
    _recordRecent(message);
    _messages.add(message);
    if (toMemberId == null) {
      _broadcastToAll(message.encode());
    } else if (toMemberId != hostSenderId) {
      _bySenderId[toMemberId]?.channel.sink.add(message.encode());
    }
  }

  /// El anfitrión avisa que está (o dejó de estar) escribiendo.
  /// [toMemberId] ausente = lo ven todos en General; con valor, sólo ese
  /// participante lo ve (conversación privada).
  void sendTypingFromHost(bool isTyping, {String? toMemberId}) {
    final message = ChatMessage(
      type: MessageType.typing,
      senderId: hostSenderId,
      senderName: _hostDisplayName,
      text: isTyping ? '1' : '0',
      recipientId: toMemberId,
    );
    if (toMemberId == null) {
      _broadcastToAll(message.encode());
    } else {
      _bySenderId[toMemberId]?.channel.sink.add(message.encode());
    }
  }

  /// Confirma la recepción (`delivered`, automático apenas un mensaje
  /// entra al anfitrión — ver [_handleIncoming]) o la lectura (`read`,
  /// disparado por `NotifyingRoomSession` cuando el anfitrión mismo mira
  /// el hilo) de un mensaje ajeno, hacia [toMemberId] (su autor
  /// original). Nunca hace falta acusar sobre un mensaje propio del
  /// anfitrión — [toMemberId] siempre es un participante real.
  void sendReceipt(MessageType type, {required String targetId, required String toMemberId}) {
    final message = ChatMessage(
      type: type,
      senderId: hostSenderId,
      senderName: _hostDisplayName,
      targetId: targetId,
      recipientId: toMemberId,
    );
    _bySenderId[toMemberId]?.channel.sink.add(message.encode());
  }

  void _recordRecent(ChatMessage message) {
    _recentMessages.add(message);
    if (_recentMessages.length > _maxRecentMessages) {
      _recentMessages.removeRange(0, _recentMessages.length - _maxRecentMessages);
    }
  }

  /// Le reenvía a [conn] lo que se perdió mientras estuvo desconectado,
  /// si esto es una reconexión (`_lastSeenAt` sólo tiene entrada para
  /// alguien que ya se había ido antes) — corrige un bug real: al
  /// recuperar la conexión, los mensajes que otros mandaron mientras
  /// tanto no llegaban nunca (ver ROADMAP.md → "Sincronizar historial de
  /// mensajes también para quien se une tarde"). No repite lo que el
  /// propio [senderId] mandó estando desconectado — eso ya le llega por
  /// su propia cola de reintento (`ChatClientConnection._flushOutbox`)
  /// apenas reconecta, y reenviarlo desde acá también lo duplicaría.
  void _replayMissed(String senderId, _Connection conn) {
    final since = _lastSeenAt.remove(senderId);
    if (since == null) return;
    final sinceMs = since.millisecondsSinceEpoch;
    for (final message in _recentMessages) {
      if (message.timestamp <= sinceMs) continue;
      if (message.senderId == senderId) continue;
      final forThem = message.recipientId == null || message.recipientId == senderId;
      if (!forThem) continue;
      conn.channel.sink.add(message.encode());
    }
  }

  void _broadcastRoster() {
    final roster =
        members.map((m) => RosterMember(id: m.id, name: m.name, isHost: m.isHost, joinOrder: m.joinOrder)).toList();
    _broadcastToAll(buildRosterMessage(roster).encode());
    _members.add(members);
  }

  // Las dos excluyen a quien todavía está esperando aprobación
  // (`_pending`) — mientras no sea miembro de verdad no tiene que ver
  // nada de lo que pasa en la sala (roster, mensajes, latido), o la
  // aprobación sería sólo de forma.
  void _broadcastToAll(String raw) {
    for (final entry in _connections.entries) {
      if (_pending.containsKey(entry.key)) continue;
      entry.value.channel.sink.add(raw);
    }
  }

  void _broadcastToOthers(String raw, {required String exceptConnKey}) {
    for (final entry in _connections.entries) {
      if (entry.key == exceptConnKey) continue;
      if (_pending.containsKey(entry.key)) continue;
      entry.value.channel.sink.add(raw);
    }
  }

  /// El anfitrión finaliza la sala para todos: avisa antes de cortar la
  /// conexión para que cada participante vea un mensaje claro en vez de
  /// un corte de socket sin explicación.
  Future<void> finishRoom() async {
    final closed = ChatMessage(
      type: MessageType.roomClosed,
      senderId: hostSenderId,
      senderName: _hostDisplayName,
    );
    _broadcastToAll(closed.encode());
    // Le da un instante a los sockets para efectivamente mandar el aviso
    // antes de cerrarlos de golpe.
    await Future.delayed(const Duration(milliseconds: 150));
    await stop();
  }

  /// El anfitrión le pasa la posta a [successorId]: le manda una oferta
  /// privada para que continúe la sala (arrancando su propia conexión
  /// local con el mismo nombre), y al resto le avisa que la sala actual
  /// termina y por qué — no hay forma de migrar la IP:puerto en vivo, así
  /// que quienes no sean el sucesor van a tener que volver a unirse con
  /// el código nuevo que el sucesor comparta.
  Future<void> transferHostAndStop({required String successorId, required String successorName}) async {
    final offer = ChatMessage(
      type: MessageType.hostTransferOffer,
      senderId: hostSenderId,
      senderName: _hostDisplayName,
      text: _roomName,
      recipientId: successorId,
    );
    _bySenderId[successorId]?.channel.sink.add(offer.encode());

    final closed = ChatMessage(
      type: MessageType.roomClosed,
      senderId: hostSenderId,
      senderName: _hostDisplayName,
      text: 'El anfitrión transfirió "$_roomName" a $successorName. '
          'Pedile el código nuevo para volver a unirte.',
    );
    for (final conn in _connections.values) {
      if (conn.senderId == successorId) continue;
      conn.channel.sink.add(closed.encode());
    }

    await Future.delayed(const Duration(milliseconds: 150));
    await stop();
  }

  Future<void> stop() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    // Copiamos los canales y limpiamos los mapas antes de cerrarlos: si
    // un participante se desconecta mientras cerramos (dispara
    // _handleDisconnect, que muta _connections), iterar el mapa "en
    // vivo" con un await adentro del loop revienta con
    // ConcurrentModificationError y el servidor nunca llega a cerrarse,
    // dejando el puerto ocupado.
    final channels = _connections.values.map((c) => c.channel).toList();
    _connections.clear();
    _bySenderId.clear();
    _pending.clear();
    for (final channel in channels) {
      try {
        await channel.sink.close();
      } catch (_) {
        // Un participante ya desconectado no debería impedir cerrar el server.
      }
    }
    await _server?.close(force: true);
    _server = null;
  }
}
