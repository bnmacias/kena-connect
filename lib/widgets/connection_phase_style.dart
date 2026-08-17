import 'package:flutter/material.dart';

import '../features/room/domain/connection_phase.dart';
import '../theme/kena_colors.dart';

/// Color/ícono de cada [ConnectionPhase], compartido por la franja
/// global ([ConnectionBanner]) y por el indicador propio de cada
/// pantalla de sala (appbar de `RoomShellScreen`/`ChatThreadScreen`) —
/// una sola fuente de verdad para no repintar el mismo semáforo con
/// reglas ligeramente distintas en cada lugar.
Color connectionPhaseColor(ConnectionPhase phase) {
  switch (phase) {
    case ConnectionPhase.unstable:
    case ConnectionPhase.reconnecting:
      return const Color(0xFFF2B33D);
    case ConnectionPhase.lost:
      return KenaColors.red;
    case ConnectionPhase.restored:
    case ConnectionPhase.connected:
      return KenaColors.green;
    case ConnectionPhase.preparing:
    case ConnectionPhase.connecting:
      return KenaColors.text2;
  }
}

IconData connectionPhaseIcon(ConnectionPhase phase) {
  switch (phase) {
    case ConnectionPhase.unstable:
      return Icons.signal_wifi_statusbar_connected_no_internet_4_rounded;
    case ConnectionPhase.reconnecting:
      return Icons.sync_rounded;
    case ConnectionPhase.lost:
      return Icons.wifi_off_rounded;
    case ConnectionPhase.restored:
    case ConnectionPhase.connected:
      return Icons.check_circle_rounded;
    case ConnectionPhase.preparing:
    case ConnectionPhase.connecting:
      return Icons.wifi_rounded;
  }
}
