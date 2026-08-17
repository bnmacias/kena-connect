// Regresión puntual para un bug real: ChatClientConnection.send()
// devolvía en silencio si no había conexión (el mensaje ni siquiera
// aparecía localmente) — ver la sección 42 del brief ("no mostrar
// 'enviado' si el mensaje realmente no fue entregado", y en general,
// no perder mensajes en silencio).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kena/core/network/chat_client_connection.dart';
import 'package:kena/core/network/chat_host_server.dart';
import 'package:kena/core/protocol/chat_message.dart';

void main() {
  test('mandar un mensaje sin conexión no lo pierde: queda visible como "failed"', () async {
    final conn = ChatClientConnection();
    final received = <ChatMessage>[];
    conn.messages.listen(received.add);

    conn.send('hola', senderId: 'a', senderName: 'Sol');
    await pumpEventQueue();

    expect(received, hasLength(1));
    expect(received.single.deliveryStatus, MessageDeliveryStatus.failed);
  });

  test('un mensaje fallido se reintenta solo y pasa a "sent" al reconectar', () async {
    // Puerto propio (no el default 8080): este archivo puede correr en
    // paralelo con host_migration_test.dart, y dos ChatHostServer real
    // escuchando el mismo puerto al mismo tiempo revienta con
    // "address already in use". En producción sólo hay un anfitrión por
    // dispositivo a la vez, así que esto es puramente aislamiento de test.
    const testPort = 8099;
    final server = ChatHostServer();
    await server.start(roomName: 'Test', hostDisplayName: 'Anfitrión', port: testPort);
    addTearDown(server.stop);

    final conn = ChatClientConnection();
    addTearDown(conn.disconnect);
    final events = <ChatMessage>[];
    conn.messages.listen(events.add);

    // Mandado antes de conectar: tiene que quedar en cola, no perderse.
    conn.send('hola', senderId: 'a', senderName: 'Sol');
    await pumpEventQueue();
    expect(events.single.deliveryStatus, MessageDeliveryStatus.failed);

    final hostSaw = Completer<ChatMessage>();
    final sub = server.messages.listen((m) {
      if (m.type == MessageType.message && !hostSaw.isCompleted) hostSaw.complete(m);
    });
    addTearDown(sub.cancel);

    await conn.connect('127.0.0.1', testPort, senderId: 'a', senderName: 'Sol');

    final deliveredToHost = await hostSaw.future.timeout(const Duration(seconds: 5));
    expect(deliveredToHost.text, 'hola');

    // El reintento vuelve a emitir por `messages` (para que la UI
    // redibuje la burbuja), pero es el MISMO objeto de antes con
    // `deliveryStatus` actualizado — no uno nuevo. La UI (ChatThreadScreen)
    // es quien deduplica por identidad antes de agregarlo a la lista
    // visible; acá sólo interesa que el objeto sea el mismo y haya
    // terminado en "sent". (`events` también trae el `roster` que el
    // anfitrión sincroniza apenas nos unimos — no es parte de esto.)
    final chatEvents = events.where((m) => m.type == MessageType.message).toList();
    expect(chatEvents, hasLength(2));
    expect(identical(chatEvents.first, chatEvents.last), isTrue);
    expect(chatEvents.last.deliveryStatus, MessageDeliveryStatus.sent);
  });

  // Regresión para otro bug real reportado por uso: un participante que
  // se reconecta (wifi que va y viene, app que se mata y se reabre)
  // recuperaba la conexión, pero los mensajes que otros mandaron
  // mientras tanto no le llegaban nunca — el anfitrión sólo relayaba en
  // vivo a quien estuviera conectado en ese instante, sin ningún buffer
  // ni reenvío al volver. Ver ROADMAP.md → "Sincronizar historial de
  // mensajes también para quien se une tarde" y
  // ChatHostServer._replayMissed.
  test('al reconectarse, se reciben los mensajes generales y privados que se perdió mientras estaba desconectado',
      () async {
    const testPort = 8098;
    final server = ChatHostServer();
    await server.start(roomName: 'Test', hostDisplayName: 'Anfitrión', port: testPort);
    addTearDown(server.stop);

    final a = ChatClientConnection();
    final b = ChatClientConnection();
    addTearDown(a.disconnect);
    addTearDown(b.disconnect);

    await a.connect('127.0.0.1', testPort, senderId: 'a', senderName: 'Sol');
    await b.connect('127.0.0.1', testPort, senderId: 'b', senderName: 'Jorge');
    await pumpEventQueue();

    // "a" se corta (wifi, app minimizada, lo que sea) mientras sigue
    // pasando actividad en la sala.
    await a.disconnect();
    await pumpEventQueue();

    b.send('te perdiste esto en general', senderId: 'b', senderName: 'Jorge');
    server.sendPrivateFromHost('y esto que te mandé por privado', toMemberId: 'a');
    await pumpEventQueue();

    final received = <ChatMessage>[];
    final sub = a.messages.listen(received.add);
    addTearDown(sub.cancel);

    // Reconecta con el mismo senderId — el anfitrión tiene que
    // reconocerlo como el mismo participante de antes, no como alguien
    // nuevo.
    await a.connect('127.0.0.1', testPort, senderId: 'a', senderName: 'Sol', code: server.code);
    await pumpEventQueue();

    final texts = received.where((m) => m.type == MessageType.message).map((m) => m.text).toList();
    expect(texts, containsAll(['te perdiste esto en general', 'y esto que te mandé por privado']));
  });

  // Regresión para el bug de seguridad reportado por uso: en una red
  // compartida (el wifi de un avión, por ejemplo) cualquiera que
  // detectara la sala entraba directo con un toque, sin que el
  // anfitrión pudiera decir que no. Con `requireApproval: true`, un
  // desconocido tiene que esperar a que el anfitrión acepte, y no ve
  // nada de la sala (ni roster ni mensajes) mientras tanto.
  group('aprobación del anfitrión antes de dejar entrar a alguien nuevo', () {
    test('un desconocido no entra hasta que el anfitrión acepta, y no ve nada mientras espera', () async {
      const testPort = 8097;
      final server = ChatHostServer();
      await server.start(roomName: 'Test', hostDisplayName: 'Anfitrión', port: testPort, requireApproval: true);
      addTearDown(server.stop);

      final stranger = ChatClientConnection();
      addTearDown(stranger.disconnect);
      final received = <ChatMessage>[];
      final sub = stranger.messages.listen(received.add);
      addTearDown(sub.cancel);

      await stranger.connect('127.0.0.1', testPort, senderId: 'x', senderName: 'Desconocido');
      await pumpEventQueue();

      // Todavía nada: ni roster, ni el propio "se unió" — sigue
      // esperando aprobación.
      expect(server.members.length, 1, reason: 'sólo el anfitrión; el pendiente no cuenta como miembro');
      expect(received, isEmpty);
      expect(server.pendingJoinRequests, hasLength(1));
      expect(server.pendingJoinRequests.single.senderName, 'Desconocido');

      // Mientras espera, no debería enterarse de nada que pase en la sala.
      server.sendGeneralFromHost('esto no lo debería ver todavía');
      await pumpEventQueue();
      expect(received, isEmpty);

      server.acceptJoinRequest(server.pendingJoinRequests.single.connKey);
      await pumpEventQueue();

      expect(server.members.length, 2);
      expect(server.pendingJoinRequests, isEmpty);
    });

    test('si el anfitrión rechaza, se le avisa el motivo y no entra a la sala', () async {
      const testPort = 8096;
      final server = ChatHostServer();
      await server.start(roomName: 'Test', hostDisplayName: 'Anfitrión', port: testPort, requireApproval: true);
      addTearDown(server.stop);

      final stranger = ChatClientConnection();
      addTearDown(stranger.disconnect);

      await stranger.connect('127.0.0.1', testPort, senderId: 'x', senderName: 'Desconocido');
      await pumpEventQueue();

      final closedStatus = Completer<ConnectionStatus>();
      final statusSub = stranger.status.listen((s) {
        if (!closedStatus.isCompleted) closedStatus.complete(s);
      });
      addTearDown(statusSub.cancel);

      server.rejectJoinRequest(server.pendingJoinRequests.single.connKey);

      final status = await closedStatus.future.timeout(const Duration(seconds: 5));
      expect(status, ConnectionStatus.closedByHost);
      expect(server.members.length, 1);
    });

    test('alguien que ya había sido aceptado antes vuelve a entrar directo tras reconectarse', () async {
      const testPort = 8095;
      final server = ChatHostServer();
      await server.start(roomName: 'Test', hostDisplayName: 'Anfitrión', port: testPort, requireApproval: true);
      addTearDown(server.stop);

      final conn = ChatClientConnection();
      addTearDown(conn.disconnect);
      await conn.connect('127.0.0.1', testPort, senderId: 'y', senderName: 'Ya conocido');
      await pumpEventQueue();
      server.acceptJoinRequest(server.pendingJoinRequests.single.connKey);
      await pumpEventQueue();
      expect(server.members.length, 2);

      await conn.disconnect();
      await pumpEventQueue();

      await conn.connect('127.0.0.1', testPort, senderId: 'y', senderName: 'Ya conocido', code: server.code);
      await pumpEventQueue();

      expect(server.pendingJoinRequests, isEmpty, reason: 'ya era conocido, no debería quedar pidiendo aprobación');
      expect(server.members.length, 2);
    });
  });
}
