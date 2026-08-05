import 'dart:async';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../protocol/chat_message.dart';

/// Conexión de cliente: se conecta a un host WebSocket en `ip:puerto`
/// (manual o descubierto automáticamente).
class ChatClientConnection {
  WebSocketChannel? _channel;
  final _messages = StreamController<ChatMessage>.broadcast();
  final _connected = StreamController<bool>.broadcast();

  Stream<ChatMessage> get messages => _messages.stream;
  Stream<bool> get connectionState => _connected.stream;
  bool get isConnected => _channel != null;

  Future<void> connect(String host, int port) async {
    final uri = Uri(scheme: 'ws', host: host, port: port);
    final channel = IOWebSocketChannel.connect(uri);

    // Espera a que el socket TCP subyacente termine de conectar antes de
    // confirmar el estado "conectado"; si falla, ready lanza la excepción.
    await channel.ready;

    _channel = channel;
    channel.stream.listen(
      (raw) {
        try {
          _messages.add(ChatMessage.decode(raw as String));
        } catch (_) {}
      },
      onDone: () {
        _channel = null;
        _connected.add(false);
      },
      onError: (_) {
        _channel = null;
        _connected.add(false);
      },
    );

    _connected.add(true);
  }

  void send(String text, {required String senderId, required String senderName}) {
    final channel = _channel;
    if (channel == null) return;
    final message = ChatMessage(
      type: MessageType.message,
      senderId: senderId,
      senderName: senderName,
      text: text,
    );
    channel.sink.add(message.encode());
    // El host no nos reenvía nuestro propio mensaje (evita el eco), así
    // que lo agregamos localmente para que el remitente también lo vea.
    _messages.add(message);
  }

  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
    _connected.add(false);
  }
}
