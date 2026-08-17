import 'package:flutter/material.dart';

/// Los 4 temas de Kena. `claro` es el default — Kena ya no es dark-only
/// (ver ROADMAP.md, decisión revertida a pedido explícito de producto).
enum KenaPreset { claro, oscuro, coral, violeta }

/// Un tema completo: cada color que usa la app es un campo acá, nunca un
/// valor suelto en una pantalla. Cambiar de tema es reemplazar la
/// instancia activa de [KenaPalette] — ningún widget necesita saber que
/// pasó (ver `KenaThemeController`/`KenaBackground`).
///
/// Los colores semánticos (verde/ámbar/rojo) se mantienen iguales entre
/// los 3 temas claros a propósito: el acento de marca y el significado
/// de un estado son dos ejes distintos (un "conectado" verde no debería
/// cambiar de tono sólo porque cambiaste el color de acento).
class KenaPalette {
  const KenaPalette({
    required this.preset,
    required this.label,
    required this.isDark,
    required this.bg,
    required this.bgSoft,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.line,
    required this.lineStrong,
    required this.overlayHover,
    required this.text,
    required this.text2,
    required this.text3,
    required this.accent,
    required this.accentSoft,
    required this.ring,
    required this.gradA,
    required this.gradB,
    required this.gradC,
    required this.onAccent,
    required this.tintA,
    required this.tintB,
    required this.tintBorder,
    required this.track,
    required this.green,
    required this.greenSoft,
    required this.amber,
    required this.amberSoft,
    required this.red,
    required this.redSoft,
    required this.pageGlowA,
    required this.pageGlowB,
    required this.scrim,
    required this.avatarPalette,
  });

  final KenaPreset preset;
  final String label;
  final bool isDark;

  final Color bg;
  final Color bgSoft;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color line;
  final Color lineStrong;
  final Color overlayHover;

  final Color text;
  final Color text2;
  final Color text3;

  final Color accent;
  final Color accentSoft;
  final Color ring;

  final Color gradA;
  final Color gradB;
  final Color gradC;
  final Color onAccent;

  final Color tintA;
  final Color tintB;
  final Color tintBorder;
  final Color track;

  final Color green;
  final Color greenSoft;
  final Color amber;
  final Color amberSoft;
  final Color red;
  final Color redSoft;

  final Color pageGlowA;
  final Color pageGlowB;
  final Color scrim;

  final List<Color> avatarPalette;

  LinearGradient get brandFlat => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [gradA, gradB],
      );

  LinearGradient get brandRich => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [gradA, gradB, gradC],
        stops: const [0.0, 0.55, 1.0],
      );
}

// Colores de identidad (avatares): deliberadamente un tono más profundo
// que los stops del degradé de marca — van siempre con iniciales blancas
// encima, en cualquier tema, así que tienen que dar contraste AA solos.
const _avatarColors = [
  Color(0xFF0D9A82),
  Color(0xFF5B49E0),
  Color(0xFF1E9E63),
  Color(0xFF2E6FD1),
  Color(0xFFE0457A),
];

const _semanticLightGreen = Color(0xFF178F5B);
const _semanticLightGreenSoft = Color(0x1F178F5B);
const _semanticLightAmber = Color(0xFFA16A00);
const _semanticLightAmberSoft = Color(0x1FA16A00);
const _semanticLightRed = Color(0xFFC43D3D);
const _semanticLightRedSoft = Color(0x1FC43D3D);

const kenaClaro = KenaPalette(
  preset: KenaPreset.claro,
  label: 'Claro',
  isDark: false,
  bg: Color(0xFFFFFFFF),
  bgSoft: Color(0xFFF5F6F7),
  surface: Color(0xFFF4F6F6),
  surface2: Color(0xFFECEFEF),
  surface3: Color(0xFFE2E6E6),
  line: Color(0x170F171A),
  lineStrong: Color(0x2E0F171A),
  overlayHover: Color(0x0D0F171A),
  text: Color(0xFF10161A),
  text2: Color(0xA3101A1A),
  text3: Color(0x66101A1A),
  accent: Color(0xFF0C8672),
  accentSoft: Color(0x1F0C8672),
  ring: Color(0x520C8672),
  // gradB un poco más claro que el "sky" original (#2E7FCB): con el
  // stop viejo, texto oscuro encima del extremo azul del degradé daba
  // 4.36:1 — por debajo del 4.5:1 de AA para texto normal. Este valor
  // da ~4.7:1 sin perder la identidad de color.
  gradA: Color(0xFF14A98D),
  gradB: Color(0xFF3985D2),
  gradC: Color(0xFF6B62D9),
  // Texto/ícono oscuro sobre el degradé, no blanco: blanco daba entre
  // 2.96:1 (extremo teal) y 4.19:1 (extremo azul) — ninguno de los dos
  // llega al 4.5:1 de AA. Oscuro da 6.15:1 / 4.7:1.
  onAccent: Color(0xFF0D1316),
  tintA: Color(0x1F14A98D),
  tintB: Color(0x142E7FCB),
  tintBorder: Color(0x4D14A98D),
  track: Color(0x26101A1A),
  green: _semanticLightGreen,
  greenSoft: _semanticLightGreenSoft,
  amber: _semanticLightAmber,
  amberSoft: _semanticLightAmberSoft,
  red: _semanticLightRed,
  redSoft: _semanticLightRedSoft,
  pageGlowA: Color(0x1414A98D),
  pageGlowB: Color(0x122E7FCB),
  scrim: Color(0x800A0C0E),
  avatarPalette: _avatarColors,
);

const kenaOscuro = KenaPalette(
  preset: KenaPreset.oscuro,
  label: 'Oscuro',
  isDark: true,
  bg: Color(0xFF0A0C0F),
  bgSoft: Color(0xFF0D1013),
  surface: Color(0xFF15181C),
  surface2: Color(0xFF1B1F24),
  surface3: Color(0xFF22272D),
  line: Color(0x12FFFFFF),
  lineStrong: Color(0x26FFFFFF),
  overlayHover: Color(0x0FFFFFFF),
  text: Color(0xFFF6F8F9),
  text2: Color(0x9EF6F8F9),
  text3: Color(0x5CF6F8F9),
  accent: Color(0xFF2ECDA8),
  accentSoft: Color(0x242ECDA8),
  ring: Color(0x472ECDA8),
  gradA: Color(0xFF2ECDA8),
  gradB: Color(0xFF4FA3E8),
  gradC: Color(0xFF7C86F2),
  onAccent: Color(0xFF06110E),
  tintA: Color(0x1F2ECDA8),
  tintB: Color(0x144FA3E8),
  tintBorder: Color(0x472ECDA8),
  track: Color(0x29FFFFFF),
  green: Color(0xFF34D399),
  greenSoft: Color(0x2434D399),
  amber: Color(0xFFF2B33D),
  amberSoft: Color(0x24F2B33D),
  red: Color(0xFFFB6A6A),
  redSoft: Color(0x24FB6A6A),
  pageGlowA: Color(0x1A2ECDA8),
  pageGlowB: Color(0x1A4FA3E8),
  scrim: Color(0x8C040608),
  avatarPalette: _avatarColors,
);

const kenaCoral = KenaPalette(
  preset: KenaPreset.coral,
  label: 'Coral',
  isDark: false,
  bg: Color(0xFFFFFFFF),
  bgSoft: Color(0xFFF7F5F3),
  surface: Color(0xFFF8F5F2),
  surface2: Color(0xFFF0EBE6),
  surface3: Color(0xFFE7DFD8),
  line: Color(0x17281909),
  lineStrong: Color(0x2E281909),
  overlayHover: Color(0x0D281909),
  text: Color(0xFF1A1310),
  text2: Color(0xA31A1310),
  text3: Color(0x661A1310),
  accent: Color(0xFFC0432B),
  accentSoft: Color(0x1FC0432B),
  ring: Color(0x4DC0432B),
  // gradB (el extremo rosa) un toque más claro que la referencia visual
  // original (#D6455F → #E0506D): con el stop original, texto oscuro
  // sobre ese extremo daba 4.23:1 — por debajo del 4.5:1 de AA.
  gradA: Color(0xFFE0603B),
  gradB: Color(0xFFE0506D),
  gradC: Color(0xFFB9375A),
  // Texto/ícono oscuro: blanco sobre este degradé cálido daba 3.55:1 en
  // el extremo naranja (#E0603B), muy por debajo de AA. Oscuro da 5.1:1.
  onAccent: Color(0xFF1A1310),
  tintA: Color(0x1FE0603B),
  tintB: Color(0x14D6455F),
  tintBorder: Color(0x4DE0603B),
  track: Color(0x26281909),
  green: _semanticLightGreen,
  greenSoft: _semanticLightGreenSoft,
  amber: _semanticLightAmber,
  amberSoft: _semanticLightAmberSoft,
  red: _semanticLightRed,
  redSoft: _semanticLightRedSoft,
  pageGlowA: Color(0x17E0603B),
  pageGlowB: Color(0x12D6455F),
  scrim: Color(0x800A0C0E),
  avatarPalette: _avatarColors,
);

const kenaVioleta = KenaPalette(
  preset: KenaPreset.violeta,
  label: 'Violeta',
  isDark: false,
  bg: Color(0xFFFFFFFF),
  bgSoft: Color(0xFFF5F5FA),
  surface: Color(0xFFF5F5FB),
  surface2: Color(0xFFECECF7),
  surface3: Color(0xFFE1E1F0),
  line: Color(0x171E193C),
  lineStrong: Color(0x2E1E193C),
  overlayHover: Color(0x0D1E193C),
  text: Color(0xFF15132A),
  text2: Color(0xA315132A),
  text3: Color(0x6615132A),
  accent: Color(0xFF5B4FD6),
  accentSoft: Color(0x1F5B4FD6),
  ring: Color(0x4D5B4FD6),
  // A diferencia de Claro/Coral, acá texto blanco da mejor contraste que
  // oscuro (violeta/azul son hues "oscuros" para la fórmula de
  // luminancia, al revés que el teal/naranja de los otros temas).
  // gradB un toque más oscuro que la referencia (#3E7BD8 → #3872C7)
  // para que el extremo azul llegue a 4.5:1 con texto blanco.
  gradA: Color(0xFF6C5CE7),
  gradB: Color(0xFF3872C7),
  gradC: Color(0xFFA65CE7),
  onAccent: Color(0xFFFFFFFF),
  tintA: Color(0x1F6C5CE7),
  tintB: Color(0x143E7BD8),
  tintBorder: Color(0x4D6C5CE7),
  track: Color(0x261E193C),
  green: _semanticLightGreen,
  greenSoft: _semanticLightGreenSoft,
  amber: _semanticLightAmber,
  amberSoft: _semanticLightAmberSoft,
  red: _semanticLightRed,
  redSoft: _semanticLightRedSoft,
  pageGlowA: Color(0x176C5CE7),
  pageGlowB: Color(0x123E7BD8),
  scrim: Color(0x800A0C0E),
  avatarPalette: _avatarColors,
);

const kenaPalettes = <KenaPreset, KenaPalette>{
  KenaPreset.claro: kenaClaro,
  KenaPreset.oscuro: kenaOscuro,
  KenaPreset.coral: kenaCoral,
  KenaPreset.violeta: kenaVioleta,
};

/// Orden en que se muestran los temas en el selector (Mi perfil →
/// Apariencia). `claro` primero porque es el default de producto.
const kenaPresetOrder = [KenaPreset.claro, KenaPreset.oscuro, KenaPreset.coral, KenaPreset.violeta];
