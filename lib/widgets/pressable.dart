import 'package:flutter/material.dart';

/// Feedback de presión (achicarse un poco al tocar) — hoy la app sólo
/// tenía el ripple por defecto de Material en filas/tarjetas/botones,
/// sin ningún indicio táctil de que algo reaccionó al toque antes de
/// que termine la acción (ver auditoría de diseño, sección I y
/// prioridad P1 "movimiento"). Usa `Listener` (no `GestureDetector`)
/// a propósito: sólo observa el puntero, nunca compite por el gesto
/// con el `InkWell`/`onTap` real que ya tiene el widget envuelto.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.scale = 0.97});

  final Widget child;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
