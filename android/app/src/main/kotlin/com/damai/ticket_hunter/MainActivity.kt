package com.damai.ticket_hunter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val HOOK_CHANNEL = "com.damai.ticket_hunter/hook"
    private val ROOT_DETECTION_CHANNEL = "com.damai.ticket_hunter/root_detection"
    private val ANTI_DETECTION_CHANNEL = "com.damai.ticket_hunter/anti_detection"
    
    private var hookService: HookService? = null
    private var rootDetectionService: RootDetectionNative? = null
    private var antiDetectionService: AntiDetectionNative? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 初始化Hook服务
        hookService = HookService(applicationContext)
        val hookChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HOOK_CHANNEL)
        hookService?.initialize(hookChannel)
        
        // 初始化Root检测服务
        rootDetectionService = RootDetectionNative(applicationContext)
        val rootChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ROOT_DETECTION_CHANNEL)
        rootDetectionService?.initialize(rootChannel)
        
        // 初始化反检测服务
        antiDetectionService = AntiDetectionNative(applicationContext)
        val antiChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ANTI_DETECTION_CHANNEL)
        antiDetectionService?.initialize(antiChannel)
    }
}
