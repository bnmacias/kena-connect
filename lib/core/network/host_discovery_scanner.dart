import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../protocol/discovery_message.dart';

class DiscoveredHost {
  final String connectionName;
  final String code;
  final String address;
  final int port;

  const DiscoveredHost({
    required this.connectionName,
    required this.code,
    required this.address,
    required this.port,
  });
}

/// Corre en el dispositivo que se quiere unir: manda un DISCOVER por
/// broadcast y junta las respuestas ANNOUNCE que lleguen dentro de la
/// ventana de [timeout].
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
        connectionName: message.connectionName,
        code: message.code,
        address: datagram.address.address,
        port: message.chatPort,
      );
    });

    final request = DiscoveryMessage(
      type: DiscoveryMessageType.discover,
      connectionName: '',
      code: '',
      chatPort: 0,
    );
    final payload = utf8.encode(request.encode());
    socket.send(payload, InternetAddress('255.255.255.255'), DiscoveryMessage.discoveryPort);
    // El broadcast "global" de arriba depende de que el sistema operativo
    // elija sola la interfaz de salida correcta — y no siempre acierta:
    // un dispositivo que está transmitiendo su propia Zona Wi-Fi (en vez
    // de ser cliente de una) no tiene una "red por defecto" clara desde
    // el punto de vista de Android, así que el broadcast global puede
    // salir por datos móviles (o por ninguna interfaz real) y nunca
    // llegar a su propia red local — el caso concreto es el anfitrión
    // original de una sala intentando reunirse a ella después de una
    // migración automática (ver HOST_MIGRATION.md), sobre su propia Zona
    // Wi-Fi. Por eso, además, se manda el mismo DISCOVER directo a la
    // dirección de broadcast de cada interfaz local conocida (asumiendo
    // /24, que es lo que usan en la práctica los hotspots de teléfono) —
    // ésa sí sale por la interfaz correcta porque se elige a mano.
    try {
      final interfaces = await NetworkInterface.list(includeLoopback: false, type: InternetAddressType.IPv4);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final broadcast = _guessBroadcastAddress(addr.address);
          if (broadcast == null) continue;
          try {
            socket.send(payload, InternetAddress(broadcast), DiscoveryMessage.discoveryPort);
          } catch (_) {
            // Una interfaz puntual puede no admitir broadcast — no debe
            // impedir que se intente con el resto.
          }
        }
      }
    } catch (_) {
      // No se pudo enumerar interfaces: el broadcast global de arriba
      // sigue siendo el intento de siempre.
    }

    Timer(timeout, () {
      if (!done.isCompleted) done.complete();
    });
    await done.future;
    await subscription.cancel();
    socket.close();

    return found.values.toList();
  }

  static String? _guessBroadcastAddress(String ipv4) {
    final parts = ipv4.split('.');
    if (parts.length != 4) return null;
    final octets = [for (final p in parts) int.tryParse(p) ?? -1];
    if (octets.any((o) => o < 0 || o > 255)) return null;
    return '${octets[0]}.${octets[1]}.${octets[2]}.255';
  }

  /// Busca específicamente una conexión cuyo código coincida con [code]
  /// (ya normalizado). Usado tanto por el ingreso manual de código como
  /// por el escaneo de QR: en ambos casos lo único que tenemos es el
  /// código, y hay que resolverlo a una IP:puerto en la red local.
  Future<DiscoveredHost?> findByCode(
    String code, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final hosts = await scan(timeout: timeout);
    for (final host in hosts) {
      if (host.code == code) return host;
    }
    return null;
  }
}
