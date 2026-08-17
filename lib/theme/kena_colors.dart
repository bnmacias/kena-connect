import 'package:flutter/material.dart';

import 'kena_palette.dart';
import 'kena_theme_controller.dart';

/// Tokens de color de Kena — cada campo lee del tema activo
/// ([KenaThemeController]), así que **son getters, no `const`**. El
/// resto de la app sigue escribiendo `KenaColors.text`, `KenaColors.bg`,
/// etc. exactamente igual que antes de que existiera el selector de
/// tema — sólo cambia que ahora el valor puede variar en el tiempo.
///
/// Para que una pantalla vuelva a *leer* estos valores cuando el tema
/// cambia hace falta algo más que esto: ver [KenaBackground].
class KenaColors {
  KenaColors._();

  static KenaPalette get _p => KenaThemeController.instance.value;

  static Color get bg => _p.bg;
  static Color get bgSoft => _p.bgSoft;
  static Color get card => _p.surface;
  static Color get card2 => _p.surface2;
  static Color get surface3 => _p.surface3;
  static Color get line => _p.line;
  static Color get lineStrong => _p.lineStrong;
  static Color get overlayHover => _p.overlayHover;

  static Color get text => _p.text;
  static Color get text2 => _p.text2;
  static Color get text3 => _p.text3;

  /// Color de acento: para texto, íconos, bordes y chips — ajustado por
  /// tema para dar contraste AA contra `bg`/`card` (ver auditoría,
  /// sección I). No usar para fondos grandes de botón: para eso está el
  /// degradé (`brandGradient`/`gradA`/`gradB`).
  static Color get accent => _p.accent;
  static Color get accentSoft => _p.accentSoft;
  static Color get ring => _p.ring;

  /// Color de texto/ícono para pintar **encima** de un relleno con
  /// `brandGradient` (botones primarios, burbuja propia, badge) — blanco
  /// en temas claros, casi negro en el oscuro, porque ahí el degradé es
  /// más claro que el texto necesita.
  static Color get onAccent => _p.onAccent;

  /// Stops crudos del degradé de marca, para cuando hace falta construir
  /// un gradiente con alpha propio (ver `KenaGlassButton`) en vez de usar
  /// `brandGradient` tal cual.
  static Color get gradA => _p.gradA;
  static Color get gradB => _p.gradB;
  static Color get gradC => _p.gradC;

  static Color get tintA => _p.tintA;
  static Color get tintB => _p.tintB;
  static Color get tintBorder => _p.tintBorder;
  static Color get track => _p.track;

  static Color get green => _p.green;
  static Color get greenSoft => _p.greenSoft;
  static Color get amber => _p.amber;
  static Color get amberSoft => _p.amberSoft;
  static Color get red => _p.red;
  static Color get redSoft => _p.redSoft;

  static LinearGradient get brandGradient => _p.brandFlat;
  static LinearGradient get brandGradientRich => _p.brandRich;

  static List<Color> get avatarPalette => _p.avatarPalette;
}

ThemeData buildKenaTheme(KenaPalette p) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: p.accent,
    brightness: p.isDark ? Brightness.dark : Brightness.light,
  ).copyWith(
    primary: p.accent,
    secondary: p.gradB,
    surface: p.surface,
    error: p.red,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: p.isDark ? Brightness.dark : Brightness.light,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: p.bg,
    fontFamily: 'Manrope Kena',
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: p.text,
        fontFamily: 'Manrope Kena',
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      hintStyle: TextStyle(color: p.text3, fontWeight: FontWeight.w600),
      labelStyle: TextStyle(
        color: p.text2,
        fontWeight: FontWeight.w700,
        fontSize: 11,
        letterSpacing: 0.6,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.accent),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.red),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    textTheme: TextTheme(
      headlineMedium: TextStyle(color: p.text, fontWeight: FontWeight.w700),
      bodyMedium: TextStyle(color: p.text),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: p.lineStrong),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface2,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.surface2,
      contentTextStyle: TextStyle(color: p.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: DividerThemeData(color: p.line, space: 1),
  );
}

/// `InheritedNotifier` alrededor de [KenaThemeController] — el único rol
/// de esto es dar a [KenaBackground] una forma de decir "avisame cuando
/// cambie el tema" a través de `context`, que es el único mecanismo de
/// Flutter que fuerza a reconstruir un `build()` sin importar si el
/// widget que lo llamó se instanció con `const` (ver nota larga en
/// `KenaBackground`). Se monta una sola vez en `main.dart`, por encima
/// de todo el `MaterialApp`.
class KenaThemeScope extends InheritedNotifier<KenaThemeController> {
  KenaThemeScope({super.key, required super.child})
      : super(notifier: KenaThemeController.instance);

  static void of(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<KenaThemeScope>();
  }
}

/// Fondo de pantalla con el doble resplandor radial de marca — apenas
/// perceptible, pero es lo que hace que el blur del vidrio líquido se
/// note en los botones. Envolvé el `body` de cada `Scaffold` con esto
/// en vez de dejar el fondo plano.
///
/// **Por qué `builder` y no `child`**: `KenaColors.xxx` son getters que
/// leen el tema activo en el momento en que se *evalúan* — no en el
/// momento en que se declaran. Si esta clase tomara un `Widget child` ya
/// construido, ese árbol ya habría leído (y fijado para siempre) los
/// colores del tema que estaba activo cuando la pantalla llamó a su
/// propio `build()`. Reconstruir sólo el glow de fondo de acá no
/// alcanzaría para que, por ejemplo, el texto de un `Scaffold` ya
/// armado cambiara de color.
///
/// Por eso [KenaBackground] toma un `builder` y lo llama recién dentro
/// de su propio `build()`, después de `KenaThemeScope.of(context)` — así
/// cada pantalla se reconstruye entera (releyendo `KenaColors` de cero)
/// apenas cambia el tema, sin que la pantalla necesite saber nada de
/// esto ni suscribirse a nada por su cuenta. Esta clase la usan las 14
/// pantallas de la app salvo `QrScannerScreen` (siempre negra, cámara).
class KenaBackground extends StatelessWidget {
  const KenaBackground({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    KenaThemeScope.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: KenaColors.bg),
        Positioned(
          top: -140,
          left: -110,
          child: _Glow(color: KenaColors.gradA, size: 360, opacity: 0.09),
        ),
        Positioned(
          bottom: -160,
          right: -120,
          child: _Glow(color: KenaColors.gradB, size: 400, opacity: 0.08),
        ),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.15,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: KenaColors.bg.computeLuminance() > 0.5 ? 0.06 : 0.35),
                ],
                stops: const [0.55, 1.0],
              ),
            ),
          ),
        ),
        Builder(builder: builder),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size, required this.opacity});

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
