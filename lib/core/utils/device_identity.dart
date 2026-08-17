import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Identificador de este dispositivo dentro de una sala, persistido
/// localmente — a diferencia de un id generado al vuelo por instancia de
/// pantalla (`identityHashCode(this)`, lo que se usaba antes), éste no
/// cambia entre reinicios de la app.
///
/// Esa diferencia importaba en la práctica: el historial de chat
/// restaurado (`ChatHistoryStore`) guarda los mensajes con el `senderId`
/// que tenían en el momento de mandarlos. Si el id cambia de una sesión
/// a la siguiente (como pasaba con `identityHashCode`, que depende de la
/// instancia del widget y es distinto cada vez que se recrea la
/// pantalla — típicamente al volver a entrar después de matar la app),
/// los mensajes propios de antes dejan de reconocerse como propios al
/// compararlos contra `mySenderId`: se veían alineados a la izquierda,
/// con el estilo de "recibido", como si fueran de otra persona.
class DeviceIdentity {
  DeviceIdentity._();

  static const _key = 'kena.device.senderId';
  static String? _cached;

  static Future<String> get() async {
    final cached = _cached;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key);
    if (id == null || id.isEmpty) {
      id = 'p-${Random.secure().nextInt(1 << 31)}-${DateTime.now().microsecondsSinceEpoch}';
      await prefs.setString(_key, id);
    }
    _cached = id;
    return id;
  }
}
