import Foundation
import UIKit

class AntiDetection {
    
    // 用户代理列表
    private static let userAgents = [
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 15_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.6 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
    ]
    
    // 视口尺寸列表
    private static let viewports = [
        ["width": 390, "height": 844],   // iPhone 12/13/14
        ["width": 428, "height": 926],   // iPhone 12/13/14 Pro Max
        ["width": 375, "height": 812],   // iPhone 11 Pro/X/XS
        ["width": 414, "height": 896],   // iPhone 11/XR
        ["width": 393, "height": 852],   // iPhone 14 Pro
    ]
    
    /// 获取随机User-Agent
    static func getRandomUserAgent() -> String {
        return userAgents.randomElement() ?? userAgents[0]
    }
    
    /// 获取随机延迟（毫秒）
    static func getRandomDelay(min: Int, max: Int) -> Int {
        guard max > min else { return min }
        return Int.random(in: min...max)
    }
    
    /// 生成设备指纹
    static func generateDeviceFingerprint() -> [String: Any] {
        let device = UIDevice.current
        let screen = UIScreen.main
        
        // 设备基本信息
        let deviceInfo: [String: Any] = [
            "model": device.model,
            "systemVersion": device.systemVersion,
            "systemName": device.systemName,
            "identifierForVendor": device.identifierForVendor?.uuidString ?? "unknown",
            "screenWidth": Int(screen.bounds.width * screen.scale),
            "screenHeight": Int(screen.bounds.height * screen.scale),
            "scale": screen.scale,
            "timezone": TimeZone.current.identifier,
            "language": Locale.current.languageCode ?? "zh",
            "platform": "iOS"
        ]
        
        return deviceInfo
    }
    
    /// 获取随机视口尺寸
    static func getRandomViewport() -> [String: Int] {
        return viewports.randomElement() ?? viewports[0]
    }
    
    /// 模拟人类行为延迟
    static func humanDelay() -> Int {
        // 生成符合人类行为的随机延迟（100-800ms）
        let baseDelay = Int.random(in: 100...400)
        let variation = Int.random(in: -50...400)
        return max(50, baseDelay + variation)
    }
    
    /// 生成随机鼠标移动路径
    static func generateMousePath(from: CGPoint, to: CGPoint, steps: Int = 20) -> [[String: Double]] {
        var path: [[String: Double]] = []
        
        for i in 0...steps {
            let progress = Double(i) / Double(steps)
            
            // 使用贝塞尔曲线模拟自然移动
            let controlX = (from.x + to.x) / 2 + Double.random(in: -50...50)
            let controlY = (from.y + to.y) / 2 + Double.random(in: -50...50)
            
            let t = progress
            let x = pow(1-t, 2) * Double(from.x) + 
                   2 * (1-t) * t * controlX + 
                   pow(t, 2) * Double(to.x)
            let y = pow(1-t, 2) * Double(from.y) + 
                   2 * (1-t) * t * controlY + 
                   pow(t, 2) * Double(to.y)
            
            path.append(["x": x, "y": y, "timestamp": Double(i * 10)])
        }
        
        return path
    }
}
