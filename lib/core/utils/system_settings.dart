import 'package:flutter/services.dart';

/// Wrapper del canal nativo `kena/system_settings` (`MainActivity.kt`):
/// abre la pantalla de Ajustes de red inalámbrica del sistema. No existe
/// una forma de saltar directo a "Zona Wi-Fi"/"Hotspot personal" que
/// funcione igual en todas las marcas (a diferencia de Wi-Fi cliente, no
/// es una pantalla estándar de Android) — se abre la pantalla general de
/// redes como punto de partida y el resto lo cubre el paso a paso escrito
/// (ver `WifiSetupGuide`).
class SystemSettings {
  SystemSettings._();

  static const _channel = MethodChannel('kena/system_settings');

  static Future<void> openWirelessSettings() async {
    try {
      await _channel.invokeMethod('openWirelessSettings');
    } catch (_) {
      // Nunca debe bloquear: si falla, el usuario igual tiene el paso a
      // paso escrito para llegar a mano desde el ícono de Ajustes.
    }
  }
}
