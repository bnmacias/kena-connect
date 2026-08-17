// Prueba de integración sobre sockets reales de loopback (sin UI): arma
// una sala de verdad (ChatHostServer + HostDiscoveryResponder), la
// conecta con ChatClientConnection reales, y verifica tanto el chat
// básico como la migración automática de anfitrión — ver
// HOST_MIGRATION.md. No usa `flutter test`/widgets: el dominio entero
// (core/network, core/protocol, features/room/domain) es Dart puro,
// así que corre igual de rápido y sin necesidad de un dispositivo.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kena/core/network/chat_client_connection.dart';
import 'package:kena/core/network/chat_host_server.dart';
import 'package:kena/core/network/host_discovery_responder.dart';
import 'package:kena/core/protocol/chat_message.dart';
import 'package:kena/features/room/domain/host_migration.dart';
import 'package:kena/features/room/domain/room_session.dart';

void main() {
  group('electStandby', () {
    test('elige al no-anfitrión con joinOrder más chico', () {
      const roster = [
        RoomMember(id: 'host', name: 'Bruno', isHost: true, joinOrder: 0),
        RoomMember(id: 'p2', name: 'Fran', isHost: false, joinOrder: 2),
        RoomMember(id: 'p1', name: 'Sol', isHost: false, joinOrder: 1),
      ];
      expect(electStandby(roster)?.id, 'p1');
    });

    test('null si sólo está el anfitrión', () {
      const roster = [RoomMember(id: 'host', name: 'Bruno', isHost: true)];
      expect(electStandby(roster), isNull);
    });
  });

  group('Sala sobre sockets reales (loopback)', () {
    late ChatHostServer server;
    late HostDiscoveryResponder responder;

    setUp(() async {
      server = ChatHostServer();
      responder = HostDiscoveryResponder();
      await server.start(roomName: 'Test', hostDisplayName: 'Anfitrión');
      try {
        await responder.start(connectionName: 'Test', code: server.code, chatPort: ChatHostServer.defaultPort);
      } catch (_) {
        // Si el puerto UDP de descubrimiento ya está tomado (otra
        // instancia corriendo en esta misma máquina), el test de
        // migración automática se salta solo — ver más abajo.
      }
    });

    tearDown(() async {
      responder.stop();
      await server.stop();
    });

    test('dos participantes se conectan, chatean, y comparten roster', () async {
      final a = ChatClientConnection();
      final b = ChatClientConnection();
      addTearDown(a.disconnect);
      addTearDown(b.disconnect);

      await a.connect('127.0.0.1', ChatHostServer.defaultPort, senderId: 'a', senderName: 'Sol');
      await b.connect('127.0.0.1', ChatHostServer.defaultPort, senderId: 'b', senderName: 'Jorge');
      await Future.delayed(const Duration(milliseconds: 400));

      expect(server.members.length, 3, reason: 'anfitrión + 2 participantes');

      final received = <ChatMessage>[];
      final sub = b.messages.listen(received.add);
      addTearDown(sub.cancel);

      a.send('hola', senderId: 'a', senderName: 'Sol');
      await Future.delayed(const Duration(milliseconds: 400));

      expect(received.any((m) => m.type == MessageType.message && m.text == 'hola' && m.senderId == 'a'), isTrue);
    });

    test(
      'si el anfitrión desaparece, el standby continúa la sala y el resto se reconecta solo',
      () async {
        if (!responder.isRunning) {
          markTestSkipped('Puerto de descubrimiento UDP ocupado en esta máquina — no se puede probar migración.');
          return;
        }

        final standbyConn = ChatClientConnection();
        final otherConn = ChatClientConnection();
        addTearDown(standbyConn.disconnect);
        addTearDown(otherConn.disconnect);

        // El RoomSession tiene que armarse ANTES de conectar (se
        // suscribe a un broadcast stream sin buffer) — mismo orden que
        // JoinRoomScreen, ver el comentario ahí.
        final standbySession = ParticipantRoomSession(standbyConn, roomName: 'Test', mySenderId: 'standby', myName: 'Sol');

        // Orden de conexión define joinOrder: standby entra primero, así
        // que va a ser el elegido para continuar la sala.
        await standbyConn.connect('127.0.0.1', ChatHostServer.defaultPort,
            senderId: 'standby', senderName: 'Sol', code: server.code);
        await otherConn.connect('127.0.0.1', ChatHostServer.defaultPort,
            senderId: 'other', senderName: 'Jorge', code: server.code);
        await Future.delayed(const Duration(milliseconds: 400));
        expect(server.members.length, 3);

        final resilient = ResilientRoomSession(initial: standbySession, roomCode: server.code, yourName: 'Sol');
        addTearDown(resilient.dispose);

        expect(electStandby(resilient.members)?.id, 'standby', reason: 'se unió antes que "other"');

        final becameHost = Completer<void>();
        final statusSub = resilient.statusStream.listen((s) {
          if (!becameHost.isCompleted && s == ConnectionStatus.connected && resilient.isHost) {
            becameHost.complete();
          }
        });
        addTearDown(statusSub.cancel);

        // El anfitrión original desaparece de golpe, sin avisar (no
        // finishRoom): exactamente el caso que la migración automática
        // tiene que cubrir.
        responder.stop();
        await server.stop();

        await becameHost.future.timeout(
          const Duration(seconds: 20),
          onTimeout: () => fail('El standby no tomó la posta como nuevo anfitrión a tiempo'),
        );
        expect(resilient.isHost, isTrue);
        expect(resilient.roomName, 'Test');

        // El otro participante no recibió ningún código nuevo ni
        // reescaneó nada — su propia ChatClientConnection tiene que
        // encontrar sola la sala continuada por su código, en el mismo
        // host físico pero otro puerto/servidor.
        final otherReconnected = Completer<void>();
        final otherSub = otherConn.status.listen((s) {
          if (!otherReconnected.isCompleted && s == ConnectionStatus.connected) otherReconnected.complete();
        });
        addTearDown(otherSub.cancel);

        await otherReconnected.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () => fail('El otro participante no se reconectó solo a la sala continuada'),
        );
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}
