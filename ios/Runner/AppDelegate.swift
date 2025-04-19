import UIKit
import Flutter
import Firebase
import FirebaseMessaging
import GoogleMobileAds

@main
@objc class AppDelegate: FlutterAppDelegate {
  // إضافة flags لتتبع حالة التهيئة
  private var isFirebaseInitialized = false
  private var firebaseInitInProgress = false
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    print("🚀 AppDelegate: تم بدء تشغيل التطبيق")
    
    // تسجيل plugins بشكل آمن
    GeneratedPluginRegistrant.register(with: self)
    
    // تبسيط الطريقة: تأخير تهيئة Firebase لضمان تهيئة Flutter أولاً
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
      self?.initializeFirebaseSafely()
    }
    
    // إعداد قنوات الاتصال بين Flutter و Swift
    setupMethodChannels()
    
    print("✅ AppDelegate: اكتمل didFinishLaunchingWithOptions")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupMethodChannels() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      print("❌ AppDelegate: لا يمكن الوصول إلى FlutterViewController")
      return
    }
    
    // قناة الرسائل
    let messagingChannel = FlutterMethodChannel(
      name: "com.egypt.redcherry.omelnourchoir/messaging",
      binaryMessenger: controller.binaryMessenger)
    
    messagingChannel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "getAPNSToken" {
        if let apnsToken = Messaging.messaging().apnsToken {
          let tokenParts = apnsToken.map { String(format: "%02.2hhx", $0) }
          let token = tokenParts.joined()
          print("✅ AppDelegate: تم استرجاع رمز APNS: \(token)")
          result(token)
        } else {
          print("⚠️ AppDelegate: رمز APNS غير متوفر")
          result(nil)
        }
      } else if call.method == "initializeFirebase" {
        self?.initializeFirebaseSafely()
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    // قناة دورة حياة التطبيق
    let lifecycleChannel = FlutterMethodChannel(
      name: "com.egypt.redcherry.omelnourchoir/app_lifecycle",
      binaryMessenger: controller.binaryMessenger)
    
    lifecycleChannel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "appResumed" {
        print("📱 AppDelegate: تم استئناف التطبيق من Flutter")
        result(true)
      } else if call.method == "appPaused" {
        print("📱 AppDelegate: تم إيقاف التطبيق مؤقتًا من Flutter")
        result(true)
      } else if call.method == "appTerminating" {
        print("📱 AppDelegate: تم استدعاء appTerminating من Flutter")
        self?.isFirebaseInitialized = false
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  // دالة محسنة وآمنة لتهيئة Firebase
  private func initializeFirebaseSafely() {
    // تجنب التهيئة المتكررة أو المتزامنة
    if isFirebaseInitialized || firebaseInitInProgress {
      print("ℹ️ AppDelegate: تم تجاهل طلب تهيئة Firebase (الحالة: تم التهيئة=\(isFirebaseInitialized), قيد التهيئة=\(firebaseInitInProgress))")
      return
    }
    
    firebaseInitInProgress = true
    print("🔥 AppDelegate: بدء تهيئة Firebase...")
    
    // التحقق مما إذا كان Firebase مهيأ بالفعل
    if FirebaseApp.app() != nil {
      print("ℹ️ AppDelegate: Firebase مهيأ بالفعل")
      isFirebaseInitialized = true
      firebaseInitInProgress = false
      
      // تهيئة المكونات التابعة
      self.setupFirebaseComponents()
      return
    }
    
    // إضافة تأخير قبل التهيئة
    Thread.sleep(forTimeInterval: 0.3)
    
    do {
      // محاولة تهيئة Firebase
      FirebaseApp.configure()
      print("✅ AppDelegate: تم تهيئة Firebase بنجاح")
      
      isFirebaseInitialized = true
      
      // تهيئة المكونات التابعة
      self.setupFirebaseComponents()
    } catch {
      print("❌ AppDelegate: خطأ في تهيئة Firebase: \(error)")
      
      // محاولة إعادة التهيئة بعد تأخير أطول
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
        self?.firebaseInitInProgress = false
        self?.initializeFirebaseSafely()
      }
    }
    
    firebaseInitInProgress = false
  }
  
  // إعداد المكونات التابعة لـ Firebase
  private func setupFirebaseComponents() {
    // تعيين مندوب الرسائل
    Messaging.messaging().delegate = self
    
    // تهيئة الإعلانات
    GADMobileAds.sharedInstance().start(completionHandler: nil)
    
    print("✅ AppDelegate: تم إعداد مكونات Firebase بنجاح")
  }
  
  // استقبال رمز APNS
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    // تعيين رمز APNS في Messaging
    Messaging.messaging().apnsToken = deviceToken
    
    // طباعة رمز APNS للتصحيح
    let tokenParts = deviceToken.map { String(format: "%02.2hhx", $0) }
    let token = tokenParts.joined()
    print("📱 AppDelegate: تم استلام رمز APNS: \(token)")
    
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    print("📱 AppDelegate: تم تنشيط التطبيق (applicationDidBecomeActive)")
    
    // محاولة تهيئة Firebase بعد تأخير قصير إذا لم تكن مهيأة بالفعل
    if !isFirebaseInitialized {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        self?.initializeFirebaseSafely()
      }
    }
    
    // إخطار Flutter
    notifyFlutterLifecycleChange(method: "appResumed")
  }
  
  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    print("📱 AppDelegate: سيتم إيقاف التطبيق مؤقتًا (applicationWillResignActive)")
    
    // إخطار Flutter
    notifyFlutterLifecycleChange(method: "appPaused")
  }
  
  override func applicationDidEnterBackground(_ application: UIApplication) {
    super.applicationDidEnterBackground(application)
    print("📱 AppDelegate: دخل التطبيق للخلفية (applicationDidEnterBackground)")
  }
  
  override func applicationWillEnterForeground(_ application: UIApplication) {
    super.applicationWillEnterForeground(application)
    print("📱 AppDelegate: سيعود التطبيق من الخلفية (applicationWillEnterForeground)")
  }
  
  override func applicationWillTerminate(_ application: UIApplication) {
    super.applicationWillTerminate(application)
    print("📱 AppDelegate: سيتم إنهاء التطبيق (applicationWillTerminate)")
    
    // إعادة تعيين حالة Firebase
    isFirebaseInitialized = false
    
    // إخطار Flutter
    notifyFlutterLifecycleChange(method: "appTerminating")
  }
  
  // دالة مساعدة لإخطار Flutter بتغييرات دورة الحياة
  private func notifyFlutterLifecycleChange(method: String) {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    
    let channel = FlutterMethodChannel(
      name: "com.egypt.redcherry.omelnourchoir/app_lifecycle",
      binaryMessenger: controller.binaryMessenger)
    
    channel.invokeMethod(method, arguments: nil)
  }
}

// امتداد لمندوب Firebase Messaging
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("🔥 AppDelegate: رمز FCM: \(String(describing: fcmToken))")
    
    let dataDict: [String: String] = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: dataDict
    )
  }
}
