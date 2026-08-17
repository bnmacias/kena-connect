import 'dart:async';

import '../../../core/network/chat_client_connection.dart';
import 'room_session.dart';

/// Estado de conexión tal como se le muestra al usuario, unificado para
/// toda la app (Inicio, Lobby, sala, chat) — ver sección 6/12 del brief
/// de producto. Es más fino que [ConnectionStatus] (la máquina de
/// estados "dura" que gobierna reconexión): agrega `unstable` (latido
/// perdido con el socket todavía abierto) y `restored` (aviso
/// transitorio al recuperarse), y dos fases que existen *antes* de que
/// haya una sesión (`preparing`/`connecting`), usadas directamente por
/// Crear/Unirme mientras arman la sala.
enum ConnectionPhase { preparing, connecting, connected, unstable, reconnecting, lost, restored }

/// [justBecameHost]: el "restablecida" que se está por mostrar es en
/// realidad un ascenso a anfitrión por una migración automática (ver
/// `RoomSession.becameHostAutomaticallyStream`) — se anuncia distinto
/// del reconectar genérico, aunque técnicamente también sea `restored`.
String connectionPhaseLabel(ConnectionPhase phase, {String? roomName, bool justBecameHost = false}) {
  switch (phase) {
    case ConnectionPhase.preparing:
      return 'Preparando tu sala…';
    case ConnectionPhase.connecting:
      return 'Conectando…';
    case ConnectionPhase.connected:
      return roomName == null ? 'Conectado' : 'Conectado a "$roomName"';
    case ConnectionPhase.unstable:
      return 'Conexión inestable';
    case ConnectionPhase.reconnecting:
      return 'Reconectando…';
    case ConnectionPhase.lost:
      return 'Conexión perdida';
    case ConnectionPhase.restored:
      if (justBecameHost) return 'Ahora sos el anfitrión de "${roomName ?? 'la sala'}"';
      return roomName == null ? 'Conexión restablecida' : 'Volviste a conectarte a "$roomName"';
  }
}

/// `true` para las fases que ameritan una franja persistente (algo va
/// mal o se está resolviendo); `false` para las que son sólo un aviso
/// transitorio (toast) que se puede perder sin que importe.
bool connectionPhaseIsPersistent(ConnectionPhase phase) {
  switch (phase) {
    case ConnectionPhase.unstable:
    case ConnectionPhase.reconnecting:
    case ConnectionPhase.lost:
      return true;
    case ConnectionPhase.preparing:
    case ConnectionPhase.connecting:
    case ConnectionPhase.connected:
    case ConnectionPhase.restored:
      return false;
  }
}

/// Deriva un [ConnectionPhase] estable a partir de los dos streams
/// "duros" de un [RoomSession] ([RoomSession.statusStream] +
/// [RoomSession.linkHealthy]), con el debounce necesario para no pasar
/// verde→rojo→verde por un microcorte (sección 10/41 del brief).
///
/// No reemplaza el mecanismo de reconexión real (eso sigue viviendo en
/// [ChatClientConnection]) — sólo traduce su resultado a algo que se
/// pueda mostrar de forma consistente en cualquier pantalla.
class ConnectionPhaseTracker {
  ConnectionPhaseTracker(this._session) {
    _phase = _session.currentStatus == ConnectionStatus.connected
        ? ConnectionPhase.connected
        : ConnectionPhase.connecting;
    _statusSub = _session.statusStream.listen(_onStatus);
    _healthySub = _session.linkHealthy.listen(_onHealthy);
  }

  final RoomSession _session;
  final _controller = StreamController<ConnectionPhase>.broadcast();
  late StreamSubscription<ConnectionStatus> _statusSub;
  late StreamSubscription<bool> _healthySub;

  ConnectionStatus? _lastDegradedStatus;
  Timer? _unstableDebounce;
  Timer? _restoredSettle;
  late ConnectionPhase _phase;

  ConnectionPhase get current => _phase;
  Stream<ConnectionPhase> get stream => _controller.stream;

  void _emit(ConnectionPhase phase) {
    _phase = phase;
    _controller.add(phase);
  }

  void _onStatus(ConnectionStatus status) {
    _unstableDebounce?.cancel();
    switch (status) {
      case ConnectionStatus.reconnecting:
        _lastDegradedStatus = status;
        _restoredSettle?.cancel();
        _emit(ConnectionPhase.reconnecting);
      case ConnectionStatus.lost:
        _lastDegradedStatus = status;
        _restoredSettle?.cancel();
        _emit(ConnectionPhase.lost);
      case ConnectionStatus.closedByHost:
        // La sala finalizada se maneja con un diálogo dedicado en la UI
        // (ver RoomShellScreen) — la franja global no necesita duplicarlo.
        break;
      case ConnectionStatus.connected:
        if (_lastDegradedStatus != null) {
          _lastDegradedStatus = null;
          _emit(ConnectionPhase.restored);
          _restoredSettle?.cancel();
          _restoredSettle = Timer(const Duration(seconds: 4), () {
            if (_phase == ConnectionPhase.restored) _emit(ConnectionPhase.connected);
          });
        } else {
          _emit(ConnectionPhase.connected);
        }
    }
  }

  void _onHealthy(bool healthy) {
    if (_phase != ConnectionPhase.connected && _phase != ConnectionPhase.unstable) return;
    _unstableDebounce?.cancel();
    if (!healthy) {
      // No declara "inestable" ante el primer indicio: espera a que se
      // sostenga un momento, así una única ráfaga corta de silencio no
      // dispara un parpadeo de estado.
      _unstableDebounce = Timer(const Duration(milliseconds: 1200), () {
        if (_phase == ConnectionPhase.connected) _emit(ConnectionPhase.unstable);
      });
    } else if (_phase == ConnectionPhase.unstable) {
      _emit(ConnectionPhase.restored);
      _restoredSettle?.cancel();
      _restoredSettle = Timer(const Duration(seconds: 4), () {
        if (_phase == ConnectionPhase.restored) _emit(ConnectionPhase.connected);
      });
    }
  }

  void dispose() {
    _statusSub.cancel();
    _healthySub.cancel();
    _unstableDebounce?.cancel();
    _restoredSettle?.cancel();
    _controller.close();
  }
}
