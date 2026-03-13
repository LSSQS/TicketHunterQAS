import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        // 注册Native方法通道
        setupMethodChannels()
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func setupMethodChannels() {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return
        }
        
        // 反检测通道
        let antiDetectionChannel = FlutterMethodChannel(
            name: "com.damai.ticket_hunter/anti_detection",
            binaryMessenger: controller.binaryMessenger
        )
        
        antiDetectionChannel.setMethodCallHandler { [weak self] (call, result) in
            self?.handleAntiDetectionCall(call, result: result)
        }
        
        // Root检测通道
        let rootDetectionChannel = FlutterMethodChannel(
            name: "com.damai.ticket_hunter/root_detection",
            binaryMessenger: controller.binaryMessenger
        )
        
        rootDetectionChannel.setMethodCallHandler { [weak self] (call, result) in
            self?.handleRootDetectionCall(call, result: result)
        }
    }
    
    private func handleAntiDetectionCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getRandomUserAgent":
            result(AntiDetection.getRandomUserAgent())
        case "getRandomDelay":
            if let args = call.arguments as? [String: Any],
               let min = args["min"] as? Int,
               let max = args["max"] as? Int {
                result(AntiDetection.getRandomDelay(min: min, max: max))
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            }
        case "generateDeviceFingerprint":
            result(AntiDetection.generateDeviceFingerprint())
        case "getRandomViewport":
            result(AntiDetection.getRandomViewport())
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleRootDetectionCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isDeviceRooted":
            result(RootDetection.isDeviceJailbroken())
        case "checkRootFiles":
            result(RootDetection.checkJailbreakFiles())
        case "checkSuspiciousApps":
            result(RootDetection.checkSuspiciousApps())
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
