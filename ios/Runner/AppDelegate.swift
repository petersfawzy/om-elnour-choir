import UIKit
import Flutter
import GoogleMobileAds // ✅ أضف السطر ده

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    GeneratedPluginRegistrant.register(with: self)
    
    GADMobileAds.sharedInstance().start(completionHandler: nil) // ✅ تأكد من هذا السطر
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
