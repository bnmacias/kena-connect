import 'package:flutter/material.dart';

/// Texto con el degradé de marca aplicado como color — para los pocos
/// momentos que ameritan ese peso visual (el nombre "Kena Connect" en
/// Inicio, el código de sala al crearla), no para uso general. Ver
/// auditoría de diseño, sección I: "el degradé de marca hace más que
/// rellenar botones".
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, required this.style, required this.gradient, this.textAlign});

  final String text;
  final TextStyle style;
  final Gradient gradient;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(text, style: style.copyWith(color: Colors.white), textAlign: textAlign),
    );
  }
}
