import Foundation
import UIKit

class RootDetection {
    
    // 越狱文件路径
    private static let jailbreakPaths = [
        "/Applications/Cydia.app",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/bin/bash",
        "/usr/sbin/sshd",
        "/etc/apt",
        "/private/var/lib/apt/",
        "/private/var/lib/cydia",
        "/private/var/stash",
        "/Applications/Sileo.app",
        "/usr/bin/ssh",
        "/usr/libexec/sftp-server",
        "/Applications/FakeCarrier.app",
        "/Applications/Icy.app",
        "/Applications/IntelliScreen.app",
        "/Applications/MxTube.app",
        "/Applications/RockApp.app",
        "/Applications/SBSettings.app",
        "/Applications/WinterBoard.app",
        "/Applications/blackra1n.app",
        "/Library/MobileSubstrate/DynamicLibraries/LiveClock.plist",
        "/Library/MobileSubstrate/DynamicLibraries/Veency.plist",
        "/System/Library/LaunchDaemons/com.ikey.bbot.plist",
        "/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
        "/bin/sh",
        "/etc/ssh/sshd_config",
        "/usr/libexec/ssh-keysign"
    ]
    
    // 可疑应用URL Scheme
    private static let suspiciousSchemes = [
        "cydia://",
        "sileo://",
        "zbra://",
        "filza://",
        "activator://"
    ]
    
    /// 检测设备是否越狱
    static func isDeviceJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        
        // 1. 检查越狱文件
        if checkJailbreakFiles() {
            return true
        }
        
        // 2. 检查是否可以写入系统目录
        if canWriteToSystemDirectory() {
            return true
        }
        
        // 3. 检查可疑应用
        if checkSuspiciousApps() {
            return true
        }
        
        // 4. 检查dyld
        if checkDyld() {
            return true
        }
        
        // 5. 检查fork
        if canFork() {
            return true
        }
        
        return false
        #endif
    }
    
    /// 检查越狱文件是否存在
    static func checkJailbreakFiles() -> Bool {
        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
            
            // 尝试打开文件
            if let file = fopen(path, "r") {
                fclose(file)
                return true
            }
        }
        return false
    }
    
    /// 检查是否可以写入系统目录
    private static func canWriteToSystemDirectory() -> Bool {
        let testPath = "/private/jailbreak_test.txt"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            return false
        }
    }
    
    /// 检查可疑应用
    static func checkSuspiciousApps() -> Bool {
        for scheme in suspiciousSchemes {
            if let url = URL(string: scheme),
               UIApplication.shared.canOpenURL(url) {
                return true
            }
        }
        return false
    }
    
    /// 检查动态库注入
    private static func checkDyld() -> Bool {
        var count: UInt32 = 0
        let images = _dyld_image_count()
        
        for i in 0..<images {
            if let imageName = _dyld_get_image_name(i) {
                let name = String(cString: imageName)
                if name.contains("MobileSubstrate") ||
                   name.contains("Substrate") ||
                   name.contains("Cydia") {
                    return true
                }
            }
        }
        return false
    }
    
    /// 检查是否可以fork进程
    private static func canFork() -> Bool {
        let pid = fork()
        if pid >= 0 {
            if pid > 0 {
                // 父进程，杀死子进程
                kill(pid, SIGTERM)
            }
            return true
        }
        return false
    }
    
    /// 获取越狱检测详细信息
    static func getJailbreakDetails() -> [String: Any] {
        var details: [String: Any] = [:]
        
        details["isJailbroken"] = isDeviceJailbroken()
        details["hasJailbreakFiles"] = checkJailbreakFiles()
        details["hasSuspiciousApps"] = checkSuspiciousApps()
        details["canFork"] = canFork()
        
        var foundPaths: [String] = []
        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                foundPaths.append(path)
            }
        }
        details["foundPaths"] = foundPaths
        
        return details
    }
}
