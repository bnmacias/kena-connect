import 'package:flutter/material.dart';

import '../core/utils/avatar.dart';

/// Círculo de avatar con iniciales — mismo componente para Mi perfil,
/// participantes, salas encontradas y conversaciones.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.color, required this.initial, this.size = 34});

  final Color color;
  final String initial;
  final double size;

  /// Construye a partir de un nombre, derivando color e inicial de la
  /// misma forma que el resto de la app (`avatarColorFor`/`initialsFor`).
  factory Avatar.forName(String name, {double size = 34}) =>
      Avatar(color: avatarColorFor(name), initial: initialsFor(name), size: size);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size * 0.32)),
      child: Text(
        initial,
        style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}
