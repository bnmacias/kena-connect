import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kena/core/protocol/chat_message.dart';
import 'package:kena/core/utils/chat_history_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('guarda y restaura el historial para el mismo código de sala', () async {
    final messages = [
      ChatMessage(type: MessageType.message, senderId: 'a', senderName: 'Sol', text: 'hola'),
      ChatMessage(type: MessageType.message, senderId: 'b', senderName: 'Jorge', text: 'hey'),
    ];
    await ChatHistoryStore.save(code: 'ABCD', roomName: 'Familia', messages: messages);

    final restored = await ChatHistoryStore.loadForCode('ABCD');

    expect(restored, hasLength(2));
    expect(restored[0].text, 'hola');
    expect(restored[1].senderName, 'Jorge');
  });

  test('no restaura nada si el código no coincide (era de otra sala)', () async {
    await ChatHistoryStore.save(code: 'ABCD', roomName: 'Familia', messages: [
      ChatMessage(type: MessageType.message, senderId: 'a', senderName: 'Sol', text: 'hola'),
    ]);

    final restored = await ChatHistoryStore.loadForCode('WXYZ');

    expect(restored, isEmpty);
  });

  test('sin nada guardado todavía, devuelve vacío sin romperse', () async {
    final restored = await ChatHistoryStore.loadForCode('ABCD');
    expect(restored, isEmpty);
  });
}
