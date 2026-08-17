import 'package:flutter/material.dart';

import '../../theme/kena_colors.dart';
import '../../theme/kena_typography.dart';

class AboutKenaScreen extends StatelessWidget {
  const AboutKenaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KenaBackground(
      builder: (context) => Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Acerca de Kena')),
      body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: KenaColors.brandGradient),
                child: Icon(Icons.wifi_tethering_rounded, size: 32, color: KenaColors.onAccent),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text('Kena Connect', style: KenaTypography.titleXL.copyWith(color: KenaColors.text)),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text('Conectados, incluso sin Internet.', style: KenaTypography.bodySmall.copyWith(color: KenaColors.accent)),
            ),
            const SizedBox(height: 24),
            Text(
              'Kena Connect te deja crear una sala de chat entre los '
              'dispositivos que están cerca tuyo, usando la red Wi-Fi local '
              'de tus dispositivos — sin necesitar datos ni Internet.',
              style: KenaTypography.body.copyWith(color: KenaColors.text2, height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Pensada para aviones, cruceros, rutas sin señal, montañas, '
              'campings, excursiones, eventos, o cualquier lugar donde un '
              'grupo cercano necesite comunicarse sin cobertura.',
              style: KenaTypography.body.copyWith(color: KenaColors.text2, height: 1.4),
            ),
            const SizedBox(height: 24),
            Divider(color: KenaColors.line),
            const SizedBox(height: 12),
            Text('Versión 1.0.0', style: KenaTypography.bodySmall.copyWith(color: KenaColors.text2)),
          ],
        ),
      ),
    );
  }
}
