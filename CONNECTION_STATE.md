# Estado de conexión

## Por qué dos enums y no uno

`ConnectionStatus` (`core/network/chat_client_connection.dart`) es la
máquina de estados **dura**: `connected` / `reconnecting` / `lost` /
`closedByHost`. Es lo que efectivamente gobierna el comportamiento de
red (cuándo reintentar, cuándo buscar por código, cuándo rendirse) —
vive en la capa de transporte porque de ahí sale.

`ConnectionPhase` (`features/room/domain/connection_phase.dart`) es la
traducción **de presentación**, con dos estados más de los que
`ConnectionStatus` puede expresar por sí solo:

```
preparing · connecting · connected · unstable · reconnecting · lost · restored
```

- `preparing`/`connecting` no vienen de ningún stream — son estados
  locales de `CreateRoomScreen`/`JoinRoomScreen` mientras todavía no
  existe una sesión (armando el servidor / resolviendo el código).
- `unstable` no es un estado de `ConnectionStatus`: se calcula aparte,
  a partir del latido (ver abajo), mientras el status sigue siendo
  `connected` — el socket sigue técnicamente abierto, pero hace rato
  que no se ve tráfico del anfitrión.
- `restored` es transitorio: se emite una vez al volver a `connected`
  desde cualquier estado degradado, y se asienta solo a `connected`
  después de unos segundos (`ConnectionPhaseTracker`).

## Latido (por qué hace falta uno)

TCP no avisa una degradación de red a tiempo — en redes móviles/Wi-Fi
el keepalive del sistema operativo puede tardar minutos en notar que
la otra punta ya no está. Por eso el anfitrión (`ChatHostServer`)
manda un `MessageType.presence` a todos cada 4s
(`ChatHostServer.heartbeatInterval`), y cada `ChatClientConnection`
lleva la marca de tiempo del último tráfico visto (latido u otro
mensaje cualquiera). Si pasan más de 9s sin nada
(`_staleThreshold`, más del doble del intervalo, para tolerar un
latido perdido sin falso positivo), se marca `healthy = false` —eso es
lo que `ConnectionPhaseTracker` traduce a `unstable`, con un debounce
de 1.2s extra para no parpadear por una ráfaga de silencio de un solo
tick.

El latido es efímero a propósito: nunca entra al log de mensajes ni
genera ningún aviso visible por sí mismo (ver `ChatClientConnection._onRaw`).

## `ConnectionPhaseTracker`

Una instancia por `RoomSession` activa, construida donde haga falta
mostrar el estado (`RoomShellScreen`, `ChatThreadScreen`,
`ConnectionBanner`) — no hay una única instancia global compartida,
pero sí una única *fuente de verdad* (los streams del `RoomSession`);
cada tracker sólo deriva presentación a partir de esos streams, nunca
duplica lógica de red.

Reglas de debounce:

- `unstable` requiere 1.2s sostenidos de `healthy = false` antes de
  mostrarse (evita verde→amarillo→verde por una ráfaga).
- `restored` se muestra 4s y se asienta solo a `connected`.
- `reconnecting`/`lost` se muestran inmediatamente — ya vienen
  debounceados por el propio mecanismo de reintento (no hay reintento
  hasta agotar varios intentos directos).

## Franja global (`ConnectionBanner`)

Montada una sola vez en `main.dart` vía `MaterialApp.builder`, por
encima de todo el `Navigator` — así se ve en Inicio, Lobby,
Participantes o cualquier chat sin que cada pantalla tenga que
suscribirse a nada. Se guía por `ActiveRoomRegistry.current`: si hay
una sala activa, arma su propio `ConnectionPhaseTracker` y muestra una
franja flotante arriba de todo sólo para los estados que ameritan
avisar (`unstable`, `reconnecting`, `lost`, `restored`) — `connected`
normal no genera ruido visual permanente.

El feedback de "recién conectado" (✓ Conectado a "Familia", sección 7
del brief) es un `SnackBar` puntual que dispara `RoomShellScreen` la
primera vez que entra ya conectado — no la franja global, que está
pensada para avisos que importan estando en *cualquier* pantalla, no
sólo al entrar.

## Qué no hace

- No sustituye los diálogos dedicados (p. ej. "la sala fue
  finalizada", que sigue siendo un `AlertDialog` explícito en
  `RoomShellScreen` — `closedByHost` no pasa por la franja).
- No mide señal real (RSSI/latencia) — el semáforo de la conexión
  **propia** sale de `ConnectionStatus` + el latido, nunca de un
  número inventado (ver "Señal: honesta, no simulada" en
  `PRODUCT_FLOW.md`).
