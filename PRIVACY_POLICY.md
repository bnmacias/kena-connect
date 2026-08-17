# Política de privacidad de Kena Connect

*Última actualización: 13 de agosto de 2026.*

Kena Connect es una app para chatear con dispositivos cercanos a
través de una red local temporal, sin necesidad de Internet ni datos
móviles. No tiene servidor propio, no requiere cuenta, y no comparte
información con terceros.

## Qué datos maneja Kena

- **Nombre y avatar (Mi perfil)**: se guardan únicamente en tu
  dispositivo (`shared_preferences`), para no tener que volver a
  escribirlos cada vez que creás o te unís a una sala. Nunca salen de
  tu dispositivo salvo que vos los compartas al unirte a una sala (ahí
  los ven los demás participantes de esa sala, como corresponde a un
  chat).
- **Mensajes de chat (general y privados)**: viajan únicamente entre
  los dispositivos conectados a la misma sala, sobre la red local que
  arma esa sala. Kena no tiene ningún servidor intermedio que los
  reciba, procese o almacene — técnicamente no es posible porque no
  existe tal servidor.
- **Historial de salas recientes**: un registro liviano (nombre de la
  sala + fecha) que vive sólo en tu dispositivo, para mostrar la
  sección "Recientes" en Inicio. No incluye contenido de los chats.

Kena **no** recolecta analítica de uso, **no** usa rastreadores de
terceros, y **no** vende ni comparte datos con nadie.

## Permisos que pide la app y por qué

| Permiso | Para qué |
|---|---|
| Ubicación (`ACCESS_FINE_LOCATION`) / dispositivos cercanos (`NEARBY_WIFI_DEVICES`) | Exigidos por Android para crear un punto de acceso Wi-Fi local cuando hace falta armar la red de una sala. Kena no calcula, guarda ni envía tu ubicación real. |
| Cámara | Sólo para escanear el código QR al unirte a una sala. No se guarda ninguna imagen. |
| Notificaciones / vibración | Para avisar de mensajes nuevos — se puede desactivar por sala. |
| Estado de la red / Internet | Android exige el permiso de Internet para cualquier conexión por socket, incluso una que nunca sale de la red local. Kena no usa datos móviles ni se conecta a servidores externos. |

## Menores de edad

Kena no está dirigida específicamente a menores de edad y no recolecta
intencionalmente información de menores.

## Cambios a esta política

Si esta política cambia, la nueva versión va a estar disponible en
este mismo documento con la fecha de actualización correspondiente.

## Contacto

Para preguntas sobre esta política, contactar al desarrollador de Kena
Connect.
