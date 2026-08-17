package com.flightchat.kena

import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Puente nativo mínimo de Kena. Se intentó en su momento que la app
 * armara y se uniera a una Zona Wi-Fi por su cuenta (crear un hotspot
 * local, unirse a él sin pedir contraseña) — Android lo rechaza en la
 * práctica en la mayoría de los dispositivos reales (permisos exigidos
 * de forma inconsistente entre fabricantes/versiones). Se abandonó esa
 * vía; el código queda archivado en `archive/auto_wifi_attempt/` por si
 * alguna vez se retoma. Lo único que queda del lado nativo:
 *
 * - `kena/foreground_service`: mantener vivo el proceso mientras hay una
 *   sala activa (`ChatForegroundService`, ver
 *   `core/notifications/room_foreground_service.dart`).
 * - `kena/system_settings`: abrir la pantalla de Ajustes de red del
 *   sistema como atajo para la guía manual de Zona Wi-Fi (ver
 *   `core/utils/system_settings.dart`, `widgets/wifi_setup_guide.dart`).
 */
class MainActivity : FlutterActivity() {
    private val foregroundChannelName = "kena/foreground_service"
    private val systemSettingsChannelName = "kena/system_settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, foregroundChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val roomName = call.argument<String>("roomName") ?: "tu sala"
                        val intent = Intent(this, ChatForegroundService::class.java)
                            .putExtra(ChatForegroundService.EXTRA_ROOM_NAME, roomName)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    "stop" -> {
                        stopService(Intent(this, ChatForegroundService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, systemSettingsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openWirelessSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_WIRELESS_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
