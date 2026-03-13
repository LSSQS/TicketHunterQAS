import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'logger.dart';

class DeviceUtils {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static final Random _random = Random();
  
  static AndroidDeviceInfo? _cachedAndroidInfo;
  static IosDeviceInfo? _cachedIosInfo;
  static WebBrowserInfo? _cachedWebInfo;

  /// 检查是否为Android平台
  static bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  
  /// 检查是否为iOS平台
  static bool get isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// 生成设备ID
  static Future<String> generateDeviceId() async {
    try {
      final deviceInfo = await getDeviceInfo();
      
      // 组合多个设备特征生成唯一ID
      final components = [
        deviceInfo['manufacturer'] ?? 'unknown',
        deviceInfo['model'] ?? 'unknown',
        deviceInfo['systemVersion'] ?? 'unknown',
        DateTime.now().millisecondsSinceEpoch.toString(),
        _random.nextInt(999999).toString().padLeft(6, '0'),
      ];
      
      final combined = components.join('|');
      final bytes = utf8.encode(combined);
      final digest = sha256.convert(bytes);
      
      return digest.toString().substring(0, 32).toUpperCase();
    } catch (e) {
      AppLogger.error('Generate device ID failed', e);
      // 生成随机设备ID作为备选
      return _generateRandomDeviceId();
    }
  }

  /// 生成随机设备ID
  static String _generateRandomDeviceId() {
    const chars = '0123456789ABCDEF';
    return List.generate(32, (_) => chars[_random.nextInt(chars.length)]).join('');
  }

  /// 获取设备信息
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      if (kIsWeb) {
        return await _getWebDeviceInfo();
      } else if (isAndroid) {
        return await _getAndroidDeviceInfo();
      } else if (isIOS) {
        return await _getIosDeviceInfo();
      } else {
        return _getDefaultDeviceInfo();
      }
    } catch (e) {
      AppLogger.error('Get device info failed', e);
      return _getDefaultDeviceInfo();
    }
  }

  /// 获取Web设备信息
  static Future<Map<String, dynamic>> _getWebDeviceInfo() async {
    try {
      _cachedWebInfo ??= await _deviceInfo.webBrowserInfo;
      final info = _cachedWebInfo!;
      
      return {
        'platform': 'web',
        'manufacturer': 'Browser',
        'model': info.browserName.name,
        'brand': info.vendor ?? 'Unknown',
        'systemVersion': info.appVersion ?? 'Unknown',
        'userAgent': info.userAgent ?? 'Unknown',
        'isPhysicalDevice': false,
      };
    } catch (e) {
      AppLogger.error('Get web device info failed', e);
      return _getDefaultDeviceInfo();
    }
  }

  /// 获取Android设备信息
  static Future<Map<String, dynamic>> _getAndroidDeviceInfo() async {
    _cachedAndroidInfo ??= await _deviceInfo.androidInfo;
    final info = _cachedAndroidInfo!;
    
    return {
      'platform': 'android',
      'manufacturer': info.manufacturer,
      'model': info.model,
      'brand': info.brand,
      'device': info.device,
      'product': info.product,
      'board': info.board,
      'hardware': info.hardware,
      'bootloader': info.bootloader,
      'fingerprint': info.fingerprint,
      'host': info.host,
      'id': info.id,
      'tags': info.tags,
      'type': info.type,
      'user': 'android_user',
      'display': info.display,
      'systemVersion': info.version.release,
      'apiLevel': info.version.sdkInt,
      'isPhysicalDevice': info.isPhysicalDevice,
    };
  }

  /// 获取iOS设备信息
  static Future<Map<String, dynamic>> _getIosDeviceInfo() async {
    _cachedIosInfo ??= await _deviceInfo.iosInfo;
    final info = _cachedIosInfo!;
    
    return {
      'platform': 'ios',
      'manufacturer': 'Apple',
      'model': info.model,
      'name': info.name,
      'systemName': info.systemName,
      'systemVersion': info.systemVersion,
      'localizedModel': info.localizedModel,
      'identifierForVendor': info.identifierForVendor,
      'isPhysicalDevice': info.isPhysicalDevice,
      'utsname': {
        'sysname': info.utsname.sysname,
        'nodename': info.utsname.nodename,
        'release': info.utsname.release,
        'version': info.utsname.version,
        'machine': info.utsname.machine,
      },
    };
  }

  /// 获取默认设备信息
  static Map<String, dynamic> _getDefaultDeviceInfo() {
    return {
      'platform': kIsWeb ? 'web' : 'unknown',
      'manufacturer': kIsWeb ? 'Browser' : 'Unknown',
      'model': kIsWeb ? 'Web Browser' : 'Unknown Device',
      'systemVersion': '1.0',
      'isPhysicalDevice': !kIsWeb,
    };
  }

  /// 生成UMID
  static Future<String> generateUmid(String deviceId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final deviceInfo = await getDeviceInfo();
      
      final components = [
        deviceId,
        timestamp.toString(),
        deviceInfo['manufacturer'] ?? 'unknown',
        deviceInfo['model'] ?? 'unknown',
        _random.nextInt(999999).toString(),
      ];
      
      final combined = components.join(':');
      final bytes = utf8.encode(combined);
      final digest = md5.convert(bytes);
      
      return 'T${digest.toString().toUpperCase()}';
    } catch (e) {
      AppLogger.error('Generate UMID failed', e);
      return 'T${_generateRandomString(32)}';
    }
  }

  /// 生成用户代理字符串
  static Future<String> getUserAgent() async {
    try {
      final deviceInfo = await getDeviceInfo();
      final packageInfo = await PackageInfo.fromPlatform();
      
      if (deviceInfo['platform'] == 'android') {
        return _generateAndroidUserAgent(deviceInfo, packageInfo);
      } else if (deviceInfo['platform'] == 'ios') {
        return _generateIosUserAgent(deviceInfo, packageInfo);
      } else {
        return _generateDefaultUserAgent(packageInfo);
      }
    } catch (e) {
      AppLogger.error('Generate user agent failed', e);
      return _generateDefaultUserAgent(null);
    }
  }

  /// 生成Android用户代理
  static String _generateAndroidUserAgent(
    Map<String, dynamic> deviceInfo,
    PackageInfo packageInfo,
  ) {
    final manufacturer = deviceInfo['manufacturer'] ?? 'Unknown';
    final model = deviceInfo['model'] ?? 'Unknown';
    final version = deviceInfo['systemVersion'] ?? '11';
    final buildId = deviceInfo['id'] ?? 'Unknown';
    
    return 'Mozilla/5.0 (Linux; Android $version; $model Build/$buildId; wv) '
           'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 '
           'Chrome/91.0.4472.114 Mobile Safari/537.36 '
           'DamaiApp/${packageInfo.version} ($manufacturer $model; Android $version)';
  }

  /// 生成iOS用户代理
  static String _generateIosUserAgent(
    Map<String, dynamic> deviceInfo,
    PackageInfo packageInfo,
  ) {
    final model = deviceInfo['model'] ?? 'iPhone';
    final version = deviceInfo['systemVersion'] ?? '15.0';
    final versionFormatted = version.replaceAll('.', '_');
    
    return 'Mozilla/5.0 ($model; CPU iPhone OS $versionFormatted like Mac OS X) '
           'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 '
           'Mobile/15E148 Safari/604.1 '
           'DamaiApp/${packageInfo.version}';
  }

  /// 生成默认用户代理
  static String _generateDefaultUserAgent(PackageInfo? packageInfo) {
    final version = packageInfo?.version ?? '1.0.0';
    return 'Mozilla/5.0 (Mobile; rv:68.0) Gecko/68.0 Firefox/68.0 '
           'DamaiApp/$version';
  }

  /// 生成随机字符串
  static String _generateRandomString(int length) {
    const chars = '0123456789ABCDEF';
    return List.generate(length, (_) => chars[_random.nextInt(chars.length)]).join('');
  }

  /// 获取网络类型
  static Future<String> getNetworkType() async {
    try {
      // 这里可以使用connectivity_plus包获取网络状态
      // 简化实现，返回默认值
      return 'wifi';
    } catch (e) {
      AppLogger.error('Get network type failed', e);
      return 'unknown';
    }
  }

  /// 获取屏幕信息
  static Future<Map<String, dynamic>> getScreenInfo() async {
    try {
      // 这里可以获取实际的屏幕信息
      // 简化实现，返回常见的屏幕参数
      return {
        'width': 1080,
        'height': 2400,
        'density': 3.0,
        'scaledDensity': 3.0,
        'densityDpi': 480,
      };
    } catch (e) {
      AppLogger.error('Get screen info failed', e);
      return {
        'width': 1080,
        'height': 1920,
        'density': 2.0,
        'scaledDensity': 2.0,
        'densityDpi': 320,
      };
    }
  }

  /// 生成设备指纹
  static Future<String> generateDeviceFingerprint(String deviceId) async {
    try {
      final deviceInfo = await getDeviceInfo();
      final screenInfo = await getScreenInfo();
      final networkType = await getNetworkType();
      
      final fingerprint = {
        'deviceId': deviceId,
        'platform': deviceInfo['platform'],
        'manufacturer': deviceInfo['manufacturer'],
        'model': deviceInfo['model'],
        'systemVersion': deviceInfo['systemVersion'],
        'screenWidth': screenInfo['width'],
        'screenHeight': screenInfo['height'],
        'density': screenInfo['density'],
        'networkType': networkType,
        'timezone': DateTime.now().timeZoneOffset.inHours,
        'language': 'zh-CN',
      };
      
      final jsonString = jsonEncode(fingerprint);
      final bytes = utf8.encode(jsonString);
      final digest = sha256.convert(bytes);
      
      return digest.toString();
    } catch (e) {
      AppLogger.error('Generate device fingerprint failed', e);
      return _generateRandomString(64);
    }
  }

  /// 验证设备ID格式
  static bool isValidDeviceId(String deviceId) {
    if (deviceId.isEmpty) return false;
    if (deviceId.length != 32) return false;
    
    final validPattern = RegExp(r'^[0-9A-F]{32}$');
    return validPattern.hasMatch(deviceId);
  }

  /// 生成MAC地址
  static String generateMacAddress() {
    final bytes = List.generate(6, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
  }

  /// 生成IMEI
  static String generateImei() {
    // 生成15位IMEI
    final tac = '35${_random.nextInt(900000) + 100000}'; // 8位TAC
    final snr = '${_random.nextInt(900000) + 100000}'; // 6位序列号
    final imei14 = tac + snr;
    
    // 计算校验位
    final checkDigit = _calculateLuhnChecksum(imei14);
    return imei14 + checkDigit.toString();
  }

  /// 计算Luhn校验和
  static int _calculateLuhnChecksum(String number) {
    int sum = 0;
    bool alternate = false;
    
    for (int i = number.length - 1; i >= 0; i--) {
      int digit = int.parse(number[i]);
      
      if (alternate) {
        digit *= 2;
        if (digit > 9) {
          digit = (digit % 10) + 1;
        }
      }
      
      sum += digit;
      alternate = !alternate;
    }
    
    return (10 - (sum % 10)) % 10;
  }

  /// 获取设备性能等级
  static Future<DevicePerformanceLevel> getPerformanceLevel() async {
    try {
      final deviceInfo = await getDeviceInfo();
      
      // 根据设备信息判断性能等级
      if (deviceInfo['platform'] == 'android') {
        final apiLevel = deviceInfo['apiLevel'] as int? ?? 0;
        if (apiLevel >= 30) {
          return DevicePerformanceLevel.high;
        } else if (apiLevel >= 26) {
          return DevicePerformanceLevel.medium;
        } else {
          return DevicePerformanceLevel.low;
        }
      } else if (deviceInfo['platform'] == 'ios') {
        // iOS设备通常性能较好
        return DevicePerformanceLevel.high;
      }
      
      return DevicePerformanceLevel.medium;
    } catch (e) {
      AppLogger.error('Get performance level failed', e);
      return DevicePerformanceLevel.medium;
    }
  }

  /// 清除缓存
  static void clearCache() {
    _cachedAndroidInfo = null;
    _cachedIosInfo = null;
    _cachedWebInfo = null;
    AppLogger.info('Device utils cache cleared');
  }
}

enum DevicePerformanceLevel {
  low,
  medium,
  high,
}