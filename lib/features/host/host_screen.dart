import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/network/chat_host_server.dart';
import '../../core/network/host_discovery_responder.dart';
import '../chat/chat_screen.dart';

/// Pantalla/lógica para iniciar el modo host: levanta el servidor WebSocket
/// y muestra las direcciones IP locales disponibles para que los clientes
/// sepan a qué conectarse.
class HostScreen extends StatefulWidget {
  const HostScreen({super.key});

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  final _server = ChatHostServer();
  final _discovery = HostDiscoveryResponder();
  final _hostName = 'Host';
  bool _starting = false;
  String? _error;
  List<String> _localAddresses = [];

  @override
  void dispose() {
    _server.stop();
    _discovery.stop();
    super.dispose();
  }

  Future<void> _startHost() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final addresses = await _listLocalIPv4Addresses();
      await _server.start(port: ChatHostServer.defaultPort, hostName: _hostName);
      // El discovery es un extra: si falla (p.ej. puerto UDP ocupado), el
      // chat por WebSocket ya arrancó y sigue funcionando igual con IP manual.
      try {
        await _discovery.start(hostName: _hostName, chatPort: ChatHostServer.defaultPort);
      } catch (_) {}
      setState(() {
        _localAddresses = addresses;
        _starting = false;
      });
    } catch (e) {
      setState(() {
        _error = 'No se pudo iniciar el servidor: $e';
        _starting = false;
      });
    }
  }

  Future<List<String>> _listLocalIPv4Addresses() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    return [
      for (final iface in interfaces)
        for (final addr in iface.addresses) '${addr.address} (${iface.name})',
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_server.isRunning) {
      return ChatScreen(
        title: 'Host · puerto ${ChatHostServer.defaultPort}',
        messages: _server.messages,
        ownSenderId: ChatHostServer.hostSenderId,
        onSend: (text) => _server.sendFromHost(text, hostName: _hostName),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Modo Host')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Va a levantar un servidor WebSocket en el puerto '
              '${ChatHostServer.defaultPort}. Los clientes se conectan a la '
              'IP de este dispositivo en ese puerto.',
            ),
            const SizedBox(height: 16),
            if (_localAddresses.isNotEmpty) ...[
              const Text('IPs locales detectadas:'),
              for (final addr in _localAddresses) Text('  • $addr'),
              const SizedBox(height: 16),
            ],
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
            ],
            ElevatedButton(
              onPressed: _starting ? null : _startHost,
              child: _starting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Iniciar host'),
            ),
          ],
        ),
      ),
    );
  }
}
