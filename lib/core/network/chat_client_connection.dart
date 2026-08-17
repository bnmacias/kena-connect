import 'dart:async';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../protocol/chat_message.dart';
import 'host_discovery_scanner.dart';

/// Estado de la conexión de un participante con la sala, tal como se le
/// muestra al usuario (sin ningún detalle de sockets/red).
enum ConnectionStatus {
  /// Todo bien, mensajes van y vienen.
  connected,

  /// Se cortó de golpe (wifi, anfitrión que colgó, etc.) y se está
  /// reintentando reconectar solo, sin que el usuario tenga que hacer nada.
  reconnecting,

  /// Se agotaron los reintentos: hay que volver a intentar unirse a mano.
  lost,

  /// El anfitrión finalizó la sala explícitamente.
  closedByHost,
}

/// Conexión de un participante con la sala (resuelta por código/QR o
/// descubierta automáticamente). Si el corte es inesperado, reintenta
/// reconectar solo unas cuantas veces antes de rendirse.
class ChatClientConnection {
  ChatClientConnection({HostDiscoveryScanner? scanner}) : _scanner = scanner ?? HostDiscoveryScanner();

  /// Reintentos directos al mismo `host:puerto` antes de asumir que ya
  /// no está ahí y pasar a buscar la sala por código (más lento, así
  /// que no conviene entrar demasiado rápido — pero tampoco hace falta
  /// agotar minutos enteros golpeando una puerta que no va a abrir).
  static const _maxReconnectAttempts = 3;

  /// Cuántas veces sigue buscando la sala por su código (en vez de
  /// rendirse) una vez agotados los reintentos directos al
  /// `host:puerto` conocido. Cubre tanto un alejamiento temporal (la
  /// sala sigue ahí, hay que volver a encontrarla) como una migración
  /// automática de anfitrión (la sala sigue existiendo con el mismo
  /// código, pero en otra IP:puerto) — ver HOST_MIGRATION.md.
  static const _maxDiscoverySearchAttempts = 20;

  /// Si no llega ningún latido/mensaje del anfitrión en esta ventana
  /// (más del doble del intervalo de latido, para tolerar uno perdido
  /// sin generar un falso positivo), la conexión se marca inestable
  /// aunque el socket TCP siga técnicamente abierto.
  static const _staleThreshold = Duration(seconds: 9);
  static const _staleCheckInterval = Duration(seconds: 2);

  final HostDiscoveryScanner _scanner;

  WebSocketChannel? _channel;
  final _messages = StreamController<ChatMessage>.broadcast();
  final _status = StreamController<ConnectionStatus>.broadcast();
  final _typing = StreamController<ChatMessage>.broadcast();
  final _healthy = StreamController<bool>.broadcast();

  String? _host;
  int? _port;
  String? _code;
  String? _senderId;
  String? _senderName;
  bool _leaving = false;
  bool _roomClosed = false;
  bool _reconnectCancelled = false;
  int _reconnectAttempts = 0;
  DateTime _lastActivityAt = DateTime.now();
  bool _isHealthy = true;
  Timer? _staleChecker;
  final _outbox = <ChatMessage>[];

  Stream<ChatMessage> get messages => _messages.stream;
  Stream<ConnectionStatus> get status => _status.stream;

  /// Avisos efímeros de "está escribiendo" (nunca pasa por [messages]).
  Stream<ChatMessage> get typing => _typing.stream;

  /// `true` = se ve tráfico reciente del anfitrión (latido u otro
  /// mensaje). `false` = silencio más largo de lo esperado con el
  /// socket todavía abierto — probable degradación de la red antes de
  /// que llegue a cortarse del todo. No reemplaza a [status]: es una
  /// señal complementaria sólo válida mientras [status] es `connected`.
  Stream<bool> get healthy => _healthy.stream;
  bool get isConnected => _channel != null;

  Future<void> connect(
    String host,
    int port, {
    required String senderId,
    required String senderName,
    // Si se pasa, un corte inesperado no sólo reintenta el mismo
    // host:puerto — también vuelve a buscar la sala por este código
    // (ver [_attemptReconnect]) antes de rendirse.
    String? code,
  }) async {
    _host = host;
    _port = port;
    _code = code;
    _senderId = senderId;
    _senderName = senderName;
    _leaving = false;
    _roomClosed = false;
    _reconnectCancelled = false;
    _reconnectAttempts = 0;
    await _openSocket();
  }

  /// Sin esto, un intento de conexión que ni se acepta ni se rechaza
  /// activamente (típico si el destino ya no está pero la red todavía
  /// no lo sabe — por ejemplo, reconectarse justo después de salir de
  /// una sala) puede quedarse esperando muchísimo más de lo que
  /// cualquier usuario va a tolerar, con la pantalla de "Conectando…"
  /// congelada porque nada vuelve a resolver la espera.
  static const _connectTimeout = Duration(seconds: 8);

  Future<void> _openSocket() async {
    final uri = Uri(scheme: 'ws', host: _host, port: _port);
    final channel = IOWebSocketChannel.connect(uri);

    // Espera a que el socket TCP subyacente termine de conectar antes de
    // confirmar el estado "conectado"; si falla, ready lanza la excepción.
    try {
      await channel.ready.timeout(_connectTimeout);
    } catch (e) {
      // Si el intento abandonado termina completando igual más tarde
      // (llegó a conectar recién después del timeout), no lo dejamos
      // como un socket huérfano sin nadie escuchando — se cierra solo,
      // en segundo plano, sin bloquear a quien llamó.
      unawaited(channel.ready.then((_) => channel.sink.close()).catchError((_) {}));
      rethrow;
    }

    _channel = channel;
    channel.stream.listen(_onRaw, onDone: _onSocketClosed, onError: (_) => _onSocketClosed());

    // Se anuncia a los demás participantes (y le permite al anfitrión
    // sumarlo a la lista del lobby con su nombre real).
    channel.sink.add(
      ChatMessage(type: MessageType.join, senderId: _senderId!, senderName: _senderName!).encode(),
    );

    _lastActivityAt = DateTime.now();
    _setHealthy(true);
    _staleChecker?.cancel();
    _staleChecker = Timer.periodic(_staleCheckInterval, (_) => _checkStale());

    _status.add(ConnectionStatus.connected);
    _flushOutbox();
  }

  void _setHealthy(bool value) {
    if (_isHealthy == value) return;
    _isHealthy = value;
    _healthy.add(value);
  }

  void _checkStale() {
    if (_channel == null) return;
    final silence = DateTime.now().difference(_lastActivityAt);
    _setHealthy(silence <= _staleThreshold);
  }

  void _onRaw(dynamic raw) {
    _lastActivityAt = DateTime.now();
    _setHealthy(true);
    try {
      final message = ChatMessage.decode(raw as String);
      if (message.type == MessageType.typing) {
        _typing.add(message);
        return;
      }
      // El latido del anfitrión ya cumplió su función (refrescar
      // _lastActivityAt arriba) — no es un mensaje de chat, no entra al
      // log ni genera ningún aviso visible.
      if (message.type == MessageType.presence) return;
      if (message.type == MessageType.roomClosed) _roomClosed = true;
      // Acuse automático de "me llegó": ver el protocolo en
      // chat_message.dart. Sólo mensajes de chat reales, nunca sobre
      // mensajes propios (el anfitrión no hace eco de lo que uno mismo
      // mandó, así que en la práctica esto nunca dispara para un
      // `senderId` propio, pero conviene dejarlo explícito).
      if (message.type == MessageType.message && message.senderId != _senderId) {
        sendReceipt(MessageType.delivered, targetId: message.id, toMemberId: message.senderId);
      }
      _messages.add(message);
    } catch (_) {}
  }

  void _onSocketClosed() {
    _channel = null;
    _staleChecker?.cancel();
    _staleChecker = null;
    if (_leaving) return;
    if (_roomClosed) {
      _status.add(ConnectionStatus.closedByHost);
      return;
    }
    _attemptReconnect();
  }

  bool get _stopReconnecting => _leaving || _reconnectCancelled;

  Future<void> _attemptReconnect() async {
    _status.add(ConnectionStatus.reconnecting);
    while (_reconnectAttempts < _maxReconnectAttempts && !_stopReconnecting) {
      _reconnectAttempts++;
      await Future.delayed(Duration(seconds: _reconnectAttempts * 2));
      if (_stopReconnecting) return;
      try {
        await _openSocket();
        _reconnectAttempts = 0;
        return;
      } catch (_) {
        // Sigue reintentando hasta agotar los intentos.
      }
    }
    if (_stopReconnecting) return;

    final code = _code;
    if (code == null) {
      _status.add(ConnectionStatus.lost);
      return;
    }
    await _searchByCode(code);
  }

  /// El `host:puerto` conocido dejó de responder — puede ser que nos
  /// alejamos y la sala sigue ahí (sección 11 del brief) o que otro
  /// dispositivo tomó la posta como anfitrión con el mismo código
  /// (migración automática). En los dos casos, la salida es la misma:
  /// volver a buscar la sala por su código como si fuera la primera vez.
  Future<void> _searchByCode(String code) async {
    var searchAttempts = 0;
    while (searchAttempts < _maxDiscoverySearchAttempts && !_stopReconnecting) {
      searchAttempts++;
      try {
        final found = await _scanner.findByCode(code, timeout: const Duration(seconds: 3));
        if (found != null && !_stopReconnecting) {
          _host = found.address;
          _port = found.port;
          await _openSocket();
          _reconnectAttempts = 0;
          return;
        }
      } catch (_) {
        // Sigue buscando hasta agotar los intentos.
      }
      if (_stopReconnecting) return;
      await Future.delayed(Duration(seconds: searchAttempts.clamp(1, 6)));
    }
    if (!_stopReconnecting) _status.add(ConnectionStatus.lost);
  }

  /// Deja de intentar reconectar sin cerrar nada más — usado cuando
  /// otra cosa (una migración automática de anfitrión en este mismo
  /// dispositivo) se hace cargo de la continuidad de la sala en vez de
  /// esta conexión. A diferencia de [disconnect], no marca `_leaving`
  /// (no es una salida voluntaria del usuario) ni toca el socket (ya
  /// está cerrado — si no, no habría reconexión en curso).
  void cancelReconnect() {
    _reconnectCancelled = true;
  }

  /// [recipientId] ausente = mensaje del chat General; presente =
  /// mensaje privado dirigido puntualmente a ese participante.
  ///
  /// Nunca se pierde en silencio: si no hay conexión en este momento,
  /// el mensaje igual se muestra localmente (marcado `failed`) y queda
  /// en cola para reintentarse solo apenas la conexión vuelva — antes,
  /// mandar un mensaje estando desconectado lo hacía desaparecer sin
  /// ningún aviso (sección 42 del brief).
  void send(
    String text, {
    required String senderId,
    required String senderName,
    String? recipientId,
  }) {
    final message = ChatMessage(
      type: MessageType.message,
      senderId: senderId,
      senderName: senderName,
      text: text,
      recipientId: recipientId,
    );
    _dispatch(message);
    // El anfitrión no nos reenvía nuestro propio mensaje (evita el eco),
    // así que lo agregamos localmente para que el remitente también lo vea.
    _messages.add(message);
  }

  /// [recipientId] tiene que ser el mismo destinatario que tenía el
  /// mensaje original ([messageId]) — ver [ChatMessage.targetId].
  void editMessage(
    String messageId,
    String newText, {
    required String senderId,
    required String senderName,
    String? recipientId,
  }) {
    final message = ChatMessage(
      type: MessageType.edited,
      senderId: senderId,
      senderName: senderName,
      text: newText,
      targetId: messageId,
      recipientId: recipientId,
    );
    _dispatch(message);
    _messages.add(message);
  }

  /// Borrado "para todos" — ver [editMessage] sobre el destinatario.
  /// Borrar "sólo para mí" nunca sale a la red (ver
  /// `RoomSession.hideMessageLocally`).
  void deleteMessage(
    String messageId, {
    required String senderId,
    required String senderName,
    String? recipientId,
  }) {
    final message = ChatMessage(
      type: MessageType.deletedForEveryone,
      senderId: senderId,
      senderName: senderName,
      targetId: messageId,
      recipientId: recipientId,
    );
    _dispatch(message);
    _messages.add(message);
  }

  /// Confirma la recepción (`delivered`, automático — ver [_onRaw]) o la
  /// lectura (`read`, disparado por `NotifyingRoomSession` cuando el
  /// usuario efectivamente mira el hilo) de un mensaje ajeno. Best-effort
  /// a propósito, sin cola de reintento propia: perder un acuse puntual
  /// sólo deja un tilde atrasado, nunca un mensaje perdido — no amerita
  /// la misma garantía que [send].
  void sendReceipt(MessageType type, {required String targetId, required String toMemberId}) {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(
        ChatMessage(
          type: type,
          senderId: _senderId!,
          senderName: _senderName!,
          targetId: targetId,
          recipientId: toMemberId,
        ).encode(),
      );
    } catch (_) {}
  }

  void _dispatch(ChatMessage message) {
    final channel = _channel;
    if (channel == null) {
      message.deliveryStatus = MessageDeliveryStatus.failed;
      _outbox.add(message);
      return;
    }
    try {
      channel.sink.add(message.encode());
      message.deliveryStatus = MessageDeliveryStatus.sent;
    } catch (_) {
      message.deliveryStatus = MessageDeliveryStatus.failed;
      _outbox.add(message);
    }
  }

  /// Reintenta en orden todo lo que quedó pendiente de la última vez
  /// que hubo conexión — se llama apenas se vuelve a abrir el socket
  /// (reconexión directa, migración de anfitrión, o simplemente volver
  /// a acercarse). Cada mensaje reintentado se vuelve a emitir por
  /// [messages] (mismo objeto, `deliveryStatus` actualizado) para que
  /// la burbuja ya dibujada en pantalla se actualice sola.
  void _flushOutbox() {
    if (_outbox.isEmpty) return;
    final pending = List<ChatMessage>.of(_outbox);
    _outbox.clear();
    for (final message in pending) {
      _dispatch(message);
      _messages.add(message);
    }
  }

  /// Avisa que este dispositivo está (o dejó de estar) escribiendo.
  /// No se agrega al log local (es efímero) ni se reintenta si falla —
  /// perder un aviso de "escribiendo" no es grave, el timeout del lado
  /// de quien lo recibe lo cubre.
  void sendTyping(
    bool isTyping, {
    required String senderId,
    required String senderName,
    String? recipientId,
  }) {
    final channel = _channel;
    if (channel == null) return;
    channel.sink.add(
      ChatMessage(
        type: MessageType.typing,
        senderId: senderId,
        senderName: senderName,
        text: isTyping ? '1' : '0',
        recipientId: recipientId,
      ).encode(),
    );
  }

  /// Salida voluntaria: no dispara el mecanismo de reconexión automática.
  Future<void> disconnect() async {
    _leaving = true;
    _staleChecker?.cancel();
    _staleChecker = null;
    await _channel?.sink.close();
    _channel = null;
  }
}
