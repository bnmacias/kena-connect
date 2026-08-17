import 'package:flutter/services.dart';

/// Wrapper del canal nativo `kena/foreground_service`
/// (`ChatForegroundService.kt`): mantiene vivo el proceso de la app
/// mientras hay una sala activa, para que el socket del chat (y las
/// notificaciones de mensajes nuevos, ver `NotificationService`) sigan
/// funcionando aunque la pantalla se bloquee o la app pase a segundo
/// plano — sin esto, Android suspende el proceso a los pocos segundos
/// (Doze / App Standby) y la conexión se corta de hecho, aunque el
/// usuario nunca haya salido de la sala.
///
/// Sólo Android — en cualquier otra plataforma es un no-op silencioso
/// (nada que hacer: no hay una limitación de background equivalente en
/// desktop, y la sala sigue andando igual en primer plano si el canal no
/// existe).
class RoomForegroundService {
  RoomForegroundService._();

  static const _channel = MethodChannel('kena/foreground_service');

  static Future<void> start(String roomName) async {
    try {
      await _channel.invokeMethod('start', {'roomName': roomName});
    } catch (_) {
      // Nunca debe bloquear el uso de la sala — sin esto sólo se pierde
      // la persistencia en segundo plano, no la sala en primer plano.
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }
}
