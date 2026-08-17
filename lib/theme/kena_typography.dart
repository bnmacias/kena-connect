import 'package:flutter/material.dart';

import 'kena_colors.dart';

/// Escala tipográfica de Kena — dos familias con roles fijos: Fraunces
/// (serif editorial, con carácter) reservada a los momentos de mayor
/// jerarquía (el código de sala, títulos grandes), y Manrope (sans
/// limpia) para todo lo demás — chrome de UI, cuerpo, labels. Ver
/// auditoría de diseño, sección J.
///
/// 8 pasos, cada uno con un rol fijo — cualquier texto nuevo debería
/// salir de acá, no de un `fontSize` suelto (ver auditoría, hallazgo #2:
/// antes de esto había 19 tamaños de fuente distintos usados en el
/// código para los mismos roles, repetidos con variaciones de medio
/// punto entre pantalla y pantalla).
///
/// Son getters (no `const`) porque el color sale de [KenaColors], que a
/// su vez depende del tema activo — así una pantalla que reconstruye por
/// un cambio de tema (ver `KenaBackground`) siempre lee el color correcto
/// sin tener que pasarlo a mano en cada sitio.
class KenaTypography {
  KenaTypography._();

  static const fontDisplay = 'Fraunces Kena';
  static const fontBody = 'Manrope Kena';

  /// El momento de mayor jerarquía de toda la app — hoy sólo el título
  /// de marca en Inicio.
  static TextStyle get display => TextStyle(
        fontFamily: fontDisplay,
        fontSize: 28,
        height: 34 / 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: KenaColors.text,
      );

  /// Igual de grande que [display] pero para momentos secundarios de
  /// marca (el aviso de "alguien quiere unirse", por ejemplo, quiere
  /// sentirse importante sin competir con el título de Inicio).
  static TextStyle get titleL => TextStyle(
        fontFamily: fontDisplay,
        fontSize: 26,
        height: 32 / 26,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: KenaColors.text,
      );

  /// Encabezado de una hoja o de un momento puntual — el nombre de la
  /// sala en Detalles de la sala, el título de una hoja de confirmación.
  static TextStyle get titleXL => TextStyle(
        fontFamily: fontDisplay,
        fontSize: 20,
        height: 26 / 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
        color: KenaColors.text,
      );

  /// Título de pantalla/fila — barras superiores, nombres de fila con
  /// énfasis.
  static TextStyle get title => TextStyle(
        fontFamily: fontBody,
        fontSize: 16.5,
        fontWeight: FontWeight.w700,
        color: KenaColors.text,
      );

  /// Contenido que se lee de corrido y es el protagonista de la
  /// pantalla — hoy sólo el texto de un mensaje de chat.
  static TextStyle get bodyLarge => TextStyle(
        fontFamily: fontBody,
        fontSize: 15.5,
        height: 1.4,
        fontWeight: FontWeight.w500,
        color: KenaColors.text,
      );

  static TextStyle get body => TextStyle(
        fontFamily: fontBody,
        fontSize: 14.5,
        height: 1.5,
        fontWeight: FontWeight.w500,
        color: KenaColors.text,
      );

  static TextStyle get bodySmall => TextStyle(
        fontFamily: fontBody,
        fontSize: 13,
        height: 1.5,
        fontWeight: FontWeight.w500,
        color: KenaColors.text2,
      );

  /// Mayúsculas por convención de uso, no automáticas — llamá
  /// `.toUpperCase()` sobre el string en el call site (mismo patrón que
  /// ya usaba `KenaField`).
  static TextStyle get label => TextStyle(
        fontFamily: fontBody,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: KenaColors.text3,
      );

  static TextStyle get caption => TextStyle(
        fontFamily: fontBody,
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: KenaColors.text3,
      );

  /// El código de sala (`KENA-XXXX`) — aparece en 2 lugares (la sala
  /// lista al crearla/retomarla, y Detalles de la sala) y es el objeto
  /// central de la propuesta de valor (ver ARCHITECTURE.md): siempre el
  /// mismo tratamiento tipográfico, nunca texto secundario. Pensado
  /// para envolverse en `GradientText` (ver widgets/gradient_text.dart)
  /// — el color acá es sólo el valor por defecto si se usa suelto.
  static TextStyle get code => TextStyle(
        fontFamily: fontDisplay,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: KenaColors.accent,
      );
}
