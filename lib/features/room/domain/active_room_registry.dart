import 'package:flutter/foundation.dart';

import 'room_session.dart';

/// A qué sala está conectado este dispositivo *ahora mismo*, si hay
/// alguna. `RoomShellScreen` se registra acá al entrar a una sala y se
/// da de baja recién cuando esa sala termina (salir/finalizar) — no
/// cuando el usuario simplemente navega para atrás sin salir, para que
/// Home pueda ofrecerle "Entrar" y retomarla en vez de perderla.
///
/// No hay historial de salas visible para el usuario (ver
/// ROADMAP.md) — esto es sólo el estado *actual*, no un registro.
class ActiveRoomRegistry {
  ActiveRoomRegistry._();

  static final ValueNotifier<RoomSession?> current = ValueNotifier<RoomSession?>(null);

  static void set(RoomSession session) => current.value = session;

  static void clearIfCurrent(RoomSession session) {
    if (identical(current.value, session)) current.value = null;
  }
}
