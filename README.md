# Kena Connect

**Conectados, incluso sin Internet.**

Kena Connect es una app de chat local para grupos que necesitan
comunicarse sin señal ni datos: aviones, cruceros, rutas de montaña,
campings, excursiones, eventos o cualquier lugar sin cobertura. Un
dispositivo crea una **sala** y los demás se suman desde la misma red
Wi-Fi local, sin que nadie tenga que entender cómo funciona por dentro.

No es una app exclusiva para vuelos — el avión es sólo uno de los casos
de uso posibles.

## Cómo se usa

1. **Crear una sala** — le ponés un nombre (ej. "Familia") y tu nombre.
   Se abre el lobby con un código (`KENA-XXXX`) y un QR para compartir.
2. **Unirme a una sala** — buscás salas cercanas automáticamente,
   ingresás el código a mano, o escaneás el QR de otro dispositivo.
3. **Dentro de la sala** — una bandeja con el chat General (todos lo
   ven) y una conversación privada por cada otro participante. Salís
   de la sala cuando quieras; el anfitrión puede finalizarla para todos.

No hace falta cuenta ni login para nada de esto — sólo un nombre. Mi
perfil y Configuración son accesibles desde el Inicio en cualquier
momento, que también recuerda las últimas salas a las que te sumaste
("Recientes") para volver a entrar más rápido.

La conexión se cuida sola: si alguien se aleja o el anfitrión pierde
señal, la app avisa con claridad y reintenta reconectar de forma
automática — y si el anfitrión desaparece de golpe, otro dispositivo
puede continuar la sala sin que nadie tenga que crear nada de nuevo
(ver [`CONNECTION_STATE.md`](CONNECTION_STATE.md) y
[`HOST_MIGRATION.md`](HOST_MIGRATION.md)).

La app nunca muestra IP, puerto, ni ningún concepto de red al usuario —
ver [`ARCHITECTURE.md`](ARCHITECTURE.md) para cómo se resuelve eso por
dentro, y [`PRODUCT_FLOW.md`](PRODUCT_FLOW.md) / [`DOMAIN_MODEL.md`](DOMAIN_MODEL.md)
para el detalle de producto y de dominio.

## Desarrollo

Proyecto Flutter estándar:

```
flutter pub get
flutter run
```

Ver [`ARCHITECTURE.md`](ARCHITECTURE.md) para la arquitectura y
[`ROADMAP.md`](ROADMAP.md) para el estado actual y los próximos pasos.
