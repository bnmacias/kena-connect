import 'package:flutter/material.dart';

import '../../core/network/chat_host_server.dart';
import '../../core/network/host_discovery_responder.dart';
import '../../core/utils/chat_history_store.dart';
import '../../theme/kena_colors.dart';
import '../room/domain/notifying_room_session.dart';
import '../room/domain/room_session.dart';
import '../room/room_shell_screen.dart';
import 'lobby_body.dart';

/// Sala de espera del anfitrión tras una migración o transferencia de
/// anfitrión (ver `HostTakeoverScreen`) — el contenido en sí (código,
/// QR, participantes) vive en [LobbyBody], compartido con el flujo
/// normal de "Crear sala" (fusionado en una sola pantalla continua, ver
/// `CreateRoomScreen`). Esta pantalla es sólo el `Scaffold` alrededor.
class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key, required this.server, required this.discovery});

  final ChatHostServer server;
  final HostDiscoveryResponder discovery;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  bool _handedOff = false;

  @override
  void dispose() {
    // `_handedOff`: ver la misma guarda en `CreateRoomScreen.dispose()`
    // — sin esto, un simple "volver atrás" desde la sala mataba el
    // servidor del anfitrión (esta pantalla quedaba debajo, en el
    // stack) y disparaba una migración automática de anfitrión no
    // pedida en el resto de los participantes.
    if (!_handedOff) {
      widget.server.stop();
      widget.discovery.stop();
    }
    super.dispose();
  }

  Future<void> _enterRoom() async {
    // Restaura el chat guardado localmente si es el mismo código de
    // sala (p. ej. la app se cerró y se volvió a abrir todavía con la
    // sala activa) — ver ChatHistoryStore.
    final restoredHistory = await ChatHistoryStore.loadForCode(widget.server.code);
    if (!mounted) return;
    _handedOff = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RoomShellScreen(
          session: NotifyingRoomSession(
            HostRoomSession(widget.server),
            roomCode: widget.server.code,
            restoredHistory: restoredHistory,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KenaBackground(
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(widget.server.roomName)),
        body: LobbyBody(server: widget.server, discovery: widget.discovery, onEnterRoom: _enterRoom),
      ),
    );
  }
}
