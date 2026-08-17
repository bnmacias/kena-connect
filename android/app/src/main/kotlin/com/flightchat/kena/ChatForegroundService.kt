package com.flightchat.kena

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Servicio en primer plano vacío: no hace nada por sí mismo — sólo
 * mantiene con vida el proceso de la app (y con él, el motor de Flutter
 * y el socket del chat que ya administra el lado Dart) mientras haya una
 * sala activa. Sin esto, Android suspende el proceso a los pocos
 * segundos de bloquear la pantalla o mandar la app a segundo plano
 * (Doze / App Standby), cortando la conexión de hecho aunque el usuario
 * nunca haya salido de la sala — es lo que se veía como "se reconecta"
 * cada vez que se volvía a abrir Kena. El lado Dart vive en
 * `core/notifications/room_foreground_service.dart`.
 *
 * Notificación silenciosa, de prioridad mínima y separada del canal de
 * mensajes (`NotificationService`) a propósito: esto no es un aviso,
 * es el indicador exigido por Android para poder correr en primer plano.
 */
class ChatForegroundService : Service() {
    companion object {
        private const val CHANNEL_ID = "kena_connection_status"
        private const val NOTIFICATION_ID = 42
        const val EXTRA_ROOM_NAME = "roomName"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val roomName = intent?.getStringExtra(EXTRA_ROOM_NAME) ?: "tu sala"
        startForeground(NOTIFICATION_ID, buildNotification(roomName))
        // STICKY: si Android igual llega a matar el proceso por presión de
        // memoria, que lo reintente — más consistente con "seguí conectado
        // mientras la sala exista" que dejarlo apagado en silencio.
        return START_STICKY
    }

    private fun buildNotification(roomName: String): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Conexión de Kena",
                NotificationManager.IMPORTANCE_MIN,
            ).apply {
                description = "Se mantiene mientras estás en una sala — no son mensajes."
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Kena · $roomName")
            .setContentText("Conectado — tocá para volver a la sala.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setContentIntent(contentIntent)
            .build()
    }
}
