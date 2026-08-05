import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../protocol/discovery_message.dart';

class DiscoveredHost {
  final String name;
  final String address;
  final int port;

  const DiscoveredHost({
    required this.name,
    required this.address,
    required this.port,
  });
}

/// Corre en el cliente: manda un DISCOVER por broadcast y junta las
/// respuestas ANNOUNCE que lleguen dentro de la ventana de [timeout].
class HostDiscoveryScanner {
  Future<List<DiscoveredHost>> scan({Duration timeout = const Duration(seconds: 3)}) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;

    final found = <String, DiscoveredHost>{};
    final done = Completer<void>();

    final subscription = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;

      final message = DiscoveryMessage.tryDecode(datagram.data);
      if (message == null || message.type != DiscoveryMessageType.announce) return;

      final key = '${datagram.address.address}:${message.chatPort}';
      found[key] = DiscoveredHost(
        name: message.hostName,
        address: datagram.address.address,
        port: message.chatPort,
      );
    });

    final request = DiscoveryMessage(
      type: DiscoveryMessageType.discover,
      hostName: '',
      chatPort: 0,
    );
    socket.send(
      utf8.encode(request.encode()),
      InternetAddress('255.255.255.255'),
      DiscoveryMessage.discoveryPort,
    );

    Timer(timeout, () {
      if (!done.isCompleted) done.complete();
    });
    await done.future;
    await subscription.cancel();
    socket.close();

    return found.values.toList();
  }
}
