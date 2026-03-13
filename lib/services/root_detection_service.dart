import 'dart:io';
import 'package:flutter/services.dart';
import '../utils/logger.dart';

/// Root检测服务
/// 检测设备是否已Root/越狱
class RootDetectionService {
  static const MethodChannel _channel = MethodChannel('com.damai.ticket_hunter/root_detection');
  
  // Root相关文件路径
  static const List<String> _rootFiles = [
    '/system/app/Superuser.apk',
    '/sbin/su',
    '/system/bin/su',
    '/system/xbin/su',
    '/data/local/xbin/su',
    '/data/local/bin/su',
    '/system/sd/xbin/su',
    '/system/bin/failsafe/su',
    '/data/local/su',
    '/su/bin/su',
    '/system/xbin/daemonsu',
    '/system/etc/init.d/99SuperSUDaemon',
    '/system/bin/.ext/.su',
    '/system/usr/we-need-root/su-backup',
    '/system/xbin/mu',
  ];
  
  // Root相关应用包名
  static const List<String> _rootApps = [
    'com.noshufou.android.su',
    'com.noshufou.android.su.elite',
    'eu.chainfire.supersu',
    'com.koushikdutta.superuser',
    'com.thirdparty.superuser',
    'com.yellowes.su',
    'com.topjohnwu.magisk',
    'com.kingroot.kinguser',
    'com.kingo.root',
    'com.smedialink.oneclickroot',
    'com.zhiqupk.root.global',
    'com.alephzain.framaroot',
  ];
  
  // Root相关属性
  static const List<String> _rootProperties = [
    'ro.secure',
    'ro.debuggable',
    'service.adb.root',
    'ro.build.selinux',
  ];
  
  /// 综合检测是否Root
  static Future<RootDetectionResult> detectRoot() async {
    AppLogger.info('Starting root detection');
    
    final results = <String, bool>{};
    
    // 检测方法1: 文件检测
    results['fileCheck'] = await _checkRootFiles();
    
    // 检测方法2: 应用检测
    results['appCheck'] = await _checkRootApps();
    
    // 检测方法3: 系统属性检测
    results['propertyCheck'] = await _checkRootProperties();
    
    // 检测方法4: su命令检测
    results['suCheck'] = await _checkSuCommand();
    
    // 检测方法5: Native层检测
    results['nativeCheck'] = await _checkRootNative();
    
    // 检测方法6: busybox检测
    results['busyboxCheck'] = await _checkBusybox();
    
    // 计算检测结果
    final rootedCount = results.values.where((v) => v).length;
    final isRooted = rootedCount >= 2; // 至少2个方法检测到Root
    final confidence = rootedCount / results.length;
    
    final result = RootDetectionResult(
      isRooted: isRooted,
      confidence: confidence,
      detectionMethods: results,
      details: _generateDetails(results),
    );
    
    AppLogger.info('Root detection result: ${result.isRooted} (confidence: ${result.confidence})');
    
    return result;
  }
  
  /// 检测Root文件
  static Future<bool> _checkRootFiles() async {
    try {
      for (final path in _rootFiles) {
        final file = File(path);
        if (await file.exists()) {
          AppLogger.warning('Root file detected: $path');
          return true;
        }
      }
      return false;
    } catch (e) {
      AppLogger.error('Root file check failed', e);
      return false;
    }
  }
  
  /// 检测Root应用
  static Future<bool> _checkRootApps() async {
    try {
      // 通过Platform Channel调用Native方法检测应用
      final result = await _channel.invokeMethod('checkRootApps', {
        'packages': _rootApps,
      });
      
      if (result == true) {
        AppLogger.warning('Root app detected');
      }
      
      return result == true;
    } catch (e) {
      // 如果Platform Channel不可用，尝试文件检测
      return await _checkRootAppsByFile();
    }
  }
  
  /// 通过文件检测Root应用
  static Future<bool> _checkRootAppsByFile() async {
    try {
      for (final pkg in _rootApps) {
        final path = '/data/data/$pkg';
        final dir = Directory(path);
        if (await dir.exists()) {
          AppLogger.warning('Root app directory detected: $path');
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// 检测系统属性
  static Future<bool> _checkRootProperties() async {
    try {
      final result = await _channel.invokeMethod('checkProperties', {
        'properties': _rootProperties,
      });
      
      if (result == true) {
        AppLogger.warning('Suspicious system property detected');
      }
      
      return result == true;
    } catch (e) {
      AppLogger.error('Property check failed', e);
      return false;
    }
  }
  
  /// 检测su命令
  static Future<bool> _checkSuCommand() async {
    try {
      // 尝试执行which su命令
      final result = await Process.run('which', ['su']);
      
      if (result.exitCode == 0 && result.stdout.toString().isNotEmpty) {
        AppLogger.warning('su command detected: ${result.stdout}');
        return true;
      }
      
      // 尝试执行su --version命令
      final versionResult = await Process.run('su', ['--version']).timeout(
        const Duration(seconds: 2),
        onTimeout: () => ProcessResult(0, 1, '', ''),
      );
      
      if (versionResult.exitCode == 0) {
        AppLogger.warning('su version command successful');
        return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// Native层检测
  static Future<bool> _checkRootNative() async {
    try {
      final result = await _channel.invokeMethod('checkRootNative');
      
      if (result == true) {
        AppLogger.warning('Native root check detected root');
      }
      
      return result == true;
    } catch (e) {
      AppLogger.error('Native root check failed', e);
      return false;
    }
  }
  
  /// 检测busybox
  static Future<bool> _checkBusybox() async {
    try {
      final paths = [
        '/system/xbin/busybox',
        '/system/bin/busybox',
        '/data/local/xbin/busybox',
        '/data/local/bin/busybox',
        '/sbin/busybox',
      ];
      
      for (final path in paths) {
        final file = File(path);
        if (await file.exists()) {
          AppLogger.warning('Busybox detected: $path');
          return true;
        }
      }
      
      // 尝试执行busybox命令
      try {
        final result = await Process.run('busybox', ['--help']).timeout(
          const Duration(seconds: 2),
          onTimeout: () => ProcessResult(0, 1, '', ''),
        );
        
        if (result.exitCode == 0) {
          AppLogger.warning('Busybox command successful');
          return true;
        }
      } catch (e) {
        // Ignore
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// 检测Magisk
  static Future<bool> detectMagisk() async {
    try {
      // 检测Magisk应用
      final magiskApps = [
        'com.topjohnwu.magisk',
        'io.github.huskydg.magisk',
      ];
      
      for (final pkg in magiskApps) {
        final path = '/data/data/$pkg';
        final dir = Directory(path);
        if (await dir.exists()) {
          AppLogger.warning('Magisk app detected: $pkg');
          return true;
        }
      }
      
      // 检测Magisk文件
      final magiskFiles = [
        '/sbin/.magisk',
        '/data/adb/magisk',
        '/cache/.disable_magisk',
        '/dev/.magisk',
      ];
      
      for (final path in magiskFiles) {
        final file = File(path);
        if (await file.exists()) {
          AppLogger.warning('Magisk file detected: $path');
          return true;
        }
        
        final dir = Directory(path);
        if (await dir.exists()) {
          AppLogger.warning('Magisk directory detected: $path');
          return true;
        }
      }
      
      return false;
    } catch (e) {
      AppLogger.error('Magisk detection failed', e);
      return false;
    }
  }
  
  /// 检测Xposed框架
  static Future<bool> detectXposed() async {
    try {
      final xposedFiles = [
        '/system/framework/XposedBridge.jar',
        '/system/lib/libxposed_art.so',
        '/system/lib/libxposed_dalvik.so',
        '/system/xbin/xposed',
        '/data/data/de.robv.android.xposed.installer',
        '/data/data/org.meowcat.edxposed.manager',
      ];
      
      for (final path in xposedFiles) {
        final file = File(path);
        if (await file.exists()) {
          AppLogger.warning('Xposed file detected: $path');
          return true;
        }
        
        final dir = Directory(path);
        if (await dir.exists()) {
          AppLogger.warning('Xposed directory detected: $path');
          return true;
        }
      }
      
      return false;
    } catch (e) {
      AppLogger.error('Xposed detection failed', e);
      return false;
    }
  }
  
  /// 检测模拟器
  static Future<EmulatorDetectionResult> detectEmulator() async {
    try {
      final result = await _channel.invokeMethod('checkEmulator');
      
      final isEmulator = result['isEmulator'] == true;
      final emulatorType = result['type']?.toString();
      
      if (isEmulator) {
        AppLogger.warning('Emulator detected: $emulatorType');
      }
      
      return EmulatorDetectionResult(
        isEmulator: isEmulator,
        emulatorType: emulatorType,
      );
    } catch (e) {
      AppLogger.error('Emulator detection failed', e);
      return EmulatorDetectionResult(
        isEmulator: false,
        emulatorType: null,
      );
    }
  }
  
  /// 生成检测详情
  static String _generateDetails(Map<String, bool> results) {
    final detectedMethods = results.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    
    if (detectedMethods.isEmpty) {
      return '未检测到Root特征';
    }
    
    return '检测到Root特征: ${detectedMethods.join(', ')}';
  }
  
  /// 快速检测（只用关键方法）
  static Future<bool> quickCheck() async {
    try {
      // 只检测关键文件
      for (final path in ['/system/bin/su', '/system/xbin/su', '/sbin/su']) {
        if (await File(path).exists()) {
          return true;
        }
      }
      
      // 检测关键应用
      for (final pkg in ['com.topjohnwu.magisk', 'eu.chainfire.supersu']) {
        if (await Directory('/data/data/$pkg').exists()) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
}

/// Root检测结果
class RootDetectionResult {
  final bool isRooted;
  final double confidence;
  final Map<String, bool> detectionMethods;
  final String details;
  
  RootDetectionResult({
    required this.isRooted,
    required this.confidence,
    required this.detectionMethods,
    required this.details,
  });
  
  @override
  String toString() {
    return 'RootDetectionResult(isRooted: $isRooted, confidence: ${(confidence * 100).toStringAsFixed(1)}%, details: $details)';
  }
}

/// 模拟器检测结果
class EmulatorDetectionResult {
  final bool isEmulator;
  final String? emulatorType;
  
  EmulatorDetectionResult({
    required this.isEmulator,
    this.emulatorType,
  });
  
  @override
  String toString() {
    return 'EmulatorDetectionResult(isEmulator: $isEmulator, type: $emulatorType)';
  }
}
