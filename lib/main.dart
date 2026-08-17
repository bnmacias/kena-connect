import 'dart:async';

import 'package:flutter/material.dart';

import 'core/notifications/notification_service.dart';
import 'features/room/chat_thread_screen.dart';
import 'features/room/domain/active_room_registry.dart';
import 'features/root_screen.dart';
import 'theme/kena_colors.dart';
import 'theme/kena_theme_controller.dart';
import 'widgets/connection_banner.dart';

Future<void> main() async {
  // Restaura el tema guardado (si había uno) antes de armar la primera
  // pantalla — así se evita un parpadeo del tema default seguido de un
  // cambio al tema guardado apenas carga SharedPreferences.
  WidgetsFlutterBinding.ensureInitialized();
  await KenaThemeController.instance.load();
  runApp(const KenaApp());
}

/// Navegación fuera del árbol de widgets — hace falta para abrir un chat
/// desde el toque de una notificación, que dispara en un callback sin
/// ningún `BuildContext` propio (ver `NotificationService.taps`).
final navigatorKey = GlobalKey<NavigatorState>();

class KenaApp extends StatefulWidget {
  const KenaApp({super.key});

  @override
  State<KenaApp> createState() => _KenaAppState();
}

class _KenaAppState extends State<KenaApp> {
  StreamSubscription<String>? _tapSub;

  @override
  void initState() {
    super.initState();
    _tapSub = NotificationService.instance.taps.listen(_openThread);
    // MaterialApp.theme se arma a partir del tema activo (ver build()) —
    // sin este listener, el ThemeData quedaría fijo al de arranque para
    // siempre, y los widgets de Material estándar (TextField, Switch,
    // RadioListTile del picker de transferencia, etc.) no seguirían un
    // cambio de tema aunque KenaBackground sí lo haga en cada pantalla.
    KenaThemeController.instance.addListener(_onThemeChanged);
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    _tapSub?.cancel();
    KenaThemeController.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  /// Sólo funciona si hay una sesión de sala viva ahora mismo
  /// (`ActiveRoomRegistry`) — cubre tocar la notificación con la app en
  /// foreground o en segundo plano real (gracias al foreground service),
  /// que es el caso común. Si la app estaba totalmente cerrada, no hay
  /// sesión que abrir todavía en este momento — ver la nota en
  /// `NotificationService.taps`.
  void _openThread(String threadKey) {
    final session = ActiveRoomRegistry.current.value;
    if (session == null) return;
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    final peerId = threadKey == '__general__' ? null : threadKey;
    navigator.push(
      MaterialPageRoute(builder: (_) => ChatThreadScreen(session: session, peerId: peerId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // KenaThemeScope tiene que envolver todo el árbol: es lo que le
    // permite a KenaBackground (una por pantalla) enterarse de un
    // cambio de tema y reconstruirse — ver el doc comment de
    // KenaBackground en theme/kena_colors.dart para el porqué.
    return KenaThemeScope(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Kena Connect',
        theme: buildKenaTheme(KenaThemeController.instance.value),
        home: const RootScreen(),
        // Franja global de estado de conexión: montada una sola vez por
        // encima de todo el Navigator, para que se vea en cualquier
        // pantalla sin que cada una tenga que suscribirse a nada (ver
        // ConnectionBanner y ARCHITECTURE.md).
        builder: (context, child) => Stack(
          children: [
            ?child,
            const ConnectionBanner(),
          ],
        ),
      ),
    );
  }
}
