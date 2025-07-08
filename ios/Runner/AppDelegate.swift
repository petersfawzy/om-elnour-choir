import UIKit
import Flutter
import Firebase
import FirebaseMessaging
import GoogleMobileAds
import AVFoundation
import MediaPlayer

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var isFirebaseInitialized = false
    private var firebaseInitInProgress = false
    private var mediaChannel: FlutterMethodChannel?
    private var mediaControlHandler: MediaControlHandler?
    private var audioSession: AVAudioSession?
    
    // متغيرات لتتبع حالة التشغيل
    private var wasPlayingBeforeTermination = false
    private var lastPlayingTitle: String?
    private var lastPlayingPosition: Double = 0.0
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("🚀 AppDelegate: بدء تشغيل التطبيق")
        
        // تعيين نافذة التطبيق وواجهة Flutter الرئيسية
        self.window = UIWindow(frame: UIScreen.main.bounds)
        let flutterViewController = FlutterViewController()
        self.window?.rootViewController = flutterViewController
        self.window?.makeKeyAndVisible()
        
        // تسجيل plugins الأساسية
        GeneratedPluginRegistrant.register(with: self)
        
        // إعداد معالج التحكم في الوسائط
        setupMediaControlHandler()
        
        // إعداد جلسة الصوت المحسنة
        setupAudioSessionEnhanced()
        
        // إعداد التحكم في الوسائط
        setupRemoteCommandCenter()
        
        // تسجيل قنوات التحكم
        setupMethodChannels()
        
        // إعداد مراقبة انقطاع الصوت المحسنة
        setupAudioInterruptionHandlingEnhanced()
        
        // إعداد مراقبة دورة حياة التطبيق
        setupAppLifecycleObservers()
        
        // تهيئة Firebase
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.initializeFirebaseSafely()
        }
        
        print("✅ AppDelegate: اكتمل التهيئة")
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // إعداد معالج التحكم في الوسائط
    private func setupMediaControlHandler() {
        print("🎵 إعداد معالج التحكم في الوسائط...")
        mediaControlHandler = MediaControlHandler()
        print("✅ تم إعداد معالج التحكم في الوسائط")
    }
    
    // إعداد جلسة الصوت المحسنة
    private func setupAudioSessionEnhanced() {
        print("🎵 إعداد جلسة الصوت المحسنة...")
        
        audioSession = AVAudioSession.sharedInstance()
        
        do {
            // إعداد فئة الصوت مع خيارات محسنة للتشغيل المستمر في الخلفية
            try audioSession?.setCategory(
                .playback,
                mode: .default,
                options: [
                    .duckOthers,
                    .allowBluetooth,
                    .allowBluetoothA2DP,
                    .allowAirPlay,
                    .defaultToSpeaker,
                    .interruptSpokenAudioAndMixWithOthers // إضافة هذا الخيار
                ]
            )
            
            // تفعيل الجلسة مع خيارات للتشغيل المستمر
            try audioSession?.setActive(true, options: [.notifyOthersOnDeactivation])
            
            print("✅ تم إعداد جلسة الصوت المحسنة بنجاح")
            
        } catch let error as NSError {
            print("❌ خطأ في إعداد جلسة الصوت: \(error)")
            
            // محاولة بديلة مع إعدادات أبسط
            do {
                try audioSession?.setCategory(.playback, mode: .default)
                try audioSession?.setActive(true)
                print("✅ تم إعداد جلسة الصوت بالطريقة البديلة")
            } catch {
                print("❌ فشل في الطريقة البديلة: \(error)")
            }
        }
    }
    
    // إعداد مراقبة انقطاع الصوت المحسنة
    private func setupAudioInterruptionHandlingEnhanced() {
        print("🔊 إعداد مراقبة انقطاع الصوت المحسنة...")
        
        // مراقبة انقطاع الصوت
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruptionEnhanced),
            name: AVAudioSession.interruptionNotification,
            object: audioSession
        )
        
        // مراقبة تغيير مسار الصوت
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChangeEnhanced),
            name: AVAudioSession.routeChangeNotification,
            object: audioSession
        )
        
        // مراقبة تغيير حالة الوسائط
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServicesReset),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: audioSession
        )
        
        print("✅ تم إعداد مراقبة انقطاع الصوت المحسنة")
    }
    
    // إعداد مراقبة دورة حياة التطبيق
    private func setupAppLifecycleObservers() {
        print("📱 إعداد مراقبة دورة حياة التطبيق...")
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        print("✅ تم إعداد مراقبة دورة حياة التطبيق")
    }
    
    // معالج انقطاع الصوت المحسن
    @objc private func handleAudioInterruptionEnhanced(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        print("🔊 تم اكتشاف انقطاع صوتي محسن: \(type)")
        
        switch type {
        case .began:
            print("🔊 بدء انقطاع الصوت - حفظ الحالة وإيقاف التشغيل")
            saveCurrentPlaybackState()
            sendCommandToFlutter("pause")
            
        case .ended:
            print("🔊 انتهاء انقطاع الصوت")
            
            // إعادة تفعيل جلسة الصوت
            do {
                try audioSession?.setActive(true, options: [.notifyOthersOnDeactivation])
                print("✅ تم إعادة تفعيل جلسة الصوت بعد الانقطاع")
                
                // ضمان استمرار التشغيل
                ensureContinuousPlayback()
            } catch {
                print("❌ خطأ في إعادة تفعيل جلسة الصوت: \(error)")
            }
            
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) && wasPlayingBeforeTermination {
                    print("🔊 استئناف التشغيل بعد انتهاء الانقطاع")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.sendCommandToFlutter("play")
                    }
                }
            }
            
        @unknown default:
            print("🔊 نوع انقطاع غير معروف")
        }
    }
    
    // معالج تغيير مسار الصوت المحسن
    @objc private func handleRouteChangeEnhanced(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        print("🔊 تغيير مسار الصوت المحسن: \(reason)")
        
        switch reason {
        case .oldDeviceUnavailable:
            print("🔊 الجهاز القديم غير متاح - حفظ الحالة وإيقاف التشغيل")
            saveCurrentPlaybackState()
            sendCommandToFlutter("pause")
            
        case .newDeviceAvailable:
            print("🔊 جهاز جديد متاح - إعادة تفعيل جلسة الصوت")
            do {
                try audioSession?.setActive(true, options: [])
            } catch {
                print("❌ خطأ في إعادة تفعيل جلسة الصوت: \(error)")
            }
            
        case .categoryChange:
            print("🔊 تغيير فئة الصوت - إعادة إعداد الجلسة")
            setupAudioSessionEnhanced()
            
        default:
            break
        }
    }
    
    // معالج إعادة تعيين خدمات الوسائط
    @objc private func handleMediaServicesReset(notification: Notification) {
        print("🔄 تم إعادة تعيين خدمات الوسائط - إعادة الإعداد")
        
        // إعادة إعداد جلسة الصوت
        setupAudioSessionEnhanced()
        
        // إعادة إعداد مركز التحكم عن بُعد
        setupRemoteCommandCenter()
        
        // إخطار Flutter بإعادة التهيئة
        sendCommandToFlutter("reinitialize")
    }
    
    // حفظ حالة التشغيل الحالية
    private func saveCurrentPlaybackState() {
        if let nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            wasPlayingBeforeTermination = (nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0.0) > 0
            lastPlayingTitle = nowPlayingInfo[MPMediaItemPropertyTitle] as? String
            lastPlayingPosition = nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double ?? 0.0
            
            print("💾 تم حفظ حالة التشغيل:")
            print("   كان يعمل: \(wasPlayingBeforeTermination)")
            print("   العنوان: \(lastPlayingTitle ?? "غير محدد")")
            print("   الموضع: \(lastPlayingPosition)s")
        }
    }
    
    // معالجات دورة حياة التطبيق
    @objc private func appWillTerminate() {
        print("📱 التطبيق سيتم إنهاؤه - حفظ الحالة")
        saveCurrentPlaybackState()
        sendCommandToFlutter("saveState")
    }
    
    @objc private func appDidEnterBackground() {
        print("📱 التطبيق دخل الخلفية - حفظ الحالة")
        saveCurrentPlaybackState()
        
        // الحفاظ على جلسة الصوت نشطة في الخلفية إذا كان هناك تشغيل
        if wasPlayingBeforeTermination {
            do {
                try audioSession?.setActive(true, options: [])
                print("✅ تم الحفاظ على جلسة الصوت في الخلفية")
            } catch {
                print("⚠️ خطأ في الحفاظ على جلسة الصوت في الخلفية: \(error)")
            }
        }
    }
    
    @objc private func appWillEnterForeground() {
        print("📱 التطبيق سيدخل المقدمة - استعادة الحالة")
        
        // إعادة تفعيل جلسة الصوت
        do {
            try audioSession?.setActive(true, options: [])
            print("✅ تم إعادة تفعيل جلسة الصوت في المقدمة")
        } catch {
            print("⚠️ خطأ في إعادة تفعيل جلسة الصوت: \(error)")
        }
        
        // إعادة تفعيل التحكم عن بُعد
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        // إخطار Flutter بالعودة للمقدمة
        sendCommandToFlutter("restoreState")
    }
    
    // إعداد مركز التحكم عن بُعد
    private func setupRemoteCommandCenter() {
        print("🎮 إعداد مركز التحكم عن بُعد...")
        
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // تنظيف المستهدفين السابقين
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        
        // تفعيل الأوامر
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        
        // إضافة معالجات الأوامر
        commandCenter.playCommand.addTarget { [weak self] _ in
            print("🎮 أمر التشغيل من شاشة القفل")
            self?.sendCommandToFlutter("play")
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            print("🎮 أمر الإيقاف من شاشة القفل")
            self?.sendCommandToFlutter("pause")
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            print("🎮 أمر التبديل من شاشة القفل")
            self?.sendCommandToFlutter("toggle")
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            print("🎮 أمر التالي من شاشة القفل")
            self?.sendCommandToFlutter("next")
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            print("🎮 أمر السابق من شاشة القفل")
            self?.sendCommandToFlutter("previous")
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                print("🎮 أمر البحث من شاشة القفل: \(event.positionTime)")
                self?.sendCommandToFlutter("seek", ["position": event.positionTime])
            }
            return .success
        }
        
        // تمكين استقبال أوامر التحكم عن بُعد
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        print("✅ تم إعداد مركز التحكم عن بُعد بنجاح")
    }
    
    // ضمان استمرار التشغيل عند انتهاء الترنيمة
    private func ensureContinuousPlayback() {
        print("🔄 ضمان استمرار التشغيل في الخلفية...")
        
        do {
            // إعادة تفعيل جلسة الصوت بقوة
            try audioSession?.setActive(true, options: [.notifyOthersOnDeactivation])
            
            // تأكيد أن التطبيق يستقبل أوامر التحكم عن بُعد
            UIApplication.shared.beginReceivingRemoteControlEvents()
            
            // إرسال إشارة لـ Flutter لضمان التشغيل المستمر
            sendCommandToFlutter("ensure_continuous_playback")
            
            print("✅ تم ضمان استمرار التشغيل في الخلفية")
        } catch {
            print("❌ خطأ في ضمان استمرار التشغيل: \(error)")
        }
    }
    
    // إرسال أمر إلى Flutter
    private func sendCommandToFlutter(_ command: String, _ arguments: [String: Any]? = nil) {
        var args: [String: Any] = ["command": command]
        if let arguments = arguments {
            args.merge(arguments) { (_, new) in new }
        }

        print("📤 إرسال أمر إلى Flutter: \(command)")

        DispatchQueue.main.async { [weak self] in
            guard
                let self = self,
                let channel = self.mediaChannel,
                let controller = self.window?.rootViewController as? FlutterViewController
            else {
                print("⚠️ لا يمكن إرسال الأمر: قناة Flutter غير متاحة أو لم يعد التطبيق في وضع Flutter")
                return
            }
            channel.invokeMethod("onRemoteCommand", arguments: args) { result in
                if let error = result as? FlutterError {
                    print("❌ خطأ في إرسال الأمر: \(error.message ?? "Unknown error")")
                } else {
                    print("✅ تم إرسال الأمر بنجاح: \(command)")
                }
            }
        }
    }
    
    // إعداد قنوات التحكم
    private func setupMethodChannels() {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            print("❌ لم يتم العثور على FlutterViewController")
            return
        }
        
        // قناة التحكم في الوسائط
        mediaChannel = FlutterMethodChannel(
            name: "com.egypt.redcherry.omelnourchoir/media_control",
            binaryMessenger: controller.binaryMessenger
        )
        
        // ربط القناة بمعالج التحكم
        if let handler = mediaControlHandler {
            handler.setMethodChannel(mediaChannel!)
            
            mediaChannel?.setMethodCallHandler { [weak handler] (call, result) in
                handler?.handle(call, result: result)
            }
        }
        
        print("✅ تم إعداد قنوات التحكم بنجاح")
    }
    
    // تهيئة Firebase
    private func initializeFirebaseSafely() {
        if isFirebaseInitialized || firebaseInitInProgress {
            return
        }
        
        firebaseInitInProgress = true
        
        if FirebaseApp.app() != nil {
            isFirebaseInitialized = true
            firebaseInitInProgress = false
            setupFirebaseComponents()
            return
        }
        
        do {
            FirebaseApp.configure()
            isFirebaseInitialized = true
            setupFirebaseComponents()
            print("✅ تم تهيئة Firebase بنجاح")
        } catch {
            print("❌ خطأ في تهيئة Firebase: \(error)")
        }
        
        firebaseInitInProgress = false
    }
    
    private func setupFirebaseComponents() {
        Messaging.messaging().delegate = self
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    // أحداث دورة حياة التطبيق
    override func applicationDidBecomeActive(_ application: UIApplication) {
        super.applicationDidBecomeActive(application)
        print("📱 التطبيق أصبح نشطاً")
        
        // إعادة تفعيل جلسة الصوت
        do {
            try audioSession?.setActive(true)
            print("✅ تم إعادة تفعيل جلسة الصوت")
        } catch {
            print("⚠️ خطأ في إعادة تفعيل جلسة الصوت: \(error)")
        }
        
        // إعادة تفعيل التحكم عن بُعد
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }
    
    override func applicationDidEnterBackground(_ application: UIApplication) {
        super.applicationDidEnterBackground(application)
        print("📱 التطبيق دخل الخلفية")
        
        // حفظ الحالة
        saveCurrentPlaybackState()
        
        // الحفاظ على جلسة الصوت نشطة في الخلفية فقط إذا كان هناك تشغيل
        if wasPlayingBeforeTermination {
            do {
                try audioSession?.setActive(true, options: [])
                print("✅ تم الحفاظ على جلسة الصوت في الخلفية")
            } catch {
                print("⚠️ خطأ في الحفاظ على جلسة الصوت في الخلفية: \(error)")
            }
        }
    }
    
    override func applicationWillTerminate(_ application: UIApplication) {
        super.applicationWillTerminate(application)
        print("📱 التطبيق سيتم إنهاؤه")
        
        // حفظ الحالة النهائية
        saveCurrentPlaybackState()
        
        // تنظيف عند إغلاق التطبيق
        NotificationCenter.default.removeObserver(self)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        UIApplication.shared.endReceivingRemoteControlEvents()
        
        do {
            try audioSession?.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ خطأ في إلغاء تفعيل جلسة الصوت: \(error)")
        }
    }
    
    // تنظيف الذاكرة
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔥 رمز FCM: \(String(describing: fcmToken))")
    }
}
