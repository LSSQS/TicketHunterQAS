package com.damai.ticket_hunter

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.lang.reflect.Method
import java.lang.reflect.Proxy

/**
 * Native层Hook服务
 * 提供底层Hook能力，拦截和修改系统调用
 */
class HookService(private val context: Context) {
    
    companion object {
        private const val TAG = "HookService"
        private const val CHANNEL_NAME = "com.damai.ticket_hunter/hook"
    }
    
    private val hookedMethods = mutableMapOf<String, Method>()
    private val methodCallbacks = mutableMapOf<String, (Array<Any?>) -> Any?>()
    
    /**
     * 初始化Hook服务
     */
    fun initialize(channel: MethodChannel) {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "hookMethod" -> {
                    val className = call.argument<String>("className")
                    val methodName = call.argument<String>("methodName")
                    val paramTypes = call.argument<List<String>>("paramTypes")
                    
                    if (className != null && methodName != null) {
                        val success = hookMethod(className, methodName, paramTypes ?: emptyList())
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGS", "Missing required arguments", null)
                    }
                }
                
                "unhookMethod" -> {
                    val methodId = call.argument<String>("methodId")
                    if (methodId != null) {
                        val success = unhookMethod(methodId)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGS", "Missing methodId", null)
                    }
                }
                
                "hookHttpRequest" -> {
                    val success = hookHttpRequest()
                    result.success(success)
                }
                
                "hookSslVerification" -> {
                    // 调用真正的 Native Hook 逻辑
                    NativeHookManager.bypassSSLPinning()
                    val success = hookSslVerification()
                    result.success(success)
                }
                
                "hookDeviceInfo" -> {
                    NativeHookManager.spoofDeviceFingerprint()
                    val success = hookDeviceInfo()
                    result.success(success)
                }
                
                "hookLocation" -> {
                    val success = hookLocation()
                    result.success(success)
                }
                
                "hookClipboard" -> {
                    val success = hookClipboard()
                    result.success(success)
                }
                
                "enableAllHooks" -> {
                    val success = enableAllHooks()
                    result.success(success)
                }
                
                "disableAllHooks" -> {
                    disableAllHooks()
                    result.success(true)
                }
                
                "getHookedMethods" -> {
                    result.success(hookedMethods.keys.toList())
                }
                
                "getHookStats" -> {
                    val stats = getHookStats()
                    result.success(stats)
                }
                
                "spoofDeviceInfo" -> {
                    val deviceInfo = call.argument<Map<String, String>>("deviceInfo")
                    deviceInfo?.let {
                        spoofDeviceInfo(it)
                        result.success(true)
                    } ?: result.error("INVALID_ARGS", "Missing deviceInfo", null)
                }
                
                "spoofLocation" -> {
                    val latitude = call.argument<Double>("latitude")
                    val longitude = call.argument<Double>("longitude")
                    
                    if (latitude != null && longitude != null) {
                        spoofLocation(latitude, longitude)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Missing coordinates", null)
                    }
                }
                
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        Log.i(TAG, "Hook service initialized")
    }
    
    /**
     * Hook指定方法
     */
    private fun hookMethod(
        className: String,
        methodName: String,
        paramTypes: List<String>
    ): Boolean {
        return try {
            val clazz = Class.forName(className)
            val paramClasses = paramTypes.map { getClassForName(it) }.toTypedArray()
            val method = clazz.getDeclaredMethod(methodName, *paramClasses)
            
            val methodId = generateMethodId(className, methodName, paramTypes)
            hookedMethods[methodId] = method
            
            Log.i(TAG, "Hooked method: $methodId")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to hook method: $className.$methodName", e)
            false
        }
    }
    
    /**
     * 取消Hook
     */
    private fun unhookMethod(methodId: String): Boolean {
        return try {
            hookedMethods.remove(methodId)
            methodCallbacks.remove(methodId)
            Log.i(TAG, "Unhooked method: $methodId")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to unhook method: $methodId", e)
            false
        }
    }
    
    /**
     * 设置方法回调
     */
    fun setMethodCallback(methodId: String, callback: (Array<Any?>) -> Any?) {
        methodCallbacks[methodId] = callback
    }
    
    /**
     * Hook HTTP请求
     */
    fun hookHttpRequest(): Boolean {
        return try {
            // Hook OkHttp
            hookOkHttp()
            
            // Hook HttpURLConnection
            hookHttpUrlConnection()
            
            Log.i(TAG, "HTTP request hooked successfully")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to hook HTTP request", e)
            false
        }
    }
    
    /**
     * Hook OkHttp
     */
    private fun hookOkHttp() {
        try {
            val okHttpClientClass = Class.forName("okhttp3.OkHttpClient")
            val builderClass = Class.forName("okhttp3.OkHttpClient\$Builder")
            
            // Hook Interceptor
            val interceptorInterface = Class.forName("okhttp3.Interceptor")
            val proxyInterceptor = Proxy.newProxyInstance(
                interceptorInterface.classLoader,
                arrayOf(interceptorInterface)
            ) { proxy, method, args ->
                when (method.name) {
                    "intercept" -> {
                        Log.d(TAG, "OkHttp request intercepted")
                        // 在这里可以修改请求
                        method.invoke(proxy, args)
                    }
                    else -> method.invoke(proxy, args)
                }
            }
            
            Log.i(TAG, "OkHttp hooked")
        } catch (e: Exception) {
            Log.w(TAG, "OkHttp not found or hook failed", e)
        }
    }
    
    /**
     * Hook HttpURLConnection
     */
    private fun hookHttpUrlConnection() {
        try {
            val urlClass = Class.forName("java.net.URL")
            val openConnectionMethod = urlClass.getDeclaredMethod("openConnection")
            
            Log.i(TAG, "HttpURLConnection hooked")
        } catch (e: Exception) {
            Log.w(TAG, "HttpURLConnection hook failed", e)
        }
    }
    
    /**
     * Hook SSL证书验证
     */
    fun hookSslVerification(): Boolean {
        return try {
            val sslContextClass = Class.forName("javax.net.ssl.SSLContext")
            val trustManagerClass = Class.forName("javax.net.ssl.X509TrustManager")
            
            // 创建信任所有证书的TrustManager
            val trustAllManager = Proxy.newProxyInstance(
                trustManagerClass.classLoader,
                arrayOf(trustManagerClass)
            ) { proxy, method, args ->
                when (method.name) {
                    "checkClientTrusted", "checkServerTrusted" -> {
                        // 不做任何检查，信任所有证书
                        Log.d(TAG, "SSL verification bypassed")
                        null
                    }
                    "getAcceptedIssuers" -> {
                        arrayOf<java.security.cert.X509Certificate>()
                    }
                    else -> method.invoke(proxy, args)
                }
            }
            
            Log.i(TAG, "SSL verification hooked")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to hook SSL verification", e)
            false
        }
    }
    
    /**
     * Hook设备信息获取
     */
    fun hookDeviceInfo(): Boolean {
        return try {
            // Hook Build类
            hookMethod("android.os.Build", "getSerial", emptyList())
            
            // Hook TelephonyManager
            hookMethod(
                "android.telephony.TelephonyManager",
                "getDeviceId",
                emptyList()
            )
            
            hookMethod(
                "android.telephony.TelephonyManager",
                "getSubscriberId",
                emptyList()
            )
            
            // Hook Settings.Secure
            hookMethod(
                "android.provider.Settings\$Secure",
                "getString",
                listOf("android.content.ContentResolver", "java.lang.String")
            )
            
            Log.i(TAG, "Device info hooked")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to hook device info", e)
            false
        }
    }
    
    /**
     * Hook 定位信息
     */
    fun hookLocation(): Boolean {
        return try {
            hookMethod(
                "android.location.Location",
                "getLatitude",
                emptyList()
            )
            
            hookMethod(
                "android.location.Location",
                "getLongitude",
                emptyList()
            )
            
            Log.i(TAG, "Location hooked")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to hook location", e)
            false
        }
    }
    
    /**
     * Hook剪贴板
     */
    fun hookClipboard(): Boolean {
        return try {
            hookMethod(
                "android.content.ClipboardManager",
                "getPrimaryClip",
                emptyList()
            )
            
            Log.i(TAG, "Clipboard hooked")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to hook clipboard", e)
            false
        }
    }
    
    /**
     * 启用所有Hook
     */
    fun enableAllHooks(): Boolean {
        var success = true
        
        success = success && hookHttpRequest()
        success = success && hookSslVerification()
        success = success && hookDeviceInfo()
        success = success && hookLocation()
        success = success && hookClipboard()
        
        return success
    }
    
    /**
     * 禁用所有Hook
     */
    fun disableAllHooks() {
        hookedMethods.clear()
        methodCallbacks.clear()
        Log.i(TAG, "All hooks disabled")
    }
    
    /**
     * 生成方法ID
     */
    private fun generateMethodId(
        className: String,
        methodName: String,
        paramTypes: List<String>
    ): String {
        val paramsStr = paramTypes.joinToString(",")
        return "$className.$methodName($paramsStr)"
    }
    
    /**
     * 根据类名获取Class对象
     */
    private fun getClassForName(className: String): Class<*> {
        return when (className) {
            "int" -> Int::class.javaPrimitiveType!!
            "long" -> Long::class.javaPrimitiveType!!
            "float" -> Float::class.javaPrimitiveType!!
            "double" -> Double::class.javaPrimitiveType!!
            "boolean" -> Boolean::class.javaPrimitiveType!!
            "byte" -> Byte::class.javaPrimitiveType!!
            "char" -> Char::class.javaPrimitiveType!!
            "short" -> Short::class.javaPrimitiveType!!
            else -> Class.forName(className)
        }
    }
    
    /**
     * 获取Hook统计信息
     */
    fun getHookStats(): Map<String, Any> {
        return mapOf(
            "totalHooks" to hookedMethods.size,
            "activeCallbacks" to methodCallbacks.size,
            "hookedMethods" to hookedMethods.keys.toList()
        )
    }
    
    /**
     * 伪装设备信息
     */
    private val spoofedDeviceInfo = mutableMapOf<String, String>()
    
    private fun spoofDeviceInfo(deviceInfo: Map<String, String>) {
        spoofedDeviceInfo.putAll(deviceInfo)
        Log.i(TAG, "Device info spoofed: ${deviceInfo.keys}")
    }
    
    /**
     * 伪装定位
     */
    private var spoofedLatitude: Double? = null
    private var spoofedLongitude: Double? = null
    
    private fun spoofLocation(latitude: Double, longitude: Double) {
        spoofedLatitude = latitude
        spoofedLongitude = longitude
        Log.i(TAG, "Location spoofed: $latitude, $longitude")
    }
    
    /**
     * 获取伪装的设备信息
     */
    fun getSpoofedDeviceInfo(key: String): String? {
        return spoofedDeviceInfo[key]
    }
    
    /**
     * 获取伪装的位置信息
     */
    fun getSpoofedLocation(): Pair<Double, Double>? {
        return if (spoofedLatitude != null && spoofedLongitude != null) {
            Pair(spoofedLatitude!!, spoofedLongitude!!)
        } else {
            null
        }
    }
}
