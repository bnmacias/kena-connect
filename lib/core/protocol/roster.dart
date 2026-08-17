import 'dart:convert';

import 'chat_message.dart';

/// Un miembro de la sala tal como se sincroniza a todos los
/// dispositivos (anfitrión + participantes) vía `MessageType.roster`.
///
/// [joinOrder] es lo que le permite a cualquier dispositivo calcular en
/// soledad (sin coordinarse con nadie) quién debería continuar la sala
/// si el anfitrión desaparece: el participante no-anfitrión con el
/// `joinOrder` más bajo — ver HOST_MIGRATION.md. El anfitrión lo asigna
/// una sola vez, al conectarse cada participante; nunca cambia.
class RosterMember {
  final String id;
  final String name;
  final bool isHost;
  final int joinOrder;

  const RosterMember({required this.id, required this.name, required this.isHost, this.joinOrder = 0});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'isHost': isHost, 'joinOrder': joinOrder};

  factory RosterMember.fromJson(Map<String, dynamic> json) => RosterMember(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '?',
        isHost: json['isHost'] as bool? ?? false,
        joinOrder: json['joinOrder'] is int ? json['joinOrder'] as int : 0,
      );
}

/// El anfitrión es la única fuente de verdad de quién está en la sala.
/// Cada vez que cambia (alguien se une o se va) manda este mensaje de
/// control a todos para que la lista de participantes se vea igual en
/// cualquier dispositivo.
ChatMessage buildRosterMessage(List<RosterMember> members) => ChatMessage(
      type: MessageType.roster,
      senderId: 'system',
      senderName: 'system',
      text: jsonEncode(members.map((m) => m.toJson()).toList()),
    );

List<RosterMember> decodeRoster(ChatMessage message) {
  if (message.type != MessageType.roster || message.text == null) return const [];
  final list = jsonDecode(message.text!) as List<dynamic>;
  return list.map((e) => RosterMember.fromJson(e as Map<String, dynamic>)).toList();
}
