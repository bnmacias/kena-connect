import 'package:flutter/material.dart';

import '../../theme/kena_colors.dart';
import '../../theme/kena_spacing.dart';
import '../../theme/kena_typography.dart';

class _PermissionInfo {
  final IconData icon;
  final String title;
  final String why;
  const _PermissionInfo({required this.icon, required this.title, required this.why});
}

const _permissions = [
  _PermissionInfo(
    icon: Icons.wifi_tethering_rounded,
    title: 'Ubicación / dispositivos cercanos',
    why: 'Lo exige Android para crear la red local de una sala cuando no hay '
        'ninguna disponible (API del sistema, no elección de Kena). Kena no '
        'calcula, guarda ni envía tu ubicación — no la usa para nada más que eso.',
  ),
  _PermissionInfo(
    icon: Icons.camera_alt_outlined,
    title: 'Cámara',
    why: 'Sólo para leer el código QR al unirte a una sala. La cámara no se '
        'usa para nada más, y no se guarda ninguna imagen.',
  ),
  _PermissionInfo(
    icon: Icons.notifications_none_rounded,
    title: 'Notificaciones y vibración',
    why: 'Para avisarte de mensajes nuevos en tus salas — se pueden apagar '
        'desde la sala en cualquier momento ("Silenciar notificaciones").',
  ),
  _PermissionInfo(
    icon: Icons.settings_ethernet_rounded,
    title: 'Estado de la red',
    why: 'Para saber si tu dispositivo ya tiene Wi-Fi antes de crear una sala, '
        'y para poder armar la conexión local en sí (Android exige el permiso '
        '"Internet" para cualquier conexión por socket, incluso una que nunca '
        'sale de tu red local — Kena no usa datos móviles ni Internet real).',
  ),
];

/// "Privacidad" en Configuración — hasta esta etapa era un placeholder
/// "Próximamente"; ahora es real. Explica, en criollo, qué pide Kena y
/// por qué, sin usar la app como excusa para simular funciones que no
/// existen (ninguna cuenta, ningún dato remoto).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KenaBackground(
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Privacidad')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Kena no tiene servidor propio ni cuenta de usuario. Todo lo que '
              'pasa dentro de una sala — mensajes, quién está conectado — vive '
              'únicamente en los dispositivos de esa sala, mientras dura. Nada '
              'se manda a Internet ni a ningún tercero.',
              style: KenaTypography.body.copyWith(color: KenaColors.text2, height: 1.5),
            ),
            const SizedBox(height: 24),
            Text('PERMISOS Y PARA QUÉ SE USAN',
                style: KenaTypography.label.copyWith(fontSize: 11, color: KenaColors.text2)),
            const SizedBox(height: 12),
            for (final p in _permissions)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: KenaColors.accentSoft, borderRadius: BorderRadius.circular(KenaRadius.sm)),
                      child: Icon(p.icon, size: 18, color: KenaColors.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.title, style: KenaTypography.bodySmall.copyWith(fontWeight: FontWeight.w700, color: KenaColors.text, fontSize: 13.5)),
                          const SizedBox(height: 3),
                          Text(p.why, style: KenaTypography.bodySmall.copyWith(color: KenaColors.text2, fontSize: 12.5, height: 1.45)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Divider(color: KenaColors.line),
            const SizedBox(height: 16),
            Text('QUÉ NO HACE KENA',
                style: KenaTypography.label.copyWith(fontSize: 11, color: KenaColors.text2)),
            const SizedBox(height: 12),
            const _NoItem('No pide cuenta, mail ni teléfono.'),
            const _NoItem('No manda mensajes, contactos ni ubicación a ningún servidor.'),
            const _NoItem('No usa datos móviles ni Internet real — todo queda en la red local que arma la sala.'),
            const _NoItem('No comparte datos con terceros ni con analítica de ningún tipo.'),
            const SizedBox(height: 24),
            Text(
              'Tu nombre y el color de tu avatar (Mi perfil) se guardan sólo en '
              'este dispositivo, para no tener que volver a escribirlos cada '
              'vez. Se pueden borrar desinstalando la app.',
              style: KenaTypography.caption.copyWith(color: KenaColors.text3, fontSize: 11.5, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoItem extends StatelessWidget {
  const _NoItem(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.close_rounded, size: 14, color: KenaColors.red),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: KenaTypography.bodySmall.copyWith(color: KenaColors.text2, fontSize: 12.5, height: 1.4))),
        ],
      ),
    );
  }
}
