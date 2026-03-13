import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../utils/logger.dart';
import '../utils/device_utils.dart';

class DeviceFingerprintService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final Map<String, Map<String, dynamic>> _fingerprintCache = {};
  final Map<String, String> _userAgentCache = {};

  Future<Map<String, dynamic>> generateFingerprint(String deviceId) async {
    try {
      // 检查缓存
      if (_fingerprintCache.containsKey(deviceId)) {
        return _fingerprintCache[deviceId]!;
      }

      final fingerprint = await _createFingerprint(deviceId);
      _fingerprintCache[deviceId] = fingerprint;
      
      AppLogger.info('Generated fingerprint for device: $deviceId');
      return fingerprint;
    } catch (e) {
      AppLogger.error('Generate fingerprint failed', e);
      throw Exception('生成设备指纹失败: $e');
    }
  }

  Future<Map<String, dynamic>> _createFingerprint(String deviceId) async {
    final random = Random(deviceId.hashCode);
    
    // 基础设备信息
    final baseFingerprint = await _getBaseFingerprint();
    
    // 生成随机但一致的设备特征
    final fingerprint = {
      ...baseFingerprint,
      'deviceId': deviceId,
      'imei': _generateIMEI(random),
      'androidId': _generateAndroidId(random),
      'macAddress': _generateMacAddress(random),
      'serialNumber': _generateSerialNumber(random),
      'buildId': _generateBuildId(random),
      'fingerprint': _generateSystemFingerprint(random),
      'bootId': _generateBootId(random),
      'procVersion': _generateProcVersion(random),
      'basebandVersion': _generateBasebandVersion(random),
      'innerVersion': _generateInnerVersion(random),
      'displayId': _generateDisplayId(random),
      'hostName': _generateHostName(random),
      'bootloader': _generateBootloader(random),
      'hardware': _generateHardware(random),
      'radioVersion': _generateRadioVersion(random),
      'device': _generateDevice(random),
      'board': _generateBoard(random),
      'brand': _generateBrand(random),
      'model': _generateModel(random),
      'product': _generateProduct(random),
      'manufacturer': _generateManufacturer(random),
      'cpuAbi': _generateCpuAbi(random),
      'cpuAbi2': _generateCpuAbi2(random),
      'tags': _generateTags(random),
      'type': _generateType(random),
      'user': _generateUser(random),
      'release': _generateRelease(random),
      'sdk': _generateSdk(random),
      'incremental': _generateIncremental(random),
      'codename': _generateCodename(random),
      'screenSize': _generateScreenSize(random),
      'density': _generateDensity(random),
      'densityDpi': _generateDensityDpi(random),
      'xdpi': _generateXdpi(random),
      'ydpi': _generateYdpi(random),
      'scaledDensity': _generateScaledDensity(random),
      'fontScale': _generateFontScale(random),
    };

    return fingerprint;
  }

  Future<Map<String, dynamic>> _getBaseFingerprint() async {
    try {
      final deviceInfo = await _deviceInfo.androidInfo;
      
      return {
        'platform': 'android',
        'version': deviceInfo.version.release,
        'apiLevel': deviceInfo.version.sdkInt,
        'manufacturer': deviceInfo.manufacturer,
        'model': deviceInfo.model,
        'brand': deviceInfo.brand,
        'device': deviceInfo.device,
        'product': deviceInfo.product,
        'board': deviceInfo.board,
        'hardware': deviceInfo.hardware,
        'bootloader': deviceInfo.bootloader,
        'fingerprint': deviceInfo.fingerprint,
        'host': deviceInfo.host,
        'id': deviceInfo.id,
        'tags': deviceInfo.tags,
        'type': deviceInfo.type,
        // 'user' 字段在新版本中已移除，使用默认值
        'user': 'builder',
        'display': deviceInfo.display,
        'isPhysicalDevice': deviceInfo.isPhysicalDevice,
      };
    } catch (e) {
      // 如果获取真实设备信息失败，返回默认值
      AppLogger.warning('Failed to get real device info, using defaults: $e');
      return {
        'platform': 'android',
        'version': '11',
        'apiLevel': 30,
        'manufacturer': 'Xiaomi',
        'model': 'Mi 11',
        'brand': 'Xiaomi',
        'device': 'venus',
        'product': 'venus',
        'board': 'venus',
        'hardware': 'qcom',
        'bootloader': 'unknown',
        'fingerprint': 'Xiaomi/venus/venus:11/RKQ1.200826.002/V12.5.1.0.RKBCNXM:user/release-keys',
        'host': 'c3-miui-ota-bd162.bj',
        'id': 'RKQ1.200826.002',
        'tags': 'release-keys',
        'type': 'user',
        'user': 'builder',
        'display': 'RKQ1.200826.002 test-keys',
        'isPhysicalDevice': true,
      };
    }
  }

  String _generateIMEI(Random random) {
    // 生成15位IMEI
    final tac = '35${random.nextInt(900000) + 100000}'; // 8位TAC
    final snr = '${random.nextInt(900000) + 100000}'; // 6位序列号
    final imei14 = tac + snr;
    
    // 计算校验位
    final checkDigit = _calculateLuhnChecksum(imei14);
    return imei14 + checkDigit.toString();
  }

  String _generateAndroidId(Random random) {
    final bytes = List.generate(8, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }

  String _generateMacAddress(Random random) {
    final bytes = List.generate(6, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
  }

  String _generateSerialNumber(Random random) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(10, (_) => chars[random.nextInt(chars.length)]).join('');
  }

  String _generateBuildId(Random random) {
    const prefixes = ['RKQ1', 'SKQ1', 'TKQ1', 'QKQ1'];
    final prefix = prefixes[random.nextInt(prefixes.length)];
    final date = '${random.nextInt(12) + 1}'.padLeft(2, '0') + 
                 '${random.nextInt(28) + 1}'.padLeft(2, '0') + 
                 '${random.nextInt(10) + 20}';
    final build = '${random.nextInt(1000) + 1}'.padLeft(3, '0');
    return '$prefix.$date.$build';
  }

  String _generateSystemFingerprint(Random random) {
    final manufacturers = ['Xiaomi', 'Samsung', 'Huawei', 'OnePlus', 'Oppo', 'Vivo'];
    final manufacturer = manufacturers[random.nextInt(manufacturers.length)];
    final device = _generateDevice(random);
    final buildId = _generateBuildId(random);
    
    return '$manufacturer/$device/$device:11/$buildId:user/release-keys';
  }

  String _generateBootId(Random random) {
    return List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join('');
  }

  String _generateProcVersion(Random random) {
    final version = '4.${random.nextInt(20) + 1}.${random.nextInt(100)}';
    return 'Linux version $version (builder@build-host) (gcc version 4.9.x) #1 SMP PREEMPT';
  }

  String _generateBasebandVersion(Random random) {
    return 'MPSS.AT.${random.nextInt(10) + 1}.${random.nextInt(10)}.c${random.nextInt(100) + 1}';
  }

  String _generateInnerVersion(Random random) {
    return 'V${random.nextInt(15) + 1}.${random.nextInt(10)}.${random.nextInt(10)}.0.RKBCNXM';
  }

  String _generateDisplayId(Random random) {
    return _generateBuildId(random) + ' test-keys';
  }

  String _generateHostName(Random random) {
    const prefixes = ['c3-miui-ota', 'build-server', 'android-build'];
    final prefix = prefixes[random.nextInt(prefixes.length)];
    return '$prefix-${random.nextInt(1000)}.bj';
  }

  String _generateBootloader(Random random) {
    return 'unknown';
  }

  String _generateHardware(Random random) {
    const hardwares = ['qcom', 'exynos', 'kirin', 'mediatek'];
    return hardwares[random.nextInt(hardwares.length)];
  }

  String _generateRadioVersion(Random random) {
    return 'MPSS.AT.${random.nextInt(10) + 1}.${random.nextInt(10)}.c${random.nextInt(100) + 1}';
  }

  String _generateDevice(Random random) {
    const devices = ['venus', 'star', 'mars', 'jupiter', 'saturn'];
    return devices[random.nextInt(devices.length)];
  }

  String _generateBoard(Random random) {
    return _generateDevice(random);
  }

  String _generateBrand(Random random) {
    const brands = ['Xiaomi', 'Samsung', 'Huawei', 'OnePlus', 'Oppo', 'Vivo'];
    return brands[random.nextInt(brands.length)];
  }

  String _generateModel(Random random) {
    const models = ['Mi 11', 'Galaxy S21', 'P40 Pro', 'OnePlus 9', 'Find X3', 'X60 Pro'];
    return models[random.nextInt(models.length)];
  }

  String _generateProduct(Random random) {
    return _generateDevice(random);
  }

  String _generateManufacturer(Random random) {
    return _generateBrand(random);
  }

  String _generateCpuAbi(Random random) {
    const abis = ['arm64-v8a', 'armeabi-v7a'];
    return abis[random.nextInt(abis.length)];
  }

  String _generateCpuAbi2(Random random) {
    return 'armeabi';
  }

  String _generateTags(Random random) {
    return 'release-keys';
  }

  String _generateType(Random random) {
    return 'user';
  }

  String _generateUser(Random random) {
    return 'builder';
  }

  String _generateRelease(Random random) {
    const releases = ['11', '12', '13'];
    return releases[random.nextInt(releases.length)];
  }

  String _generateSdk(Random random) {
    const sdks = ['30', '31', '32', '33'];
    return sdks[random.nextInt(sdks.length)];
  }

  String _generateIncremental(Random random) {
    return 'V${random.nextInt(15) + 1}.${random.nextInt(10)}.${random.nextInt(10)}.0.RKBCNXM';
  }

  String _generateCodename(Random random) {
    const codenames = ['REL', 'BETA'];
    return codenames[random.nextInt(codenames.length)];
  }

  Map<String, int> _generateScreenSize(Random random) {
    const resolutions = [
      {'width': 1080, 'height': 2400},
      {'width': 1440, 'height': 3200},
      {'width': 1080, 'height': 2340},
      {'width': 1080, 'height': 2280},
    ];
    return resolutions[random.nextInt(resolutions.length)];
  }

  double _generateDensity(Random random) {
    const densities = [2.75, 3.0, 3.5, 4.0];
    return densities[random.nextInt(densities.length)];
  }

  int _generateDensityDpi(Random random) {
    const dpis = [440, 480, 560, 640];
    return dpis[random.nextInt(dpis.length)];
  }

  double _generateXdpi(Random random) {
    return 440.0 + random.nextDouble() * 200;
  }

  double _generateYdpi(Random random) {
    return 440.0 + random.nextDouble() * 200;
  }

  double _generateScaledDensity(Random random) {
    return _generateDensity(random);
  }

  double _generateFontScale(Random random) {
    const scales = [1.0, 1.15, 1.3];
    return scales[random.nextInt(scales.length)];
  }

  int _calculateLuhnChecksum(String number) {
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

  Future<String> getUserAgent(String deviceId) async {
    // 检查缓存
    if (_userAgentCache.containsKey(deviceId)) {
      return _userAgentCache[deviceId]!;
    }

    final fingerprint = await getFingerprint(deviceId);
    final userAgent = _buildUserAgent(fingerprint);
    
    _userAgentCache[deviceId] = userAgent;
    return userAgent;
  }

  String _buildUserAgent(Map<String, dynamic> fingerprint) {
    final manufacturer = fingerprint['manufacturer'] ?? 'Xiaomi';
    final model = fingerprint['model'] ?? 'Mi 11';
    final version = fingerprint['version'] ?? '11';
    final buildId = fingerprint['buildId'] ?? 'RKQ1.200826.002';
    
    return 'Mozilla/5.0 (Linux; Android $version; $model Build/$buildId; wv) '
           'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 '
           'Chrome/91.0.4472.114 Mobile Safari/537.36 '
           'DamaiApp/8.6.2 ($manufacturer $model; Android $version)';
  }

  Future<Map<String, dynamic>> getFingerprint(String deviceId) async {
    return await generateFingerprint(deviceId);
  }

  void clearCache() {
    _fingerprintCache.clear();
    _userAgentCache.clear();
    AppLogger.info('Device fingerprint cache cleared');
  }

  // 生成设备指纹摘要（用于快速比较）
  String generateFingerprintHash(Map<String, dynamic> fingerprint) {
    final jsonString = jsonEncode(fingerprint);
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // 验证设备指纹完整性
  bool validateFingerprint(Map<String, dynamic> fingerprint) {
    final requiredFields = [
      'deviceId', 'imei', 'androidId', 'macAddress',
      'manufacturer', 'model', 'brand', 'version'
    ];
    
    for (final field in requiredFields) {
      if (!fingerprint.containsKey(field) || fingerprint[field] == null) {
        return false;
      }
    }
    
    return true;
  }
}