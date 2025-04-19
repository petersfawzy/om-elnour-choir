package com.egypt.redcherry.omelnourchoir

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothHeadset
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val APP_CHANNEL = "com.egypt.redcherry.omelnourchoir/app"
    private val SHARE_CHANNEL = "com.egypt.redcherry.omelnourchoir/share"
    private val HEADPHONE_EVENTS_CHANNEL = "com.egypt.redcherry.omelnourchoir/headphone_events"
    
    private var headsetPlugReceiver: BroadcastReceiver? = null
    private lateinit var methodChannel: MethodChannel
    private lateinit var shareChannel: MethodChannel
    private var headphoneEventSink: EventChannel.EventSink? = null
    
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
                    val isHeadphoneConnected = audioManager.isWiredHeadsetOn || isBluetoothHeadsetConnected()
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
        
        // إعداد قناة الأحداث لمراقبة تغييرات حالة السماعات
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, HEADPHONE_EVENTS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    headphoneEventSink = events
                    registerHeadsetPlugReceiver()
                }
                
                override fun onCancel(arguments: Any?) {
                    unregisterHeadsetPlugReceiver()
                    headphoneEventSink = null
                }
            }
        )
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
        // إلغاء تسجيل المستقبل القديم إذا كان موجودًا
        unregisterHeadsetPlugReceiver()
        
        headsetPlugReceiver = HeadphoneStateReceiver { isConnected, isRemoved ->
            activity?.runOnUiThread {
                if (isRemoved) {
                    headphoneEventSink?.success("removed")
                } else {
                    headphoneEventSink?.success(if (isConnected) "connected" else "disconnected")
                }
            }
        }
        
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_HEADSET_PLUG)
            addAction(BluetoothHeadset.ACTION_CONNECTION_STATE_CHANGED)
            addAction("android.bluetooth.headset.profile.action.AUDIO_STATE_CHANGED")
        }
        
        context.registerReceiver(headsetPlugReceiver, filter)
        println("✅ تم تسجيل مستقبل حالة السماعات")
    }
    
    private fun unregisterHeadsetPlugReceiver() {
        if (headsetPlugReceiver != null) {
            try {
                context.unregisterReceiver(headsetPlugReceiver)
                println("✅ تم إلغاء تسجيل مستقبل حالة السماعات")
            } catch (e: Exception) {
                println("⚠️ خطأ في إلغاء تسجيل مستقبل حالة السماعات: ${e.message}")
            }
            headsetPlugReceiver = null
        }
    }
    
    private fun isBluetoothHeadsetConnected(): Boolean {
        val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter() ?: return false
        return bluetoothAdapter.isEnabled && 
               bluetoothAdapter.getProfileConnectionState(BluetoothProfile.HEADSET) == BluetoothProfile.STATE_CONNECTED
    }
    
    override fun onDestroy() {
        // إلغاء تسجيل مستقبل البث عند تدمير النشاط
        unregisterHeadsetPlugReceiver()
        super.onDestroy()
    }
}
