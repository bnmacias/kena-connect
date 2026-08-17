# Intento de auto-wifi (archivado)

Código sacado de la app activa el 2026-08-14. Se intentó que Kena:

1. **Anfitrión**: creara su propia Zona Wi-Fi automáticamente al tocar
   "Crear sala" cuando no había ninguna red (`local_hotspot.dart` +
   el canal `kena/local_hotspot` de `MainActivity.kt`, sobre
   `WifiManager.startLocalOnlyHotspot`).
2. **Cliente**: se uniera solo a esa red al escanear el QR del
   anfitrión, sin pedir la contraseña a mano (`wifi_joiner.dart` +
   `join_link.dart` + el canal `kena/wifi_join`, sobre
   `WifiNetworkSpecifier`).

## Por qué se abandonó

En dispositivos Android reales, `startLocalOnlyHotspot` rechazó el
pedido de forma persistente con `SecurityException`, incluso después de
conceder el permiso de ubicación y de que un chequeo nativo confirmara
`ACCESS_FINE_LOCATION` concedido. No se aisló la causa exacta a tiempo.

**Candidato más probable, sin confirmar**: nunca se declaró
`android.permission.CHANGE_WIFI_STATE` en `AndroidManifest.xml` — es un
permiso normal (no requiere pedirlo en tiempo de ejecución) pero
Android igual lo exige para `startLocalOnlyHotspot`, además de
`ACCESS_FINE_LOCATION`. Sin él, la llamada nativa tira
`SecurityException` con un mensaje que, tal como estaba escrito el
catch original, se leía igual al de "falta permiso de ubicación" —
indistinguible desde la UI, lo que hizo perder tiempo insistiendo con
permisos de ubicación (precisión, `NEARBY_WIFI_DEVICES`, servicio de
Ubicación del sistema) sin que ninguno resolviera nada.

## Si se retoma algún día

1. Agregar `<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />`
   al manifest — primer paso, antes de tocar cualquier otra cosa.
2. Volver a probar en un dispositivo real (no alcanza con emulador: el
   hardware de Wi-Fi virtual de los AVD nunca completa el pedido, ver
   la nota de verificación que quedó en el historial de `ARCHITECTURE.md`).
3. Si sigue fallando, revisar restricciones específicas del fabricante
   (MIUI/Xiaomi, Samsung y similares suelen restringir
   `startLocalOnlyHotspot` más allá de lo que documenta AOSP).

Mientras tanto, Kena pide activar la Zona Wi-Fi a mano
(`widgets/wifi_setup_guide.dart`) y detecta sola cuándo ya está lista.
