import 'package:flutter/material.dart';

import '../theme/kena_colors.dart';

/// La marca de Kena: anillos de señal concéntricos alrededor de un
/// círculo con degradé de marca — la firma visual de "red sin
/// Internet" en onboarding, Inicio y momentos de conexión. [icon]
/// permite variar el ícono central (por ejemplo, en cada paso del
/// onboarding — ver `OnboardingScreen`) sin perder la marca en sí.
class SignalRings extends StatelessWidget {
  const SignalRings({super.key, this.size = 84, this.active = true, this.icon = Icons.wifi_rounded});

  final double size;
  final bool active;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (active) ...[
            _ring(size, 0.15),
            _ring(size * 0.72, 0.3),
            _ring(size * 0.46, 0.55),
          ],
          Container(
            width: size * 0.32,
            height: size * 0.32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: KenaColors.brandGradient,
              boxShadow: [
                BoxShadow(color: KenaColors.accent.withValues(alpha: 0.22), blurRadius: size * 0.25),
              ],
            ),
            child: Icon(icon, size: size * 0.16, color: KenaColors.onAccent),
          ),
        ],
      ),
    );
  }

  Widget _ring(double ringSize, double opacity) {
    return Container(
      width: ringSize,
      height: ringSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: KenaColors.accent.withValues(alpha: opacity)),
      ),
    );
  }
}
