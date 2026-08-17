# Flujo de producto

## Modelo conceptual

```
Kena Connect (app/plataforma)
  └─ Red local Kena (infraestructura Wi-Fi LAN, invisible para el usuario)
      └─ Sala (espacio lógico temporal — lo único que el usuario "ve")
          └─ Participantes
              └─ Servicios de la sala
                  └─ Mensajería (chat General + privados) — el único servicio de esta etapa
```

El chat no es "lo que es" Kena — es el primer servicio sobre una red
local temporal. La arquitectura (`RoomSession`, protocolo con
`recipientId`/tipos de mensaje) está pensada para que agregar otro
servicio el día de mañana no requiera rehacer la sala ni el
descubrimiento — ver `ARCHITECTURE.md`.

## Flujo principal

```
Abrir Kena
  │
  ▼
Inicio ── Crear una sala ──► Nombre de la sala + Tu nombre ──► Lobby
  │                                                              │
  └── Unirme a una sala ──► Salas cerca / código / QR ──► Conectado
                                                              │
                                        (anfitrión)            (participante)
                                        "Entrar a la sala"          │
                                              │                     │
                                              ▼                     ▼
                                        ┌─────────────────────────────┐
                                        │   Bandeja de la sala        │
                                        │   💬 General            ●2 │
                                        │   👤 Sol                    │
                                        │   👤 Fran               ●1 │
                                        └─────────────────────────────┘
                                              │
                              tocar una fila  ▼
                                    Chat (General o privado)
```

Desde la bandeja también se llega a: Participantes, Configuración de
la sala (nombre, código/QR, silenciar notificaciones, transferir
anfitrión, salir/cambiar/finalizar — todo consolidado en una sola
pantalla, ver más abajo).

La primera vez que se abre Kena se muestra un **onboarding de 3
pasos** ("Chateá sin Internet" / "Creá una red con tu grupo" / "Solo
funciona de cerca"), con "Saltar" siempre visible; una vez visto no
vuelve a aparecer (`shared_preferences`).

Desde Inicio, sin necesidad de crear/unirse a nada, se llega a **Mi
perfil** y **Configuración** (barra superior). Si el dispositivo ya
está en una sala (por ejemplo, volvió para atrás sin salir), Inicio
muestra una card **"🟢 Sala activa"** para retomarla. Debajo, una
sección **"Recientes"** lista hasta 4 salas a las que el dispositivo
se conectó antes (nombre + "Hoy"/"Ayer"/"Hace N días"); tocar una
lleva directo a "Unirme a una sala" con el código prellenado e intenta
reconectar sola — ver "Recientes en Inicio" más abajo.

## Crear una sala

1. Inicio → "Crear una sala".
2. Nombre de la sala (prellenado con "Familia" como ejemplo) + Tu
   nombre (prellenado con el de Mi perfil si ya lo configuraste).
3. Al tocar "Crear sala": la app arma la red local por dentro (esto es
   lo único "técnico" — nunca se lo mostramos al usuario) y te lleva
   al **Lobby**. Si el dispositivo no tiene Wi-Fi activo (datos
   móviles no alcanzan — Kena arma una red local, no usa Internet),
   antes muestra "Necesitamos que actives una conexión Wi-Fi..." y
   sigue solo apenas la detecta, sin que haga falta tocar "Crear sala"
   de nuevo.
4. Lobby: nombre de la sala, QR, código `KENA-XXXX`, cantidad de
   participantes y su lista en vivo (vos aparecés como "Vos ·
   Anfitrión").
5. "Entrar a la sala" → Bandeja de la sala.

## Unirme a una sala

1. Inicio → "Unirme a una sala".
2. Tu nombre (mismo prellenado que en Crear).
3. La app busca salas cerca automáticamente ("Salas cerca tuyo"),
   mostrando sólo las que están detectables *ahora* — nunca una
   histórica. Si encuentra alguna, se puede tocar directamente. Si no:
   "No encontramos ninguna sala cerca."
4. Alternativas siempre disponibles: ingresar el código a mano, o
   escanear el QR de otro dispositivo (abre la cámara).
5. Al conectar → directo a la Bandeja de la sala (sin lobby intermedio
   — el lobby es la sala de espera del anfitrión mientras arma la
   sala, no tiene sentido para quien ya se está uniendo a una que ya
   existe).

## Dentro de la sala: la bandeja

Es la pantalla principal mientras estás en una sala — una lista de
conversaciones, General y privados conviviendo en un mismo lugar (no
hay una sección aparte de "chats privados"):

```
Kena · Familia          🟢 Conexión activa

💬  General                          18:04
    Vos: nos vemos en la puerta 12

👤  Sol                          ●2  18:12
    hola todo bien?

👤  Fran                             18:07
    dale, ahí llego
```

Tocar cualquier fila abre el chat correspondiente. El chat privado con
alguien se "crea" la primera vez que le mandás un mensaje — no hace
falta ningún paso previo de "crear conversación" (aunque también se
puede arrancar desde Participantes, tocando a la persona).

En pantallas anchas (tablet/desktop, ancho ≥ 700dp) la bandeja y la
conversación elegida se muestran lado a lado en vez de navegar a una
pantalla nueva.

## "Está escribiendo"

Tanto en General como en un privado, si alguien más está tipeando en
ese mismo hilo aparece una franja fina arriba del campo de mensaje:
"Sol está escribiendo…", "Sol y Jorge están escribiendo…" (General,
con varios a la vez), o "3 personas están escribiendo…" a partir de
la tercera. Aparece apenas la otra persona empieza a tipear y
desaparece sola cuando deja de hacerlo — con un margen de seguridad
(6s sin noticias) para que nunca quede pegado si se pierde el aviso
de "dejé de escribir" (por ejemplo, la app pasa a background a mitad
de tipear).

## Notificaciones y no leídos

Sin servidor remoto — todo sale de eventos locales de mensajes
recibidos por la propia conexión de red de la sala:

- Cada conversación (General o privada) tiene su propio contador de no
  leídos, visible como una bolita numerada en la bandeja.
- Un mensaje nuevo en un hilo que **no** estás mirando: suma al
  contador, dispara sonido + vibración + notificación local (Android).
- Un mensaje nuevo en el hilo que **sí** estás mirando: no genera
  aviso, pero tampoco hace falta — ya lo estás viendo.
- Abrir un hilo limpia su contador de no leídos al instante.
- "Silenciar notificaciones" (menú de la sala) apaga sonido/vibración/
  notificación pero el contador de no leídos se sigue actualizando.

## Participantes

Ícono de personas en la bandeja → lista completa, con quién es el
anfitrión y quién está conectado (barras de señal — ver "Señal:
honesta, no simulada" abajo). Tocar a alguien (que no seas vos) abre
la conversación privada con esa persona. Si sos anfitrión, cada fila
de otro participante tiene además un ícono para transferirle el rol
directamente desde ahí (mismo flujo de confirmación que "Transferir
anfitrión" del menú).

## Configuración de la sala

Reemplaza lo que antes eran dos pantallas separadas ("Invitar" e
"Información de la sala"): se llega tocando el nombre de la sala en el
encabezado o desde el menú, y reúne en un solo lugar todo lo que antes
estaba desperdigado en el menú de la bandeja:

- Nombre de la sala (sin edición — ver "Por qué no se puede renombrar"
  en `ROADMAP.md`).
- Código y QR para compartir (sólo visible si sos anfitrión — los
  participantes no tienen código propio para invitar, comparten el
  mismo del anfitrión).
- Acceso a Participantes.
- Silenciar/activar notificaciones.
- Transferir anfitrión (sólo si hay otros participantes).
- Salir de la sala / Cambiar de sala (participante) o Finalizar sala
  (anfitrión).

## Salir / Cambiar / Finalizar / Transferir

- **Participante — "Salir de la sala"**: confirmación → vuelve al
  Inicio.
- **Participante — "Cambiar de sala"**: confirmación → sale de la
  sala actual y va directo a "Unirme a una sala" para buscar otra.
- **Anfitrión — "Finalizar sala"**: confirmación ("todos los
  participantes serán desconectados") → se avisa a todos y vuelve al
  Inicio. Los participantes ven un diálogo claro en vez de un error de
  conexión.
- **Anfitrión — "Transferir anfitrión"** (visible sólo si hay otros
  participantes): elegís quién continúa la sala. Esa persona pasa a
  armar su propia red local con el mismo nombre y un código nuevo para
  compartir; al resto se le avisa que la sala terminó y por qué, para
  que puedan pedir el código nuevo y volver a unirse. No existe forma
  de migrar la sala en vivo sin que cambie el código cuando es el
  propio anfitrión el que decide irse — ver `ARCHITECTURE.md` para el
  porqué. Esto es distinto de que el anfitrión **desaparezca de
  golpe** (se le corta, se le apaga el teléfono): ahí no hace falta
  ninguna acción de nadie — ver "Migración automática" abajo.

## Migración automática de anfitrión

Si el anfitrión se cae sin avisar (a diferencia de "Transferir
anfitrión" o "Finalizar sala", que son decisiones explícitas), la sala
**intenta seguir sola**: uno de los participantes toma la posta como
nuevo anfitrión de forma automática, reusando el mismo código — nadie
tiene que crear una sala nueva, compartir un código nuevo, ni volver a
escanear un QR. El único indicio es la franja de conexión pasando por
"Reconectando…" y después "Conexión restablecida", igual que un corte
de wifi cualquiera. Ver `HOST_MIGRATION.md` para el detalle técnico y
sus límites conocidos (no es magia: si el participante elegido para
continuar la sala también está inalcanzable, la sala sí se pierde,
como antes).

## Estados de conexión que ve un participante

Hay dos capas: el estado propio de cada pantalla de sala/chat (un
punto + texto en la barra superior) y una **franja global** que se ve
en cualquier pantalla de la app mientras haya una sala activa — ver
`CONNECTION_STATE.md` para el detalle técnico.

- 🟢 **Conexión activa** — todo normal.
- 🟡 **Conexión inestable** — el socket sigue abierto pero hace rato
  que no se ve al anfitrión; probable degradación antes de un corte.
- 🟡 **Reconectando…** — se cortó, la app está reintentando sola (al
  mismo lugar primero, y si no aparece, buscando la sala por su código
  como si fuera la primera vez — cubre tanto un alejamiento temporal
  como que la sala haya migrado de anfitrión, ver `HOST_MIGRATION.md`).
- 🟢 **Conexión restablecida** — aviso breve al volver a `Conexión
  activa` desde cualquiera de los estados anteriores; se asienta solo.
- 🔴 **Conexión perdida** — se agotó también la búsqueda por código;
  pantalla con botón para volver al inicio.
- **Sala finalizada** — el anfitrión la cerró o transfirió
  (manualmente); diálogo explicando el motivo y vuelta al inicio. Si
  en cambio la sala sigue por una migración automática, no hay ningún
  diálogo — es exactamente lo que se busca, que no haga falta que el
  usuario se entere (sección 25 del brief).

Antes de que exista una sala, "Crear sala"/"Conectar con código"
muestran sus propios pasos previos ("Preparando tu sala…"/
"Conectando…") — no son parte de la franja global (todavía no hay
ninguna sesión a la que suscribirse), son el estado local de esa
pantalla.

## Recientes en Inicio

**Decisión revertida a propósito**: una etapa anterior de este mismo
rediseño decidió explícitamente que no debía existir ninguna pantalla
de historial de salas ("Mis salas"), porque una sala es una red local
temporal y mostrarla como si siguiera disponible sería engañoso. El
brief de diseño final que dio forma a la interfaz actual pidió
específicamente reincorporar el historial como una sección
"Recientes" en Inicio, así que se implementó — pero con el mismo
cuidado que motivó la decisión original:

- Usa el mismo registro liviano que ya existía (`RoomHistoryStore`,
  pensado en su momento sólo para analytics/debug) — no se agregó
  ningún dato nuevo.
- Cada fila muestra nombre + antigüedad relativa ("Hoy", "Ayer", "Hace
  N días"), nunca un estado de conexión — no hay forma honesta de
  saber si esa sala sigue activa sin intentar conectarse.
- Tocar una fila no "reabre" nada mágicamente: navega a "Unirme a una
  sala" con el código prellenado y reintenta la conexión real: si la
  sala ya no existe, se ve el mismo error de código vencido que
  tipeando a mano.

La card "Sala activa" (para la sala en la que el dispositivo sigue
efectivamente conectado ahora mismo) sigue siendo algo aparte de
Recientes.

## Mi perfil / Configuración

Accesibles desde la barra superior de Inicio, sin necesidad de estar
en una sala:

- **Mi perfil**: nombre + color de avatar (autoguardado, sin botón
  "Guardar"), sin cuenta ni login. Se usa como valor inicial al
  crear/unirte a una sala. "Apariencia" muestra Oscuro (activo) y
  Claro como preview deshabilitado — Kena es dark-only por ahora, ver
  `ROADMAP.md`.
- **Configuración**: Perfil y Acerca de Kena son reales; el resto de
  las categorías (Cuenta, Chat, Notificaciones, Sonidos, Conexiones,
  Privacidad, Ayuda) están listadas pero avisan "Próximamente" — a
  propósito no simulan una función que todavía no existe.

## Estado de un mensaje propio

Cada burbuja propia muestra, junto a la hora, un ícono honesto sobre
lo que la app puede saber de verdad: un check simple significa "salió
de este dispositivo" (nunca un doble check — eso implicaría
entregado/leído, y no hay acuse de recibo real). Si no había conexión
al mandarlo, se ve igual en la burbuja pero marcado con un aviso de
error — nunca desaparece en silencio — y se reintenta solo apenas la
conexión vuelve, sin que haga falta reenviarlo a mano.

## Señal: honesta, no simulada

Las barras de señal (propia conexión y de otros participantes) nunca
muestran un número inventado:

- La conexión propia mapea 1:1 desde el estado real (`connected` → 4
  barras, `reconnecting` → 2, `lost`/`closedByHost` → 0).
- Un participante del roster siempre se ve con 4 barras fijas: "está
  en la lista" ya significa "conectado al anfitrión ahora mismo"; no
  existe telemetría de RSSI/latencia por dispositivo, así que mostrar
  una variación más fina sería inventar un dato.

## Adjuntar (Foto / Ubicación)

El ícono de clip en el chat abre una hoja "Adjuntar" con dos opciones,
ambas deshabilitadas y marcadas "Próximamente": compartir archivos no
es parte del protocolo de mensajería todavía. Está ahí para mostrar
hacia dónde crece Kena, no para simular una función que no existe.

## Mensajes de sistema en el chat

Cuando alguien se conecta o se desconecta de la sala, el chat General
muestra un mensaje de sistema centrado (no es un mensaje de ningún
participante):

- Primera vez que alguien se une: **"[nombre] se unió"**.
- Si ese mismo `senderId` ya se había desconectado antes en este
  hilo, un nuevo `join` se lee como **"[nombre] volvió a
  conectarse"** en vez de "se unió".
- Al desconectarse: **"Se perdió la conexión con [nombre]"** (nunca
  "se fue" ni nada que sugiera una salida intencional, porque desde
  la sala no se puede distinguir una desconexión de un cierre de app).

Es copy derivado 100% del log de eventos `join`/`leave` que ya emitía
el protocolo — no hay estado de conectividad remota nuevo.
