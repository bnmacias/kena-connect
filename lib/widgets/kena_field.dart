import 'package:flutter/material.dart';

import '../theme/kena_colors.dart';
import '../theme/kena_spacing.dart';
import '../theme/kena_typography.dart';

/// Campo de texto con etiqueta chica en mayúsculas arriba (no flotante)
/// y error inline debajo — el patrón usado en Crear sala, Unirme,
/// Perfil, etc.
class KenaField extends StatelessWidget {
  const KenaField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.error,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? error;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Un poco más visible que el label genérico del sistema
        // (KenaColors.text2 en vez de text3): estás por escribir acá,
        // conviene que se lea con más peso que un eyebrow decorativo.
        Text(label.toUpperCase(), style: KenaTypography.label.copyWith(color: KenaColors.text2)),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          autofocus: autofocus,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: KenaTypography.body.copyWith(fontWeight: FontWeight.w600, color: KenaColors.text),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KenaRadius.input),
              borderSide: BorderSide(color: error != null ? KenaColors.red : KenaColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KenaRadius.input),
              borderSide: BorderSide(color: error != null ? KenaColors.red : KenaColors.lineStrong),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: KenaSpacing.xs + 2),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 13, color: KenaColors.red),
                const SizedBox(width: KenaSpacing.xs + 1),
                Expanded(child: Text(error!, style: KenaTypography.caption.copyWith(color: KenaColors.red))),
              ],
            ),
          ),
        const SizedBox(height: KenaSpacing.lg),
      ],
    );
  }
}
