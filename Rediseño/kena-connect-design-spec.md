# Kena Connect — Especificación de diseño

Este documento es independiente de la tecnología. Sirve como referencia fija sin
importar si la implementación final es Flutter, React Native o nativo — cuando
se defina el stack, se le agrega un prompt específico para Claude Code arriba
de esto.

## 1. Paleta

| Token | Valor | Uso |
|---|---|---|
| `bg` | `#0A0908` | Fondo base de pantalla |
| `card` | `#15120F` | Tarjetas, inputs, filas |
| `card2` | `#1B1712` | Hojas inferiores, modales |
| `line` | `rgba(255,255,255,0.08)` | Bordes por defecto |
| `lineStrong` | `rgba(255,255,255,0.16)` | Bordes de énfasis |
| `teal` | `#2BB89F` | Inicio de degradé de marca (verde agua, tono atenuado) |
| `sky` | `#3C8FC4` | Fin de degradé de marca (celeste, tono atenuado) |
| `text` | `#FFFFFF` | Texto principal |
| `text2` | `rgba(255,255,255,0.55)` | Texto secundario |
| `text3` | `rgba(255,255,255,0.35)` | Texto terciario / placeholders |
| `green` | `#3DD68C` | Estado conectado |
| `red` | `#FF6B6B` | Estado de error / acción destructiva |

Degradé de marca: `linear-gradient(135deg, teal, sky)` — se usa en el logo,
burbujas de mensaje propio, botón de enviar y CTAs primarios.

## 2. Efecto "liquid glass" (botones) — versión atenuada

Se bajó el brillo respecto de la primera pasada para que no canse a la vista
en uso prolongado. El efecto se sigue logrando con 4 capas, pero con menos
opacidad y menos contraste en cada una:

1. **Fondo translúcido**: degradé de marca al **32%** de opacidad (antes 55%),
   no al 55%.
2. **Blur detrás** (`backdrop-filter: blur(16–20px) saturate(180%)`) — sin
   cambios, sigue necesitando los resplandores radiales de fondo, pero
   ahora a **10% de opacidad** (antes 22%).
3. **Borde con brillo direccional**, más sutil: borde general a
   `rgba(255,255,255,0.22)` (antes 0.4), borde superior a
   `rgba(255,255,255,0.4)` (antes 0.65).
4. **Sombra compuesta**, más contenida: sombra exterior de color a `0 6px
   18px rgba(43,184,159,0.16)` (antes con blur de 26px y 0.28 de opacidad) y
   sombra interior clara a `inset 0 1px 0 rgba(255,255,255,0.28)` (antes 0.5).

Los botones fantasma (Cancelar, Salir, Transferir anfitrión) llevan una
versión más sutil del mismo efecto — blur más bajo, sin degradé de color, para
que no compitan visualmente con los botones primarios.

## 3. Inventario de pantallas (14)

1. Onboarding (3 pasos, con omitir)
2. Home
3. Perfil local (nombre, avatar/color, apariencia)
4. Crear sala
5. Sala creada (código + QR)
6. Unirme a sala (salas encontradas cerca + campo de código)
7. Escanear QR (cámara simulada, esquinas de encuadre, línea de escaneo)
8. Sala — lista de canales (general + privados)
9. Chat (con mensajes de sistema para reconexión/desconexión)
10. Adjuntar (hoja inferior: foto, ubicación)
11. Participantes (con barra de señal individual, transferir host)
12. Configuración de sala (renombrar, ver código, transferir, salir, finalizar)
13. Confirmación de salir / finalizar sala (modal)
14. Estado de código inválido (inline en el campo, no un modal aparte)

## 4. Reglas de UX que no son negociables al implementar

- **Nunca redactar copy que implique conectividad remota.** Nada de "en
  camino", "ya llegamos", "nos vemos allá" en ningún placeholder o dato de
  ejemplo — los mensajes solo viajan entre dispositivos conectados a la misma
  red local, en el momento en que están cerca.
- **Todo estado de conexión debe ser visible**, no un punto de color solo: usar
  el componente de barra de señal (4 barras) en el header de sala, en la lista
  de participantes y en las salas encontradas cerca.
- **Los eventos de red son mensajes de sistema** dentro del chat (burbuja
  gris centrada, ícono de wifi cortado), no notificaciones push ni banners
  aparte — el usuario tiene que poder scrollear el chat y entender qué pasó.
- **Toda acción destructiva** (finalizar sala, salir) pasa por una confirmación
  con el texto explícito de qué se pierde.
- **El código de sala es el objeto central** de la propuesta de valor — nunca
  reducirlo a texto chico secundario; siempre acompañado de QR y opción de
  copiar.

## 6. Fondo con profundidad — corrección sobre la primera implementación

Si el resultado se ve como un **círculo con borde duro** en una esquina en vez
de un resplandor que se disuelve, el problema casi seguro es que se
implementó como una forma sólida con blur encima, en vez de un degradé
radial que se apaga solo. La diferencia importa: un `RadialGradient` que va
de `color.withOpacity(x)` a `color.withOpacity(0)` no necesita `BackdropFilter`
para verse suave — el borde duro desaparece porque el gradiente mismo se
funde con el fondo.

Reglas para que el fondo tenga profundidad real y no solo un blob de color:

1. Los resplandores van **posicionados parcialmente fuera de la pantalla**
   (`Positioned` con valores negativos), así nunca se ve su borde circular
   completo, solo la parte interna y suave.
2. Agregar una **viñeta**: un `RadialGradient` centrado, transparente en el
   medio y `Colors.black` al ~35% en los bordes — es lo que más aporta
   sensación de profundidad en una UI oscura, mucho más que el color en sí.
3. Los resplandores de color quedan a **8–10% de opacidad**, nunca más — si
   hace falta que se note más, se agranda el tamaño del círculo, no se sube
   la opacidad (subir opacidad es lo que genera el efecto "mancha").

```dart
class KenaBackground extends StatelessWidget {
  final Widget child;
  const KenaBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: KenaColors.bg),
        Positioned(
          top: -140, left: -110,
          child: _Glow(color: KenaColors.teal, size: 360, opacity: 0.09),
        ),
        Positioned(
          bottom: -160, right: -120,
          child: _Glow(color: KenaColors.sky, size: 400, opacity: 0.08),
        ),
        // Viñeta: la que realmente da sensación de profundidad
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.15,
                colors: [Colors.transparent, Colors.black.withOpacity(0.35)],
                stops: const [0.55, 1.0],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _Glow({required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(opacity), color.withOpacity(0)],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}
```

Usar `KenaBackground` envolviendo el `body` de cada `Scaffold`, no como fondo
del `Scaffold` en sí — así el resplandor queda detrás de todo el contenido de
esa pantalla en particular.

## 7. Campo de mensaje — una sola forma, no dos superpuestas

Si el campo de texto se ve como dos cajas con colores distintos encimadas, es
porque el `TextField` tiene su propia decoración (`filled`, `fillColor`,
`border`) además del contenedor que lo rodea. La forma visual la da **solo**
el contenedor de afuera — el `TextField` va sin decoración propia:

```dart
Container(
  margin: const EdgeInsets.fromLTRB(14, 8, 14, 16),
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
  decoration: BoxDecoration(
    color: KenaColors.card,
    borderRadius: BorderRadius.circular(28),
    border: Border.all(color: KenaColors.line),
  ),
  child: Row(
    children: [
      IconButton(
        icon: const Icon(Icons.attach_file, size: 18, color: KenaColors.text3),
        onPressed: _openAttach,
      ),
      Expanded(
        child: TextField(
          controller: _controller,
          style: const TextStyle(color: KenaColors.text, fontSize: 14),
          cursorColor: KenaColors.teal,
          decoration: const InputDecoration(
            hintText: 'Mensaje',
            hintStyle: TextStyle(color: KenaColors.text2),
            border: InputBorder.none,      // clave: sin borde propio
            filled: false,                  // clave: sin relleno propio
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
      KenaGlassButton(
        onPressed: _send,
        child: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
      ),
    ],
  ),
)
```


## 8. Referencia visual

Adjunto el prototipo navegable en React (`kena-connect-app.jsx`) como
referencia de comportamiento e interacción — no es el código final, es la
maqueta funcional que valida el flujo y la paleta antes de portarlo al stack
real. Junto con la auditoría UX (`auditoria-ux-kena-connect.md`) para el
razonamiento detrás de cada pantalla agregada.
