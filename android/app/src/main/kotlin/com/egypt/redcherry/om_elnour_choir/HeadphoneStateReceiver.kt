package com.egypt.redcherry.omelnourchoir

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothHeadset
import android.util.Log

class HeadphoneStateReceiver(private val callback: (Boolean, Boolean) -> Unit) : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "HeadphoneStateReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        
        when (action) {
            // تغيير حالة سماعات الرأس السلكية
            Intent.ACTION_HEADSET_PLUG -> {
                val state = intent.getIntExtra("state", -1)
                val isConnected = state == 1
                
                Log.d(TAG, "سماعات الرأس السلكية: ${if (isConnected) "متصلة" else "غير متصلة"}")
                callback(isConnected, false)
            }
            
            // تغيير حالة سماعات البلوتوث
            BluetoothHeadset.ACTION_CONNECTION_STATE_CHANGED -> {
                val state = intent.getIntExtra(BluetoothProfile.EXTRA_STATE, -1)
                val isConnected = state == BluetoothProfile.STATE_CONNECTED
                
                Log.d(TAG, "سماعات البلوتوث: ${if (isConnected) "متصلة" else "غير متصلة"}")
                callback(isConnected, false)
            }
            
            // اكتشاف إزالة سماعات الأذن (بعض سماعات البلوتوث المتقدمة)
            "android.bluetooth.headset.profile.action.AUDIO_STATE_CHANGED" -> {
                val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                val state = intent.getIntExtra(BluetoothHeadset.EXTRA_STATE, -1)
                
                // بعض سماعات البلوتوث ترسل إشارة عند إزالتها من الأذن
                if (device != null && state == 0) {
                    Log.d(TAG, "تم اكتشاف إزالة سماعات البلوتوث من الأذن")
                    callback(true, true) // متصلة ولكن تمت إزالتها
                }
            }
        }
    }
}
