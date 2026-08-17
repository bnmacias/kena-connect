import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/kena_colors.dart';
import '../theme/kena_spacing.dart';
import '../theme/kena_typography.dart';
import 'pressable.dart';

/// Botón primario "vidrio líquido": blur + degradé translúcido + borde
/// con brillo direccional + sombra compuesta. Versión atenuada a
/// propósito (ver kena-connect-design-spec.md) para no cansar la vista
/// en uso prolongado.
///
/// Costoso en gama media — reservado para botones primarios y el
/// círculo de enviar, nunca para filas repetidas en una lista.
class KenaGlassButton extends StatelessWidget {
  const KenaGlassButton({
    super.key,
    required this.child,
    this.onPressed,
    this.danger = false,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final gradient = danger
        ? LinearGradient(colors: [KenaColors.red.withValues(alpha: 0.32), KenaColors.red.withValues(alpha: 0.32)])
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [KenaColors.gradA.withValues(alpha: 0.32), KenaColors.gradB.withValues(alpha: 0.32)],
          );
    final shadowColor = danger ? KenaColors.red : KenaColors.accent;

    final button = ClipRRect(
      borderRadius: BorderRadius.circular(KenaRadius.button),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KenaRadius.button),
            gradient: disabled ? null : gradient,
            // Deshabilitado: superficie neutra (no hay degradé de color
            // detrás), así que usa el mismo tinte que el resto del
            // sistema para "algo apenas visible sobre el fondo" en vez
            // de un blanco fijo que desaparece en un tema claro.
            color: disabled ? KenaColors.overlayHover : null,
            // Border.all (no per-side colors): Flutter no puede pintar un
            // borderRadius sobre un Border con colores no uniformes por
            // lado — tira "A borderRadius can only be given on borders
            // with uniform colors" en paint. Habilitado: blanco fijo es
            // intencional, es el brillo de vidrio sobre el degradé de
            // color (funciona en cualquier tema porque el degradé mismo
            // ya tiene el contraste resuelto). Deshabilitado: no hay
            // degradé debajo, así que usa un borde neutro del tema.
            border: Border.all(
              color: disabled ? KenaColors.lineStrong : Colors.white.withValues(alpha: 0.28),
            ),
            boxShadow: disabled
                ? const []
                : [
                    BoxShadow(
                      color: shadowColor.withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Opacity(
            opacity: disabled ? 0.5 : 1,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(KenaRadius.button),
                onTap: onPressed,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  // Align con heightFactor: 1 (no Center) — Center se
                  // estira para llenar toda la altura disponible cuando
                  // el padre da constraints sueltas pero acotadas (p.ej.
                  // Scaffold.bottomNavigationBar), lo que infla el botón
                  // a pantalla completa. heightFactor fuerza el alto a
                  // ajustarse al contenido sin importar el padre.
                  child: Align(
                    heightFactor: 1,
                    child: DefaultTextStyle(
                      style: KenaTypography.body.copyWith(height: 1, fontWeight: FontWeight.w700, color: KenaColors.onAccent),
                      child: IconTheme(
                        data: IconThemeData(color: KenaColors.onAccent, size: 16),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return disabled ? button : Pressable(child: button);
  }
}

/// Botón secundario "fantasma": la misma familia visual, pero más
/// discreto — sin degradé de color, blur más bajo — para que nunca
/// compita con un [KenaGlassButton] en la misma pantalla.
class KenaGhostButton extends StatelessWidget {
  const KenaGhostButton({super.key, required this.child, this.onPressed, this.danger = false});

  final Widget child;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final button = ClipRRect(
      borderRadius: BorderRadius.circular(KenaRadius.card),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KenaRadius.card),
            color: KenaColors.overlayHover,
            border: Border.all(color: KenaColors.lineStrong),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(KenaRadius.card),
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Align(
                  heightFactor: 1,
                  child: DefaultTextStyle(
                    style: KenaTypography.bodySmall.copyWith(
                      fontSize: 13.5,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      color: danger ? KenaColors.red : KenaColors.text,
                    ),
                    child: IconTheme(
                      data: IconThemeData(color: danger ? KenaColors.red : KenaColors.text, size: 15),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return onPressed == null ? button : Pressable(child: button);
  }
}
