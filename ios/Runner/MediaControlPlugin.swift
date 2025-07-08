import Flutter
import UIKit
import MediaPlayer

public class MediaControlPlugin: NSObject, FlutterPlugin {
    private var mediaControlHandler: MediaControlHandler?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        print("🔌 MediaControlPlugin: بدء التسجيل...")
        
        // قناة التحكم الرئيسية
        let channel = FlutterMethodChannel(
            name: "com.egypt.redcherry.omelnourchoir/app", 
            binaryMessenger: registrar.messenger()
        )
        
        // قناة معلومات التشغيل
        let nowPlayingChannel = FlutterMethodChannel(
            name: "com.egypt.redcherry.omelnourchoir/now_playing", 
            binaryMessenger: registrar.messenger()
        )
        
        // قناة أزرار التحكم
        let mediaButtonChannel = FlutterMethodChannel(
            name: "com.egypt.redcherry.omelnourchoir/media_buttons", 
            binaryMessenger: registrar.messenger()
        )
        
        let instance = MediaControlPlugin()
        
        // تسجيل المعالجات
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addMethodCallDelegate(instance, channel: nowPlayingChannel)
        
        // تهيئة MediaControlHandler
        instance.mediaControlHandler = MediaControlHandler()
        instance.mediaControlHandler?.setMethodChannel(mediaButtonChannel)
        
        print("✅ MediaControlPlugin: تم التسجيل بنجاح")
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("📥 MediaControlPlugin: استلام استدعاء \(call.method)")
        
        guard let handler = mediaControlHandler else {
            print("❌ MediaControlHandler غير متاح")
            result(FlutterError(code: "HANDLER_NOT_AVAILABLE", message: "MediaControlHandler not available", details: nil))
            return
        }
        
        handler.handle(call, result: result)
    }
}
