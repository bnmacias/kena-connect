# Modelo de dominio

Este documento describe los conceptos de producto y cómo se
implementan en el código. La terminología de producto (columna
izquierda) es la única que debe aparecer en la UI.

## Conceptos

| Producto | Tipo en código | Dónde vive |
|---|---|---|
| Sala | `ChatHostServer` (si sos anfitrión) | `core/network/chat_host_server.dart` |
| Anfitrión / Participante | `RoomMember { id, name, isHost }` | `core/network/chat_host_server.dart` |
| Mensaje del chat General | `ChatMessage` con `recipientId == null` | `core/protocol/chat_message.dart` |
| Mensaje privado | `ChatMessage` con `recipientId != null` | `core/protocol/chat_message.dart` |
| Conversación privada | Se deriva, no se guarda aparte (ver abajo) | `features/room/domain/conversation_summary.dart` |
| Estado de conexión (red) | `ConnectionStatus` (`connected`/`reconnecting`/`lost`/`closedByHost`) | `core/network/chat_client_connection.dart` |
| Estado de conexión (presentación) | `ConnectionPhase` (7 estados, ver CONNECTION_STATE.md) | `features/room/domain/connection_phase.dart` |
| Mi perfil | `KenaProfile { name, avatarColorIndex }` | `core/utils/profile_store.dart` |
| No leídos por conversación | `Map<String?, int>` en `NotifyingRoomSession` | `features/room/domain/notifying_room_session.dart` |
| Aviso de "está escribiendo" | `ChatMessage` con `type == MessageType.typing` (efímero, no se guarda) | `core/protocol/chat_message.dart` |
| Orden de llegada de un miembro | `RoomMember.joinOrder` / `RosterMember.joinOrder` — base de la elección de sucesor en una migración | `core/network/chat_host_server.dart`, `core/protocol/roster.dart` |
| Estado de entrega de un mensaje propio | `ChatMessage.deliveryStatus` (`sending`/`sent`/`failed`, local, no viaja por la red) | `core/protocol/chat_message.dart` |

**Nota:** `RoomHistoryEntry`/`RoomHistoryStore` (`core/utils/room_history.dart`)
existen pero **no tienen ninguna pantalla que los muestre** — es
registro interno (analytics/debug), no una funcionalidad de "Mis
salas" visible. Una sala es una red local temporal; cuando termina,
no debería seguir apareciendo como si estuviera disponible.

## Por qué no existe una clase `PrivateConversation`

Una conversación privada **no es una entidad con estado propio**: es
simplemente "todos los `ChatMessage` con `recipientId` donde
participan estas dos personas", calculado al vuelo a partir del log de
mensajes de la sesión (`RoomSession.messageLog`). Esto evita tener dos
fuentes de verdad (el log de mensajes y una lista de conversaciones)
que podrían desincronizarse, y significa que **no hace falta crear una
sala nueva para hablar en privado** — es justamente el requisito que
pedía el producto.

`buildConversationSummaries(session)` (en
`features/room/domain/conversation_summary.dart`) es la función pura
que arma la bandeja: recorre el log una vez, agrupa por destinatario,
y devuelve `General` + una fila por cada otro miembro de la sala.

## RoomSession: el mismo modelo para anfitrión y participante

Toda la UI de "dentro de la sala" (`RoomShellScreen`,
`ChatThreadScreen`, `ParticipantsScreen`) está escrita una sola vez,
contra la interfaz `RoomSession` (`features/room/domain/room_session.dart`).
No le importa si detrás hay un `ChatHostServer` (`HostRoomSession`) o
un `ChatClientConnection` (`ParticipantRoomSession`) — expone lo mismo:

```
roomName, code (null si no sos anfitrión), isHost, mySenderId, myName
messages / messageLog          -> log completo de ChatMessage
members / membersStream        -> lista de RoomMember
currentStatus / statusStream   -> ConnectionStatus
sendGeneral(text)
sendPrivate(text, toMemberId)
leaveRoom() / finishRoom()
```

Esto es lo que permite que "unirme a una sala" y "crear una sala"
terminen en exactamente la misma pantalla de bandeja/chat sin
duplicar código de UI.

### La cadena de decoradores de un participante

`JoinRoomScreen` no le pasa un `ParticipantRoomSession` pelado a la
UI: lo envuelve en dos capas, cada una agregando una responsabilidad
sin que la de abajo sepa nada de la de arriba (mismo patrón que ya
usaba `NotifyingRoomSession`):

```
NotifyingRoomSession       — no leídos + notificaciones + mute
  └─ ResilientRoomSession  — migración automática de anfitrión (ver HOST_MIGRATION.md)
       └─ ParticipantRoomSession — el contrato de red de siempre
```

`ResilientRoomSession` es la única pieza nueva: por fuera es un
`RoomSession` más (nadie que la consuma necesita saberlo), pero por
dentro puede reemplazar su propio delegado de `ParticipantRoomSession`
a `HostRoomSession` en caliente si este dispositivo termina
continuando la sala. El anfitrión (`HostRoomSession` armado desde
`LobbyScreen`) no pasa por esta cadena — no tiene a quién migrarle
nada.

## Identidad de un miembro (por qué importa)

Antes de esta etapa, el servidor identificaba a cada conexión con un id
interno propio (timestamp de cuando se conectó el socket), distinto del
`senderId` que el propio dispositivo elige para sus mensajes. Eso hacía
imposible enrutar un mensaje privado de forma consistente: el emisor no
tenía forma de decir "este mensaje es para tal persona" usando un id
que el receptor reconociera como "yo".

Se unificó: el servidor ahora indexa cada conexión por el `senderId`
que declara al mandar su primer mensaje (`MessageType.join`), y ese
mismo id es el que aparece en `RoomMember.id`, en `ChatMessage.senderId`
y en `ChatMessage.recipientId`. Un solo espacio de identidad para toda
la sala.

## Roster: por qué todos ven la misma lista de participantes

El anfitrión es la única fuente de verdad de quién está en la sala (es
quien acepta las conexiones). Para que los participantes también vean
la lista completa (no sólo "yo estoy conectado"), el anfitrión
sincroniza la lista completa a todos cada vez que cambia, vía
`MessageType.roster` — un mensaje de control (no aparece en ningún
chat) que cada `ParticipantRoomSession` decodifica para alimentar su
propio `membersStream`.

## Cierre de sala vs. corte de conexión

- **El anfitrión finaliza la sala** (`finishRoom`): manda
  `MessageType.roomClosed` a todos antes de cerrar los sockets. Cada
  participante lo recibe, pasa a `ConnectionStatus.closedByHost` y ve
  un diálogo claro — no un error de red.
- **Se corta solo** (wifi, anfitrión que se cuelga sin avisar): el
  participante pasa a `reconnecting`, reintenta conectarse al mismo
  `host:puerto` unas cuantas veces con backoff, y si no lo logra pasa a
  `lost` con una pantalla para volver al inicio.
- **Un participante se va o se cae**: el anfitrión lo detecta por el
  cierre del socket, lo saca de `members` y vuelve a sincronizar el
  roster — no requiere ningún mensaje explícito del que se va (cubre
  tanto la salida voluntaria como una desconexión abrupta).

## Fuera de alcance en esta etapa (documentado a propósito)

- **Reconexión con historial retenido en el anfitrión**: si un
  participante se cae y vuelve a entrar, hoy entra como un miembro
  nuevo (nuevo `senderId` si usa "Unirme a una sala" de nuevo) — no hay
  sesión persistente del lado del anfitrión. Alcanza para esta etapa
  porque el reintento automático (mismo `senderId`, mismo socket)
  cubre el caso más común (corte breve de wifi).
- **Estado de presencia fino para participantes vistos por otros**
  (🟡 reconectando de un tercero): el roster es binario (está o no
  está). El indicador de 🟡/🔴 se implementó para la conexión **propia**
  del dispositivo, no para la de los demás.
