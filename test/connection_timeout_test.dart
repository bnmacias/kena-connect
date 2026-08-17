// Regresión para un bug real reportado por el usuario: reconectarse
// justo después de salir de una sala podía dejar la pantalla de
// "Unirme a una sala" congelada (campo de código sin responder) porque
// ChatClientConnection._openSocket() esperaba `channel.ready` sin
// ningún timeout — si el destino ni aceptaba ni rechazaba activamente
// la conexión, la espera no terminaba nunca.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kena/core/network/chat_client_connection.dart';

void main() {
  test(
    'un intento de conexión que nunca responde no cuelga para siempre',
    () async {
      // Acepta la conexión TCP pero nunca completa el upgrade de
      // WebSocket — simula un destino "silenciosamente" inalcanzable
      // (ni acepta ni rechaza a nivel de aplicación), justo el caso que
      // dejaba la UI pegada.
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      final sub = server.listen((socket) {
        // A propósito: no le contesta nada al socket.
      });
      addTearDown(sub.cancel);

      final conn = ChatClientConnection();
      addTearDown(conn.disconnect);

      final stopwatch = Stopwatch()..start();
      await expectLater(
        conn.connect('127.0.0.1', server.port, senderId: 'a', senderName: 'Sol'),
        throwsA(anything),
      );
      stopwatch.stop();

      expect(
        stopwatch.elapsed,
        lessThan(const Duration(seconds: 12)),
        reason: 'tiene que rendirse sola en vez de esperar para siempre',
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
