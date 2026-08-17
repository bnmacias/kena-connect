import 'dart:async';

import '../../../core/network/chat_client_connection.dart';
import '../../../core/network/chat_host_server.dart';
import '../../../core/protocol/chat_message.dart';
import '../../../core/protocol/roster.dart';

/// Re-emite un stream de mensajes guardando un historial en memoria, así
/// cualquier pantalla que se abra más tarde (por ejemplo, un chat
/// privado que se abre después de varios mensajes) puede pintar lo que
/// ya pasó y no sólo lo que llegue de ahí en más.
class _MessageBus {
  final _log = <ChatMessage>[];
  final _controller = StreamController<ChatMessage>.broadcast();
  StreamSubscription<ChatMessage>? _sub;

  List<ChatMessage> get log => List.unmodifiable(_log);
  Stream<ChatMessage> get stream => _controller.stream;

  void attach(Stream<ChatMessage> source) {
    _sub = source.listen((m) {
      _log.add(m);
      if (!_controller.isClosed) _controller.add(m);
    });
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}

bool _isChatOrEditOrDelete(ChatMessage m) =>
    m.type == MessageType.message || m.type == MessageType.edited || m.type == MessageType.deletedForEveryone;

bool isGeneralMessage(ChatMessage m) =>
    (_isChatOrEditOrDelete(m) && m.recipientId == null) ||
    m.type == MessageType.join ||
    m.type == MessageType.leave;

bool isPrivateMessageBetween(ChatMessage m, String a, String b) =>
    _isChatOrEditOrDelete(m) &&
    m.recipientId != null &&
    ((m.senderId == a && m.recipientId == b) || (m.senderId == b && m.recipientId == a));

/// Une el rol (anfitrión/participante) con la sala a la que representa:
/// desde el punto de vista de la UI de la sala (bandeja, chat,
/// participantes) da exactamente lo mismo si detrás hay un
/// [ChatHostServer] o un [ChatClientConnection] — todo pasa por acá.
abstract class RoomSession {
  String get roomName;

  /// Sólo el anfitrión tiene código para compartir/invitar.
  String? get code;

  bool get isHost;
  String get mySenderId;
  String get myName;

  List<ChatMessage> get messageLog;
  Stream<ChatMessage> get messages;

  List<RoomMember> get members;
  Stream<List<RoomMember>> get membersStream;

  ConnectionStatus get currentStatus;
  Stream<ConnectionStatus> get statusStream;

  /// Señal complementaria a [statusStream]: `true` mientras se ve
  /// tráfico reciente del anfitrión, `false` si hay un silencio más
  /// largo de lo esperado con la conexión todavía técnicamente abierta
  /// (degradación previa a un corte). El anfitrión no tiene una versión
  /// de esto para sí mismo — su propio dispositivo no se "degrada"
  /// respecto de sí mismo.
  Stream<bool> get linkHealthy;

  /// Motivo que dio el anfitrión al cerrar la sala (finalización o
  /// transferencia), si lo hay — para mostrarlo tal cual en vez de un
  /// mensaje genérico.
  String? get closeReason;

  /// Emite el nombre de la sala cuando ESTE dispositivo fue elegido
  /// para continuarla como nuevo anfitrión — transferencia MANUAL
  /// (`RoomShellScreen._handlePromotion` reacciona con un diálogo propio
  /// y una pantalla nueva, porque ahí sí cambia el código de sala).
  Stream<String> get promotedToHostStream;

  /// Distinto del anterior: se emite cuando este dispositivo pasó a ser
  /// anfitrión de forma AUTOMÁTICA (el anfitrión anterior desapareció sin
  /// avisar — ver HOST_MIGRATION.md) — ahí, a propósito, no hay ningún
  /// diálogo ni pantalla nueva, el único indicio es la franja global. Se
  /// usa sólo para que esa franja diga "Ahora sos el anfitrión" en vez
  /// del texto genérico de reconexión (ver `ConnectionBanner`).
  Stream<void> get becameHostAutomaticallyStream;

  void sendGeneral(String text);
  void sendPrivate(String text, {required String toMemberId});

  /// Edita un mensaje propio ya enviado — llega a quienes ya lo habían
  /// visto (mismo destinatario que el mensaje original) como un evento
  /// que reemplaza el texto en su copia del log, marcado "editado". Sólo
  /// tiene sentido sobre mensajes propios — se impone desde la UI
  /// (`ChatThreadScreen`, sólo ofrece la opción en burbujas propias), no
  /// reforzado por el protocolo (ver ARCHITECTURE.md sobre el modelo de
  /// confianza de una red LAN sin cuentas).
  void editMessage(String messageId, String newText, {String? toMemberId});

  /// Borra un mensaje para todos los que ya lo habían visto (mismo
  /// destinatario que el original) — a diferencia de
  /// [hideMessageLocally], sí sale a la red.
  void deleteMessageForEveryone(String messageId, {String? toMemberId});

  /// Oculta un mensaje sólo en este dispositivo — nunca toca la red ni
  /// al resto de la sala. Implementación real sólo en
  /// `NotifyingRoomSession` (dueña del log persistido); en el resto es
  /// un no-op, mismo patrón que `setActiveThread`/`unreadCounts`.
  void hideMessageLocally(String messageId);

  /// Confirma la recepción (`MessageType.delivered`) o lectura
  /// (`MessageType.read`) de un mensaje ajeno — nunca se llama desde la
  /// UI directamente (ver `NotifyingRoomSession`, que es quien sabe qué
  /// hilo se está mirando y arma el acuse de lectura en el momento
  /// justo; el de entrega es automático en la capa de red, ver
  /// `ChatClientConnection`/`ChatHostServer`). [toMemberId] es el autor
  /// original del mensaje [targetMessageId] — a quien le vuelve el
  /// acuse, sea el mensaje original General o privado.
  void sendReceipt(MessageType type, {required String targetMessageId, required String toMemberId});

  /// Avisos efímeros de "está escribiendo" de otros miembros de la sala
  /// — `recipientId == null` es del hilo General, con valor es un aviso
  /// privado dirigido a mí. Nunca incluye mensajes propios (el
  /// anfitrión/servidor no hace eco de lo que uno mismo manda).
  Stream<ChatMessage> get typingEvents;

  /// Avisa a los demás que estoy (o dejé de estar) escribiendo en el
  /// hilo General (`toMemberId` ausente) o en un privado puntual.
  void sendTyping(bool isTyping, {String? toMemberId});

  /// Para un participante: se va de la sala. Para el anfitrión, no hay
  /// "irse" sin afectar a todos — usar [finishRoom] o [transferHostTo].
  Future<void> leaveRoom();

  /// Sólo el anfitrión puede finalizar la sala para todos.
  Future<void> finishRoom();

  /// Sólo el anfitrión puede transferir su rol a otro participante.
  Future<void> transferHostTo(RoomMember member);

  /// Qué hilo está mirando el usuario ahora mismo (`null` = General) —
  /// se usa para no generar notificación/no-leído de lo que ya está
  /// viendo.
  void setActiveThread(String? peerId);

  /// El usuario dejó de ver cualquier hilo (está en la bandeja, o salió
  /// de la sala).
  void clearActiveThread();

  Map<String?, int> get unreadCounts;
  Stream<Map<String?, int>> get unreadStream;

  /// Silenciar sonido/vibración/notificación de mensajes nuevos — el
  /// contador de no leídos se sigue actualizando igual.
  bool get isMuted;
  void setMuted(bool muted);

  /// Pedidos de ingreso esperando que el anfitrión los acepte o
  /// rechace (ver `ChatHostServer.requireApproval`) — sólo tiene algo
  /// real para el anfitrión de una sala creada con esa exigencia;
  /// siempre vacío para un participante (no le corresponde a él
  /// decidir quién más entra).
  List<PendingJoinRequest> get pendingJoinRequests;
  Stream<List<PendingJoinRequest>> get joinRequestsStream;
  void acceptJoinRequest(String connKey);
  void rejectJoinRequest(String connKey);

  void dispose();
}

class HostRoomSession implements RoomSession {
  HostRoomSession(this._server) {
    _bus.attach(_server.messages);
  }

  final ChatHostServer _server;
  final _bus = _MessageBus();
  final _status = StreamController<ConnectionStatus>.broadcast();

  @override
  String get roomName => _server.roomName;
  @override
  String? get code => _server.code;
  @override
  bool get isHost => true;
  @override
  String get mySenderId => ChatHostServer.hostSenderId;
  @override
  String get myName => _server.hostDisplayName;
  @override
  List<ChatMessage> get messageLog => _bus.log;
  @override
  Stream<ChatMessage> get messages => _bus.stream;
  @override
  List<RoomMember> get members => _server.members;
  @override
  Stream<List<RoomMember>> get membersStream => _server.membersStream;
  @override
  ConnectionStatus get currentStatus => ConnectionStatus.connected;
  @override
  Stream<ConnectionStatus> get statusStream => _status.stream;
  @override
  Stream<bool> get linkHealthy => const Stream.empty();
  @override
  String? get closeReason => null;
  @override
  Stream<String> get promotedToHostStream => const Stream.empty();
  @override
  Stream<void> get becameHostAutomaticallyStream => const Stream.empty();

  @override
  void sendGeneral(String text) => _server.sendGeneralFromHost(text);
  @override
  void sendPrivate(String text, {required String toMemberId}) =>
      _server.sendPrivateFromHost(text, toMemberId: toMemberId);
  @override
  void editMessage(String messageId, String newText, {String? toMemberId}) =>
      _server.editMessageFromHost(messageId, newText, toMemberId: toMemberId);
  @override
  void deleteMessageForEveryone(String messageId, {String? toMemberId}) =>
      _server.deleteMessageFromHost(messageId, toMemberId: toMemberId);
  @override
  void hideMessageLocally(String messageId) {}
  @override
  void sendReceipt(MessageType type, {required String targetMessageId, required String toMemberId}) =>
      _server.sendReceipt(type, targetId: targetMessageId, toMemberId: toMemberId);

  @override
  Stream<ChatMessage> get typingEvents => _server.typing;
  @override
  void sendTyping(bool isTyping, {String? toMemberId}) =>
      _server.sendTypingFromHost(isTyping, toMemberId: toMemberId);

  @override
  Future<void> leaveRoom() => finishRoom();
  @override
  Future<void> finishRoom() => _server.finishRoom();
  @override
  Future<void> transferHostTo(RoomMember member) =>
      _server.transferHostAndStop(successorId: member.id, successorName: member.name);

  @override
  void setActiveThread(String? peerId) {}
  @override
  void clearActiveThread() {}
  @override
  Map<String?, int> get unreadCounts => const {};
  @override
  Stream<Map<String?, int>> get unreadStream => const Stream.empty();
  @override
  bool get isMuted => false;
  @override
  void setMuted(bool muted) {}

  @override
  List<PendingJoinRequest> get pendingJoinRequests => _server.pendingJoinRequests;
  @override
  Stream<List<PendingJoinRequest>> get joinRequestsStream => _server.joinRequests;
  @override
  void acceptJoinRequest(String connKey) => _server.acceptJoinRequest(connKey);
  @override
  void rejectJoinRequest(String connKey) => _server.rejectJoinRequest(connKey);

  @override
  void dispose() {
    _bus.dispose();
    _status.close();
  }
}

class ParticipantRoomSession implements RoomSession {
  ParticipantRoomSession(
    this._connection, {
    required String roomName,
    required this.mySenderId,
    required this.myName,
    // El parámetro público se llama `roomName`; `this._roomName`
    // forzaría a que quien llame al constructor desde otro archivo
    // escriba un named arg con guión bajo, que en Dart es privado y no
    // se puede usar desde afuera del archivo.
    // ignore: prefer_initializing_formals
  }) : _roomName = roomName {
    _bus.attach(_connection.messages);
    _bus.stream.listen((m) {
      if (m.type == MessageType.roster) {
        _members = decodeRoster(m)
            .map((r) => RoomMember(id: r.id, name: r.name, isHost: r.isHost, joinOrder: r.joinOrder))
            .toList();
        _membersController.add(_members);
      } else if (m.type == MessageType.roomClosed) {
        _closeReason = m.text;
      } else if (m.type == MessageType.hostTransferOffer && m.recipientId == mySenderId) {
        _promotedController.add(m.text ?? _roomName);
      }
    });
    _connection.status.listen((s) => _statusController.add(s));
  }

  final ChatClientConnection _connection;
  final _bus = _MessageBus();
  final _membersController = StreamController<List<RoomMember>>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _promotedController = StreamController<String>.broadcast();
  List<RoomMember> _members = const [];
  String? _closeReason;
  final String _roomName;

  @override
  final String mySenderId;
  @override
  final String myName;

  @override
  String get roomName => _roomName;
  @override
  String? get code => null;
  @override
  bool get isHost => false;
  @override
  List<ChatMessage> get messageLog => _bus.log;
  @override
  Stream<ChatMessage> get messages => _bus.stream;
  @override
  List<RoomMember> get members => _members;
  @override
  Stream<List<RoomMember>> get membersStream => _membersController.stream;
  @override
  ConnectionStatus get currentStatus => _connection.isConnected ? ConnectionStatus.connected : ConnectionStatus.reconnecting;
  @override
  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  @override
  Stream<bool> get linkHealthy => _connection.healthy;
  @override
  String? get closeReason => _closeReason;
  @override
  Stream<String> get promotedToHostStream => _promotedController.stream;
  @override
  Stream<void> get becameHostAutomaticallyStream => const Stream.empty();

  @override
  void sendGeneral(String text) => _connection.send(text, senderId: mySenderId, senderName: myName);
  @override
  void sendPrivate(String text, {required String toMemberId}) =>
      _connection.send(text, senderId: mySenderId, senderName: myName, recipientId: toMemberId);
  @override
  void editMessage(String messageId, String newText, {String? toMemberId}) => _connection.editMessage(
        messageId,
        newText,
        senderId: mySenderId,
        senderName: myName,
        recipientId: toMemberId,
      );
  @override
  void deleteMessageForEveryone(String messageId, {String? toMemberId}) => _connection.deleteMessage(
        messageId,
        senderId: mySenderId,
        senderName: myName,
        recipientId: toMemberId,
      );
  @override
  void hideMessageLocally(String messageId) {}
  @override
  void sendReceipt(MessageType type, {required String targetMessageId, required String toMemberId}) =>
      _connection.sendReceipt(type, targetId: targetMessageId, toMemberId: toMemberId);

  @override
  Stream<ChatMessage> get typingEvents => _connection.typing;
  @override
  void sendTyping(bool isTyping, {String? toMemberId}) =>
      _connection.sendTyping(isTyping, senderId: mySenderId, senderName: myName, recipientId: toMemberId);

  /// No forma parte de [RoomSession] a propósito (es plomería específica
  /// de la conexión de un participante, irrelevante para el anfitrión)
  /// — usado por [ResilientRoomSession] para cortar el intento de
  /// reconexión propio cuando este dispositivo se hace cargo de la sala
  /// como nuevo anfitrión en una migración automática.
  void cancelReconnect() => _connection.cancelReconnect();

  @override
  Future<void> leaveRoom() => _connection.disconnect();
  @override
  Future<void> finishRoom() =>
      throw UnsupportedError('Sólo el anfitrión puede finalizar la sala.');
  @override
  Future<void> transferHostTo(RoomMember member) =>
      throw UnsupportedError('Sólo el anfitrión puede transferir su rol.');

  @override
  void setActiveThread(String? peerId) {}
  @override
  void clearActiveThread() {}
  @override
  Map<String?, int> get unreadCounts => const {};
  @override
  Stream<Map<String?, int>> get unreadStream => const Stream.empty();
  @override
  bool get isMuted => false;
  @override
  void setMuted(bool muted) {}

  @override
  List<PendingJoinRequest> get pendingJoinRequests => const [];
  @override
  Stream<List<PendingJoinRequest>> get joinRequestsStream => const Stream.empty();
  @override
  void acceptJoinRequest(String connKey) {}
  @override
  void rejectJoinRequest(String connKey) {}

  @override
  void dispose() {
    _bus.dispose();
    _membersController.close();
    _statusController.close();
    _promotedController.close();
  }
}
