package com.egypt.redcherry.omelnourchoir

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val APP_CHANNEL = "com.egypt.redcherry.omelnourchoir/app"
    private val SHARE_CHANNEL = "com.egypt.redcherry.omelnourchoir/share"
    private var headsetPlugReceiver: BroadcastReceiver? = null
    private lateinit var methodChannel: MethodChannel
    private lateinit var shareChannel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // قناة لتصغير التطبيق وحالة سماعات الرأس
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "moveTaskToBack" -> {
                    // تصغير التطبيق ليعمل في الخلفية
                    moveTaskToBack(true)
                    result.success(null)
                }
                "checkHeadphoneStatus" -> {
                    val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val isHeadphoneConnected = audioManager.isWiredHeadsetOn || audioManager.isBluetoothA2dpOn
                    result.success(isHeadphoneConnected)
                }
                else -> result.notImplemented()
            }
        }
        
        // قناة للمشاركة
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
        shareChannel.setMethodCallHandler { call, result ->
            if (call.method == "shareText") {
                try {
                    val text = call.argument<String>("text")
                    if (text != null) {
                        shareText(text)
                        result.success(true)
                    } else {
                        result.error("NULL_TEXT", "Text to share was null", null)
                    }
                } catch (e: Exception) {
                    result.error("SHARE_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
        
        // تسجيل مستقبل البث لمراقبة حالة سماعات الرأس
        registerHeadsetPlugReceiver()
    }
    
    // دالة لمشاركة النص
    private fun shareText(text: String) {
        try {
            val sendIntent: Intent = Intent().apply {
                action = Intent.ACTION_SEND
                putExtra(Intent.EXTRA_TEXT, text)
                type = "text/plain"
            }
            val shareIntent = Intent.createChooser(sendIntent, "مشاركة الآية")
            startActivity(shareIntent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    private fun registerHeadsetPlugReceiver() {
        headsetPlugReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action == Intent.ACTION_HEADSET_PLUG) {
                    val state = intent.getIntExtra("state", -1)
                    val isConnected = state == 1
                    methodChannel.invokeMethod("headphoneStateChanged", isConnected)
                }
            }
        }
        
        val filter = IntentFilter(Intent.ACTION_HEADSET_PLUG)
        context.registerReceiver(headsetPlugReceiver, filter)
    }
    
    override fun onDestroy() {
        // إلغاء تسجيل مستقبل البث عند تدمير النشاط
        if (headsetPlugReceiver != null) {
            context.unregisterReceiver(headsetPlugReceiver)
            headsetPlugReceiver = null
        }
        super.onDestroy()
    }
}
