package com.damai.ticket_hunter

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Native层Root检测
 */
class RootDetectionNative(private val context: Context) {
    
    companion object {
        private const val TAG = "RootDetectionNative"
    }
    
    fun initialize(channel: MethodChannel) {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkRootApps" -> {
                    val packages = call.argument<List<String>>("packages")
                    val hasRootApp = packages?.any { checkAppInstalled(it) } ?: false
                    result.success(hasRootApp)
                }
                
                "checkProperties" -> {
                    val properties = call.argument<List<String>>("properties")
                    val hasSuspicious = checkSystemProperties(properties ?: emptyList())
                    result.success(hasSuspicious)
                }
                
                "checkRootNative" -> {
                    val isRooted = checkRootNative()
                    result.success(isRooted)
                }
                
                "checkEmulator" -> {
                    val emulatorResult = checkEmulator()
                    result.success(emulatorResult)
                }
                
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        Log.i(TAG, "Root detection native initialized")
    }
    
    /**
     * 检查应用是否安装
     */
    private fun checkAppInstalled(packageName: String): Boolean {
        return try {
            context.packageManager.getPackageInfo(packageName, 0)
            Log.w(TAG, "Root app installed: $packageName")
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }
    
    /**
     * 检查系统属性
     */
    private fun checkSystemProperties(properties: List<String>): Boolean {
        return try {
            for (property in properties) {
                val value = getSystemProperty(property)
                
                when (property) {
                    "ro.secure" -> if (value == "0") {
                        Log.w(TAG, "Suspicious property: ro.secure = 0")
                        return true
                    }
                    "ro.debuggable" -> if (value == "1") {
                        Log.w(TAG, "Suspicious property: ro.debuggable = 1")
                        return true
                    }
                    "service.adb.root" -> if (value == "1") {
                        Log.w(TAG, "Suspicious property: service.adb.root = 1")
                        return true
                    }
                    "ro.build.selinux" -> if (value == "0") {
                        Log.w(TAG, "Suspicious property: ro.build.selinux = 0")
                        return true
                    }
                }
            }
            false
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check system properties", e)
            false
        }
    }
    
    /**
     * 获取系统属性
     */
    private fun getSystemProperty(key: String): String {
        return try {
            val process = Runtime.getRuntime().exec("getprop $key")
            process.inputStream.bufferedReader().use { it.readText().trim() }
        } catch (e: Exception) {
            ""
        }
    }
    
    /**
     * Native层Root检测
     */
    private fun checkRootNative(): Boolean {
        // 检查Test-Keys
        val buildTags = Build.TAGS
        if (buildTags != null && buildTags.contains("test-keys")) {
            Log.w(TAG, "Build tags contain test-keys")
            return true
        }
        
        // 检查OTA证书
        return try {
            val file = File("/etc/security/otacerts.zip")
            if (!file.exists()) {
                Log.w(TAG, "OTA certs not found")
                true
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * 检测模拟器
     */
    private fun checkEmulator(): Map<String, Any> {
        var score = 0
        var emulatorType: String? = null
        
        // 检查Build信息
        if (Build.FINGERPRINT.startsWith("generic") ||
            Build.FINGERPRINT.startsWith("unknown") ||
            Build.MODEL.contains("google_sdk") ||
            Build.MODEL.contains("Emulator") ||
            Build.MODEL.contains("Android SDK built for x86") ||
            Build.MANUFACTURER.contains("Genymotion") ||
            Build.HARDWARE.contains("goldfish") ||
            Build.HARDWARE.contains("ranchu") ||
            Build.PRODUCT.contains("sdk") ||
            Build.PRODUCT.contains("google_sdk") ||
            Build.PRODUCT.contains("sdk_google") ||
            Build.PRODUCT.contains("sdk_x86") ||
            Build.PRODUCT.contains("vbox86p") ||
            Build.PRODUCT.contains("emulator") ||
            Build.PRODUCT.contains("simulator")
        ) {
            score += 3
            emulatorType = "Generic Emulator"
        }
        
        // 检查特定模拟器特征
        if (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic")) {
            score += 2
            emulatorType = "Android Studio Emulator"
        }
        
        if (Build.MANUFACTURER.contains("Genymotion")) {
            score += 3
            emulatorType = "Genymotion"
        }
        
        // 检查传感器
        val sensors = try {
            val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as android.hardware.SensorManager
            sensorManager.getSensorList(android.hardware.Sensor.TYPE_ALL)
        } catch (e: Exception) {
            emptyList()
        }
        
        if (sensors.isEmpty()) {
            score += 2
        }
        
        val isEmulator = score >= 3
        
        return mapOf<String, Any>(
            "isEmulator" to isEmulator,
            "type" to (emulatorType ?: ""),
            "score" to score
        )
    }
}
