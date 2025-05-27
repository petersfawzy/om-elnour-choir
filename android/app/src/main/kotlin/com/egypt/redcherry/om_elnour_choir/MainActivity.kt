package com.egypt.redcherry.omelnourchoir

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothHeadset
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.view.KeyEvent
import android.os.Bundle
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat as MediaNotificationCompat
import androidx.media.session.MediaButtonReceiver
import android.os.Build
import android.content.ComponentName
import android.support.v4.media.MediaMetadataCompat
import android.graphics.Bitmap
import android.graphics.BitmapFactory

class MainActivity : FlutterActivity() {
    private val APP_CHANNEL = "com.egypt.redcherry.omelnourchoir/app"
    private val SHARE_CHANNEL = "com.egypt.redcherry.omelnourchoir/share"
    private val HEADPHONE_EVENTS_CHANNEL = "com.egypt.redcherry.omelnourchoir/headphone_events"
    private val MEDIA_BUTTON_CHANNEL = "com.egypt.redcherry.omelnourchoir/media_buttons"
    
    private var headsetPlugReceiver: BroadcastReceiver? = null
    private lateinit var methodChannel: MethodChannel
    private lateinit var shareChannel: MethodChannel
    private lateinit var mediaButtonChannel: MethodChannel
    private var headphoneEventSink: EventChannel.EventSink? = null
    
    private var mediaSession: MediaSessionCompat? = null
    private var notificationManager: NotificationManager? = null
    private val NOTIFICATION_ID = 123
    private val CHANNEL_ID = "com.egypt.redcherry.omelnourchoir.channel.audio"
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        println("🎵 MainActivity تم إنشاؤها")
        setupMediaSessionAndNotification()
    }
    
    private fun setupMediaSessionAndNotification() {
        try {
            createNotificationChannel()
            
            // إنشاء MediaSession مع إعدادات محسنة
            val mediaButtonReceiver = ComponentName(this, MediaButtonReceiver::class.java)
            val mediaButtonIntent = Intent(Intent.ACTION_MEDIA_BUTTON)
            mediaButtonIntent.component = mediaButtonReceiver
            val pendingIntent = PendingIntent.getBroadcast(
                this, 0, mediaButtonIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            mediaSession = MediaSessionCompat(this, "OmElnourMediaSession", mediaButtonReceiver, pendingIntent).apply {
                setFlags(
                    MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or 
                    MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS
                )
                
                setCallback(object : MediaSessionCompat.Callback() {
                    override fun onPlay() {
                        println("▶️ MediaSession: تم الضغط على التشغيل")
                        sendMediaCommand("play")
                    }
                    
                    override fun onPause() {
                        println("⏸️ MediaSession: تم الضغط على الإيقاف المؤقت")
                        sendMediaCommand("pause")
                    }
                    
                    override fun onSkipToNext() {
                        println("⏭️ MediaSession: تم الضغط على التالي")
                        sendMediaCommand("next")
                    }
                    
                    override fun onSkipToPrevious() {
                        println("⏮️ MediaSession: تم الضغط على السابق")
                        sendMediaCommand("previous")
                    }
                    
                    override fun onStop() {
                        println("⏹️ MediaSession: تم الضغط على الإيقاف")
                        sendMediaCommand("stop")
                    }
                    
                    override fun onFastForward() {
                        println("⏩ MediaSession: تقديم سريع")
                        sendMediaCommand("fastForward")
                    }
                    
                    override fun onRewind() {
                        println("⏪ MediaSession: ترجيع")
                        sendMediaCommand("rewind")
                    }
                    
                    override fun onMediaButtonEvent(mediaButtonEvent: Intent?): Boolean {
                        println("🎵 MediaSession: تم استقبال زر وسائط")
                        return super.onMediaButtonEvent(mediaButtonEvent)
                    }
                })
                
                // تفعيل MediaSession فوراً
                isActive = true
                
                // تعيين حالة التشغيل الأولية
                setPlaybackState(
                    PlaybackStateCompat.Builder()
                        .setActions(
                            PlaybackStateCompat.ACTION_PLAY or
                            PlaybackStateCompat.ACTION_PAUSE or
                            PlaybackStateCompat.ACTION_PLAY_PAUSE or
                            PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                            PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                            PlaybackStateCompat.ACTION_STOP or
                            PlaybackStateCompat.ACTION_FAST_FORWARD or
                            PlaybackStateCompat.ACTION_REWIND
                        )
                        .setState(PlaybackStateCompat.STATE_STOPPED, 0, 1.0f)
                        .build()
                )
            }
            
            println("✅ تم إعداد MediaSession بنجاح")
            
        } catch (e: Exception) {
            println("❌ خطأ في إعداد MediaSession: ${e.message}")
        }
    }
    
    private fun createNotificationChannel() {
        try {
            notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "أم النور - تشغيل الترانيم",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "تشغيل ترانيم أم النور مع التحكم الكامل"
                    setSound(null, null)
                    enableVibration(false)
                    setShowBadge(false)
                    lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                }
                
                notificationManager?.createNotificationChannel(channel)
                println("✅ تم إنشاء قناة الإشعارات")
            }
        } catch (e: Exception) {
            println("❌ خطأ في إنشاء قناة الإشعارات: ${e.message}")
        }
    }
    
    fun showMediaNotification(title: String, isPlaying: Boolean, artworkUrl: String? = null) {
        try {
            println("🎵 عرض إشعار للترنيمة: $title")
            println("🖼️ رابط الصورة المستلم: ${artworkUrl ?: "لا توجد صورة"}")
            
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                this, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // إنشاء أزرار التحكم
            val playPauseIcon = if (isPlaying) {
                android.R.drawable.ic_media_pause
            } else {
                android.R.drawable.ic_media_play
            }
            val playPauseText = if (isPlaying) "إيقاف مؤقت" else "تشغيل"
            val playPauseAction = if (isPlaying) "pause" else "play"
            
            val previousAction = NotificationCompat.Action.Builder(
                android.R.drawable.ic_media_previous,
                "السابق",
                createMediaPendingIntent("previous")
            ).build()
            
            val playPauseActionBuilder = NotificationCompat.Action.Builder(
                playPauseIcon,
                playPauseText,
                createMediaPendingIntent(playPauseAction)
            ).build()
            
            val nextAction = NotificationCompat.Action.Builder(
                android.R.drawable.ic_media_next,
                "التالي",
                createMediaPendingIntent("next")
            ).build()
            
            // إنشاء الإشعار مع التحكم الكامل
            val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle(title)
                .setContentText("كورال أم النور")
                .setContentIntent(pendingIntent)
                .addAction(previousAction)
                .addAction(playPauseActionBuilder)
                .addAction(nextAction)
                .setStyle(
                    MediaNotificationCompat.MediaStyle()
                        .setMediaSession(mediaSession?.sessionToken)
                        .setShowActionsInCompactView(0, 1, 2)
                        .setShowCancelButton(true)
                        .setCancelButtonIntent(createMediaPendingIntent("stop"))
                )
                .setOngoing(isPlaying)
                .setShowWhen(false)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
                .setDeleteIntent(createMediaPendingIntent("stop"))
            
            // التحقق من وجود رابط صورة صحيح
            if (!artworkUrl.isNullOrEmpty() && artworkUrl != "null" && artworkUrl.startsWith("http")) {
                println("🖼️ محاولة تحميل صورة الألبوم: $artworkUrl")
                
                // تحميل الصورة في thread منفصل
                Thread {
                    try {
                        val bitmap = loadImageFromUrl(artworkUrl)
                        if (bitmap != null) {
                            println("✅ تم تحميل صورة الألبوم بنجاح")
                            runOnUiThread {
                                notificationBuilder.setLargeIcon(bitmap)
                                val notification = notificationBuilder.build()
                                notificationManager?.notify(NOTIFICATION_ID, notification)
                                println("✅ تم عرض الإشعار مع صورة الألبوم")
                            }
                        } else {
                            println("❌ فشل في تحميل صورة الألبوم")
                            runOnUiThread {
                                val notification = notificationBuilder.build()
                                notificationManager?.notify(NOTIFICATION_ID, notification)
                                println("✅ تم عرض الإشعار بدون صورة")
                            }
                        }
                    } catch (e: Exception) {
                        println("❌ خطأ في تحميل صورة الألبوم: ${e.message}")
                        runOnUiThread {
                            val notification = notificationBuilder.build()
                            notificationManager?.notify(NOTIFICATION_ID, notification)
                        }
                    }
                }.start()
            } else {
                // عرض الإشعار بدون صورة
                val notification = notificationBuilder.build()
                notificationManager?.notify(NOTIFICATION_ID, notification)
                println("✅ تم عرض الإشعار بدون صورة (لا يوجد رابط صحيح)")
            }
            
        } catch (e: Exception) {
            println("❌ خطأ في عرض إشعار التحكم: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun loadImageFromUrl(url: String): Bitmap? {
        return try {
            println("🔄 محاولة تحميل الصورة من: $url")
            
            // التحقق من صحة الرابط أولاً
            if (url.isBlank() || !url.startsWith("http")) {
                println("❌ رابط غير صالح: $url")
                return null
            }
            
            val connection = java.net.URL(url).openConnection()
            connection.connectTimeout = 15000 // زيادة المهلة إلى 15 ثانية
            connection.readTimeout = 15000
            connection.doInput = true
            
            // إضافة User-Agent لتجنب الحظر
            connection.setRequestProperty("User-Agent", "Mozilla/5.0 (Android)")
            
            println("📡 محاولة الاتصال بالرابط...")
            connection.connect()
            
            val responseCode = if (connection is java.net.HttpURLConnection) {
                connection.responseCode
            } else -1
            
            println("📊 رمز الاستجابة: $responseCode")
            
            if (responseCode != -1 && responseCode != 200) {
                println("❌ رمز استجابة غير صحيح: $responseCode")
                return null
            }
            
            val inputStream = connection.getInputStream()
            println("📥 تم فتح InputStream بنجاح")
            
            val bitmap = BitmapFactory.decodeStream(inputStream)
            inputStream.close()
            
            if (bitmap != null) {
                println("✅ تم فك تشفير الصورة بنجاح: ${bitmap.width}x${bitmap.height}")
                
                // تصغير الصورة إذا كانت كبيرة جداً
                val maxSize = 512
                if (bitmap.width > maxSize || bitmap.height > maxSize) {
                    val ratio = Math.min(
                        maxSize.toFloat() / bitmap.width,
                        maxSize.toFloat() / bitmap.height
                    )
                    val width = (bitmap.width * ratio).toInt()
                    val height = (bitmap.height * ratio).toInt()
                    val resizedBitmap = Bitmap.createScaledBitmap(bitmap, width, height, true)
                    bitmap.recycle() // تحرير الذاكرة
                    println("🔄 تم تصغير الصورة إلى: ${width}x${height}")
                    resizedBitmap
                } else {
                    println("✅ الصورة بحجم مناسب: ${bitmap.width}x${bitmap.height}")
                    bitmap
                }
            } else {
                println("❌ فشل في فك تشفير الصورة")
                null
            }
        } catch (e: java.net.SocketTimeoutException) {
            println("⏰ انتهت مهلة تحميل الصورة: ${e.message}")
            null
        } catch (e: java.net.UnknownHostException) {
            println("🌐 خطأ في الشبكة أو DNS: ${e.message}")
            null
        } catch (e: java.io.IOException) {
            println("📡 خطأ في الإدخال/الإخراج: ${e.message}")
            null
        } catch (e: Exception) {
            println("❌ خطأ عام في تحميل الصورة: ${e.message}")
            e.printStackTrace()
            null
        }
    }
    
    private fun createMediaPendingIntent(action: String): PendingIntent {
        val intent = Intent(this, MediaButtonReceiver::class.java).apply {
            putExtra("media_action", action)
        }
        return PendingIntent.getBroadcast(
            this,
            action.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
    
    fun updatePlaybackState(isPlaying: Boolean, position: Long = 0L) {
        try {
            val state = if (isPlaying) {
                PlaybackStateCompat.STATE_PLAYING
            } else {
                PlaybackStateCompat.STATE_PAUSED
            }
            
            val playbackState = PlaybackStateCompat.Builder()
                .setActions(
                    PlaybackStateCompat.ACTION_PLAY or
                    PlaybackStateCompat.ACTION_PAUSE or
                    PlaybackStateCompat.ACTION_PLAY_PAUSE or
                    PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                    PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                    PlaybackStateCompat.ACTION_STOP or
                    PlaybackStateCompat.ACTION_FAST_FORWARD or
                    PlaybackStateCompat.ACTION_REWIND or
                    PlaybackStateCompat.ACTION_SEEK_TO
                )
                .setState(state, position, if (isPlaying) 1.0f else 0.0f)
                .build()
            
            mediaSession?.setPlaybackState(playbackState)
            println("✅ تم تحديث حالة التشغيل في MediaSession: ${if (isPlaying) "يعمل" else "متوقف"}, الموضع: ${position}ms")
            
        } catch (e: Exception) {
            println("❌ خطأ في تحديث حالة التشغيل: ${e.message}")
        }
    }
    
    fun keepNotificationVisible() {
        try {
            // الحفاظ على الإشعار مرئياً حتى أثناء تغيير الترانيم
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                this, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle("جاري التحميل...")
                .setContentText("كورال أم النور")
                .setContentIntent(pendingIntent)
                .setStyle(
                    MediaNotificationCompat.MediaStyle()
                        .setMediaSession(mediaSession?.sessionToken)
                        .setShowActionsInCompactView()
                        .setShowCancelButton(false)
                )
                .setOngoing(true)
                .setShowWhen(false)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
                .build()
            
            notificationManager?.notify(NOTIFICATION_ID, notification)
            println("✅ تم الحفاظ على الإشعار مرئياً أثناء التغيير")
            
        } catch (e: Exception) {
            println("❌ خطأ في الحفاظ على الإشعار: ${e.message}")
        }
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "moveTaskToBack" -> {
                    moveTaskToBack(true)
                    result.success(null)
                }
                "checkHeadphoneStatus" -> {
                    val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val isWiredConnected = audioManager.isWiredHeadsetOn
                    val isBluetoothConnected = isBluetoothHeadsetConnected()
                    val finalResult = isWiredConnected || isBluetoothConnected
                    result.success(finalResult)
                }
                "isSimulator" -> {
                    result.success(false)
                }
                "showMediaNotification" -> {
                    val title = call.argument<String>("title") ?: "ترنيمة"
                    val artist = call.argument<String>("artist") ?: "كورال أم النور"
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                    val position = (call.argument<Number>("position")?.toLong()) ?: 0L
                    val duration = (call.argument<Number>("duration")?.toLong()) ?: 0L
                    val artworkUrl = call.argument<String>("artworkUrl")
                    
                    showMediaNotification(title, isPlaying, artworkUrl)
                    updatePlaybackState(isPlaying, position)
                    result.success(true)
                }
                "updatePlaybackState" -> {
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                    val position = (call.argument<Number>("position")?.toLong()) ?: 0L
                    updatePlaybackState(isPlaying, position)
                    result.success(true)
                }
                "hideMediaNotification" -> {
                    notificationManager?.cancel(NOTIFICATION_ID)
                    result.success(true)
                }
                "updateNotificationState" -> {
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                    val position = (call.argument<Number>("position")?.toLong()) ?: 0L
                    updatePlaybackState(isPlaying, position)
                    result.success(true)
                }
                "enableMediaButtonReceiver" -> {
                    // تفعيل استقبال أوامر الوسائط
                    mediaSession?.isActive = true
                    result.success(true)
                }
                "keepNotificationVisible" -> {
                    keepNotificationVisible()
                    result.success(true)
                }
                "updateNotificationPosition" -> {
                    val position = (call.argument<Number>("position")?.toLong()) ?: 0L
                    val duration = (call.argument<Number>("duration")?.toLong()) ?: 0L
                    updateNotificationPosition(position, duration)
                    result.success(true)
                }
                "updateMediaMetadata" -> {
                    val title = call.argument<String>("title") ?: "ترنيمة"
                    val artist = call.argument<String>("artist") ?: "كورال أم النور"
                    val duration = (call.argument<Number>("duration")?.toLong()) ?: 0L
                    val artworkUrl = call.argument<String>("artworkUrl")
                    updateMediaMetadata(title, artist, duration, artworkUrl)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        
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
        
        mediaButtonChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_BUTTON_CHANNEL)
        
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
    
    private fun sendMediaCommand(command: String) {
        try {
            mediaButtonChannel.invokeMethod(command, null)
            println("✅ تم إرسال أمر التحكم: $command")
        } catch (e: Exception) {
            println("❌ خطأ في إرسال أمر التحكم $command: ${e.message}")
        }
    }
    
    private fun shareText(text: String) {
        try {
            val sendIntent = Intent().apply {
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
        unregisterHeadsetPlugReceiver()
        
        headsetPlugReceiver = HeadphoneStateReceiver { isConnected, isRemoved ->
            runOnUiThread {
                val status = when {
                    isRemoved -> "removed"
                    isConnected -> "connected"
                    else -> "disconnected"
                }
                headphoneEventSink?.success(status)
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
        headsetPlugReceiver?.let {
            try {
                context.unregisterReceiver(it)
                println("✅ تم إلغاء تسجيل مستقبل حالة السماعات")
            } catch (e: Exception) {
                println("⚠️ خطأ في إلغاء تسجيل مستقبل حالة السماعات: ${e.message}")
            }
            headsetPlugReceiver = null
        }
    }
    
    private fun isBluetoothHeadsetConnected(): Boolean {
        return try {
            val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
            if (bluetoothAdapter != null && bluetoothAdapter.isEnabled) {
                bluetoothAdapter.getProfileConnectionState(BluetoothProfile.HEADSET) == BluetoothProfile.STATE_CONNECTED
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }
    
    override fun onDestroy() {
        unregisterHeadsetPlugReceiver()
        mediaSession?.release()
        super.onDestroy()
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        println("🎵 تم الضغط على زر: $keyCode")
        
        return when (keyCode) {
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, KeyEvent.KEYCODE_HEADSETHOOK -> {
                println("⏯️ تم الضغط على زر التشغيل/الإيقاف")
                sendMediaCommand("playPause")
                true
            }
            KeyEvent.KEYCODE_MEDIA_PLAY -> {
                println("▶️ تم الضغط على زر التشغيل")
                sendMediaCommand("play")
                true
            }
            KeyEvent.KEYCODE_MEDIA_PAUSE -> {
                println("⏸️ تم الضغط على زر الإيقاف المؤقت")
                sendMediaCommand("pause")
                true
            }
            KeyEvent.KEYCODE_MEDIA_NEXT -> {
                println("⏭️ تم الضغط على زر التالي")
                sendMediaCommand("next")
                true
            }
            KeyEvent.KEYCODE_MEDIA_PREVIOUS -> {
                println("⏮️ تم الضغط على زر السابق")
                sendMediaCommand("previous")
                true
            }
            KeyEvent.KEYCODE_MEDIA_STOP -> {
                println("⏹️ تم الضغط على زر الإيقاف")
                sendMediaCommand("stop")
                true
            }
            KeyEvent.KEYCODE_MEDIA_FAST_FORWARD -> {
                println("⏩ تم الضغط على زر التقديم السريع")
                sendMediaCommand("fastForward")
                true
            }
            KeyEvent.KEYCODE_MEDIA_REWIND -> {
                println("⏪ تم الضغط على زر الترجيع")
                sendMediaCommand("rewind")
                true
            }
            else -> super.onKeyDown(keyCode, event)
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (Intent.ACTION_MEDIA_BUTTON == intent.action) {
            val keyEvent = intent.getParcelableExtra<KeyEvent>(Intent.EXTRA_KEY_EVENT)
            keyEvent?.let {
                if (it.action == KeyEvent.ACTION_DOWN) {
                    onKeyDown(it.keyCode, it)
                }
            }
        }
    }

    fun updateMediaMetadata(title: String, artist: String, duration: Long, artworkUrl: String?) {
        try {
            println("📝 تحديث metadata - Title: \"$title\", Artist: \"$artist\", Duration: ${duration}ms")
            
            val metadataBuilder = MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
                .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)
                .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, duration)
            
            if (!artworkUrl.isNullOrEmpty() && artworkUrl != "null") {
                metadataBuilder.putString(MediaMetadataCompat.METADATA_KEY_ART_URI, artworkUrl)
                println("🖼️ تم إضافة رابط الصورة: $artworkUrl")
                
                // تحميل الصورة وإضافتها للـ metadata
                Thread {
                    try {
                        val bitmap = loadImageFromUrl(artworkUrl)
                        if (bitmap != null) {
                            runOnUiThread {
                                val updatedBuilder = MediaMetadataCompat.Builder()
                                    .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
                                    .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)
                                    .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, duration)
                                    .putString(MediaMetadataCompat.METADATA_KEY_ART_URI, artworkUrl)
                                    .putBitmap(MediaMetadataCompat.METADATA_KEY_ART, bitmap)
                                
                                mediaSession?.setMetadata(updatedBuilder.build())
                                println("✅ تم تحديث metadata مع صورة الألبوم")
                            }
                        }
                    } catch (e: Exception) {
                        println("❌ خطأ في تحميل الصورة للـ metadata: ${e.message}")
                    }
                }.start()
            }
            
            mediaSession?.setMetadata(metadataBuilder.build())
            println("✅ تم تحديث metadata في MediaSession بنجاح - Title: \"$title\"")
            
        } catch (e: Exception) {
            println("❌ خطأ في تحديث metadata: ${e.message}")
            e.printStackTrace()
        }
    }

    fun updateNotificationPosition(position: Long, duration: Long) {
        try {
            println("📍 تحديث موضع الإشعار: ${position}ms من ${duration}ms")
            
            // الحصول على العنوان الحالي من metadata
            val currentMetadata = mediaSession?.controller?.metadata
            val currentTitle = currentMetadata?.getString(MediaMetadataCompat.METADATA_KEY_TITLE) ?: "ترنيمة"
            val currentArtist = currentMetadata?.getString(MediaMetadataCompat.METADATA_KEY_ARTIST) ?: "كورال أم النور"
            
            println("📝 العنوان الحالي في الإشعار: \"$currentTitle\"")
            
            // تحديث الموضع في MediaSession بشكل مباشر ومفصل
            val currentState = mediaSession?.controller?.playbackState
            if (currentState != null) {
                val isPlaying = currentState.state == PlaybackStateCompat.STATE_PLAYING
                val playbackSpeed = if (isPlaying) 1.0f else 0.0f
                
                val newState = PlaybackStateCompat.Builder()
                    .setActions(
                        PlaybackStateCompat.ACTION_PLAY or
                        PlaybackStateCompat.ACTION_PAUSE or
                        PlaybackStateCompat.ACTION_PLAY_PAUSE or
                        PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                        PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                        PlaybackStateCompat.ACTION_STOP or
                        PlaybackStateCompat.ACTION_FAST_FORWARD or
                        PlaybackStateCompat.ACTION_REWIND or
                        PlaybackStateCompat.ACTION_SEEK_TO
                    )
                    .setState(currentState.state, position, playbackSpeed)
                    .build()
                
                mediaSession?.setPlaybackState(newState)
                println("✅ تم تحديث PlaybackState - State: ${currentState.state}, Position: ${position}ms, Speed: ${playbackSpeed}")
            }
            
            // تحديث metadata مع المدة الصحيحة والاحتفاظ بالعنوان
            if (duration > 0) {
                val metadataBuilder = MediaMetadataCompat.Builder()
                    .putString(MediaMetadataCompat.METADATA_KEY_TITLE, currentTitle)
                    .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, currentArtist)
                    .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, duration)
                
                // إضافة معلومات إضافية للموضع
                currentMetadata?.getString(MediaMetadataCompat.METADATA_KEY_ART_URI)?.let {
                    metadataBuilder.putString(MediaMetadataCompat.METADATA_KEY_ART_URI, it)
                }
                
                mediaSession?.setMetadata(metadataBuilder.build())
                println("✅ تم تحديث Metadata - Title: \"$currentTitle\", Duration: ${duration}ms")
            }
            
            // إعادة إنشاء الإشعار مع الموضع المحدث والعنوان الصحيح
            val isCurrentlyPlaying = mediaSession?.controller?.playbackState?.state == PlaybackStateCompat.STATE_PLAYING
            
            // تحديث الإشعار مع العنوان الصحيح
            showMediaNotification(currentTitle, isCurrentlyPlaying)
            
            println("📍 تم تحديث موضع التشغيل بنجاح: ${position}ms من ${duration}ms (${if (duration > 0) (position * 100 / duration) else 0}%) للترنيمة: \"$currentTitle\"")
            
        } catch (e: Exception) {
            println("❌ خطأ في تحديث موضع التشغيل: ${e.message}")
            e.printStackTrace()
        }
    }
}
