import 'package:flutter/material.dart';

import '../theme/kena_colors.dart';
import '../theme/kena_typography.dart';
import 'avatar.dart';
import 'signal_bars.dart';

/// Fila de un participante — usada en el lobby y en Participantes.
/// `signal` es honesto (ver [SignalBars]): 4 si está presente en el
/// roster ahora mismo, no un número inventado.
class ParticipantRow extends StatelessWidget {
  const ParticipantRow({
    super.key,
    required this.name,
    this.isSelf = false,
    this.isHost = false,
    this.signal = 4,
    this.trailing,
  });

  final String name;
  final bool isSelf;
  final bool isHost;
  final int signal;

  /// Acción extra al final de la fila (p.ej. transferir anfitrión) —
  /// se agrega después de las barras de señal, sin reemplazarlas.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final label = isSelf ? 'Vos' : name;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Avatar.forName(name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: KenaTypography.bodySmall.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700, height: 1, color: KenaColors.text),
                      ),
                    ),
                    if (isHost) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.workspace_premium_rounded, size: 13, color: KenaColors.accent),
                    ],
                  ],
                ),
                Text(
                  isHost ? 'Anfitrión' : 'Participante',
                  style: KenaTypography.caption.copyWith(color: KenaColors.text2),
                ),
              ],
            ),
          ),
          SignalBars(strength: signal),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing!,
          ],
        ],
      ),
    );
  }
}
