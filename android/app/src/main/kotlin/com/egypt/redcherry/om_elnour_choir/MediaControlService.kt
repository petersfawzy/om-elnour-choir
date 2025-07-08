package com.egypt.redcherry.omelnourchoir

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

class MediaControlService : Service() {

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.getStringExtra("action")

        Log.d("MediaControlService", "تم استلام أمر التحكم: $action")

        when (action) {
            "PLAY_PAUSE" -> sendToFlutter("playPause")
            "PLAY" -> sendToFlutter("play")
            "PAUSE" -> sendToFlutter("pause")
            "NEXT" -> sendToFlutter("next")
            "PREVIOUS" -> sendToFlutter("previous")
            "STOP" -> sendToFlutter("stop")
            "FAST_FORWARD" -> sendToFlutter("fastForward")
            "REWIND" -> sendToFlutter("rewind")
        }

        return START_NOT_STICKY
    }

    private fun sendToFlutter(command: String) {
        // حاول الحصول على FlutterEngine من الكاش
        val engine: FlutterEngine? = FlutterEngineCache.getInstance().get("main")
        if (engine != null) {
            MethodChannel(engine.dartExecutor, "com.egypt.redcherry.omelnourchoir/media_buttons")
                .invokeMethod("mediaAction", command)
            Log.d("MediaControlService", "تم إرسال أمر الوسائط إلى Flutter: $command")
        } else {
            Log.w("MediaControlService", "FlutterEngine غير متوفر، لم يتم إرسال الأمر: $command")
        }
    }
}
