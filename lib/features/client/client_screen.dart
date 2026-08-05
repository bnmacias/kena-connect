import 'package:flutter/material.dart';

import '../../core/network/chat_client_connection.dart';
import '../../core/network/host_discovery_scanner.dart';
import '../chat/chat_screen.dart';

/// Pantalla/lógica para unirse como cliente: permite buscar hosts
/// automáticamente en la red local (UDP broadcast) o, si eso falla o no
/// aparece nada, ingresar la IP:puerto a mano.
class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  final _connection = ChatClientConnection();
  final _scanner = HostDiscoveryScanner();
  final _ipController = TextEditingController(text: '10.0.2.2');
  final _portController = TextEditingController(text: '8080');
  final _nameController = TextEditingController(text: 'Cliente');

  bool _connecting = false;
  bool _scanning = false;
  String? _error;
  List<DiscoveredHost> _discovered = [];

  String get _senderId => 'client-${identityHashCode(this)}';

  @override
  void dispose() {
    _connection.disconnect();
    _ipController.dispose();
    _portController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final hosts = await _scanner.scan();
      setState(() {
        _discovered = hosts;
        _scanning = false;
      });
    } catch (e) {
      setState(() {
        _error = 'No se pudo buscar hosts: $e';
        _scanning = false;
      });
    }
  }

  void _selectDiscovered(DiscoveredHost host) {
    setState(() {
      _ipController.text = host.address;
      _portController.text = '${host.port}';
    });
  }

  Future<void> _connect() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    if (ip.isEmpty || port == null) {
      setState(() => _error = 'IP o puerto inválido');
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });

    try {
      await _connection.connect(ip, port);
      setState(() => _connecting = false);
    } catch (e) {
      setState(() {
        _error = 'No se pudo conectar a $ip:$port ($e)';
        _connecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_connection.isConnected) {
      return ChatScreen(
        title: 'Cliente · ${_ipController.text}:${_portController.text}',
        messages: _connection.messages,
        ownSenderId: _senderId,
        onSend: (text) => _connection.send(
          text,
          senderId: _senderId,
          senderName: _nameController.text.trim().isEmpty
              ? 'Cliente'
              : _nameController.text.trim(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Modo Cliente')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Tu nombre'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Text('Hosts en la red local:')),
                OutlinedButton(
                  onPressed: _scanning ? null : _scan,
                  child: _scanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Buscar'),
                ),
              ],
            ),
            if (_discovered.isEmpty && !_scanning)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Ningún host encontrado todavía.'),
              ),
            for (final host in _discovered)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(host.name),
                subtitle: Text('${host.address}:${host.port}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectDiscovered(host),
              ),
            const Divider(height: 32),
            const Text('...o ingresá la IP a mano:'),
            const SizedBox(height: 8),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(labelText: 'IP del host'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(labelText: 'Puerto'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
            ],
            ElevatedButton(
              onPressed: _connecting ? null : _connect,
              child: _connecting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Conectar'),
            ),
          ],
        ),
      ),
    );
  }
}
