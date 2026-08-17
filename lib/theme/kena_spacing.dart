/// Escala de espaciado de Kena — base de 4px. Toda pantalla nueva debería
/// elegir exclusivamente de acá en vez de inventar un número de padding
/// suelto (ver auditoría de diseño, sección J).
class KenaSpacing {
  KenaSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const xxxxl = 40.0;
}

/// Radios — un rol fijo por tamaño, calibrados contra el uso real que
/// ya tenía la app (no al revés): `card` es el que más se repite, así
/// que es el default implícito de [KenaCard](../widgets/kena_card.dart).
class KenaRadius {
  KenaRadius._();

  /// Chips de ícono chicos, indicadores.
  static const sm = 10.0;

  /// Campos de texto.
  static const input = 12.0;

  /// El default — tarjetas, filas, botón fantasma.
  static const card = 14.0;

  /// Botón primario ("vidrio líquido"), círculo de enviar.
  static const button = 16.0;

  /// Hojas inferiores, contenedores de QR.
  static const sheet = 20.0;
}
