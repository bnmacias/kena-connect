# Migración automática de anfitrión

## El problema que resuelve

Antes de esta etapa, si el anfitrión desaparecía sin avisar (se le
apagó el teléfono, perdió la sala de la app, etc.), la sala terminaba
para todos: cada participante caía a `ConnectionStatus.lost` con un
botón para "volver al inicio". La única forma de continuar era que
alguien creara una sala nueva y compartiera un código nuevo. La
**transferencia manual** de anfitrión (ver `ARCHITECTURE.md`) resuelve
el caso de que el anfitrión se quiera ir voluntariamente, pero no el
de que se caiga de golpe.

Esto implementa el caso que faltaba: si el anfitrión se cae de golpe,
la sala **intenta seguir sola**, sin que nadie tenga que crear nada
nuevo ni volver a escanear un QR — secciones 24 a 27 del brief de
producto.

## Elección de sucesor: determinística, sin coordinación

Cada miembro tiene un `joinOrder` (asignado por el anfitrión al
conectarse, sincronizado a todos vía el roster de siempre —
`RosterMember.joinOrder` / `RoomMember.joinOrder`). La regla de
sucesión es:

> El participante no-anfitrión con el `joinOrder` más chico (el que
> lleva más tiempo en la sala) de la última lista de miembros conocida.

(`electStandby` en `features/room/domain/host_migration.dart`.)

Es determinística a propósito: cualquier dispositivo que haya visto el
mismo roster llega solo a la misma conclusión, sin necesidad de que
los participantes se coordinen entre sí (no hay forma de coordinarse
de todos modos — el anfitrión, que sería el árbitro natural, es
justamente el que desapareció).

## Qué pasa cuando el anfitrión se cae

Todo esto vive en `ResilientRoomSession`, que envuelve la
`ParticipantRoomSession` de cualquier dispositivo (no sólo la del
sucesor — todos la tienen, porque cualquiera podría llegar a serlo):

1. El corte se nota igual que siempre: `ChatClientConnection` pasa a
   `reconnecting` y reintenta el mismo `host:puerto` unas pocas veces
   (`_maxReconnectAttempts`, con backoff).
2. `ResilientRoomSession` espera 3s adicionales desde que ve
   `reconnecting` (para no reaccionar a un microcorte que la propia
   reconexión directa ya va a resolver) y recién ahí se pregunta si
   este dispositivo es el sucesor electo.
3. Si **no** lo es, no hace nada especial — sigue el flujo normal del
   punto 4.
4. Todo dispositivo (sea o no el sucesor) cuya reconexión directa se
   agota pasa a buscar la sala por su **código** en vez de rendirse
   (`ChatClientConnection._searchByCode`) — hasta 20 intentos con
   backoff, sondeando el descubrimiento UDP como si fuera la primera
   vez que se une. Esto por sí solo ya cubre "me alejé y volví"
   (sección 11 del brief) tanto como "el anfitrión cambió".
5. Si el dispositivo **es** el sucesor: antes de tomar acción, espera
   un jitter corto (250–750ms) y hace un sondeo propio por el mismo
   código ("escuchá antes de hablar"). Si encuentra que alguien ya está
   respondiendo con ese código (el anfitrión original en realidad
   seguía vivo — sólo se cortó ese socket puntual — u otro sucesor que
   se le adelantó), no hace nada: se pliega al flujo normal del punto
   4, y su propia búsqueda por código lo va a reconectar como a
   cualquiera.
6. Si nadie responde, el sucesor levanta su propio `ChatHostServer` +
   `HostDiscoveryResponder`, **reusando el mismo código** de sala (no
   uno nuevo) y el mismo nombre. Esto es lo que hace posible que el
   resto se reconecte solo en el punto 4: siguen buscando exactamente
   ese código.
7. `ResilientRoomSession` cambia por dentro de `ParticipantRoomSession`
   a `HostRoomSession` sin que la UI se entere — mismo
   `RoomShellScreen`, mismo historial de esta sesión (se acarrea el
   log de mensajes ya visto). El único indicio visible es la franja
   global pasando por "Reconectando…" y después "Conexión
   restablecida" (ver `CONNECTION_STATE.md`).

## Qué NO garantiza (documentado a propósito)

- **No hay verdadero consenso distribuido.** La prevención de "dos
  anfitriones simultáneos" es el "escuchá antes de hablar" del paso 5,
  no un protocolo de elección con quórum. Con el patrón de uso
  esperado (un puñado de dispositivos, un solo sucesor elegido de
  antemano) la ventana de colisión es muy chica, pero no es
  matemáticamente imposible: si el anfitrión original y el sucesor
  quedan aislados de red exactamente en el mismo instante y la red se
  recompone antes de que termine el sondeo del sucesor, podrían
  coexistir dos anfitriones con el mismo código por un rato. No se
  resolvió con un protocolo más pesado porque el caso común (corte real
  del anfitrión, o un blip de un participante cualquiera) ya queda
  cubierto de forma robusta, y complejizar más el protocolo no parecía
  justificado para el tamaño de sala esperado.
- **Un solo sucesor, no una cadena.** Si el sucesor elegido también
  está inalcanzable, la sala no sigue escalando al siguiente
  `joinOrder` — el resto termina en `lost` como antes. Cubre "caso
  donde queda un solo dispositivo" (sección 26) de la forma más simple
  posible: ese dispositivo, al no tener a nadie más en el roster no
  intenta convertirse en nada, y ve `lost` con el botón de siempre.
- **No hay continuidad de mensajes entre dispositivos.** El sucesor
  conserva su propio historial de esta sesión (lo que él vio antes de
  migrar), pero el resto no recibe un "backfill" de lo que se perdió
  mientras no había anfitrión — coherente con la limitación ya
  documentada de que Kena no persiste chat entre sesiones
  (`ROADMAP.md`).
- **La licencia/identidad del anfitrión original no se "recupera"
  automáticamente** si vuelve a aparecer — hoy simplemente se
  reconectaría como un participante más (mismo comportamiento que
  cualquier corte-y-vuelta). Ver sección 27 del brief: la arquitectura
  no ata la sala a un dispositivo físico, pero todavía no hay un
  concepto de "licencia" implementado (a propósito, fuera de alcance
  de esta etapa).

## Verificación

`test/host_migration_test.dart` prueba `electStandby` en aislamiento y
un escenario de punta a punta sobre sockets reales de loopback (sin
UI): anfitrión + 2 participantes reales, se mata el anfitrión sin
avisar, y se verifica que (a) el standby efectivamente levanta un
nuevo `ChatHostServer` con el mismo código y (b) el otro participante
se reconecta solo, sin ninguna intervención manual. No se pudo probar
en dispositivos Android reales ni en el emulador en este entorno de
desarrollo (no había ninguno disponible) — recomendado antes de
publicar.
