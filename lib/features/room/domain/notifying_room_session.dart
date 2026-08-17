import 'dart:async';

import '../../../core/network/chat_client_connection.dart';
import '../../../core/network/chat_host_server.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/protocol/chat_message.dart';
import '../../../core/utils/chat_history_store.dart';
import 'room_session.dart';

/// Envuelve cualquier [RoomSession] (anfitrión o participante — no le
/// importa cuál) y le agrega lo que ninguna de las dos implementaciones
/// de red necesita saber: qué hilo está mirando el usuario ahora mismo,
/// cuántos mensajes no leídos hay por hilo, cuándo avisar (sonido +
/// vibración + notificación local) por un mensaje nuevo, y — a
/// diferencia de antes — persistir el log localmente para no perderlo
/// si la app se va a segundo plano y el sistema la mata (ver
/// `ChatHistoryStore` y ROADMAP.md → "Persistir el chat localmente").
///
/// Sólo se generan avisos para mensajes reales (no para join/leave/
/// roster/etc.) que no sean propios y que no pertenezcan al hilo que ya
/// se está mirando.
class NotifyingRoomSession implements RoomSession {
  NotifyingRoomSession(
    this._inner, {
    required this.roomCode,
    List<ChatMessage> restoredHistory = const [],
  }) {
    _log.addAll(restoredHistory);
    _log.addAll(_inner.messageLog);
    _sub = _inner.messages.listen(_handleMessage);
  }

  final RoomSession _inner;

  /// Código de la sala — es lo que identifica de forma estable a qué
  /// snapshot local corresponde este chat (ver `ChatHistoryStore`). No
  /// es lo mismo que [code] (esa es la vidriera pública, sólo para el
  /// anfitrión); esto es puertas adentro, siempre presente.
  final String roomCode;

  late final StreamSubscription<ChatMessage> _sub;

  final _log = <ChatMessage>[];
  final _logController = StreamController<ChatMessage>.broadcast();
  Timer? _persistDebounce;
  DateTime? _burstStartedAt;

  final Map<String?, int> _unread = {};
  final _unreadController = StreamController<Map<String?, int>>.broadcast();

  bool _viewingThread = false;
  String? _activePeerId;
  bool _muted = false;

  /// Ids de mensajes ajenos por los que ya se mandó acuse de lectura —
  /// evita reenviarlo cada vez que se vuelve a entrar al mismo hilo (ver
  /// [_markThreadRead]).
  final _readAcked = <String>{};

  void _handleMessage(ChatMessage m) {
    // Acuse de entrega/lectura ajeno: no es una fila del chat, muta el
    // `deliveryStatus` del mensaje propio al que se refiere (por
    // `targetId`) — nunca hacia atrás (ver `deliveryStatusRank`), así un
    // `delivered` que llega después de un `read` de otro destinatario no
    // le hace perder el tilde ya mostrado. Se reenvía igual por
    // `_logController` para que `ChatThreadScreen` actualice la burbuja
    // ya dibujada.
    if ((m.type == MessageType.delivered || m.type == MessageType.read) && m.targetId != null) {
      final idx = _log.indexWhere((e) => e.id == m.targetId);
      if (idx != -1) {
        final next = m.type == MessageType.read ? MessageDeliveryStatus.read : MessageDeliveryStatus.delivered;
        if (deliveryStatusRank(next) > deliveryStatusRank(_log[idx].deliveryStatus)) {
          _log[idx].deliveryStatus = next;
        }
      }
      _logController.add(m);
      return;
    }
    // Edición/borrado: mutan la fila del mensaje original en vez de
    // agregar una fila propia — el log persistido tiene que reflejar el
    // estado final, no una lista de eventos crudos. Se reenvía igual por
    // `_logController` (sin tocar `_log` de nuevo) para que
    // `ChatThreadScreen` — que mantiene su propia copia en pantalla —
    // aplique la misma mutación sin tener que releer todo el log.
    if (m.type == MessageType.edited && m.targetId != null) {
      final idx = _log.indexWhere((e) => e.id == m.targetId);
      if (idx != -1) {
        _log[idx].text = m.text;
        _log[idx].edited = true;
      }
      _logController.add(m);
      _schedulePersist();
      return;
    }
    if (m.type == MessageType.deletedForEveryone && m.targetId != null) {
      _log.removeWhere((e) => e.id == m.targetId);
      _logController.add(m);
      _schedulePersist();
      return;
    }

    _log.add(m);
    _logController.add(m);
    _schedulePersist();

    if (m.type != MessageType.message) return;
    if (m.senderId == mySenderId) return;

    final String? threadKey;
    if (m.recipientId == null) {
      threadKey = null;
    } else if (m.recipientId == mySenderId) {
      threadKey = m.senderId;
    } else {
      return; // privado entre otras dos personas: no es para mí.
    }

    if (_viewingThread && _activePeerId == threadKey) {
      // Ya lo estás mirando — no hace falta avisar con una notificación
      // completa (banner + sonido de notificación), pero tampoco debería
      // pasar en silencio total: un tick corto y distinto (sin banner)
      // para no confundirlo con un mensaje que sí necesita atención en
      // otro lado. Además cuenta como leído en el momento: se ve en la
      // pantalla que ya está abierta, no hace falta esperar a que
      // vuelva a entrar al hilo.
      if (!_muted) NotificationService.instance.playSoftTick();
      _ackRead(m);
      return;
    }

    _unread[threadKey] = (_unread[threadKey] ?? 0) + 1;
    _unreadController.add(Map.unmodifiable(_unread));

    if (_muted) return;
    final title = threadKey == null ? roomName : m.senderName;
    final body = threadKey == null ? '${m.senderName}: ${m.text ?? ''}' : (m.text ?? '');
    NotificationService.instance.showMessage(
      title: title,
      body: body,
      threadKey: threadKey ?? '__general__',
    );
  }

  void _ackRead(ChatMessage m) {
    if (!_readAcked.add(m.id)) return;
    _inner.sendReceipt(MessageType.read, targetMessageId: m.id, toMemberId: m.senderId);
  }

  /// Al entrar a un hilo, marca como leído todo lo que ya estaba ahí sin
  /// acusar todavía (llegó mientras se miraba otro hilo o la bandeja) —
  /// sin esto, sólo se acusaba lectura de lo que llegaba EN VIVO con el
  /// hilo ya abierto, nunca de lo que ya estaba esperando al entrar.
  void _markThreadRead(String? threadKey) {
    for (final m in _log) {
      if (m.type != MessageType.message) continue;
      if (m.senderId == mySenderId) continue;
      final belongsHere = threadKey == null ? m.recipientId == null : (m.recipientId == mySenderId && m.senderId == threadKey);
      if (!belongsHere) continue;
      _ackRead(m);
    }
  }

  /// Techo máximo que puede durar una ráfaga sin guardarse — ver
  /// [_schedulePersist].
  static const _maxPersistGap = Duration(seconds: 4);

  /// Debounce corto: agrupa ráfagas de mensajes seguidos en una sola
  /// escritura a disco en vez de una por mensaje. Pero sólo debounce: un
  /// chat activo sin pausas de 1.2s reinicia el timer sin parar y nunca
  /// llegaría a guardar nada — si la app se cierra a la fuerza en medio
  /// de esa ráfaga, se pierde toda la conversación (no sólo el último
  /// mensaje). Por eso hay un techo: `_burstStartedAt` marca cuándo
  /// empezó la ráfaga actual sin guardar; si ya pasaron
  /// [_maxPersistGap] desde ahí, se guarda ya mismo en vez de
  /// reprogramar de nuevo, sin importar que sigan llegando mensajes.
  void _schedulePersist() {
    _persistDebounce?.cancel();
    final burstStart = _burstStartedAt ??= DateTime.now();
    if (DateTime.now().difference(burstStart) >= _maxPersistGap) {
      _persistNow();
      return;
    }
    _persistDebounce = Timer(const Duration(milliseconds: 1200), _persistNow);
  }

  void _persistNow() {
    _persistDebounce?.cancel();
    _burstStartedAt = null;
    ChatHistoryStore.save(code: roomCode, roomName: roomName, messages: List.of(_log));
  }

  @override
  bool get isMuted => _muted;
  @override
  void setMuted(bool muted) => _muted = muted;

  @override
  void setActiveThread(String? peerId) {
    _viewingThread = true;
    _activePeerId = peerId;
    if ((_unread[peerId] ?? 0) != 0) {
      _unread[peerId] = 0;
      _unreadController.add(Map.unmodifiable(_unread));
    }
    _markThreadRead(peerId);
  }

  @override
  void clearActiveThread() {
    _viewingThread = false;
    _activePeerId = null;
  }

  @override
  Map<String?, int> get unreadCounts => Map.unmodifiable(_unread);
  @override
  Stream<Map<String?, int>> get unreadStream => _unreadController.stream;

  // El resto es un simple delegate al RoomSession real.
  @override
  String get roomName => _inner.roomName;
  @override
  String? get code => _inner.code;
  @override
  bool get isHost => _inner.isHost;
  @override
  String get mySenderId => _inner.mySenderId;
  @override
  String get myName => _inner.myName;
  @override
  List<ChatMessage> get messageLog => List.unmodifiable(_log);
  @override
  Stream<ChatMessage> get messages => _logController.stream;
  @override
  List<RoomMember> get members => _inner.members;
  @override
  Stream<List<RoomMember>> get membersStream => _inner.membersStream;
  @override
  ConnectionStatus get currentStatus => _inner.currentStatus;
  @override
  Stream<ConnectionStatus> get statusStream => _inner.statusStream;
  @override
  Stream<bool> get linkHealthy => _inner.linkHealthy;
  @override
  String? get closeReason => _inner.closeReason;
  @override
  Stream<String> get promotedToHostStream => _inner.promotedToHostStream;
  @override
  Stream<void> get becameHostAutomaticallyStream => _inner.becameHostAutomaticallyStream;

  @override
  void sendGeneral(String text) => _inner.sendGeneral(text);
  @override
  void sendPrivate(String text, {required String toMemberId}) => _inner.sendPrivate(text, toMemberId: toMemberId);
  @override
  void editMessage(String messageId, String newText, {String? toMemberId}) =>
      _inner.editMessage(messageId, newText, toMemberId: toMemberId);
  @override
  void deleteMessageForEveryone(String messageId, {String? toMemberId}) =>
      _inner.deleteMessageForEveryone(messageId, toMemberId: toMemberId);

  /// Única implementación real (ver la doc en `RoomSession`) — muta el
  /// log persistido directamente, sin pasar por la red. No hace falta
  /// reenviar nada por `_logController`: quien la llama (`ChatThreadScreen`)
  /// ya sabe qué mensaje ocultó y actualiza su propia copia en el mismo
  /// gesto del usuario.
  @override
  void hideMessageLocally(String messageId) {
    final removed = _log.any((m) => m.id == messageId);
    if (!removed) return;
    _log.removeWhere((m) => m.id == messageId);
    _schedulePersist();
  }

  @override
  void sendReceipt(MessageType type, {required String targetMessageId, required String toMemberId}) =>
      _inner.sendReceipt(type, targetMessageId: targetMessageId, toMemberId: toMemberId);

  @override
  Stream<ChatMessage> get typingEvents => _inner.typingEvents;
  @override
  void sendTyping(bool isTyping, {String? toMemberId}) => _inner.sendTyping(isTyping, toMemberId: toMemberId);
  @override
  Future<void> leaveRoom() => _inner.leaveRoom();
  @override
  Future<void> finishRoom() => _inner.finishRoom();
  @override
  Future<void> transferHostTo(RoomMember member) => _inner.transferHostTo(member);

  @override
  List<PendingJoinRequest> get pendingJoinRequests => _inner.pendingJoinRequests;
  @override
  Stream<List<PendingJoinRequest>> get joinRequestsStream => _inner.joinRequestsStream;
  @override
  void acceptJoinRequest(String connKey) => _inner.acceptJoinRequest(connKey);
  @override
  void rejectJoinRequest(String connKey) => _inner.rejectJoinRequest(connKey);

  @override
  void dispose() {
    _persistDebounce?.cancel();
    _persistNow();
    _sub.cancel();
    _logController.close();
    _unreadController.close();
    _inner.dispose();
  }
}
