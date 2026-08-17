import 'package:flutter/material.dart';

import '../../core/network/chat_host_server.dart';
import '../../core/network/host_discovery_responder.dart';
import '../../theme/kena_colors.dart';
import '../lobby/lobby_screen.dart';

/// Pantalla de transición cuando este dispositivo fue elegido para
/// continuar una sala como nuevo anfitrión: arranca su propia conexión
/// local con el mismo nombre de sala y aterriza en el lobby con un
/// código nuevo para volver a compartir. No hay forma de migrar la
/// IP:puerto del anfitrión anterior en vivo, así que el resto de los
/// participantes va a tener que volver a unirse con ese código nuevo.
class HostTakeoverScreen extends StatefulWidget {
  const HostTakeoverScreen({super.key, required this.roomName, required this.yourName});

  final String roomName;
  final String yourName;

  @override
  State<HostTakeoverScreen> createState() => _HostTakeoverScreenState();
}

class _HostTakeoverScreenState extends State<HostTakeoverScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final server = ChatHostServer();
    final discovery = HostDiscoveryResponder();
    try {
      await server.start(roomName: widget.roomName, hostDisplayName: widget.yourName);
      try {
        await discovery.start(connectionName: widget.roomName, code: server.code, chatPort: ChatHostServer.defaultPort);
      } catch (_) {
        // El descubrimiento es un extra; si falla, el código a mano sigue sirviendo.
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => LobbyScreen(server: server, discovery: discovery)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo continuar la sala en este dispositivo. Probá crear una sala nueva.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return KenaBackground(
      builder: (context) => Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
          child: _error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: KenaColors.text)),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: KenaColors.accent),
                    const SizedBox(height: 16),
                    Text('Preparando la sala…', style: TextStyle(color: KenaColors.text2)),
                  ],
                ),
        ),
      ),
    );
  }
}
