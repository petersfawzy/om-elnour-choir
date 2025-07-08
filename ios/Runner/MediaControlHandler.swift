import Foundation
import MediaPlayer
import AVFoundation
import Flutter

@objc public class MediaControlHandler: NSObject {
    private var commandCenter: MPRemoteCommandCenter
    private var nowPlayingInfoCenter: MPNowPlayingInfoCenter
    private var remoteCommandHandler: ((String) -> Void)?
    private var isInitialized = false
    private var methodChannel: FlutterMethodChannel?

    @objc public override init() {
        self.commandCenter = MPRemoteCommandCenter.shared()
        self.nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
        super.init()
        print("🍎 MediaControlHandler تم إنشاؤه")
    }
    
    @objc public func initialize() {
        guard !isInitialized else {
            print("⚠️ MediaControlHandler مهيأ بالفعل")
            return
        }
        
        print("🔄 تهيئة MediaControlHandler...")
        
        // تفعيل جلسة الصوت أولاً
        setupAudioSession()
        
        // تمكين أوامر التحكم عن بُعد
        setupRemoteCommands()
        
        isInitialized = true
        print("✅ تم تهيئة MediaControlHandler بنجاح")
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // استخدم .playback فقط بدون خيارات إضافية
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
            print("✅ تم إعداد جلسة الصوت للتحكم في الوسائط")
        } catch {
            print("❌ خطأ في إعداد جلسة الصوت: \(error)")
        }
    }
    
    private func setupRemoteCommands() {
        // تنظيف الأوامر السابقة
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        
        // تمكين أوامر التشغيل والإيقاف
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] event in
            print("🎵 تم الضغط على زر التشغيل من شاشة القفل")
            self?.handleRemoteCommand("play")
            return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] event in
            print("⏸️ تم الضغط على زر الإيقاف من شاشة القفل")
            self?.handleRemoteCommand("pause")
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] event in
            print("⏯️ تم الضغط على زر التبديل من شاشة القفل")
            self?.handleRemoteCommand("toggle")
            return .success
        }
        
        // تمكين أوامر التنقل
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] event in
            print("⏭️ تم الضغط على زر التالي من شاشة القفل")
            self?.handleRemoteCommand("next")
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] event in
            print("⏮️ تم الضغط على زر السابق من شاشة القفل")
            self?.handleRemoteCommand("previous")
            return .success
        }
        
        // تمكين أمر البحث
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let positionEvent = event as? MPChangePlaybackPositionCommandEvent {
                let position = positionEvent.positionTime
                print("🔍 تم طلب البحث إلى الموضع: \(position) ثانية")
                self?.handleSeekCommand(position)
            }
            return .success
        }
        
        print("✅ تم إعداد أوامر التحكم عن بُعد")
    }
    
    @objc public func registerRemoteCommandHandler(_ handler: @escaping (String) -> Void) {
        self.remoteCommandHandler = handler
        print("📱 تم تسجيل معالج أوامر التحكم عن بُعد")
    }
    
    @objc public func setMethodChannel(_ channel: FlutterMethodChannel) {
        self.methodChannel = channel
        print("📡 تم تعيين قناة Flutter في MediaControlHandler")
    }

    @objc public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("📲 تم استقبال ميثود من Flutter: \(call.method)")
        switch call.method {
        case "initialize":
            self.initialize()
            result(true)
        case "updateNowPlayingInfo":
            if let args = call.arguments as? [String: Any],
               let title = args["title"] as? String,
               let artist = args["artist"] as? String,
               let duration = args["duration"] as? Double,
               let position = args["position"] as? Double,
               let isPlaying = args["isPlaying"] as? Bool {
                self.updateNowPlayingInfo(
                    title: title,
                    artist: artist,
                    duration: duration,
                    position: position,
                    isPlaying: isPlaying
                )
                result(true)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for updateNowPlayingInfo", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleRemoteCommand(_ command: String) {
        print("📱 معالجة أمر التحكم عن بُعد: \(command)")
        remoteCommandHandler?(command)
    }
    
    private func handleSeekCommand(_ position: TimeInterval) {
        print("🔍 معالجة أمر البحث إلى الموضع: \(position)")
        remoteCommandHandler?("seek")
    }
    
    @objc public func updateNowPlayingInfo(title: String, artist: String, duration: TimeInterval, position: TimeInterval, isPlaying: Bool) {
        var nowPlayingInfo = [String: Any]()
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "كورال أم النور"
        
        if duration > 0 {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        }
        
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        // إضافة معلومات إضافية
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = false
        
        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
        
        // تفعيل جلسة الصوت كل مرة لضمان بقاء التحكم ظاهر
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ خطأ في إعادة تفعيل جلسة الصوت: \(error)")
        }
        
        print("🍎 تم تحديث معلومات التشغيل في iOS:")
        print("   العنوان: \(title)")
        print("   الفنان: \(artist)")
        print("   المدة: \(duration) ثانية")
        print("   الموضع: \(position) ثانية")
        print("   حالة التشغيل: \(isPlaying ? "يعمل" : "متوقف")")
    }
    
    @objc public func clearNowPlayingInfo() {
        nowPlayingInfoCenter.nowPlayingInfo = nil
        print("🗑️ تم مسح معلومات التشغيل من iOS")
    }
    
    @objc public func reactivateMediaSession() {
        print("🔄 إعادة تفعيل جلسة الوسائط...")
        
        // إعادة تفعيل جلسة الصوت
        setupAudioSession()
        
        // إعادة إعداد أوامر التحكم
        setupRemoteCommands()
        
        print("✅ تم إعادة تفعيل جلسة الوسائط بنجاح")
    }
    
    @objc public func handleAppLifecycleEvent(_ event: String) {
        print("📱 معالجة حدث دورة حياة التطبيق: \(event)")
        
        switch event {
        case "didEnterBackground":
            print("📱 التطبيق انتقل للخلفية")
            // حفظ الحالة
            remoteCommandHandler?("save_state")
            
        case "willEnterForeground":
            print("📱 التطبيق سيعود للمقدمة")
            // إعادة تفعيل الجلسة
            reactivateMediaSession()
            
        case "didBecomeActive":
            print("📱 التطبيق أصبح نشطاً")
            // استعادة التشغيل
            remoteCommandHandler?("restore_playback")
            
        case "willResignActive":
            print("📱 التطبيق سيفقد النشاط")
            // حفظ الحالة
            remoteCommandHandler?("save_state")
            
        case "willTerminate":
            print("📱 التطبيق سيتم إنهاؤه")
            // حفظ الحالة النهائية
            remoteCommandHandler?("save_state")
            
        default:
            print("⚠️ حدث دورة حياة غير معروف: \(event)")
        }
    }
    
    deinit {
        print("🧹 تنظيف MediaControlHandler")
        
        // تعطيل جميع الأوامر
        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.togglePlayPauseCommand.isEnabled = false
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = false
        
        // إزالة جميع الأهداف
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        
        // مسح معلومات التشغيل
        clearNowPlayingInfo()
        
        // إلغاء تفعيل جلسة الصوت
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("⚠️ خطأ في إلغاء تفعيل جلسة الصوت: \(error)")
        }
    }
}
