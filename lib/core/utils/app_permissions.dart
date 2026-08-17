import 'package:permission_handler/permission_handler.dart';

/// Pide de una vez los permisos "sensibles" que hacen falta para el rol
/// elegido — se llama al entrar a Crear sala/Unirme a una sala (ver
/// `CreateRoomScreen`/`JoinRoomScreen`), no cuando el componente que
/// cada uno habilita (la cámara del escáner QR, una notificación de
/// mensaje nuevo) recién los necesita. Antes no se pedía nada por
/// adelantado — Android terminaba mostrando el diálogo de permiso a
/// mitad de un flujo ya en marcha (p.ej. al abrir la cámara del QR),
/// lo que en algunos dispositivos dejaba esa pantalla en blanco si el
/// usuario tardaba en responder o lo negaba una vez.
///
/// Nunca bloquea ni lanza: si el usuario niega un permiso, cada
/// pantalla se las arregla igual (ver `qr_scanner_screen.dart` para el
/// caso de cámara) — esto es sólo el empujón temprano para que el
/// caso común (usuario que acepta) no vea el diálogo de golpe más
/// adelante.
Future<void> requestHostPermissions() async {
  await Permission.notification.request();
}

Future<void> requestClientPermissions() async {
  await [Permission.camera, Permission.notification].request();
}
