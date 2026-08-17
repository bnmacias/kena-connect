/// Metadata organizativa de una sala dentro de un grupo — por ejemplo,
/// dentro de "Familia Macías": General, Padres, Hermanos, Primos (ver
/// brief, sección 5).
///
/// **Importante:** esto NO es la sala de red en vivo (`RoomSession`,
/// `ChatHostServer` — ver `features/room/domain/room_session.dart`).
/// Esas siguen siendo sesiones locales efímeras atadas a una red Wi-Fi
/// física, sin ningún cambio (el brief pide explícitamente no tocar el
/// networking existente). `GroupRoom` es sólo el nombre/organización que
/// un grupo le da a "las salas que solemos armar" — quien la abre de
/// verdad sigue pasando por el flujo de Crear/Unirme sala de siempre;
/// no hay (todavía) forma de que una `GroupRoom` abra sola una conexión
/// de red, porque eso requeriría que el dispositivo que la abre esté
/// físicamente en la misma red local que quien la crea, algo que un
/// backend de grupos no puede resolver por sí solo.
class GroupRoom {
  final String id;
  final String groupId;
  final String name;
  final String createdByUserId;
  final DateTime createdAt;

  const GroupRoom({
    required this.id,
    required this.groupId,
    required this.name,
    required this.createdByUserId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'name': name,
        'createdByUserId': createdByUserId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory GroupRoom.fromJson(Map<String, dynamic> json) => GroupRoom(
        id: json['id'] as String,
        groupId: json['groupId'] as String,
        name: json['name'] as String,
        createdByUserId: json['createdByUserId'] as String,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}
