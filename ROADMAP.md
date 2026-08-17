# Roadmap

## Etapa actual (connection experience + reliability + UX) — completa

Sobre la base de la etapa anterior (sala como entidad central), esta
etapa agregó la capa de confiabilidad/UX de conexión que faltaba:

- [x] Estado global de conexión (7 fases: preparando/conectando/
  conectado/inestable/reconectando/perdido/restablecido), con franja
  visible desde cualquier pantalla — ver `CONNECTION_STATE.md`
- [x] Latido propio (no depender sólo del timeout de TCP) para
  detectar degradación antes de un corte total
- [x] "Está escribiendo…" en General y en privados, con timeout de
  seguridad
- [x] Estado de entrega honesto por mensaje (enviando/enviado/error) +
  cola de reintento automático — corrige un bug real donde mandar un
  mensaje sin conexión lo hacía desaparecer sin aviso
- [x] **Migración automática de anfitrión**: si el anfitrión desaparece
  sin avisar, la sala intenta seguir sola (mismo código, sin que nadie
  tenga que volver a unirse a mano) — ver `HOST_MIGRATION.md`.
  Verificado de punta a punta con una prueba automatizada sobre
  sockets reales (`test/host_migration_test.dart`)
- [x] Preparación de red antes de crear una sala: detecta Wi-Fi/
  Ethernet (incluida la propia Zona Wi-Fi del dispositivo, que
  `connectivity_plus` no ve por sí solo) y, si no hay ninguna red,
  muestra una guía paso a paso para activarla a mano (`WifiSetupGuide`)
  con un atajo a Ajustes de red — sondea en segundo plano y retoma la
  creación de la sala sola en cuanto detecta que ya hay red. Se intentó
  que la app creara el punto de acceso automáticamente
  (`WifiManager.startLocalOnlyHotspot`), pero se abandonó: en
  dispositivos reales el sistema rechazó el pedido de forma persistente
  pese a los permisos correctos — ver "Por qué es manual y no
  automático" en `ARCHITECTURE.md`. Código archivado en
  `archive/auto_wifi_attempt/`.
- [x] Timeout de conexión (8s): corrige un bug real reportado por uso
  — reconectarse justo después de salir de una sala podía dejar
  "Unirme a una sala" congelada esperando una respuesta que nunca
  llegaba. Ver `test/connection_timeout_test.dart`.
- [x] Persistir el chat localmente (`ChatHistoryStore` +
  `NotifyingRoomSession`): el log de la sala se guarda en el
  dispositivo y se restaura si volvés a entrar con el mismo código —
  ya no se pierde si la app se va a segundo plano y el sistema la
  mata. Guarda un solo snapshot (la última sala), no un historial de
  salas — coherente con que Kena no tiene "Mis salas".
- [x] Firma de release propia (`android/kena-release-key.jks`, nunca
  commiteada — ver `android/README_KEYSTORE.md`) en vez de la clave de
  debug.
- [x] "Privacidad" en Configuración: pasó de "Próximamente" a una
  pantalla real explicando qué permisos pide Kena y por qué, más
  `PRIVACY_POLICY.md` en la raíz del repo (para hostear públicamente
  cuando haga falta publicar en una tienda de apps).

Fuera de esta etapa, documentado a propósito (ver "Decisiones de
scope" y `HOST_MIGRATION.md`): acuses de recibo reales
(entregado/leído), y reconectar automáticamente a otros dispositivos a
un punto de acceso nuevo creado durante una migración (frontera de
seguridad del propio SO — ningún dispositivo puede unir a otro a una
red sin su aprobación, no es algo que el código pueda resolver).

## Etapa anterior (sala como entidad central) — completa

Kena como red local temporal para mensajería, con Sala como entidad
central:

```
Abrir Kena → Crear/Unirme a una sala → Lobby → Participantes
→ Entrar a la sala → Bandeja (General + privados) → Notificaciones/no leídos
→ Salir / Cambiar de sala / Finalizar / Transferir anfitrión
```

- [x] Onboarding de 3 pasos en el primer uso (se puede saltar; no vuelve a aparecer)
- [x] Inicio con "Crear una sala" / "Unirme a una sala", sin jerga técnica
- [x] Card "Sala activa" en Inicio cuando el dispositivo sigue conectado a una sala
- [x] Sección "Recientes" en Inicio (hasta 4 salas, re-entrada con reconexión real) — ver decisión de scope abajo
- [x] Crear sala (nombre + tu nombre) → Lobby (código `KENA-XXXX`, QR, participantes en vivo)
- [x] Unirme a una sala (detección automática, código manual, QR)
- [x] Bandeja de la sala: General + una conversación por participante, con último mensaje y hora
- [x] Chat privado 1:1 entre participantes (sin crear una sala nueva), iniciable desde la bandeja o desde Participantes
- [x] Notificaciones locales + sonido + vibración + badge de no leídos por conversación, con "Silenciar notificaciones"
- [x] Lista de participantes con barras de señal honestas (ver decisión de scope) y transferencia de anfitrión directa desde la fila
- [x] "Configuración de la sala" (nombre, código/QR, silenciar, transferir, salir/cambiar/finalizar) consolidada en una pantalla
- [x] Salir de la sala / Cambiar de sala (participante); Finalizar sala / Transferir anfitrión (anfitrión), con confirmación
- [x] Estados de conexión propios: conectado / reconectando / conexión perdida / sala finalizada, con reintento automático
- [x] Mensajes de sistema en el chat distinguen primera unión ("se unió") de reconexión ("volvió a conectarse" / "se perdió la conexión con")
- [x] Hoja "Adjuntar" (Foto / Ubicación) — sólo UI, deshabilitada y marcada "Próximamente"
- [x] Layout maestro-detalle en pantallas anchas (tablet/desktop) para la bandeja
- [x] Mi perfil (nombre + avatar autoguardado), Configuración (categorías reales donde hay funcionalidad, "Próximamente" donde no)
- [x] Sistema de diseño "vidrio líquido" propio (`lib/theme/kena_colors.dart`, `lib/widgets/`) — dark-only, degradé teal→sky, blur reservado a botones primarios
- [x] Motor de networking (WebSocket + descubrimiento UDP) preservado — extendido mínimamente (privados, roster, cierre/transferencia de sala)

Explícitamente fuera de esta etapa (no implementado a propósito):
cuenta/login obligatorio, pagos, suscripciones, contenido multimedia,
otros servicios sobre la red local (archivos, fotos, música, video).

## Decisiones de scope (documentadas, no accidentes)

- **Transferencia de anfitrión no es una migración en vivo**: el
  sucesor arranca una sala nueva (mismo nombre, código distinto) y el
  resto tiene que volver a unirse a mano. Ver `ARCHITECTURE.md`.
- **"Recientes" en Inicio (reversión documentada)**: una etapa
  anterior de este mismo rediseño decidió explícitamente no mostrar
  historial de salas ("Mis salas"), por ser una sala una red temporal.
  El brief de diseño final pidió reincorporarlo, así que se
  implementó — reusando el mismo registro liviano que ya existía
  (`RoomHistoryStore`), mostrando sólo nombre + antigüedad relativa
  (nunca un estado de conexión inventado), y haciendo que tocar una
  fila dispare una reconexión real en vez de "reabrir" nada. Ver
  `PRODUCT_FLOW.md` → "Recientes en Inicio".
- **Renombrar una sala no es posible**: `RoomSession` no expone forma
  de cambiar `roomName` una vez creada la sala — cambiarlo implicaría
  decidir qué pasa con el código/QR ya compartido. "Configuración de
  la sala" muestra el nombre pero no lo edita.
- **Señal honesta, no simulada**: las barras de señal de un
  participante del roster son siempre 4 (fijo) porque no existe
  telemetría real de RSSI/latencia por dispositivo — inventar una
  variación más fina sería mentir. Sólo la conexión **propia** del
  dispositivo tiene una escala real, mapeada 1:1 desde
  `ConnectionStatus`.
- **Tema dark-only**: "Apariencia > Claro" en Mi perfil es un preview
  deshabilitado de algo futuro, no una opción funcional — no se
  implementó un tema claro completo en esta etapa.
- **Reconexión** es "mismo dispositivo, mismo `senderId`, reintenta al
  mismo `host:puerto`" — no hay sesión persistente del lado del
  anfitrión que permita "volver a entrar" reteniendo un lugar
  reservado.
- **Presencia de terceros** es binaria (está o no está en el roster) —
  el semáforo 🟢/🟡/🔴 fino es para la conexión **propia** del
  dispositivo, no para la de los demás participantes.
- **Notificaciones son 100% locales**: no hay servidor remoto ni push
  real — se disparan a partir de mensajes que ya llegaron por la
  conexión de la sala. No suenan por mensajes que el dispositivo no
  recibió (por ejemplo, app cerrada del todo, no sólo en background).
- **Responsive**: sólo la bandeja/chat tiene un layout dedicado para
  pantallas anchas; el resto de las pantallas son de una columna
  centrada — se ven bien pero no aprovechan el espacio extra.
- **Migración automática de anfitrión no es consenso distribuido**: un
  solo sucesor predeterminado (`joinOrder` más bajo), con "escuchá
  antes de hablar" en vez de un protocolo de elección con quórum — ver
  `HOST_MIGRATION.md` para la ventana de colisión residual (chica,
  documentada, no eliminada del todo) y por qué no se justificaba un
  protocolo más pesado para el tamaño de sala esperado.
- **Sin acuses de recibo reales**: el estado de un mensaje propio
  (enviando/enviado/error) es honesto sobre lo que este dispositivo
  sabe, pero no hay "entregado"/"leído" — el protocolo no tiene acks
  de esa granularidad todavía (`MessageType.ack` existe pero no se usa
  con ese propósito).
- **Activación de hotspot automática: intentada y abandonada** — ver
  "Por qué es manual y no automático" en `ARCHITECTURE.md`. En
  dispositivos Android reales, `startLocalOnlyHotspot` rechazó el
  pedido de forma persistente (`SecurityException`) pese a los permisos
  correctos; no se aisló la causa exacta a tiempo como para justificar
  seguir insistiendo. Hoy Kena siempre pide activar la Zona Wi-Fi a
  mano (`WifiSetupGuide`), con detección automática de cuándo ya está
  lista. Código del intento archivado en `archive/auto_wifi_attempt/`.
- **Reconexión a un hotspot nuevo tras una migración: no automatizada,
  y no es posible automatizarla del todo**: si una migración de
  anfitrión (ver `HOST_MIGRATION.md`) termina creando un punto de
  acceso nuevo (porque la red dependía del anfitrión que desapareció),
  el resto del grupo tiene que reconectar su Wi-Fi a mano una vez — no
  hay forma de que un dispositivo una a otro a una red sin que su
  usuario lo apruebe, es una frontera de seguridad del sistema
  operativo. Tampoco se implementó todavía una forma de mostrar esas
  credenciales nuevas en la UI durante la migración (ver "Próximos
  pasos" abajo).

## Próximos pasos posibles

- Sincronizar historial de mensajes también para quien se une tarde.
- Persistir el chat localmente entre sesiones (hoy se pierde al salir).
- Badge en el ícono de la app (launcher), no sólo notificación.
- Cuenta Kena opcional y sincronización entre dispositivos.
- Otros servicios sobre la red local (archivos, fotos) — la
  arquitectura (`RoomSession`, protocolo con tipos de mensaje
  extensible) está pensada para no bloquearlo, no para tenerlo listo.
- Reforzar identidad visual con iconografía propia en vez de Material Icons.
- Retomar la activación automática de hotspot si en algún momento se
  quiere reintentar: el primer paso sería declarar `CHANGE_WIFI_STATE`
  en el manifest (candidato más probable, sin confirmar, de por qué
  `startLocalOnlyHotspot` rechazaba el pedido) — ver "Por qué es manual
  y no automático" en `ARCHITECTURE.md` y `archive/auto_wifi_attempt/`.
- Mostrar en la UI las credenciales de un hotspot nuevo creado durante
  una migración automática (SSID/contraseña, quizás como QR de "unirse
  a esta red"), para que reconectar manualmente sea un paso en vez de
  una explicación técnica — ver "Decisiones de scope" arriba.
- Sucesor de sucesor: si el elegido para continuar la sala también
  está inalcanzable, hoy la sala se pierde igual que antes — se podría
  encadenar al siguiente `joinOrder`.
