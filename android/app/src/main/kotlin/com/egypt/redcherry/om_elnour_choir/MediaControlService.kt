package com.egypt.redcherry.omelnourchoir

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log

class MediaControlService : Service() {
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.getStringExtra("action")
        
        Log.d("MediaControlService", "تم استلام أمر التحكم: $action")
        
        when (action) {
            "PLAY_PAUSE" -> {
                Log.d("MediaControlService", "إرسال أمر التشغيل/الإيقاف إلى Flutter")
                sendToFlutter("playPause")
            }
            "PLAY" -> {
                Log.d("MediaControlService", "إرسال أمر التشغيل إلى Flutter")
                sendToFlutter("play")
            }
            "PAUSE" -> {
                Log.d("MediaControlService", "إرسال أمر الإيقاف المؤقت إلى Flutter")
                sendToFlutter("pause")
            }
            "NEXT" -> {
                Log.d("MediaControlService", "إرسال أمر التالي إلى Flutter")
                sendToFlutter("next")
            }
            "PREVIOUS" -> {
                Log.d("MediaControlService", "إرسال أمر السابق إلى Flutter")
                sendToFlutter("previous")
            }
            "STOP" -> {
                Log.d("MediaControlService", "إرسال أمر الإيقاف إلى Flutter")
                sendToFlutter("stop")
            }
            "FAST_FORWARD" -> {
                Log.d("MediaControlService", "إرسال أمر التقديم السريع إلى Flutter")
                sendToFlutter("fastForward")
            }
            "REWIND" -> {
                Log.d("MediaControlService", "إرسال أمر الترجيع إلى Flutter")
                sendToFlutter("rewind")
            }
        }
        
        return START_NOT_STICKY
    }
    
    private fun sendToFlutter(command: String) {
        // سيتم تنفيذ هذا عندما يكون Flutter engine متاحًا
        // في الوقت الحالي، سنعتمد على AudioService للتعامل مع أوامر الوسائط
        Log.d("MediaControlService", "أمر الوسائط: $command")
    }
}
