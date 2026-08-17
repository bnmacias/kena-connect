import '../../../core/network/chat_host_server.dart';
import '../../../core/network/host_discovery_responder.dart';
import '../../../core/network/host_discovery_scanner.dart';
import '../../../core/utils/chat_history_store.dart';
import '../../../core/utils/host_session_store.dart';
import '../../../core/utils/participant_session_store.dart';
import 'notifying_room_session.dart';
import 'participant_connect.dart';
import 'room_session.dart';

/// Se llama una sola vez, al arrancar la app en frío (`RootScreen`): si
/// este dispositivo estaba en una sala —como anfitrión o como
/// participante— cuando el proceso murió (cierre a la fuerza, algo que
/// ningún foreground service puede evitar), intenta recuperarla sola,
/// sin que el usuario tenga que tocar nada.
Future<RoomSession?> tryResumeActiveRoom() async {
  final hostSnapshot = await HostSessionStore.load();
  if (hostSnapshot != null) {
    final resumed = await _resumeAsHost(hostSnapshot);
    if (resumed != null) return resumed;
  }

  final participantSnapshot = await ParticipantSessionStore.load();
  if (participantSnapshot != null) {
    return _resumeAsParticipant(participantSnapshot);
  }

  return null;
}

/// "Escuchá antes de hablar" antes de levantar el servidor de nuevo: si
/// mientras este dispositivo estaba muerto la sala ya migró a otro
/// participante (`ResilientRoomSession._becomeHost`, el caso normal si
/// tardó en volver a abrirse), levantar un segundo servidor con el mismo
/// código crearía dos anfitriones simultáneos — en vez de eso, se suma
/// como participante a la sala que ya está en pie.
Future<RoomSession?> _resumeAsHost(HostSessionSnapshot snapshot) async {
  final existing = await HostDiscoveryScanner().findByCode(snapshot.code, timeout: const Duration(seconds: 2));

  if (existing != null) {
    await HostSessionStore.clear();
    try {
      final session = await connectAsParticipant(existing, yourName: snapshot.hostDisplayName);
      // Ya no es anfitrión de esta sala — si a este dispositivo lo matan
      // de nuevo, el próximo arranque en frío tiene que intentar
      // reconectarse como participante, no volver a crear un servidor.
      await ParticipantSessionStore.save(ParticipantSessionSnapshot(
        code: existing.code,
        yourName: snapshot.hostDisplayName,
      ));
      return session;
    } catch (_) {
      return null; // no bloquea el arranque normal si esto falla.
    }
  }

  final server = ChatHostServer();
  final discovery = HostDiscoveryResponder();
  try {
    await server.start(
      roomName: snapshot.roomName,
      hostDisplayName: snapshot.hostDisplayName,
      code: snapshot.code,
    );
  } catch (_) {
    return null;
  }
  try {
    await discovery.start(
      connectionName: snapshot.roomName,
      code: snapshot.code,
      chatPort: ChatHostServer.defaultPort,
    );
  } catch (_) {
    // El descubrimiento es un extra — el servidor ya está en pie y
    // quien busque por código lo va a encontrar apenas reintente.
  }

  final restoredHistory = await ChatHistoryStore.loadForCode(snapshot.code);
  return NotifyingRoomSession(
    HostRoomSession(server),
    roomCode: snapshot.code,
    restoredHistory: restoredHistory,
  );
}

/// Sólo un intento (no los ~20 reintentos con backoff de una sesión
/// viva, `ChatClientConnection._searchByCode` — acá no hay ninguna
/// sesión corriendo todavía, es el arranque en frío) — si no responde
/// nadie, se cae al arranque normal (Inicio) sin bloquear a nadie; el
/// usuario siempre puede reintentar a mano desde "Recientes".
Future<RoomSession?> _resumeAsParticipant(ParticipantSessionSnapshot snapshot) async {
  final found = await HostDiscoveryScanner().findByCode(snapshot.code, timeout: const Duration(seconds: 3));
  if (found == null) return null;
  try {
    return await connectAsParticipant(found, yourName: snapshot.yourName);
  } catch (_) {
    return null;
  }
}
