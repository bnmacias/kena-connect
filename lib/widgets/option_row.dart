import 'package:flutter/material.dart';

import '../theme/kena_colors.dart';
import '../theme/kena_spacing.dart';
import '../theme/kena_typography.dart';
import 'kena_card.dart';

/// Fila "ícono/avatar + título + subtítulo + trailing" — el patrón que
/// antes se reimplementaba por separado en Inicio (`_RowAction`, fila de
/// Recientes), Unirme (fila de sala cercana), Configuración de la sala y
/// Configuración (`ListTile`), cada uno con su propio padding y tamaño
/// de fuente ligeramente distinto (ver auditoría de diseño, hallazgo
/// #10 y sección K). Ahora es un único componente.
///
/// Se usa siempre envuelta en un [KenaCard] (o pasando [onTap] acá
/// directamente si no hace falta el borde/fondo de tarjeta — ver
/// [bare]).
class OptionRow extends StatelessWidget {
  const OptionRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.icon,
    this.trailing,
    this.dense = false,
  });

  final String title;
  final String? subtitle;

  /// Widget a la izquierda ya armado (p.ej. un `Avatar.forName(...)`).
  /// Si no se pasa, se arma un chip con [icon].
  final Widget? leading;
  final IconData? icon;

  /// Por defecto, un chevron — pasar `SizedBox.shrink()` para no mostrar
  /// nada, o cualquier otro widget (switch, badge, barras de señal).
  final Widget? trailing;

  /// Fila más compacta (usada en Recientes) — mismo layout, menos padding
  /// y un escalón de la tipografía más chico.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final effectiveLeading = leading ??
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: KenaColors.accentSoft, borderRadius: BorderRadius.circular(KenaRadius.sm)),
          alignment: Alignment.center,
          child: Icon(icon, color: KenaColors.accent, size: 19),
        );

    final titleStyle = (dense ? KenaTypography.bodySmall : KenaTypography.body)
        .copyWith(fontWeight: FontWeight.w700, color: KenaColors.text);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: KenaSpacing.lg - 1, vertical: dense ? KenaSpacing.sm : KenaSpacing.md + 1),
      child: Row(
        children: [
          effectiveLeading,
          const SizedBox(width: KenaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: KenaTypography.caption),
                ],
              ],
            ),
          ),
          trailing ?? Icon(Icons.chevron_right_rounded, size: 16, color: KenaColors.text3),
        ],
      ),
    );
  }
}

/// Atajo para el caso más común: [OptionRow] adentro de un [KenaCard]
/// tocable.
class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.icon,
    this.trailing,
    this.onTap,
    this.dense = false,
    this.color,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dense;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return KenaCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      color: color,
      child: OptionRow(
        title: title,
        subtitle: subtitle,
        leading: leading,
        icon: icon,
        trailing: trailing,
        dense: dense,
      ),
    );
  }
}
