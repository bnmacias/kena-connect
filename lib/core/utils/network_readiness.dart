import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Si el dispositivo tiene ahora mismo una red local utilizable para
/// armar una sala. Kena arma una red LAN, no usa Internet — datos
/// móviles no sirven para esto aunque den "conectividad", así que se
/// pide específicamente Wi-Fi (o Ethernet, para desktop). Ver la
/// sección "Hotspot / red local" del brief de producto y
/// ARCHITECTURE.md.
///
/// Capacidad real de la plataforma (no inventada): `connectivity_plus`
/// expone el tipo de red activa a través de las APIs estándar de cada
/// SO (`ConnectivityManager` en Android). No existe una forma
/// multiplataforma de *activar* Wi-Fi mediante programación sin
/// permisos elevados — por eso esto es sólo lectura/detección, nunca
/// activación automática (ver `NetworkSetupGate`).
///
/// `connectivity_plus` sólo informa la red por la que este dispositivo
/// *sale* (de qué red es cliente) — nunca ve una que el propio
/// dispositivo esté transmitiendo. Por eso, si el anfitrión prendió a
/// mano su hotspot clásico (Ajustes > Conexiones > Hotspot personal,
/// el caso típico de "dos teléfonos sin ningún router cerca"),
/// `checkConnectivity()` sigue devolviendo "sin red" para siempre — el
/// teléfono no es cliente de nada, está transmitiendo. `hasOwnHotspotInterface`
/// cubre exactamente ese hueco mirando las interfaces de red en vez de
/// la conectividad "de salida".
Future<bool> hasUsableLocalNetwork() async {
  final results = await Connectivity().checkConnectivity();
  if (_isUsable(results)) return true;
  return hasOwnHotspotInterface();
}

/// `true` si hay una interfaz de red local con una IP privada (RFC1918)
/// que no sea de datos móviles — cubre tanto ser cliente Wi-Fi (aunque
/// `connectivity_plus` ya debería haberlo visto) como estar transmitiendo
/// el propio hotspot (interfaz `ap0`/`wlan0` en modo punto de acceso,
/// donde el dispositivo nunca es "cliente" de nada). Se excluyen las
/// interfaces de datos móviles por nombre porque también tienen IP
/// asignada, pero esa IP nunca es alcanzable por otro dispositivo en la
/// misma sala — no serviría para bindear el servidor de chat.
Future<bool> hasOwnHotspotInterface() async {
  try {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    for (final iface in interfaces) {
      final name = iface.name.toLowerCase();
      if (name.startsWith('rmnet') || name.startsWith('ccmni') || name.startsWith('pdp') || name.startsWith('cellular')) {
        continue;
      }
      for (final addr in iface.addresses) {
        if (_isPrivateIPv4(addr.address)) return true;
      }
    }
  } catch (_) {
    // No se pudo enumerar interfaces (plataforma sin soporte, permiso
    // denegado): no es peor que lo que ya sabíamos por connectivity_plus.
  }
  return false;
}

bool _isPrivateIPv4(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) return false;
  final octets = [for (final p in parts) int.tryParse(p) ?? -1];
  if (octets.any((o) => o < 0 || o > 255)) return false;
  if (octets[0] == 10) return true;
  if (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) return true;
  if (octets[0] == 192 && octets[1] == 168) return true;
  return false;
}

/// Emite cada vez que cambia si hay o no una red local utilizable —
/// permite detectar solo, sin que el usuario tenga que volver a tocar
/// nada, el momento en que activa el Wi-Fi (sección 39 del brief).
Stream<bool> get localNetworkChanges =>
    Connectivity().onConnectivityChanged.map(_isUsable);

bool _isUsable(List<ConnectivityResult> results) =>
    results.any((r) => r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet);
