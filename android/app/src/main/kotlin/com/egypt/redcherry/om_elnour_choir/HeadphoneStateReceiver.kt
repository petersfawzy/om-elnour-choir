package com.egypt.redcherry.omelnourchoir

import android.bluetooth.BluetoothHeadset
import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class HeadphoneStateReceiver() : BroadcastReceiver() {
    // لو محتاج callback استخدمه في حالة التسجيل الديناميكي فقط
    var callback: ((Boolean, Boolean) -> Unit)? = null

    constructor(callback: (Boolean, Boolean) -> Unit) : this() {
        this.callback = callback
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        Log.d("HeadphoneStateReceiver", "تم استلام حدث: ${intent?.action}")

        when (intent?.action) {
            Intent.ACTION_HEADSET_PLUG -> {
                val state = intent.getIntExtra("state", -1)
                val isConnected = state == 1
                Log.d("HeadphoneStateReceiver", "حالة السماعة السلكية: ${if (isConnected) "متصلة" else "منفصلة"}")
                callback?.invoke(isConnected, false)
            }
            BluetoothHeadset.ACTION_CONNECTION_STATE_CHANGED -> {
                val state = intent.getIntExtra(BluetoothProfile.EXTRA_STATE, BluetoothProfile.STATE_DISCONNECTED)
                val isConnected = state == BluetoothProfile.STATE_CONNECTED
                Log.d("HeadphoneStateReceiver", "حالة السماعة اللاسلكية: ${if (isConnected) "متصلة" else "منفصلة"}")
                callback?.invoke(isConnected, false)
            }
            "android.bluetooth.headset.profile.action.AUDIO_STATE_CHANGED" -> {
                val state = intent.getIntExtra(BluetoothProfile.EXTRA_STATE, BluetoothProfile.STATE_DISCONNECTED)
                val isConnected = state == BluetoothProfile.STATE_CONNECTED
                Log.d("HeadphoneStateReceiver", "تغيير حالة صوت البلوتوث: ${if (isConnected) "متصل" else "منفصل"}")
                callback?.invoke(isConnected, state == BluetoothProfile.STATE_DISCONNECTED)
            }
        }
    }
}
