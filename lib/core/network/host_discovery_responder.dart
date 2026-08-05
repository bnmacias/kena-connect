import 'dart:convert';
import 'dart:io';

import '../protocol/discovery_message.dart';

/// Corre en el host: escucha pedidos DISCOVER por UDP broadcast y responde
/// (unicast, directo al que preguntó) con la IP:puerto del servidor de
/// chat, para que el cliente no tenga que tipearla a mano.
class HostDiscoveryResponder {
  RawDatagramSocket? _socket;

  bool get isRunning => _socket != null;

  Future<void> start({required String hostName, required int chatPort}) async {
    if (_socket != null) return;

    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      DiscoveryMessage.discoveryPort,
    );
    socket.broadcastEnabled = true;
    _socket = socket;

    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;

      final message = DiscoveryMessage.tryDecode(datagram.data);
      if (message == null || message.type != DiscoveryMessageType.discover) return;

      final reply = DiscoveryMessage(
        type: DiscoveryMessageType.announce,
        hostName: hostName,
        chatPort: chatPort,
      );
      socket.send(utf8.encode(reply.encode()), datagram.address, datagram.port);
    });
  }

  void stop() {
    _socket?.close();
    _socket = null;
  }
}
