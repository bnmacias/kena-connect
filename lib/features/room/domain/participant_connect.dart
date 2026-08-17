import '../../../core/network/chat_client_connection.dart';
import '../../../core/network/host_discovery_scanner.dart';
import '../../../core/utils/chat_history_store.dart';
import '../../../core/utils/device_identity.dart';
import 'host_migration.dart';
import 'notifying_room_session.dart';
import 'room_session.dart';

/// Arma la sesión completa de un participante que se conecta a [room] —
/// compartido entre `JoinRoomScreen` (unirse a mano) y la recuperación
/// automática al reabrir la app (`host_session_resume.dart`), para no
/// repetir tres veces el mismo armado (identidad persistida, orden
/// suscripción-antes-que-conexión, envoltorio resiliente, historial
/// restaurado).
Future<RoomSession> connectAsParticipant(DiscoveredHost room, {required String yourName}) async {
  final senderId = await DeviceIdentity.get();
  final connection = ChatClientConnection();

  // Mismo motivo que en JoinRoomScreen: `ParticipantRoomSession` tiene
  // que suscribirse antes de que `connect()` abra el socket, o se pierde
  // cualquier roster/mensaje que llegue en el hueco.
  final participantSession = ParticipantRoomSession(
    connection,
    roomName: room.connectionName,
    mySenderId: senderId,
    myName: yourName,
  );
  await connection.connect(
    room.address,
    room.port,
    senderId: senderId,
    senderName: yourName,
    code: room.code,
  );

  final restoredHistory = await ChatHistoryStore.loadForCode(room.code);
  return NotifyingRoomSession(
    ResilientRoomSession(
      initial: participantSession,
      roomCode: room.code,
      yourName: yourName,
    ),
    roomCode: room.code,
    restoredHistory: restoredHistory,
  );
}
