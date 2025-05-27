package com.egypt.redcherry.omelnourchoir

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.view.KeyEvent
import android.util.Log

class MediaButtonReceiver : BroadcastReceiver() {
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("MediaButtonReceiver", "تم استلام أمر: ${intent.action}")
        
        when (intent.action) {
            Intent.ACTION_MEDIA_BUTTON -> {
                val event = intent.getParcelableExtra<KeyEvent>(Intent.EXTRA_KEY_EVENT)
                
                if (event != null && event.action == KeyEvent.ACTION_DOWN) {
                    when (event.keyCode) {
                        KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE -> {
                            Log.d("MediaButtonReceiver", "تم الضغط على زر التشغيل/الإيقاف")
                            sendMediaCommand(context, "playPause")
                        }
                        KeyEvent.KEYCODE_MEDIA_PLAY -> {
                            Log.d("MediaButtonReceiver", "تم الضغط على زر التشغيل")
                            sendMediaCommand(context, "play")
                        }
                        KeyEvent.KEYCODE_MEDIA_PAUSE -> {
                            Log.d("MediaButtonReceiver", "تم الضغط على زر الإيقاف المؤقت")
                            sendMediaCommand(context, "pause")
                        }
                        KeyEvent.KEYCODE_MEDIA_NEXT -> {
                            Log.d("MediaButtonReceiver", "تم الضغط على زر التالي")
                            sendMediaCommand(context, "next")
                        }
                        KeyEvent.KEYCODE_MEDIA_PREVIOUS -> {
                            Log.d("MediaButtonReceiver", "تم الضغط على زر السابق")
                            sendMediaCommand(context, "previous")
                        }
                        KeyEvent.KEYCODE_HEADSETHOOK -> {
                            Log.d("MediaButtonReceiver", "تم الضغط على زر السماعة")
                            sendMediaCommand(context, "playPause")
                        }
                        KeyEvent.KEYCODE_MEDIA_STOP -> {
                            Log.d("MediaButtonReceiver", "تم الضغط على زر الإيقاف")
                            sendMediaCommand(context, "stop")
                        }
                        KeyEvent.KEYCODE_MEDIA_FAST_FORWARD -> {
                            Log.d("MediaButtonReceiver", "تم الضغط على زر التقديم السريع")
                            sendMediaCommand(context, "fastForward")
                        }
                        KeyEvent.KEYCODE_MEDIA_REWIND -> {
                            Log.d("MediaButtonReceiver", "تم الضغط على زر الترجيع")
                            sendMediaCommand(context, "rewind")
                        }
                    }
                }
            }
            // التعامل مع الأوامر المخصصة من الإشعارات
            else -> {
                val mediaAction = intent.getStringExtra("media_action")
                if (mediaAction != null) {
                    Log.d("MediaButtonReceiver", "تم استلام أمر مخصص: $mediaAction")
                    sendMediaCommand(context, mediaAction)
                }
            }
        }
    }
    
    private fun sendMediaCommand(context: Context, action: String) {
        Log.d("MediaButtonReceiver", "معالجة أمر التحكم: $action")
        
        // إرسال الأمر مباشرة إلى MainActivity إذا كانت نشطة
        try {
            val broadcastIntent = Intent("com.egypt.redcherry.omelnourchoir.MEDIA_BUTTON")
            broadcastIntent.putExtra("action", action)
            context.sendBroadcast(broadcastIntent)
            Log.d("MediaButtonReceiver", "تم إرسال الأمر عبر Broadcast: $action")
        } catch (e: Exception) {
            Log.e("MediaButtonReceiver", "خطأ في إرسال الأمر: ${e.message}")
        }
    }
}
