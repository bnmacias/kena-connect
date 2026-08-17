import 'package:flutter/material.dart';

/// Revelado con un leve rebote — para el momento que más lo amerita en
/// toda la app: el código/QR de una sala recién lista para compartir
/// (ver auditoría de diseño, sección I — "es el corazón de la
/// propuesta de valor y hoy no tiene ninguna animación"). Corre una
/// sola vez al montarse, igual que [StaggerIn]/`_MessageIn`.
class RevealIn extends StatelessWidget {
  const RevealIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0, 1),
        child: Transform.scale(scale: 0.85 + (value.clamp(0, 1.2) * 0.15), child: child),
      ),
      child: child,
    );
  }
}
