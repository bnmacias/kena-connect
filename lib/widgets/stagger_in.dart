import 'package:flutter/material.dart';

/// Entrada escalonada para listas — cada elemento aparece con un
/// pequeño desfasaje respecto al anterior en vez de que todos salten a
/// la vez, para que la pantalla se sienta viva sin ser ruidosa (ver
/// auditoría de diseño, hallazgo #6 y sección I). Corre una sola vez,
/// al montarse — no se repite en reconstrucciones posteriores.
class StaggerIn extends StatelessWidget {
  const StaggerIn({super.key, required this.index, required this.child, this.baseDelayMs = 0});

  final int index;
  final Widget child;
  final int baseDelayMs;

  @override
  Widget build(BuildContext context) {
    final delay = baseDelayMs + index * 45;
    return TweenAnimationBuilder<double>(
      key: ValueKey('stagger-$index-$baseDelayMs'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        // El delay se simula estirando la duración y arrancando la
        // curva recién pasado ese punto — evita depender de
        // `Future.delayed`/`AnimationController` propio sólo para
        // escalonar una entrada que corre una vez.
        final t = ((value * (320 + delay) - delay) / 320).clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(t);
        return Opacity(
          opacity: eased,
          child: Transform.translate(offset: Offset(0, (1 - eased) * 12), child: child),
        );
      },
      child: child,
    );
  }
}
