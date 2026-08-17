import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/chat_host_server.dart';
import '../../core/network/host_discovery_responder.dart';
import '../../core/utils/app_permissions.dart';
import '../../core/utils/chat_history_store.dart';
import '../../core/utils/host_session_store.dart';
import '../../core/utils/network_readiness.dart';
import '../../core/utils/participant_session_store.dart';
import '../../core/utils/profile_store.dart';
import '../../core/utils/room_history.dart';
import '../../theme/kena_colors.dart';
import '../../theme/kena_typography.dart';
import '../../widgets/kena_field.dart';
import '../../widgets/kena_glass_button.dart';
import '../../widgets/wifi_setup_guide.dart';
import '../lobby/lobby_body.dart';
import '../room/domain/notifying_room_session.dart';
import '../room/domain/room_session.dart';
import '../room/room_shell_screen.dart';

/// Convertirse en anfitrión, de punta a punta, en una sola pantalla
/// continua: formulario (nombre de la sala + tu nombre) → sala lista
/// (código/QR/participantes, el mismo contenido que ve quien retoma una
/// sala tras una migración — ver [LobbyBody]) → "Entrar a la sala".
///
/// Antes eran dos pantallas (`CreateRoomScreen` → `pushReplacement` →
/// `LobbyScreen`) para una sola decisión del usuario ("quiero armar una
/// sala") — ver auditoría de diseño, hallazgo #3 y sección F.1. La
/// fusión es de presentación únicamente: `_server`/`_discovery` siguen
/// siendo exactamente los mismos objetos, con el mismo dueño de ciclo
/// de vida de siempre (ver ARCHITECTURE.md → "Dueño del ciclo de vida
/// de la sala") — sólo que ahora ese dueño nunca cambia de pantalla.
class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key, this.initialRoomName});

  /// Prefijado desde afuera (p.ej. una `GroupRoom` — ver
  /// `features/accounts/group_home_screen.dart`) — sigue siendo
  /// editable, sólo ahorra tipear si ya se sabe el nombre.
  final String? initialRoomName;

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _server = ChatHostServer();
  final _discovery = HostDiscoveryResponder();
  late final _roomNameController = TextEditingController(text: widget.initialRoomName ?? 'Familia');
  final _yourNameController = TextEditingController();

  bool _creating = false;
  bool _ready = false;
  bool _waitingForNetwork = false;
  bool _handedOff = false;
  String? _error;
  Timer? _networkPoll;

  @override
  void initState() {
    super.initState();
    requestHostPermissions();
    ProfileStore.load().then((profile) {
      if (mounted && profile.name.isNotEmpty) {
        _yourNameController.text = profile.name;
      }
    });
  }

  @override
  void dispose() {
    // `_handedOff`: una vez que se entra a la sala (`_enterRoom`,
    // `pushReplacement` a `RoomShellScreen`) el dueño del servidor pasa
    // a ser esa sesión — si acá igual lo parábamos, un simple "volver
    // atrás" desde la sala (que antes dejaba esta pantalla debajo, en
    // el stack, en vez de reemplazarla) terminaba matando el servidor
    // del anfitrión sin que nadie haya tocado "Finalizar sala", lo que
    // además disparaba una migración automática de anfitrión no pedida
    // en el resto de los participantes (ver HOST_MIGRATION.md). Mismo
    // patrón que `_handedOff` en `JoinRoomScreen`.
    if (!_handedOff) {
      _server.stop();
      _discovery.stop();
    }
    _networkPoll?.cancel();
    _roomNameController.dispose();
    _yourNameController.dispose();
    super.dispose();
  }

  /// `true` si ya hay red local para seguir. Si no hay ninguna, muestra la
  /// guía manual (ver `WifiSetupGuide`) y sondea en segundo plano hasta
  /// que el usuario activa su Zona Wi-Fi por su cuenta, continuando solo
  /// sin que haga falta volver a tocar "Crear sala" (sección 39 del
  /// brief). Kena no crea la red por sí sola — ver ARCHITECTURE.md.
  Future<bool> _ensureNetworkReady() async {
    bool usable;
    try {
      usable = await hasUsableLocalNetwork();
    } catch (_) {
      // No se pudo verificar (plataforma no soportada, etc.) — no
      // bloqueamos la creación de la sala por una comprobación que
      // podría estar rota; el intento de levantar el servidor más abajo
      // ya es, en los hechos, la prueba definitiva.
      return true;
    }
    if (usable) return true;

    if (mounted) setState(() => _waitingForNetwork = true);
    _networkPoll?.cancel();
    _networkPoll = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) return;
      if (await hasUsableLocalNetwork()) {
        _networkPoll?.cancel();
        setState(() => _waitingForNetwork = false);
        _create();
      }
    });
    return false;
  }

  Future<void> _create() async {
    final roomName = _roomNameController.text.trim();
    final yourName = _yourNameController.text.trim().isEmpty ? 'Vos' : _yourNameController.text.trim();
    if (roomName.isEmpty) {
      setState(() => _error = 'Ponele un nombre a la sala.');
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
    });

    if (!await _ensureNetworkReady()) {
      if (mounted) setState(() => _creating = false);
      return;
    }

    try {
      // `requireApproval`: sin esto, cualquiera en la misma red (por
      // ejemplo, el wifi de un avión) entraba directo con un toque en
      // cuanto la sala aparecía en su búsqueda — ver
      // ChatHostServer.requireApproval. No se activa en la migración
      // automática de anfitrión ni al retomar la sala tras reabrir la
      // app (ver host_migration.dart / host_session_resume.dart): ahí
      // quien "entra" ya es gente conocida reconectándose, no caras
      // nuevas, y exigir aprobación de nuevo rompería la continuidad
      // sin ninguna sala que lo justifique.
      await _server.start(roomName: roomName, hostDisplayName: yourName, requireApproval: true);
      // El descubrimiento es un extra: si falla (p.ej. puerto UDP ocupado),
      // la sala ya arrancó y quien se une siempre puede ingresar el
      // código a mano.
      try {
        await _discovery.start(
          connectionName: roomName,
          code: _server.code,
          chatPort: ChatHostServer.defaultPort,
        );
      } catch (_) {}

      await ProfileStore.save((await ProfileStore.load()).copyWith(name: yourName));
      await RoomHistoryStore.record(RoomHistoryEntry(
        roomName: roomName,
        code: _server.code,
        wasHost: true,
        memberCount: 1,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      ));
      // Vive mientras la sala siga en pie en este dispositivo — es lo
      // que permite recuperarla sola si la app se cierra a la fuerza y
      // se vuelve a abrir (ver host_session_resume.dart). Se borra al
      // finalizar/transferir la sala (RoomShellScreen._goHome).
      await HostSessionStore.save(HostSessionSnapshot(
        code: _server.code,
        roomName: roomName,
        hostDisplayName: yourName,
      ));
      await ParticipantSessionStore.clear();

      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e) {
      setState(() {
        _error = 'No se pudo crear la sala. Probá de nuevo.';
        _creating = false;
      });
    }
  }

  Future<void> _enterRoom() async {
    final restoredHistory = await ChatHistoryStore.loadForCode(_server.code);
    if (!mounted) return;
    _handedOff = true;
    // `pushReplacement`, no `push`: así "volver atrás" desde la sala
    // aterriza directo en Inicio (mismo comportamiento que el flujo de
    // Unirme — ver `JoinRoomScreen._connectTo`), en vez de dejar esta
    // pantalla de por medio.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RoomShellScreen(
          session: NotifyingRoomSession(
            HostRoomSession(_server),
            roomCode: _server.code,
            restoredHistory: restoredHistory,
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Padding(
      key: const ValueKey('form'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Le vamos a poner un nombre a tu sala para que la gente '
            'cercana la reconozca fácil.',
            style: KenaTypography.bodySmall,
          ),
          const SizedBox(height: 20),
          KenaField(
            label: 'Nombre de la sala',
            controller: _roomNameController,
            hint: 'Ej: Familia, Vuelo AR1234, Camping',
            textCapitalization: TextCapitalization.sentences,
          ),
          KenaField(
            label: 'Tu nombre',
            controller: _yourNameController,
            hint: 'Como te van a ver los demás',
            textCapitalization: TextCapitalization.words,
          ),
          const Spacer(),
          if (_waitingForNetwork) ...[
            const WifiSetupGuide(role: WifiSetupRole.host),
            const SizedBox(height: 12),
          ],
          if (_error != null) ...[
            Text(_error!, style: KenaTypography.bodySmall.copyWith(color: KenaColors.red)),
            const SizedBox(height: 12),
          ],
          if (_creating && !_waitingForNetwork) ...[
            Center(
              child: Text('Preparando tu sala…', style: KenaTypography.bodySmall),
            ),
            const SizedBox(height: 10),
          ],
          KenaGlassButton(
            onPressed: _creating ? null : _create,
            child: _creating
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: KenaColors.onAccent),
                  )
                : const Text('Crear sala'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KenaBackground(
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(_ready ? _server.roomName : 'Crear sala')),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: _ready
              ? LobbyBody(key: const ValueKey('ready'), server: _server, discovery: _discovery, onEnterRoom: _enterRoom)
              : _buildForm(),
        ),
      ),
    );
  }
}
