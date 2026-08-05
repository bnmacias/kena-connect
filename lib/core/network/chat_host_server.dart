import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../protocol/chat_message.dart';

/// Levanta un servidor WebSocket local y hace broadcast de cualquier
/// mensaje recibido de un cliente a todos los demás clientes conectados.
class ChatHostServer {
  static const int defaultPort = 8080;
  static const String hostSenderId = 'host';

  HttpServer? _server;
  final Map<String, WebSocketChannel> _clients = {};
  final _messages = StreamController<ChatMessage>.broadcast();

  Stream<ChatMessage> get messages => _messages.stream;
  int get connectedClients => _clients.length;
  bool get isRunning => _server != null;

  Future<void> start({int port = defaultPort, required String hostName}) async {
    if (_server != null) return;

    final handler = webSocketHandler((WebSocketChannel webSocket, String? protocol) {
      final clientId = '${DateTime.now().microsecondsSinceEpoch}';
      _clients[clientId] = webSocket;

      webSocket.stream.listen(
        (raw) => _handleIncoming(clientId, raw as String),
        onDone: () => _handleDisconnect(clientId),
        onError: (_) => _handleDisconnect(clientId),
      );
    });

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  }

  void _handleIncoming(String clientId, String raw) {
    try {
      final incoming = ChatMessage.decode(raw);
      _messages.add(incoming);
      _broadcastRaw(raw, exceptClientId: clientId);
    } catch (_) {
      // Mensaje malformado: se ignora (protocolo versionado en el futuro
      // podría loguear/ACKear el error en vez de descartar en silencio).
    }
  }

  void _handleDisconnect(String clientId) {
    if (_clients.remove(clientId) == null) return;
    final leave = ChatMessage(
      type: MessageType.leave,
      senderId: clientId,
      senderName: 'client-$clientId',
    );
    _messages.add(leave);
    _broadcastRaw(leave.encode());
  }

  /// El host también puede escribir mensajes: se emiten localmente
  /// (para la propia UI del host) y se broadcastean a los clientes.
  void sendFromHost(String text, {required String hostName}) {
    final message = ChatMessage(
      type: MessageType.message,
      senderId: hostSenderId,
      senderName: hostName,
      text: text,
    );
    _messages.add(message);
    _broadcastRaw(message.encode());
  }

  void _broadcastRaw(String raw, {String? exceptClientId}) {
    for (final entry in _clients.entries) {
      if (entry.key == exceptClientId) continue;
      entry.value.sink.add(raw);
    }
  }

  Future<void> stop() async {
    // Copiamos los canales y limpiamos el mapa antes de cerrarlos: si un
    // cliente se desconecta mientras cerramos (dispara _handleDisconnect,
    // que muta _clients), iterar el mapa "en vivo" con un await adentro
    // del loop revienta con ConcurrentModificationError y el servidor
    // nunca llega a cerrarse, dejando el puerto ocupado.
    final channels = _clients.values.toList();
    _clients.clear();
    for (final channel in channels) {
      try {
        await channel.sink.close();
      } catch (_) {
        // Un cliente ya desconectado no debería impedir cerrar el server.
      }
    }
    await _server?.close(force: true);
    _server = null;
  }
}
