import 'package:flutter/material.dart';

import '../core/network/chat_client_connection.dart';
import '../theme/kena_colors.dart';
import '../theme/kena_typography.dart';

/// Fuerza de señal como 4 barras crecientes — el indicador de conexión
/// deja de ser "un punto de color chico" y pasa a ser protagonista,
/// como pide el sistema de diseño.
///
/// **Sobre la honestidad de estos datos**: no existe (ni se agregó)
/// telemetría real de RSSI/latencia por dispositivo — eso viviría en la
/// capa de red, que esta pantalla no toca. `strength` sale siempre de
/// datos que ya existen:
///  - la conexión propia → [SignalBars.fromStatus] mapea
///    [ConnectionStatus] (conectado = 4, reconectando = 2, perdida = 0);
///  - un participante en el roster → 4 fijo, porque "está en la lista"
///    ya significa "conectado al anfitrión ahora mismo"; no hay forma
///    honesta de mostrar una variación más fina sin inventar un número.
class SignalBars extends StatelessWidget {
  const SignalBars({super.key, required this.strength, this.label, this.barHeight = 13});

  final int strength;
  final String? label;
  final double barHeight;

  factory SignalBars.fromStatus(ConnectionStatus status, {String? label}) {
    final strength = switch (status) {
      ConnectionStatus.connected => 4,
      ConnectionStatus.reconnecting => 2,
      ConnectionStatus.lost || ConnectionStatus.closedByHost => 0,
    };
    return SignalBars(strength: strength, label: label);
  }

  @override
  Widget build(BuildContext context) {
    const heights = [0.31, 0.54, 0.77, 1.0];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Container(
                  width: 3,
                  height: barHeight * heights[i],
                  decoration: BoxDecoration(
                    color: i < strength ? KenaColors.accent : KenaColors.track,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
          ],
        ),
        if (label != null) ...[
          const SizedBox(width: 8),
          Text(label!, style: KenaTypography.caption.copyWith(fontSize: 11, color: KenaColors.text2, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}
