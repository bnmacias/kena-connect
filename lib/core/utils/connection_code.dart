import 'dart:math';

/// Genera un código corto y fácil de dictar/tipear para identificar una
/// conexión en la red local (se muestra como "KENA-XXXX"). Excluye
/// caracteres ambiguos (0/O, 1/I/L) para minimizar errores de transcripción.
const _alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

String generateConnectionCode({int length = 4, Random? random}) {
  final rng = random ?? Random.secure();
  return List.generate(length, (_) => _alphabet[rng.nextInt(_alphabet.length)]).join();
}

/// Normaliza texto ingresado a mano o leído de un QR ("kena-482a",
/// " 482A ", "KENA482A") a un código comparable ("482A").
String normalizeConnectionCode(String raw) {
  final upper = raw.toUpperCase().trim();
  final stripped = upper.startsWith('KENA-')
      ? upper.substring(5)
      : upper.startsWith('KENA')
          ? upper.substring(4)
          : upper;
  return stripped.replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

String formatConnectionCode(String code) => 'KENA-$code';
