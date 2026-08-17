import 'dart:async';

import 'package:flutter/material.dart';

import '../features/room/domain/active_room_registry.dart';
import '../features/room/domain/connection_phase.dart';
import '../features/room/domain/room_session.dart';
import '../theme/kena_colors.dart';
import '../theme/kena_typography.dart';
import 'connection_phase_style.dart';

/// Franja global de estado de conexión, montada una sola vez por encima
/// de todo el `Navigator` (ver `MaterialApp.builder` en `main.dart`) —
/// así el usuario ve "Reconectando…"/"Conexión perdida"/"Conexión
/// restablecida" sin importar en qué pantalla esté (Inicio, Lobby,
/// Participantes, un chat privado, etc.), como pide la sección 12 del
/// brief de producto. Se guía por [ActiveRoomRegistry] — no duplica
/// ninguna lógica de red, sólo observa.
class ConnectionBanner extends StatefulWidget {
  const ConnectionBanner({super.key});

  @override
  State<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends State<ConnectionBanner> {
  RoomSession? _session;
  ConnectionPhaseTracker? _tracker;
  StreamSubscription<ConnectionPhase>? _sub;
  StreamSubscription<void>? _becameHostSub;
  ConnectionPhase? _phase;
  bool _justBecameHost = false;

  @override
  void initState() {
    super.initState();
    ActiveRoomRegistry.current.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  @override
  void dispose() {
    ActiveRoomRegistry.current.removeListener(_onSessionChanged);
    _sub?.cancel();
    _becameHostSub?.cancel();
    _tracker?.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    final session = ActiveRoomRegistry.current.value;
    if (identical(session, _session)) return;
    _sub?.cancel();
    _becameHostSub?.cancel();
    _tracker?.dispose();
    _session = session;
    _justBecameHost = false;
    if (session == null) {
      setState(() => _phase = null);
      return;
    }
    final tracker = ConnectionPhaseTracker(session);
    _tracker = tracker;
    _phase = tracker.current;
    _sub = tracker.stream.listen((phase) {
      if (!mounted) return;
      // Se consume una sola vez: el próximo "restablecida" que no venga
      // de un ascenso a anfitrión (p.ej. un corte de wifi cualquiera más
      // tarde) no debe heredar este texto.
      if (phase != ConnectionPhase.restored) _justBecameHost = false;
      setState(() => _phase = phase);
    });
    _becameHostSub = session.becameHostAutomaticallyStream.listen((_) {
      _justBecameHost = true;
    });
  }

  bool get _visible {
    final phase = _phase;
    if (phase == null) return false;
    return connectionPhaseIsPersistent(phase) || phase == ConnectionPhase.restored;
  }

  @override
  Widget build(BuildContext context) {
    // Sin esto, este chip (montado por fuera de cualquier pantalla, vía
    // MaterialApp.builder) no se enteraría de un cambio de tema — ver
    // el doc comment de KenaBackground en theme/kena_colors.dart.
    KenaThemeScope.of(context);
    final phase = _phase;
    final visible = _visible && phase != null;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: visible
                ? _BannerChip(
                    key: ValueKey(phase),
                    label: connectionPhaseLabel(phase, roomName: _session?.roomName, justBecameHost: _justBecameHost),
                    color: connectionPhaseColor(phase),
                    icon: connectionPhaseIcon(phase),
                    spinning: phase == ConnectionPhase.reconnecting,
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _BannerChip extends StatelessWidget {
  const _BannerChip({super.key, required this.label, required this.color, required this.icon, required this.spinning});

  final String label;
  final Color color;
  final IconData icon;
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: KenaColors.bg.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.45)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            spinning
                ? SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(strokeWidth: 1.8, color: color),
                  )
                : Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Text(label, style: KenaTypography.bodySmall.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1, color: color)),
          ],
        ),
      ),
    );
  }
}
