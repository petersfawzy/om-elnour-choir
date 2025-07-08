import Foundation
import AVFoundation
import MediaPlayer

class AudioSessionObserver {
    static let shared = AudioSessionObserver()
    
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var secondaryAudioObserver: NSObjectProtocol?
    
    private init() {}
    
    func startObserving(interruptionHandler: @escaping (AVAudioSession.InterruptionType) -> Void,
                        routeChangeHandler: @escaping (AVAudioSession.RouteChangeReason) -> Void,
                        secondaryAudioHandler: @escaping (Bool) -> Void) {
        
        // مراقبة الانقطاعات (مثل المكالمات الواردة)
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main) { notification in
                guard let userInfo = notification.userInfo,
                      let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                    return
                }
                
                interruptionHandler(type)
            }
        
        // مراقبة تغييرات المسار (مثل توصيل/فصل السماعات)
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main) { notification in
                guard let userInfo = notification.userInfo,
                      let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
                    return
                }
                
                routeChangeHandler(reason)
            }
        
        // مراقبة الصوت الثانوي (مثل تشغيل تطبيق آخر للصوت)
        secondaryAudioObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.silenceSecondaryAudioHintNotification,
            object: nil,
            queue: .main) { notification in
                guard let userInfo = notification.userInfo,
                      let typeValue = userInfo[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt,
                      let type = AVAudioSession.SilenceSecondaryAudioHintType(rawValue: typeValue) else {
                    return
                }
                
                let isSilenced = type == .begin
                secondaryAudioHandler(isSilenced)
            }
    }
    
    func stopObserving() {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }
        
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            routeChangeObserver = nil
        }
        
        if let observer = secondaryAudioObserver {
            NotificationCenter.default.removeObserver(observer)
            secondaryAudioObserver = nil
        }
    }
}
