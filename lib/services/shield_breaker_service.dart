import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import '../utils/logger.dart';
import '../utils/device_utils.dart';
import 'anti_detection_service.dart';

enum ShieldLevel {
  none,
  softBan,
  hardBan,
  captcha,
}

class ShieldBreakerService {
  static final ShieldBreakerService _instance = ShieldBreakerService._internal();
  factory ShieldBreakerService() => _instance;
  ShieldBreakerService._internal();

  final AntiDetectionService _antiDetection = AntiDetectionService();
  
  int _consecutiveFailures = 0;
  static const int MAX_RETRIES = 5;
  static const int CIRCUIT_BREAKER_THRESHOLD = 3;
  int _h5Failures = 0;
  
  final List<String> _userAgents = [
    'Mozilla/5.0 (Linux; Android 13; 2211133C Build/TKQ1.220829.002; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/119.0.6045.193 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 14; ALN-AL00 Build/HUAWEIALN-AL00; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/117.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; SM-S9180 Build/TP1A.220624.014; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/118.0.5993.80 Mobile Safari/537.36',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
  ];

  String getRandomUserAgent() {
    return _userAgents[DateTime.now().millisecond % _userAgents.length];
  }

  void recordH5Failure() {
    _h5Failures++;
    if (_h5Failures >= CIRCUIT_BREAKER_THRESHOLD) {
      AppLogger.error('H5 Circuit Breaker Open');
    }
  }

  void resetH5Status() {
    _h5Failures = 0;
  }

  ShieldLevel analyzeResponse(Response? response, Object? error) {
    if (_h5Failures >= CIRCUIT_BREAKER_THRESHOLD) {
      return ShieldLevel.hardBan;
    }
    if (response == null && error is DioException) {
      if (error.response?.statusCode == 403) return ShieldLevel.hardBan;
      if (error.type == DioExceptionType.connectionTimeout) return ShieldLevel.softBan;
    }

    if (response != null) {
      final data = response.data.toString();
      if (data.contains('rgv587_flag') || data.contains('滑动验证')) return ShieldLevel.captcha;
      if (data.contains('FAIL_SYS_USER_VALIDATE')) return ShieldLevel.softBan;
      if (data.contains('20001') || data.contains('非法请求')) return ShieldLevel.softBan;
    }

    return ShieldLevel.none;
  }

  Future<bool> executeBreakerStrategy(ShieldLevel level, String targetUrl) async {
    AppLogger.warning('Breaker Strategy Start: $level - $targetUrl');
    
    _consecutiveFailures++;
    
    try {
      switch (level) {
        case ShieldLevel.softBan:
          return await _strategySoftReset();
        case ShieldLevel.hardBan:
          return await _strategyHardReset();
        case ShieldLevel.captcha:
          return true;
        case ShieldLevel.none:
          _consecutiveFailures = 0;
          return true;
      }
    } catch (e) {
      AppLogger.error('Breaker Strategy Failed', e);
      return false;
    }
  }

  Future<bool> _strategySoftReset() async {
    await Future.delayed(Duration(milliseconds: 1500 + (DateTime.now().millisecond)));
    return true;
  }

  Future<bool> _strategyHardReset() async {
    final newDeviceId = await DeviceUtils.generateDeviceId();
    await _antiDetection.spoofDeviceFingerprint(newDeviceId);
    await Future.delayed(Duration(seconds: 3));
    return true;
  }

  String getFallbackProtocol() {
    if (_consecutiveFailures > 2) {
      return 'H5_API';
    }
    return 'APP_API';
  }
}
