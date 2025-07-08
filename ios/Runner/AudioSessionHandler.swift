import Foundation
import AVFoundation
import MediaPlayer
import UIKit

@objc class AudioSessionHandler: NSObject {
    static let shared = AudioSessionHandler()
    private override init() {}

    internal var nowPlayingInfo: [String: Any] = [:]

    // تهيئة جلسة الصوت مع إعدادات متقدمة
    func configureAudioSessionAdvanced() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .default,
                policy: .longFormAudio,
                options: [
                    .allowBluetooth,
                    .allowBluetoothA2DP,
                    .allowAirPlay,
                    .duckOthers
                ]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            UIApplication.shared.beginReceivingRemoteControlEvents()
            print("✅ تم تهيئة جلسة الصوت المتقدمة بنجاح")
        } catch {
            print("❌ خطأ في تهيئة جلسة الصوت المتقدمة: \(error.localizedDescription)")
        }
    }

    // تهيئة جلسة الصوت
    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("❌ خطأ في تهيئة جلسة الصوت: \(error)")
        }
    }

    // معالجة انقطاع الصوت (مثل المكالمات الواردة)
    func handleInterruption(_ type: AVAudioSession.InterruptionType) {
        switch type {
        case .began:
            NotificationCenter.default.post(
                name: Notification.Name("AudioInterruptionBegan"),
                object: nil
            )
            print("🔇 بدأ انقطاع الصوت")
        case .ended:
            NotificationCenter.default.post(
                name: Notification.Name("AudioInterruptionEnded"),
                object: nil
            )
            print("🔊 انتهى انقطاع الصوت")
        @unknown default:
            break
        }
    }

    // معالجة تغيير مسار الصوت (مثل توصيل/فصل السماعات)
    func handleRouteChange(_ reason: AVAudioSession.RouteChangeReason) {
        switch reason {
        case .newDeviceAvailable:
            print("🎧 تم توصيل جهاز صوت جديد")
        case .oldDeviceUnavailable:
            print("🔌 تم فصل جهاز صوت")
        default:
            break
        }
    }

    // تحديث معلومات التشغيل مع دعم للتحكم في الموضع
    func updateNowPlayingInfoWithSeekability(
        title: String,
        artist: String,
        duration: Double,
        position: Double,
        imageUrl: String?,
        isSeekable: Bool = true
    ) {
        updateNowPlayingInfo(title: title, artist: artist, artwork: nil)
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
        if isSeekable {
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
            nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        print("✅ تم تحديث معلومات التشغيل مع إمكانية التحكم في الموضع")
    }

    // تحديث معلومات التشغيل (مع artwork)
    func updateNowPlayingInfo(title: String, artist: String, artwork: UIImage?) {
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        if let artworkImage = artwork {
            let artwork = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in
                return artworkImage
            }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    // تحديث معلومات التشغيل (مع مدة وموقع وحالة التشغيل)
    func updateNowPlayingInfo(title: String, artist: String, duration: TimeInterval, position: TimeInterval, isPlaying: Bool) {
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [:]
    }
}
