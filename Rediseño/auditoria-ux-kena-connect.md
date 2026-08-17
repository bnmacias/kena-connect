# Auditoría UX — Kena Connect

## 1. Qué funciona hoy (según las capturas)

El flujo core está sólido a nivel funcional: crear sala → compartir código/QR → sala con canal general → chat en tiempo real, todo sobre red local sin Internet. Eso es lo difícil y ya está resuelto. El problema no es la ingeniería de red — es que la interfaz todavía se ve y se siente como un prototipo interno, no como un producto que alguien instalaría desde una store.

Puntos débiles concretos que veo en las 9 pantallas:

- **Visual genérico**: componentes de Material Design por defecto (inputs grises, botón naranja plano, sin jerarquía tipográfica). No transmite "producto terminado".
- **Pantallas vacías sin diseño**: la lista de sala sin mensajes ("Sin mensajes todavía") no tiene ilustración, ni copy que invite a la acción — es un vacío literal.
- **Sin feedback de conexión real**: "Conexión activa" / "Sala activa" es un texto chico verde. En una app cuya propuesta de valor ES la conectividad sin Internet, ese estado debería ser mucho más protagonista (fuerza de señal, cantidad de nodos conectados, calidad del enlace).
- **Onboarding inexistente**: se abre directo a "Crear sala / Unirme a sala". Un usuario nuevo no entiende qué es esto, por qué funciona sin Internet, ni qué esperar. No hay explicación del concepto en el primer uso.
- **Falta de identidad de marca**: el logo es un ícono genérico de wifi/broadcast en un círculo naranja. No hay una construcción de marca distintiva (tipografía propia, motivo visual recurrente) que diferencie a Kena de cualquier chat genérico.
- **Nombre del participante sin foto/avatar real**: "B" en círculo azul — no hay personalización (elegir color, inicial, o avatar).
- **El código de sala (KENA-HDVZ) está subutilizado**: es el objeto central de la propuesta de valor (es lo que la gente comparte a los gritos en un camping) y hoy es texto chico naranja con un ícono de copiar al lado.

## 2. Auditoría del flujo (mapa actual)

```
Splash → [Crear sala | Unirme a sala]
  Crear sala → nombre sala + tu nombre → código/QR generado → Entrar a la sala → Sala (lista de canales) → Chat
  Unirme sala → tu nombre + código o buscar cerca → (conectar)
```

Esto cubre lo mínimo. Lo que falta para que sea una app "completa" según lo que describís:

| Falta | Por qué importa |
|---|---|
| Onboarding de 2-3 pantallas | Explicar el concepto ("sin Internet, sin cuenta") antes de pedir una acción |
| Perfil de usuario local | Elegir avatar/color/nombre una sola vez, no cada vez que te unís a una sala |
| Estado de red visible | Mostrar señal, nodos conectados, distancia aproximada — es el corazón del producto |
| Lista de participantes con estados | Quién está cerca, quién se alejó y perdió señal, quién es el host |
| Perfil de sala / configuración | Renombrar, ver código de nuevo, transferir host, finalizar sala — mencionás que ya existe el ciclo de vida, pero no vi la pantalla de administración |
| Chats privados | Se menciona que conviven con el general, pero no hay captura de esa vista ni del selector |
| Historial de salas recientes | Volver a una sala frecuente (ej. la del camping familiar) sin pedir el código de nuevo |
| Estados vacíos diseñados | "Sin mensajes todavía" necesita ilustración + micro-copy, no solo texto gris |
| Errores y estados de borde | Sala llena, código inválido, se perdió la conexión con el host, host se desconectó — ninguno está diseñado |
| Adjuntos básicos | Ya que la arquitectura lo permite a futuro, al menos la UI de "adjuntar" (cámara, ubicación) debería estar presente aunque backend venga después |
| Permisos del sistema explicados | Wi-Fi/Bluetooth/ubicación se piden para descubrir salas cerca — necesita una pantalla de permisos con explicación, no un popup nativo crudo |

## 3. Arquitectura de información recomendada

```
Splash/Onboarding (primera vez)
  └─ 3 pantallas: "Chateá sin Internet" / "Creá una red con la gente cerca" / "Nunca se guarda en la nube"

Home
  ├─ Crear sala
  │    └─ Nombre sala + Tu perfil (avatar/color) → Sala creada (código + QR grandes) → Entrar
  ├─ Unirme a sala
  │    └─ Salas cerca (radar/lista) o código manual → Uniendo... → Entrar
  └─ Salas recientes (si las hubo)

Sala (dentro)
  ├─ Header: nombre sala + estado de red (señal, nodos conectados)
  ├─ Lista de canales: General + Privados (con no leídos)
  ├─ Chat individual
  │    └─ Adjuntar (placeholder foto/ubicación) · estado de entrega
  ├─ Participantes (lista con host, señal por persona, transferir host)
  └─ Configuración de sala (renombrar, código, salir, finalizar)

Perfil local (yo)
  └─ Nombre, avatar/color, apariencia (claro/oscuro), permisos
```

## 4. Sobre las 3 propuestas visuales

Adjunto tres mockups (pantalla inicial, creación/descubrimiento de sala, chat) con direcciones distintas:

1. **Liquid Glass** — estética Apple/iOS: tarjetas translúcidas con blur, degradés suaves violeta-coral, muy premium pero exige más trabajo de rendimiento (blur real en Android es costoso en dispositivos gama media, que es justo el público de "camping/crucero").
2. **Señal Nítida** — minimalismo plano estilo Telegram/WhatsApp: máximo contraste, cero decoración, carga instantánea, se lee "serio y confiable". Es la opción más segura y la más barata de implementar bien en Flutter/RN sobre gama media.
3. **Pulso de Malla** — dirección propia con identidad: anillos de señal concéntricos como firma visual (referencian literalmente "red sin Internet"), fondo de puntos tipo malla de nodos, tipografía display propia (Space Grotesk) en vez de la tipografía default del sistema. Es la que más diferencia a Kena de "otro chat más".

Mi recomendación: **base de la propuesta 2 (rendimiento y legibilidad) con el sistema de anillos/nodos de la propuesta 3 como firma visual** en los momentos clave (splash, pantalla de conexión, indicador de señal). El liquid glass real de iOS 18 conviene reservarlo para variantes específicas de iOS más adelante, no como base multiplataforma.

## 5. Prompt final para el developer (Claude Code)

```
Contexto: Kena Connect es una app de chat local sin Internet (red Wi-Fi cercana,
sin servidor externo). El flujo core de crear/unirse a sala y chatear ya funciona
en producción. Esta tarea es exclusivamente de UI/UX — no tocar la lógica de red,
sockets, ni el manejo de sesión de sala existente.

Objetivo: Rediseñar el frontend siguiendo un sistema de diseño flat-minimal
(estilo Telegram/WhatsApp) con una firma visual propia de "anillos de señal /
malla de nodos" para los momentos de conexión, en vez de componentes Material
Design por defecto.

Tareas:
1. Crear un design system base: tipografía (Inter para UI, Space Grotesk para
   títulos/marca), paleta (fondo casi negro #0A0908, tarjeta #151210, acento
   ámbar #FF8A3D → #E85D25 en degradé, texto secundario a 50% opacidad), radios
   de borde 10-16px, bordes de 1px al 8% de opacidad en vez de sombras.
2. Rediseñar las pantallas existentes (splash, crear sala, unirse a sala, sala
   creada con QR, lista de canales, chat) con ese sistema.
3. Agregar las pantallas faltantes: onboarding de 3 pasos para primer uso,
   perfil local (nombre + avatar/color, sin cuenta ni login), pantalla de
   participantes con estado de señal por persona y opción de transferir host,
   configuración de sala (renombrar/código/salir/finalizar), estados vacíos
   ilustrados, estados de error (código inválido, host desconectado, sala llena).
4. El indicador de "conexión activa" pasa a ser un componente reutilizable con
   fuerza de señal visible (no solo un punto de color), usado en el header de
   sala y en la lista de participantes.
5. Mobile-first, pero mantené el layout usable en tablet (la app es
   multiplataforma según la arquitectura ya definida).

No hacer: no cambiar el protocolo de red, no agregar dependencias de backend
nuevas, no tocar la lógica de creación/unión/transferencia de sala — solo la
capa visual y las pantallas nuevas que son puramente de UI (el estado real que
consumen puede quedar mockeado hasta integrarlo).

Entregable: componentes reutilizables (no pantallas hardcodeadas una por una),
para que el mismo sistema sirva cuando se agreguen fotos/archivos/música más
adelante sobre la misma arquitectura.
```
