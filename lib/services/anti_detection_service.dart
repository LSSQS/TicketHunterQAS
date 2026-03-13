import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import '../utils/logger.dart';
import '../utils/device_utils.dart';
import 'device_fingerprint_service.dart';
import 'behavior_simulation_service.dart';
import 'hook_manager.dart';

/// 高级反检测服务
/// 提供多层次的反检测和伪装能力
class AntiDetectionService {
  final DeviceFingerprintService _fingerprintService = DeviceFingerprintService();
  final BehaviorSimulationService _behaviorService = BehaviorSimulationService();
  
  static const MethodChannel _channel = MethodChannel('com.damai.ticket_hunter/anti_detection');
  
  bool _initialized = false;
  String? _currentDeviceId;
  Map<String, dynamic>? _currentFingerprint;
  
  /// 初始化反检测服务
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // 初始化Hook管理器
      await HookManager.initialize();
      
      // 启用基础Hook
      await _enableBasicHooks();
      
      // 初始化设备指纹
      _currentDeviceId = await DeviceUtils.generateDeviceId();
      _currentFingerprint = await _fingerprintService.generateFingerprint(_currentDeviceId!);
      
      _initialized = true;
      AppLogger.info('Anti-detection service initialized');
    } catch (e) {
      AppLogger.error('Failed to initialize anti-detection service', e);
    }
  }
  
  /// 启用基础Hook
  Future<void> _enableBasicHooks() async {
    try {
      // Hook HTTP请求
      await HookManager.hookHttpRequest();
      
      // Hook设备信息
      await HookManager.hookDeviceInfo();
      
      // Hook定位信息
      await HookManager.hookLocation();
      
      AppLogger.info('Basic hooks enabled');
    } on PlatformException catch(e) {
      AppLogger.warning('Basic hooks partial failure: $e');
    } catch (e) {
      AppLogger.error('Failed to enable basic hooks', e);
    }
  }
  
  /// 设备指纹伪装
  Future<void> spoofDeviceFingerprint(String deviceId) async {
    try {
      final fingerprint = await _fingerprintService.generateFingerprint(deviceId);
      
      // 伪装IMEI
      await _spoofValue('imei', fingerprint['imei']);
      
      // 伪装Android ID
      await _spoofValue('androidId', fingerprint['androidId']);
      
      // 伪装MAC地址
      await _spoofValue('macAddress', fingerprint['macAddress']);
      
      // 伪装设备序列号
      await _spoofValue('serialNumber', fingerprint['serialNumber']);
      
      // 伪装设备型号
      await _spoofValue('model', fingerprint['model']);
      
      // 伪装制造商
      await _spoofValue('manufacturer', fingerprint['manufacturer']);
      
      _currentDeviceId = deviceId;
      _currentFingerprint = fingerprint;
      
      AppLogger.info('Device fingerprint spoofed: $deviceId');
    } on PlatformException {
      AppLogger.info('Spoofing simulated for $deviceId');
      _currentDeviceId = deviceId;
    } catch (e) {
      AppLogger.error('Failed to spoof device fingerprint', e);
    }
  }
  
  /// 伪装单个值
  Future<void> _spoofValue(String key, dynamic value) async {
    try {
      await _channel.invokeMethod('spoofValue', {
        'key': key,
        'value': value?.toString(),
      });
    } on PlatformException {
      // Ignore native errors
    } catch (e) {
      AppLogger.error('Failed to spoof value: $key', e);
    }
  }
  
  /// 网络流量伪装
  Future<void> spoofNetworkTraffic({
    required String url,
    required Map<String, dynamic> headers,
    Map<String, dynamic>? params,
  }) async {
    try {
      // 添加随机延迟
      await _behaviorService.randomDelay(minMs: 100, maxMs: 500);
      
      // 修改User-Agent
      if (!headers.containsKey('User-Agent')) {
        headers['User-Agent'] = _behaviorService.generateRandomUserAgent();
      }
      
      // 添加随机header
      headers['X-Request-ID'] = _generateRandomId();
      headers['X-Timestamp'] = DateTime.now().millisecondsSinceEpoch.toString();
      
      // 添加referer链
      if (!headers.containsKey('Referer')) {
        headers['Referer'] = _generateReferer(url);
      }
      
      AppLogger.debug('Network traffic spoofed for: $url');
    } catch (e) {
      AppLogger.error('Failed to spoof network traffic', e);
    }
  }
  
  /// 时间戳防护
  int protectTimestamp(int timestamp) {
    // 添加随机偏移（±100ms）
    final offset = Random().nextInt(200) - 100;
    return timestamp + offset;
  }
  
  /// Canvas指纹防护
  Future<void> protectCanvasFingerprint() async {
    try {
      await _channel.invokeMethod('protectCanvas');
      AppLogger.info('Canvas fingerprint protected');
    } catch (e) {
      AppLogger.error('Failed to protect canvas fingerprint', e);
    }
  }
  
  /// WebGL指纹防护
  Future<void> protectWebGLFingerprint() async {
    try {
      await _channel.invokeMethod('protectWebGL');
      AppLogger.info('WebGL fingerprint protected');
    } catch (e) {
      AppLogger.error('Failed to protect WebGL fingerprint', e);
    }
  }
  
  /// 字体指纹防护
  Future<void> protectFontFingerprint() async {
    try {
      await _channel.invokeMethod('protectFont');
      AppLogger.info('Font fingerprint protected');
    } catch (e) {
      AppLogger.error('Failed to protect font fingerprint', e);
    }
  }
  
  /// 音频指纹防护
  Future<void> protectAudioFingerprint() async {
    try {
      await _channel.invokeMethod('protectAudio');
      AppLogger.info('Audio fingerprint protected');
    } catch (e) {
      AppLogger.error('Failed to protect audio fingerprint', e);
    }
  }
  
  /// 电池信息伪装
  Future<void> spoofBatteryInfo({
    int? level,
    bool? isCharging,
  }) async {
    try {
      await _channel.invokeMethod('spoofBattery', {
        'level': level ?? (50 + Random().nextInt(40)), // 50-90%
        'isCharging': isCharging ?? Random().nextBool(),
      });
      
      AppLogger.info('Battery info spoofed');
    } catch (e) {
      AppLogger.error('Failed to spoof battery info', e);
    }
  }
  
  /// 传感器数据伪装
  Future<void> spoofSensorData({
    List<double>? accelerometer,
    List<double>? gyroscope,
    List<double>? magnetometer,
  }) async {
    try {
      await _channel.invokeMethod('spoofSensors', {
        'accelerometer': accelerometer ?? _generateRealisticAccelerometer(),
        'gyroscope': gyroscope ?? _generateRealisticGyroscope(),
        'magnetometer': magnetometer ?? _generateRealisticMagnetometer(),
      });
      
      AppLogger.info('Sensor data spoofed');
    } catch (e) {
      AppLogger.error('Failed to spoof sensor data', e);
    }
  }
  
  /// 生成真实的加速度计数据
  List<double> _generateRealisticAccelerometer() {
    final random = Random();
    return [
      random.nextDouble() * 2 - 1, // x: -1 to 1
      random.nextDouble() * 2 - 1, // y: -1 to 1
      9.8 + random.nextDouble() * 0.4 - 0.2, // z: ~9.8 (gravity)
    ];
  }
  
  /// 生成真实的陀螺仪数据
  List<double> _generateRealisticGyroscope() {
    final random = Random();
    return [
      random.nextDouble() * 0.2 - 0.1, // x: small rotation
      random.nextDouble() * 0.2 - 0.1, // y: small rotation
      random.nextDouble() * 0.2 - 0.1, // z: small rotation
    ];
  }
  
  /// 生成真实的磁力计数据
  List<double> _generateRealisticMagnetometer() {
    final random = Random();
    return [
      random.nextDouble() * 100 - 50, // x
      random.nextDouble() * 100 - 50, // y
      random.nextDouble() * 100 - 50, // z
    ];
  }
  
  /// 内存信息伪装
  Future<void> spoofMemoryInfo({
    int? totalMemory,
    int? availableMemory,
  }) async {
    try {
      await _channel.invokeMethod('spoofMemory', {
        'total': totalMemory ?? (4 * 1024 * 1024 * 1024), // 4GB
        'available': availableMemory ?? (2 * 1024 * 1024 * 1024), // 2GB
      });
      
      AppLogger.info('Memory info spoofed');
    } catch (e) {
      AppLogger.error('Failed to spoof memory info', e);
    }
  }
  
  /// CPU信息伪装
  Future<void> spoofCpuInfo({
    int? cores,
    String? architecture,
  }) async {
    try {
      await _channel.invokeMethod('spoofCpu', {
        'cores': cores ?? 8,
        'architecture': architecture ?? 'arm64-v8a',
      });
      
      AppLogger.info('CPU info spoofed');
    } catch (e) {
      AppLogger.error('Failed to spoof CPU info', e);
    }
  }
  
  /// 屏幕信息伪装
  Future<void> spoofScreenInfo({
    int? width,
    int? height,
    double? density,
  }) async {
    try {
      await _channel.invokeMethod('spoofScreen', {
        'width': width ?? 1080,
        'height': height ?? 2400,
        'density': density ?? 3.0,
      });
      
      AppLogger.info('Screen info spoofed');
    } catch (e) {
      AppLogger.error('Failed to spoof screen info', e);
    }
  }
  
  /// DNS泄露防护
  Future<void> protectDnsLeak() async {
    try {
      await _channel.invokeMethod('protectDns');
      AppLogger.info('DNS leak protected');
    } catch (e) {
      AppLogger.error('Failed to protect DNS leak', e);
    }
  }
  
  /// WebRTC泄露防护
  Future<void> protectWebRtcLeak() async {
    try {
      await _channel.invokeMethod('protectWebRtc');
      AppLogger.info('WebRTC leak protected');
    } catch (e) {
      AppLogger.error('Failed to protect WebRTC leak', e);
    }
  }
  
  /// 时区伪装
  Future<void> spoofTimezone(String timezone) async {
    try {
      await _channel.invokeMethod('spoofTimezone', {
        'timezone': timezone,
      });
      
      AppLogger.info('Timezone spoofed: $timezone');
    } catch (e) {
      AppLogger.error('Failed to spoof timezone', e);
    }
  }
  
  /// 语言伪装
  Future<void> spoofLanguage(String language) async {
    try {
      await _channel.invokeMethod('spoofLanguage', {
        'language': language,
      });
      
      AppLogger.info('Language spoofed: $language');
    } catch (e) {
      AppLogger.error('Failed to spoof language', e);
    }
  }
  
  /// 启用全面防护
  Future<void> enableFullProtection() async {
    try {
      AppLogger.info('Enabling full protection');
      
      // 设备指纹伪装
      if (_currentDeviceId != null) {
        await spoofDeviceFingerprint(_currentDeviceId!);
      }
      
      // 指纹防护
      await protectCanvasFingerprint();
      await protectWebGLFingerprint();
      await protectFontFingerprint();
      await protectAudioFingerprint();
      
      // 信息伪装
      await spoofBatteryInfo();
      await spoofSensorData();
      await spoofMemoryInfo();
      await spoofCpuInfo();
      await spoofScreenInfo();
      
      // 泄露防护
      await protectDnsLeak();
      await protectWebRtcLeak();
      
      // 启用所有Hook
      await HookManager.enableAllHooks();
      
      AppLogger.info('Full protection enabled');
    } catch (e) {
      AppLogger.error('Failed to enable full protection', e);
    }
  }
  
  /// 禁用全面防护
  Future<void> disableFullProtection() async {
    try {
      await HookManager.disableAllHooks();
      await _channel.invokeMethod('disableProtection');
      
      AppLogger.info('Full protection disabled');
    } catch (e) {
      AppLogger.error('Failed to disable full protection', e);
    }
  }
  
  /// 生成随机ID
  String _generateRandomId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(32, (index) => chars[random.nextInt(chars.length)]).join();
  }
  
  /// 生成Referer
  String _generateReferer(String url) {
    final uri = Uri.parse(url);
    return '${uri.scheme}://${uri.host}/';
  }
  
  /// 获取当前防护状态
  Future<Map<String, dynamic>> getProtectionStatus() async {
    try {
      final result = await _channel.invokeMethod('getProtectionStatus');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      AppLogger.error('Failed to get protection status', e);
      return {};
    }
  }
  
  /// 检测是否被检测
  Future<DetectionCheckResult> checkIfDetected() async {
    try {
      final result = await _channel.invokeMethod('checkDetection');
      
      return DetectionCheckResult(
        isDetected: result['detected'] == true,
        detectionType: result['type']?.toString(),
        details: result['details']?.toString(),
      );
    } catch (e) {
      AppLogger.error('Failed to check detection', e);
      return DetectionCheckResult(
        isDetected: false,
        detectionType: null,
        details: null,
      );
    }
  }
}

/// 检测检查结果
class DetectionCheckResult {
  final bool isDetected;
  final String? detectionType;
  final String? details;
  
  DetectionCheckResult({
    required this.isDetected,
    this.detectionType,
    this.details,
  });
  
  @override
  String toString() {
    return 'DetectionCheckResult(isDetected: $isDetected, type: $detectionType, details: $details)';
  }
}
