import 'package:flutter/material.dart';

import '../theme/kena_colors.dart';
import '../theme/kena_spacing.dart';
import 'pressable.dart';

/// Fila/tarjeta plana del sistema — sin blur. El blur es la excepción
/// que marca jerarquía (ver [KenaGlassButton]); esto es la regla para
/// todo lo demás: filas de lista, tarjetas de opción, inputs.
class KenaCard extends StatelessWidget {
  const KenaCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    this.color,
    this.margin,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? KenaColors.card,
        borderRadius: BorderRadius.circular(KenaRadius.card),
        border: Border.all(color: KenaColors.line),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(KenaRadius.card),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return onTap == null ? content : Pressable(child: content);
  }
}

/// Ícono chico dentro de un cuadrado con fondo teal al 14% — el
/// "chip" que precede a la mayoría de las filas del sistema.
class KenaIconChip extends StatelessWidget {
  const KenaIconChip({super.key, required this.icon, this.size = 34});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: KenaColors.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.29),
      ),
      child: Icon(icon, color: KenaColors.accent, size: size * 0.5),
    );
  }
}
