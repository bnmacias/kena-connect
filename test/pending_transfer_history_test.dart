// Regresión para un pedido real de uso: al transferir la sala a mano,
// quien la transfirió perdía su historial local si más adelante volvía
// a unirse a la sala que arrancó el sucesor (mismo nombre, código
// distinto — ver ROADMAP.md → "Transferencia de anfitrión no es una
// migración en vivo"). Ver PendingTransferHistoryStore.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kena/core/protocol/chat_message.dart';
import 'package:kena/core/utils/pending_transfer_history.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('se consume si el nombre de sala coincide', () async {
    final messages = [
      ChatMessage(type: MessageType.message, senderId: 'host', senderName: 'Bruno', text: 'hola'),
    ];
    await PendingTransferHistoryStore.save(roomName: 'Familia', messages: messages);

    final carried = await PendingTransferHistoryStore.consumeIfMatches('Familia');

    expect(carried, isNotNull);
    expect(carried!.single.text, 'hola');
  });

  test('no entrega nada si el nombre de sala no coincide', () async {
    await PendingTransferHistoryStore.save(roomName: 'Familia', messages: [
      ChatMessage(type: MessageType.message, senderId: 'host', senderName: 'Bruno', text: 'hola'),
    ]);

    final carried = await PendingTransferHistoryStore.consumeIfMatches('Vuelo AR1234');

    expect(carried, isNull);
  });

  test('se consume una sola vez, aunque coincida', () async {
    await PendingTransferHistoryStore.save(roomName: 'Familia', messages: [
      ChatMessage(type: MessageType.message, senderId: 'host', senderName: 'Bruno', text: 'hola'),
    ]);

    final first = await PendingTransferHistoryStore.consumeIfMatches('Familia');
    final second = await PendingTransferHistoryStore.consumeIfMatches('Familia');

    expect(first, isNotNull);
    expect(second, isNull);
  });

  test('sin nada guardado todavía, devuelve null sin romperse', () async {
    final carried = await PendingTransferHistoryStore.consumeIfMatches('Familia');
    expect(carried, isNull);
  });
}
