import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Avisos de mensajes nuevos: sonido + vibración + notificación local
/// cuando corresponda (background, o simplemente no estás mirando ese
/// hilo). Kena no tiene servidor remoto — todo esto sale de eventos
/// locales de mensajes recibidos, nunca de un push real.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// Emite el `threadKey` (ver [showMessage]) cada vez que se toca una
  /// notificación — quien arma la navegación (fuera de este archivo, que
  /// no conoce pantallas/sesiones de sala) escucha esto para abrir el
  /// hilo correspondiente. Sólo cubre la app viva (foreground o
  /// background real, no matada) — el toque sobre una notificación con
  /// la app totalmente cerrada necesitaría además
  /// `getNotificationAppLaunchDetails()` al arrancar, que todavía no está
  /// cableado.
  final _tapController = StreamController<String>.broadcast();
  Stream<String> get taps => _tapController.stream;

  // Los canales de notificación de Android son inmutables una vez
  // creados — ninguna llamada posterior a `createNotificationChannel`
  // puede cambiar su sonido/importancia, sólo el usuario a mano desde
  // Ajustes. Si en algún momento (una versión anterior, una prueba)
  // este canal se creó sin sonido o con importancia baja, cualquier
  // instalación que reutilice el mismo ID queda con eso pegado para
  // siempre, aunque el código de acá diga `playSound: true`. Cambiar el
  // ID fuerza un canal 100% nuevo, sin arrastrar configuración vieja.
  static const _channelId = 'kena_messages_v2';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) _tapController.add(payload);
      },
    );

    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      'Mensajes de Kena',
      description: 'Avisos de mensajes nuevos en tus salas.',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    ));
  }

  /// [threadKey] agrupa notificaciones del mismo hilo bajo el mismo id
  /// (Android la actualiza en vez de apilar una nueva por cada mensaje).
  Future<void> showMessage({
    required String title,
    required String body,
    required String threadKey,
  }) async {
    if (!_ready) await init();
    await _plugin.show(
      id: threadKey.hashCode & 0x7fffffff,
      title: title,
      body: body,
      payload: threadKey,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Mensajes de Kena',
          channelDescription: 'Avisos de mensajes nuevos en tus salas.',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.message,
        ),
      ),
    );
  }

  /// Aviso liviano para "llegó un mensaje en el hilo que ya estás
  /// mirando" — a propósito no es una notificación del sistema (nada de
  /// banner, ni entra al centro de notificaciones): sólo el click corto
  /// que ya usa el propio SO para confirmaciones de UI, así se distingue
  /// de un mensaje que sí necesita que vengas a mirarlo.
  Future<void> playSoftTick() async {
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {
      // Nunca debe romper el flujo de mensajes por esto.
    }
  }
}
