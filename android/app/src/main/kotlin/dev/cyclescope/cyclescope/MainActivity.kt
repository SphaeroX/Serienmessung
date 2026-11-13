package dev.cyclescope.cyclescope

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var captureKeys = false
    private var keySink: EventChannel.EventSink? = null
    private var actionSink: EventChannel.EventSink? = null
    private var frameDecoder: FrameDecoder? = null

    private val actionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                ACTION_NEXT -> actionSink?.success("next")
                ACTION_TOGGLE -> actionSink?.success("toggle")
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val filter = IntentFilter().apply {
            addAction(ACTION_NEXT)
            addAction(ACTION_TOGGLE)
        }
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(actionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(actionReceiver, filter)
        }
    }

    override fun onDestroy() {
        unregisterReceiver(actionReceiver)
        frameDecoder?.dispose()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "dev.cyclescope/platform").setMethodCallHandler { call, result ->
            when (call.method) {
                "setKeyCapture" -> {
                    captureKeys = call.arguments as? Boolean ?: false
                    result.success(null)
                }
                "elapsedRealtimeMicros" ->
                    result.success(SystemClock.elapsedRealtimeNanos() / 1000)
                "showRecordingNotification" -> {
                    @Suppress("UNCHECKED_CAST")
                    showRecordingNotification(call.arguments as Map<String, Any?>)
                    result.success(null)
                }
                "hideRecordingNotification" -> {
                    notificationManager().cancel(NOTIFICATION_ID)
                    result.success(null)
                }
                "openUrl" -> result.success(openUrl(call.arguments as? String))
                else -> result.notImplemented()
            }
        }

        frameDecoder = FrameDecoder().also {
            MethodChannel(messenger, "dev.cyclescope/frames").setMethodCallHandler(it)
        }

        EventChannel(messenger, "dev.cyclescope/keys").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    keySink = events
                }

                override fun onCancel(arguments: Any?) {
                    keySink = null
                }
            }
        )

        EventChannel(messenger, "dev.cyclescope/notification_actions").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    actionSink = events
                }

                override fun onCancel(arguments: Any?) {
                    actionSink = null
                }
            }
        )
    }

    /** Captures volume keys while recording so they don't change the volume. */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val code = event.keyCode
        val isVolume = code == KeyEvent.KEYCODE_VOLUME_UP || code == KeyEvent.KEYCODE_VOLUME_DOWN
        val sink = keySink
        if (captureKeys && isVolume && sink != null) {
            val isDown = event.action == KeyEvent.ACTION_DOWN
            val isUp = event.action == KeyEvent.ACTION_UP
            if ((isDown && event.repeatCount == 0) || isUp) {
                // eventTime is in the uptimeMillis base; send the event's age.
                val ageMicros = (SystemClock.uptimeMillis() - event.eventTime) * 1000
                sink.success(
                    mapOf(
                        "key" to if (code == KeyEvent.KEYCODE_VOLUME_UP) "up" else "down",
                        "action" to if (isDown) "down" else "up",
                        "ageMicros" to ageMicros,
                    )
                )
            }
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    /** Opens an https link in the browser; false when no app can handle it. */
    private fun openUrl(url: String?): Boolean {
        val uri = url?.let(Uri::parse) ?: return false
        if (uri.scheme != "https") return false
        return try {
            startActivity(Intent(Intent.ACTION_VIEW, uri).addCategory(Intent.CATEGORY_BROWSABLE))
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    private fun notificationManager() =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    /**
     * Ongoing notification with a live chronometer. The chronometer runs from
     * the given elapsed time, so no background code is needed to keep it
     * ticking; the recording state itself is persisted on the Dart side.
     */
    private fun showRecordingNotification(args: Map<String, Any?>) {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
            return
        }
        val manager = notificationManager()
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Recording", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val running = args["running"] as? Boolean ?: false
        val elapsedMs = (args["elapsedMs"] as? Number)?.toLong() ?: 0L
        val flags = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        val open = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            flags,
        )
        fun action(name: String, code: Int) = PendingIntent.getBroadcast(
            this, code, Intent(name).setPackage(packageName), flags,
        )
        val builder = Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(args["title"] as? String ?: "")
            .setContentText(args["text"] as? String ?: "")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(open)
            .setCategory(Notification.CATEGORY_STOPWATCH)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .addAction(
                Notification.Action.Builder(
                    null, args["toggleLabel"] as? String ?: "Stop", action(ACTION_TOGGLE, 2),
                ).build()
            )
        if (running) {
            builder.addAction(
                Notification.Action.Builder(
                    null, args["nextLabel"] as? String ?: "Next", action(ACTION_NEXT, 1),
                ).build()
            )
            builder.setUsesChronometer(true)
                .setShowWhen(true)
                .setWhen(System.currentTimeMillis() - elapsedMs)
        } else {
            builder.setShowWhen(false)
        }
        manager.notify(NOTIFICATION_ID, builder.build())
    }

    companion object {
        private const val CHANNEL_ID = "recording"
        private const val NOTIFICATION_ID = 1001
        private const val ACTION_NEXT = "dev.cyclescope.action.NEXT"
        private const val ACTION_TOGGLE = "dev.cyclescope.action.TOGGLE"
    }
}
