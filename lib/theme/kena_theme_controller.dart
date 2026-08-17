import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kena_palette.dart';

const _presetKey = 'kena.themePreset';

/// Única fuente de verdad de qué tema está activo. Es un `ValueNotifier`
/// (mismo patrón que `ActiveRoomRegistry`) — cualquiera puede escucharlo,
/// pero en la práctica sólo dos lugares lo hacen: `KenaApp` (para
/// regenerar el `ThemeData` que ven los widgets de Material estándar) y
/// `KenaBackground` (para que cada pantalla vuelva a leer `KenaColors`
/// con el tema nuevo — ver ese archivo para el porqué).
class KenaThemeController extends ValueNotifier<KenaPalette> {
  KenaThemeController._() : super(kenaClaro);

  static final KenaThemeController instance = KenaThemeController._();

  /// Restaura el tema guardado, si había uno. Se llama una sola vez al
  /// arrancar la app, antes de `runApp` — así no hay parpadeo del tema
  /// default seguido de un cambio al tema guardado.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_presetKey);
    if (saved == null) return;
    final preset = KenaPreset.values.where((p) => p.name == saved).firstOrNull;
    if (preset != null) value = kenaPalettes[preset]!;
  }

  Future<void> setPreset(KenaPreset preset) async {
    value = kenaPalettes[preset]!;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_presetKey, preset.name);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
