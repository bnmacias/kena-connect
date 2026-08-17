import 'package:flutter/material.dart';

import '../theme/kena_colors.dart';
import '../theme/kena_spacing.dart';
import '../theme/kena_typography.dart';
import 'kena_glass_button.dart';

/// Tono visual de [KenaConfirmSheet] — decide el color del ícono y del
/// botón de confirmar. `danger` para lo irreversible (finalizar sala,
/// salir), `neutral` para una decisión sin pérdida de datos (cambiar de
/// sala).
enum KenaConfirmTone { danger, neutral }

/// Hoja de confirmación del sistema de diseño — reemplaza los
/// `AlertDialog` nativos de Material que hoy rompen el lenguaje "vidrio
/// líquido" del resto de la app (ver auditoría de diseño, hallazgo #5 y
/// sección F.3). Mismo propósito que un `AlertDialog` de sí/no, pero
/// como hoja inferior, en la misma familia visual que el resto de Kena.
///
/// Uso:
/// ```dart
/// final confirmed = await KenaConfirmSheet.show(
///   context,
///   title: '¿Salir de la sala?',
///   body: 'Vas a dejar de ver los mensajes de esta sala.',
///   confirmLabel: 'Salir de la sala',
///   tone: KenaConfirmTone.danger,
/// );
/// if (confirmed == true) { ... }
/// ```
class KenaConfirmSheet extends StatelessWidget {
  const KenaConfirmSheet({
    super.key,
    required this.title,
    required this.body,
    required this.confirmLabel,
    this.cancelLabel = 'Cancelar',
    this.tone = KenaConfirmTone.danger,
    this.icon,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;
  final KenaConfirmTone tone;
  final IconData? icon;

  /// Muestra la hoja y devuelve `true` si se confirmó, `false`/`null` si
  /// se canceló o se cerró tocando afuera.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    String cancelLabel = 'Cancelar',
    KenaConfirmTone tone = KenaConfirmTone.danger,
    IconData? icon,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      builder: (_) => KenaConfirmSheet(
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        tone: tone,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final danger = tone == KenaConfirmTone.danger;
    final toneColor = danger ? KenaColors.red : KenaColors.accent;
    final toneSoft = danger ? KenaColors.redSoft : KenaColors.accentSoft;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(KenaSpacing.xl, KenaSpacing.xl, KenaSpacing.xl, KenaSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: toneSoft, borderRadius: BorderRadius.circular(KenaRadius.button)),
              alignment: Alignment.center,
              child: Icon(icon ?? (danger ? Icons.error_outline_rounded : Icons.info_outline_rounded), color: toneColor, size: 24),
            ),
            const SizedBox(height: KenaSpacing.lg),
            Text(title, style: KenaTypography.titleXL),
            const SizedBox(height: KenaSpacing.sm),
            Text(body, style: KenaTypography.bodySmall),
            const SizedBox(height: KenaSpacing.xxl),
            KenaGlassButton(
              danger: danger,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
            const SizedBox(height: KenaSpacing.sm),
            KenaGhostButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hoja informativa de un solo botón — para avisos que el usuario tiene
/// que reconocer antes de seguir ("te transfirieron la sala", "la sala
/// fue finalizada"), sin una decisión sí/no real de por medio. Misma
/// familia visual que [KenaConfirmSheet], no confundir con ella: acá no
/// hay "cancelar" porque no hay nada que cancelar.
class KenaInfoSheet extends StatelessWidget {
  const KenaInfoSheet({
    super.key,
    required this.title,
    required this.body,
    required this.buttonLabel,
    this.icon,
  });

  final String title;
  final String body;
  final String buttonLabel;
  final IconData? icon;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String body,
    required String buttonLabel,
    IconData? icon,
    bool barrierDismissible = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: barrierDismissible,
      enableDrag: barrierDismissible,
      builder: (_) => KenaInfoSheet(title: title, body: body, buttonLabel: buttonLabel, icon: icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(KenaSpacing.xl, KenaSpacing.xl, KenaSpacing.xl, KenaSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: KenaColors.accentSoft, borderRadius: BorderRadius.circular(KenaRadius.button)),
              alignment: Alignment.center,
              child: Icon(icon ?? Icons.info_outline_rounded, color: KenaColors.accent, size: 24),
            ),
            const SizedBox(height: KenaSpacing.lg),
            Text(title, style: KenaTypography.titleXL),
            const SizedBox(height: KenaSpacing.sm),
            Text(body, style: KenaTypography.bodySmall),
            const SizedBox(height: KenaSpacing.xxl),
            KenaGlassButton(onPressed: () => Navigator.of(context).pop(), child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}
