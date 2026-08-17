# Firma de release

`kena-release-key.jks` + `key.properties` (los dos en esta carpeta,
`android/`) son la identidad criptográfica de Kena Connect para
publicar actualizaciones. **Ninguno de los dos se sube al repositorio**
(están en `.gitignore`) — si se pierden, no hay forma de recuperarlos
ni de reconstruirlos: cualquier actualización futura de la app
necesita estar firmada con esta misma clave, o Android la rechaza en
los dispositivos donde Kena ya esté instalado.

## Qué hacer AHORA

Guardá una copia de `kena-release-key.jks` y `key.properties` en un
lugar seguro y separado de esta máquina — un gestor de contraseñas,
un backup cifrado, algo así. Si esta carpeta se pierde sin backup,
se pierde la identidad de la app para siempre (no hay "recuperar
contraseña" para esto).

## Cómo se usa

`android/app/build.gradle.kts` lee `key.properties` automáticamente
si existe y firma los builds `release` con esa clave. Si el archivo no
está (por ejemplo, un checkout nuevo del repo sin el keystore todavía),
cae solo a la firma de debug — así `flutter build`/`flutter run` nunca
se rompen por esto, aunque el resultado no sirva para publicar.

```
flutter build apk --release
```

## Datos del certificado

- Alias: `kena`
- Validez: 10.000 días (~27 años) desde el 13/08/2026
- Algoritmo: RSA 2048
