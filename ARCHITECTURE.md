# Arquitectura

## Principio de UX: cero jerga técnica

Ningún texto de UI usa "host", "cliente", "servidor", "IP", "puerto",
"WebSocket", "socket" ni ningún término de networking. Esos conceptos
existen en el código (nombres de clase, comentarios, logs) porque ahí
sirven para que el código se entienda, pero nunca llegan a una pantalla.
La terminología de producto es:

| Concepto técnico | Lo que ve el usuario |
|---|---|
| Host / servidor | Anfitrión / "Crear una sala" |
| Cliente | Participante / "Unirme a una sala" |
| Servidor WebSocket | "Sala" |
| IP + puerto | Código `KENA-XXXX` o QR |
| Join | "Unirme a una sala" |
| Mensaje general (`recipientId == null`) | Chat "General" |
| Mensaje con destinatario | Conversación privada |

Si se agrega una pantalla nueva, cualquier texto ahí debe poder leerlo
alguien que nunca usó una red local y entenderlo igual. Ver
[`DOMAIN_MODEL.md`](DOMAIN_MODEL.md) para el detalle conceptual,
[`PRODUCT_FLOW.md`](PRODUCT_FLOW.md) para el flujo pantalla por
pantalla, [`CONNECTION_STATE.md`](CONNECTION_STATE.md) para el estado
global de conexión, y [`HOST_MIGRATION.md`](HOST_MIGRATION.md) para
la migración automática de anfitrión.

## Capas

```
lib/
  core/
    protocol/       — formatos de mensaje sobre el wire (ChatMessage, DiscoveryMessage, roster)
    network/        — transporte: WebSocket (chat) + UDP broadcast (descubrimiento)
    notifications/  — NotificationService (sonido/vibración/notificación local)
    utils/          — helpers puros (avatar, código de sala, perfil local, historial interno,
                       network_readiness.dart — detección de Wi-Fi/Ethernet vía connectivity_plus)
  theme/
    kena_colors.dart — identidad visual: KenaColors (tokens), buildKenaTheme(), KenaBackground (glow de fondo)
  widgets/           — sistema de diseño reutilizable ("vidrio líquido"):
    kena_glass_button.dart — KenaGlassButton/KenaGhostButton (blur, sólo para acciones primarias)
    kena_card.dart          — KenaCard/KenaIconChip (fila/tarjeta plana, sin blur — la regla general)
    signal_bars.dart        — barras de señal honestas (ver DOMAIN_MODEL.md)
    signal_rings.dart       — marca de marca (onboarding/Home)
    avatar.dart              — círculo de iniciales
    kena_field.dart          — input de texto con label y error inline
    participant_row.dart     — fila de participante (+ acción opcional, p.ej. transferir host)
    connection_banner.dart      — franja global de estado de conexión (ver CONNECTION_STATE.md)
    connection_phase_style.dart — color/ícono por ConnectionPhase, compartido banner + pantallas de sala
  features/
    onboarding/      — 3 pasos, sólo la primera vez (shared_preferences)
    root_screen.dart — decide Onboarding vs Home al arrancar
    home/            — pantalla inicial (+ card "Sala activa", "Recientes", acceso a Perfil/Configuración)
    create_room/     — formulario para convertirse en anfitrión (+ gate de red local, ver más abajo)
    lobby/           — sala de espera del anfitrión (código, QR, participantes)
    join_room/       — buscar/ingresar código/escanear QR para unirse
    room/            — todo lo que pasa "dentro" de una sala:
      domain/
        room_session.dart            — RoomSession (contrato único anfitrión/participante)
        notifying_room_session.dart  — decorator: no leídos + notificaciones + mute
        connection_phase.dart        — ConnectionPhase + ConnectionPhaseTracker (ver CONNECTION_STATE.md)
        host_migration.dart          — ResilientRoomSession + electStandby (ver HOST_MIGRATION.md)
        conversation_summary.dart    — deriva la bandeja a partir del log de mensajes
        active_room_registry.dart    — "a qué sala estoy conectado ahora", para la card de Home
                                        y para que ConnectionBanner sepa a qué sesión suscribirse
      room_shell_screen.dart    — bandeja (General + privados), responsive
      chat_thread_screen.dart   — un hilo de chat (general o privado), + typing indicator + hoja "Adjuntar"
      participants_screen.dart  — lista de participantes (+ transferir anfitrión por fila)
      room_info_screen.dart     — "Configuración de la sala": nombre/código/QR/participantes +
                                   silenciar/transferir/salir/cambiar/finalizar, todo en un lugar
      host_takeover_screen.dart — arranca la continuación de la sala tras una transferencia MANUAL
                                   (ver "Transferencia de anfitrión" — la migración automática no
                                   pasa por acá, es transparente, ver HOST_MIGRATION.md)
    profile/         — Mi perfil (nombre + avatar, local, autoguardado)
    settings/        — Configuración + Acerca de Kena
```

`core/` no sabe nada de pantallas ni de nomenclatura de producto — es
donde vive toda la jerga técnica. `features/` no habla directamente los
protocolos: siempre pasa por `core/network`, o mejor, por la capa de
dominio (`RoomSession`) descripta en `DOMAIN_MODEL.md`.

**No existe `features/my_rooms`** como pantalla dedicada — el
historial de salas recientes vive directamente en `home_screen.dart`
como una sección más de Inicio, no como una pantalla aparte. Ver
`PRODUCT_FLOW.md` → "Recientes en Inicio" y `ROADMAP.md` para el porqué
de esta vuelta atrás sobre una decisión anterior de no mostrar
historial. `core/utils/room_history.dart` sigue siendo el mismo
registro liviano de siempre — no se le agregó ningún dato nuevo.

## Transporte

- **Chat**: WebSocket sobre `shelf`/`shelf_web_socket`. El anfitrión
  (`ChatHostServer`) escucha en un puerto TCP fijo y hace de relay
  entre los participantes conectados — a todos (chat General) o a uno
  puntual (privado), según traiga o no `recipientId` el mensaje. Cada
  participante (`ChatClientConnection`) es un cliente WebSocket normal,
  con reconexión automática ante un corte inesperado: primero unos
  pocos intentos directos al mismo `host:puerto`, y si eso se agota,
  vuelve a buscar la sala por su código (ver HOST_MIGRATION.md) antes
  de rendirse del todo. Cada intento de abrir el socket tiene un
  timeout de 8s (`ChatClientConnection._connectTimeout`) — sin esto, un
  destino que ni acepta ni rechaza activamente la conexión (típico al
  reconectarse justo después de salir de una sala) dejaba la espera sin
  resolver nunca, y con ella la pantalla de "Unirme a una sala" con el
  campo de código congelado (bug real, reportado por uso — ver
  `test/connection_timeout_test.dart`).
- **Descubrimiento**: UDP broadcast en un puerto fijo
  (`DiscoveryMessage.discoveryPort`). Quien se quiere unir manda un
  `DISCOVER`; cada anfitrión que escucha responde `ANNOUNCE` con el
  nombre de la sala, su código corto y el puerto de chat.
- **Latido**: el anfitrión manda `MessageType.presence` a todos cada
  4s — no es chat, nunca se muestra ni se guarda; sólo alimenta la
  detección de "conexión inestable" (ver CONNECTION_STATE.md).
- **"Está escribiendo"**: `MessageType.typing` es efímero (nunca entra
  al log de mensajes), con la misma semántica General/privado que un
  mensaje normal según lleve o no `recipientId`.
- **Entrega de mensajes propios**: `ChatMessage.deliveryStatus`
  (`sending`/`sent`/`failed`) es un campo local, mutable, que nunca se
  serializa — sin acuses de recibo reales en el protocolo, es lo único
  que un dispositivo puede saber honestamente de un mensaje propio. Si
  no hay conexión al mandar, el mensaje se muestra igual (marcado
  `failed`, nunca desaparece en silencio) y queda en una cola que se
  reintenta sola apenas la conexión vuelve (`ChatClientConnection._outbox`).

## Cómo se resuelve "unirse sin saber nada de redes"

Quien crea la sala recibe un código corto generado al azar
(`generateConnectionCode()`, 4 caracteres sin ambigüedad tipo `0`/`O`).
Ese código:

- se muestra como texto (`KENA-XXXX`) y como QR (`qr_flutter`);
- **no** codifica la IP — codifica sólo el código.

Quien se quiere unir, sea por texto o escaneando el QR
(`mobile_scanner`), termina llamando a lo mismo:
`HostDiscoveryScanner.findByCode(code)`, que hace un broadcast UDP y
se queda con el primer `ANNOUNCE` cuyo código matchee. Recién ahí se
obtiene IP:puerto y se abre la conexión WebSocket real. El usuario nunca
ve ese IP:puerto — sólo el nombre de la sala a la que se sumó.

`Nota de entorno`: los emuladores Android son poco confiables para
probar broadcast UDP — cada instancia corre en su propia red virtual
aislada (así que dos emuladores distintos nunca se descubren entre sí),
y hasta dos apps en el **mismo** emulador pueden fallar en descubrirse
de forma intermitente (el AVD expone `eth0` y `wlan0` en paralelo sobre
la misma subred, lo que genera ruteo ambiguo para el broadcast). **Re-
verificado en esta etapa**: con dos AVD reales (`kena_host`/
`kena_client`) corriendo la app de verdad, "Unirme a una sala" (tanto
detección automática como código a mano) efectivamente no encuentra la
sala del otro emulador — se ve el mismo mensaje honesto que vería un
usuario ("No encontramos ninguna sala con ese código cerca tuyo."), sin
colgarse ni romperse. Es una limitación conocida del entorno de
emuladores, no del protocolo ni del producto — en dispositivos reales
sobre la misma red Wi-Fi funciona de
forma estable. La conexión WebSocket (TCP) en sí no tiene este problema.

## Preparación de red antes de crear una sala

`CreateRoomScreen` chequea `hasUsableLocalNetwork()`
(`core/utils/network_readiness.dart`, sobre `connectivity_plus` +
enumeración de interfaces para detectar la propia Zona Wi-Fi del
dispositivo, que `connectivity_plus` no ve porque no es "salida" —
sólo transmite) antes de levantar `ChatHostServer`. Si ya hay
Wi-Fi/Ethernet activo (datos móviles no sirven — Kena arma una LAN, no
usa Internet), sigue directo. Si no, muestra `WifiSetupGuide`
(`widgets/wifi_setup_guide.dart`): un paso a paso escrito para activar
la Zona Wi-Fi a mano, con un atajo a Ajustes de red del sistema
(`core/utils/system_settings.dart`, canal nativo `kena/system_settings`
→ `Settings.ACTION_WIRELESS_SETTINGS`) — y sondea en segundo plano cada
2s, retomando la creación de la sala sola en cuanto detecta que ya hay
red, sin que el usuario tenga que volver a tocar nada.

**Por qué es manual y no automático**: se intentó que la app creara la
Zona Wi-Fi por su cuenta (`WifiManager.startLocalOnlyHotspot`) y que
quien se une a una sala se conectara solo a esa red vía un QR con las
credenciales adentro (`WifiNetworkSpecifier`). En emulador la lógica se
veía correcta de punta a punta, pero en dispositivos reales
`startLocalOnlyHotspot` rechazó el pedido con `SecurityException` de
forma persistente pese a tener el permiso de ubicación concedido — la
causa exacta no se terminó de aislar (candidato más probable, sin
confirmar: falta declarar `CHANGE_WIFI_STATE` en el manifest, que
Android exige además de `ACCESS_FINE_LOCATION` para este método
puntual). Se decidió no seguir insistiendo — la superficie de fallos de
permisos de Wi-Fi varía demasiado entre fabricantes/versiones como para
que valiera la pena seguir. El código de ese intento quedó archivado en
`archive/auto_wifi_attempt/` por si se retoma con `CHANGE_WIFI_STATE`
declarado como primer paso.

`ResilientRoomSession._becomeHost()` (ver HOST_MIGRATION.md) sólo
verifica si ya hay red utilizable cuando un dispositivo se hace cargo
de la sala en una migración automática — no intenta crear una. Si la
red del grupo dependía del propio anfitrión que desapareció (su Zona
Wi-Fi personal) y el sucesor tampoco tiene ninguna, la migración no
puede completarse sola (ver límites ya documentados en
HOST_MIGRATION.md).

**Límite real, no inventado, que ningún código puede resolver**: no
existe forma de que un dispositivo obligue a *otro* dispositivo a
unirse a una red Wi-Fi nueva sin que su usuario lo apruebe (frontera de
seguridad del SO, no una limitación de Kena) — por eso, si una
migración automática de anfitrión termina creando un punto de acceso
nuevo (porque la red anterior dependía del anfitrión que desapareció),
el resto del grupo va a necesitar reconectar su Wi-Fi a mano una vez.

## Dueño del ciclo de vida de la sala

- `CreateRoomScreen` crea `ChatHostServer` + `HostDiscoveryResponder` y
  se los pasa a `LobbyScreen`. `LobbyScreen` los apaga en su
  `dispose()`. Entrar a la sala desde el lobby empuja `RoomShellScreen`
  *encima* (no reemplaza el lobby), así que volver atrás desde la sala
  te deja en el lobby con todo intacto.
- `JoinRoomScreen` reemplaza (`pushReplacement`) por `RoomShellScreen`
  una vez conectado; no hay lobby del lado de quien se une, según el
  flujo: *Unirme → seleccionar/escanear → bandeja de la sala*.
- Dentro de la sala, `RoomShellScreen` es la pantalla "ancla": abrir un
  hilo (`ChatThreadScreen`) o `ParticipantsScreen` sólo empuja encima.
  Salir/Cambiar/Finalizar/Transferir son las únicas acciones que cierran
  la sesión de red y navegan fuera de la sala.
- `ActiveRoomRegistry` (un `ValueNotifier<RoomSession?>` global) guarda
  a qué sala está conectado el dispositivo *ahora*. `RoomShellScreen` se
  registra al entrar y se da de baja recién al salir/finalizar — así,
  si el usuario vuelve para atrás con el botón del sistema sin salir
  formalmente, la sala sigue viva y el Inicio se lo ofrece de nuevo con
  la card "Sala activa" en vez de perderla silenciosamente.

## Notificaciones, no leídos y silenciar

`NotifyingRoomSession` (`features/room/domain/notifying_room_session.dart`)
es un *decorator* sobre cualquier `RoomSession` — no le importa si por
dentro hay un anfitrión o un participante. Escucha el stream de
mensajes y:

- lleva un contador de no leídos por hilo (`null` = General);
- sabe qué hilo está mirando el usuario ahora (`setActiveThread`/
  `clearActiveThread`, llamado por `ChatThreadScreen` en
  `initState`/`dispose`) para no generar aviso de algo que ya se está
  viendo;
- dispara `NotificationService` (sonido + vibración + notificación
  local vía `flutter_local_notifications`) salvo que el hilo esté
  silenciado (`setMuted`) — en ese caso el contador se sigue
  actualizando, sólo se corta el aviso.

Es un decorator y no algo mezclado en `HostRoomSession`/
`ParticipantRoomSession` a propósito: ninguna de las dos necesita saber
nada de UI/notificaciones, y así se implementa una sola vez para los
dos roles.

## Transferencia de anfitrión: dos mecanismos distintos

No hay forma de migrar la sala en vivo (misma IP:puerto) a otro
dispositivo — el "anfitrión" es, técnicamente, quien corre el servidor
WebSocket, y eso no se puede mover sin cortar la conexión de todos.
Hay dos caminos, para dos situaciones distintas:

- **Transferencia manual** (el anfitrión se quiere ir voluntariamente,
  con la sala funcionando normalmente): visible, con un código nuevo
  para compartir — descripta abajo.
- **Migración automática** (el anfitrión desaparece de golpe, sin
  avisar): invisible para el usuario, reusa el mismo código — ver
  `HOST_MIGRATION.md`. No pasa por `HostTakeoverScreen`/`LobbyScreen`;
  vive enteramente en `ResilientRoomSession`.

### Transferencia manual: qué es y qué no es

1. El anfitrión elige un sucesor (`RoomSession.transferHostTo`).
2. `ChatHostServer.transferHostAndStop` le manda al sucesor un mensaje
   de control privado (`MessageType.hostTransferOffer`, con el nombre
   de la sala) y a todos los demás un `roomClosed` con el motivo en
   texto plano ("transferida a fulano, pedile el código nuevo").
3. El dispositivo del sucesor escucha ese mensaje
   (`RoomSession.promotedToHostStream`), muestra un diálogo, y
   `HostTakeoverScreen` arranca su propia sala con el mismo nombre —
   aterriza en un `LobbyScreen` nuevo con un código distinto para
   volver a compartir.
4. El resto de los participantes ve el motivo en el diálogo de "sala
   finalizada" y tiene que volver a unirse a mano con el código nuevo.

Es decir: la sala *puede continuar* sin el anfitrión original (el
objetivo del producto — que el anfitrión no sea un dueño absoluto que
se lleva la sala si se va), pero no de forma perfectamente transparente
para el resto. Documentado como decisión de scope, no como bug.

## Responsive

`RoomShellScreen` usa `LayoutBuilder`: por debajo de 700dp de ancho,
tocar una conversación empuja `ChatThreadScreen` como pantalla nueva
(mobile). Por encima, se muestra un layout maestro-detalle — lista de
conversaciones a la izquierda, hilo elegido a la derecha, sin navegar —
para aprovechar el espacio en tablet/desktop. El resto de las pantallas
(Inicio, Lobby, Crear/Unirme) son de una sola columna centrada con
ancho máximo implícito por el padding, así que no se ven rotas en
pantallas anchas aunque no tengan un layout dedicado.

## Identidad visual

`KenaColors` (en `theme/kena_colors.dart`) es un sistema "vidrio
líquido" propio — fondo casi negro, degradé de marca teal→sky
atenuado (nada de neón), verde/rojo reservados a estados de conexión —
deliberadamente distinto del celeste de Telegram, el verde de
WhatsApp o el blurple de Discord. Es dark-only a propósito (ver
`ROADMAP.md`).

El blur (`BackdropFilter`) es costoso en gama media, así que está
reservado a dos lugares: los botones primarios (`KenaGlassButton`/
`KenaGhostButton`, en `widgets/kena_glass_button.dart`) y el círculo de
enviar del chat — nunca en listas o filas repetidas, que usan
`KenaCard` (sin blur) en su lugar. `KenaBackground` (en
`theme/kena_colors.dart`) agrega un resplandor radial de fondo muy
sutil (10% de opacidad) en cada Scaffold para que ese blur se note sin
cansar en sesiones largas.

Nota técnica: un `BoxDecoration.border` con colores distintos por lado
no se puede combinar con `borderRadius` ni con `BoxShape.circle` —
Flutter tira una excepción de pintado en tiempo de ejecución
("A borderRadius can only be given on borders with uniform colors").
Por eso los bordes de `KenaGlassButton`/`KenaGhostButton` y del botón
de enviar son `Border.all` (un solo alfa), no un borde con brillo
distinto arriba/abajo como en la referencia visual original.
