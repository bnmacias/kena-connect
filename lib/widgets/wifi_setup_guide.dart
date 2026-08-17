import 'package:flutter/material.dart';

import '../core/utils/system_settings.dart';
import '../theme/kena_colors.dart';
import '../theme/kena_spacing.dart';
import '../theme/kena_typography.dart';

/// Kena no puede activar la Zona Wi-Fi ni conectarse a ella por su
/// cuenta (se intentó — ver `archive/auto_wifi_attempt/` — Android
/// rechaza la creación automática de un punto de acceso en la mayoría
/// de los dispositivos reales). En vez de un cartel genérico ("activá
/// tu Wi-Fi"), esto explica el camino real paso a paso, distinto según
/// el rol, con un atajo a Ajustes.
enum WifiSetupRole { host, client }

class WifiSetupGuide extends StatelessWidget {
  const WifiSetupGuide({super.key, required this.role});

  final WifiSetupRole role;

  static const _hostSteps = [
    'Abrí los Ajustes de tu teléfono.',
    'Buscá "Zona Wi-Fi", "Hotspot personal" o "Compartir Internet" — el nombre cambia según la marca (Samsung: "Uso compartido de conexión y Zona Wi-Fi". Xiaomi: "Hotspot personal". Motorola/Android puro: "Zona Wi-Fi portátil").',
    'Activala. Los datos móviles pueden quedar apagados — Kena no los necesita.',
    'Volvé a Kena: la vamos a detectar sola y seguir automáticamente, sin que toques nada más acá.',
  ];

  static const _clientSteps = [
    'Pedile al anfitrión el nombre de su red y la contraseña — las va a ver en su propia pantalla, en Ajustes → Zona Wi-Fi.',
    'Andá a los Ajustes de Wi-Fi de tu teléfono.',
    'Buscá esa red en la lista de redes disponibles y conectate con la contraseña.',
    'Volvé a Kena y escaneá el QR o ingresá el código — ya vas a estar en la misma red.',
  ];

  @override
  Widget build(BuildContext context) {
    final steps = role == WifiSetupRole.host ? _hostSteps : _clientSteps;
    final title = role == WifiSetupRole.host
        ? 'Activá tu Zona Wi-Fi para que los demás puedan conectarse'
        : 'Conectate a la red del anfitrión';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KenaColors.card2,
        borderRadius: BorderRadius.circular(KenaRadius.card),
        border: Border.all(color: KenaColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: KenaTypography.bodySmall.copyWith(color: KenaColors.text, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(color: KenaColors.accent, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: KenaTypography.caption.copyWith(color: KenaColors.onAccent, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: KenaTypography.bodySmall.copyWith(color: KenaColors.text2, fontSize: 12, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: SystemSettings.openWirelessSettings,
              icon: const Icon(Icons.settings_rounded, size: 16),
              label: const Text('Abrir Ajustes de red'),
              style: OutlinedButton.styleFrom(
                foregroundColor: KenaColors.accent,
                side: BorderSide(color: KenaColors.line),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
