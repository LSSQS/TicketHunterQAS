import 'dart:async';
import 'package:dio/dio.dart';
import '../utils/logger.dart';

/// 短信接码平台服务
/// 集成多个接码平台
class SmsPlatformService {
  final Dio _dio = Dio();
  
  // 支持的接码平台
  static const List<SmsProvider> _providers = [
    SmsProvider.jieMaWang,
    SmsProvider.yiMaPing,
    SmsProvider.yuMa,
    SmsProvider.laiFenSms,
  ];
  
  // 当前使用的平台
  SmsProvider _currentProvider = SmsProvider.jieMaWang;
  
  // API配置
  final Map<SmsProvider, SmsConfig> _configs = {};
  
  SmsPlatformService() {
    _setupDio();
    _initializeConfigs();
  }
  
  void _setupDio() {
    _dio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    );
  }
  
  void _initializeConfigs() {
    // 接码王 - http://www.jiemawang.com/
    _configs[SmsProvider.jieMaWang] = SmsConfig(
      name: '接码王',
      apiUrl: 'http://api.jiemawang.com',
      apiKey: '', // 需要用户配置
    );
    
    // 易码平台 - http://www.yimaping.com/
    _configs[SmsProvider.yiMaPing] = SmsConfig(
      name: '易码平台',
      apiUrl: 'http://api.yimaping.com',
      apiKey: '', // 需要用户配置
    );
    
    // 域名 - http://www.yuma.cm/
    _configs[SmsProvider.yuMa] = SmsConfig(
      name: '域名',
      apiUrl: 'http://api.yuma.cm',
      apiKey: '', // 需要用户配置
    );
    
    // 来分短信 - http://www.laifensms.com/
    _configs[SmsProvider.laiFenSms] = SmsConfig(
      name: '来分短信',
      apiUrl: 'http://api.laifensms.com',
      apiKey: '', // 需要用户配置
    );
  }
  
  /// 配置API密钥
  void configureApiKey(SmsProvider provider, String apiKey) {
    if (_configs.containsKey(provider)) {
      _configs[provider]!.apiKey = apiKey;
      AppLogger.info('Configured API key for ${_configs[provider]!.name}');
    }
  }
  
  /// 设置当前使用的平台
  void setProvider(SmsProvider provider) {
    _currentProvider = provider;
    AppLogger.info('Switched to SMS provider: ${_configs[provider]?.name}');
  }
  
  /// 获取手机号
  Future<PhoneNumberResult> getPhoneNumber({
    required String projectType, // 项目类型，如 'damai', 'maoyan'
    SmsProvider? provider,
    String? area, // 区号，如 '86' 代表中国
  }) async {
    final useProvider = provider ?? _currentProvider;
    final config = _configs[useProvider];
    
    if (config == null || config.apiKey.isEmpty) {
      return PhoneNumberResult(
        success: false,
        message: '未配置${config?.name ?? ''}的API密钥',
      );
    }
    
    try {
      AppLogger.info('Getting phone number from ${config.name} for $projectType');
      
      final response = await _dio.post(
        '${config.apiUrl}/getPhone',
        data: {
          'token': config.apiKey,
          'project': projectType,
          'area': area ?? '86',
        },
      );
      
      return _parsePhoneNumberResponse(response, useProvider);
    } catch (e) {
      AppLogger.error('Failed to get phone number', e);
      return PhoneNumberResult(
        success: false,
        message: '获取手机号失败: $e',
      );
    }
  }
  
  /// 获取验证码
  Future<VerifyCodeResult> getVerifyCode({
    required String phoneNumber,
    required String projectType,
    SmsProvider? provider,
    int timeout = 60, // 超时时间（秒）
    int retryInterval = 5, // 重试间隔（秒）
  }) async {
    final useProvider = provider ?? _currentProvider;
    final config = _configs[useProvider];
    
    if (config == null || config.apiKey.isEmpty) {
      return VerifyCodeResult(
        success: false,
        message: '未配置${config?.name ?? ''}的API密钥',
      );
    }
    
    try {
      AppLogger.info('Getting verify code for $phoneNumber from ${config.name}');
      
      final startTime = DateTime.now();
      final endTime = startTime.add(Duration(seconds: timeout));
      
      while (DateTime.now().isBefore(endTime)) {
        final response = await _dio.post(
          '${config.apiUrl}/getMessage',
          data: {
            'token': config.apiKey,
            'phone': phoneNumber,
            'project': projectType,
          },
        );
        
        final result = _parseVerifyCodeResponse(response, useProvider);
        
        if (result.success) {
          return result;
        }
        
        // 如果还没有收到验证码，等待后重试
        if (!result.success && result.message.contains('未收到')) {
          await Future.delayed(Duration(seconds: retryInterval));
          continue;
        }
        
        // 其他错误直接返回
        return result;
      }
      
      return VerifyCodeResult(
        success: false,
        message: '获取验证码超时',
      );
    } catch (e) {
      AppLogger.error('Failed to get verify code', e);
      return VerifyCodeResult(
        success: false,
        message: '获取验证码失败: $e',
      );
    }
  }
  
  /// 释放手机号
  Future<bool> releasePhoneNumber({
    required String phoneNumber,
    SmsProvider? provider,
  }) async {
    final useProvider = provider ?? _currentProvider;
    final config = _configs[useProvider];
    
    if (config == null || config.apiKey.isEmpty) {
      return false;
    }
    
    try {
      AppLogger.info('Releasing phone number $phoneNumber from ${config.name}');
      
      final response = await _dio.post(
        '${config.apiUrl}/releasePhone',
        data: {
          'token': config.apiKey,
          'phone': phoneNumber,
        },
      );
      
      return response.data['code'] == 0 || response.data['success'] == true;
    } catch (e) {
      AppLogger.error('Failed to release phone number', e);
      return false;
    }
  }
  
  /// 拉黑手机号
  Future<bool> blacklistPhoneNumber({
    required String phoneNumber,
    SmsProvider? provider,
  }) async {
    final useProvider = provider ?? _currentProvider;
    final config = _configs[useProvider];
    
    if (config == null || config.apiKey.isEmpty) {
      return false;
    }
    
    try {
      AppLogger.info('Blacklisting phone number $phoneNumber from ${config.name}');
      
      final response = await _dio.post(
        '${config.apiUrl}/blackPhone',
        data: {
          'token': config.apiKey,
          'phone': phoneNumber,
        },
      );
      
      return response.data['code'] == 0 || response.data['success'] == true;
    } catch (e) {
      AppLogger.error('Failed to blacklist phone number', e);
      return false;
    }
  }
  
  /// 查询余额
  Future<double> queryBalance(SmsProvider? provider) async {
    final useProvider = provider ?? _currentProvider;
    final config = _configs[useProvider];
    
    if (config == null || config.apiKey.isEmpty) {
      return 0.0;
    }
    
    try {
      final response = await _dio.post(
        '${config.apiUrl}/getBalance',
        data: {'token': config.apiKey},
      );
      
      return (response.data['balance'] ?? 0.0).toDouble();
    } catch (e) {
      AppLogger.error('Failed to query balance', e);
      return 0.0;
    }
  }
  
  /// 获取支持的项目列表
  Future<List<Map<String, dynamic>>> getSupportedProjects(SmsProvider? provider) async {
    final useProvider = provider ?? _currentProvider;
    final config = _configs[useProvider];
    
    if (config == null || config.apiKey.isEmpty) {
      return [];
    }
    
    try {
      final response = await _dio.post(
        '${config.apiUrl}/getProjects',
        data: {'token': config.apiKey},
      );
      
      final projects = response.data['projects'] as List? ?? [];
      return projects.map((p) => Map<String, dynamic>.from(p)).toList();
    } catch (e) {
      AppLogger.error('Failed to get supported projects', e);
      return [];
    }
  }
  
  /// 解析手机号响应
  PhoneNumberResult _parsePhoneNumberResponse(Response response, SmsProvider provider) {
    try {
      final data = response.data;
      
      switch (provider) {
        case SmsProvider.jieMaWang:
          return _parseJieMaWangPhoneResponse(data);
        case SmsProvider.yiMaPing:
          return _parseYiMaPingPhoneResponse(data);
        case SmsProvider.yuMa:
          return _parseYuMaPhoneResponse(data);
        case SmsProvider.laiFenSms:
          return _parseLaiFenSmsPhoneResponse(data);
      }
    } catch (e) {
      AppLogger.error('Failed to parse phone number response', e);
      return PhoneNumberResult(
        success: false,
        message: '解析响应失败: $e',
      );
    }
  }
  
  /// 解析验证码响应
  VerifyCodeResult _parseVerifyCodeResponse(Response response, SmsProvider provider) {
    try {
      final data = response.data;
      
      switch (provider) {
        case SmsProvider.jieMaWang:
          return _parseJieMaWangCodeResponse(data);
        case SmsProvider.yiMaPing:
          return _parseYiMaPingCodeResponse(data);
        case SmsProvider.yuMa:
          return _parseYuMaCodeResponse(data);
        case SmsProvider.laiFenSms:
          return _parseLaiFenSmsCodeResponse(data);
      }
    } catch (e) {
      AppLogger.error('Failed to parse verify code response', e);
      return VerifyCodeResult(
        success: false,
        message: '解析响应失败: $e',
      );
    }
  }
  
  // 接码王响应解析
  PhoneNumberResult _parseJieMaWangPhoneResponse(dynamic data) {
    if (data['code'] == 0) {
      return PhoneNumberResult(
        success: true,
        phoneNumber: data['phone']?.toString() ?? '',
        message: '获取手机号成功',
      );
    }
    return PhoneNumberResult(
      success: false,
      message: data['msg'] ?? '获取手机号失败',
    );
  }
  
  VerifyCodeResult _parseJieMaWangCodeResponse(dynamic data) {
    if (data['code'] == 0 && data['sms'] != null) {
      return VerifyCodeResult(
        success: true,
        verifyCode: data['sms']?.toString() ?? '',
        message: '获取验证码成功',
      );
    }
    return VerifyCodeResult(
      success: false,
      message: data['msg'] ?? '未收到验证码',
    );
  }
  
  // 易码平台响应解析
  PhoneNumberResult _parseYiMaPingPhoneResponse(dynamic data) {
    if (data['success'] == true) {
      return PhoneNumberResult(
        success: true,
        phoneNumber: data['mobile']?.toString() ?? '',
        message: '获取手机号成功',
      );
    }
    return PhoneNumberResult(
      success: false,
      message: data['message'] ?? '获取手机号失败',
    );
  }
  
  VerifyCodeResult _parseYiMaPingCodeResponse(dynamic data) {
    if (data['success'] == true && data['code'] != null) {
      return VerifyCodeResult(
        success: true,
        verifyCode: data['code']?.toString() ?? '',
        message: '获取验证码成功',
      );
    }
    return VerifyCodeResult(
      success: false,
      message: data['message'] ?? '未收到验证码',
    );
  }
  
  // 域名响应解析
  PhoneNumberResult _parseYuMaPhoneResponse(dynamic data) {
    if (data['status'] == 200) {
      return PhoneNumberResult(
        success: true,
        phoneNumber: data['data']?['phone']?.toString() ?? '',
        message: '获取手机号成功',
      );
    }
    return PhoneNumberResult(
      success: false,
      message: data['msg'] ?? '获取手机号失败',
    );
  }
  
  VerifyCodeResult _parseYuMaCodeResponse(dynamic data) {
    if (data['status'] == 200 && data['data']?['sms'] != null) {
      return VerifyCodeResult(
        success: true,
        verifyCode: data['data']['sms']?.toString() ?? '',
        message: '获取验证码成功',
      );
    }
    return VerifyCodeResult(
      success: false,
      message: data['msg'] ?? '未收到验证码',
    );
  }
  
  // 来分短信响应解析
  PhoneNumberResult _parseLaiFenSmsPhoneResponse(dynamic data) {
    if (data['RetCode'] == 0) {
      return PhoneNumberResult(
        success: true,
        phoneNumber: data['Data']?.toString() ?? '',
        message: '获取手机号成功',
      );
    }
    return PhoneNumberResult(
      success: false,
      message: data['RetMsg'] ?? '获取手机号失败',
    );
  }
  
  VerifyCodeResult _parseLaiFenSmsCodeResponse(dynamic data) {
    if (data['RetCode'] == 0 && data['Data'] != null) {
      return VerifyCodeResult(
        success: true,
        verifyCode: data['Data']?.toString() ?? '',
        message: '获取验证码成功',
      );
    }
    return VerifyCodeResult(
      success: false,
      message: data['RetMsg'] ?? '未收到验证码',
    );
  }
  
  /// 获取支持的平台列表
  List<String> getSupportedProviders() {
    return _configs.keys.map((p) => _configs[p]!.name).toList();
  }
  
  /// 检查平台是否已配置
  bool isProviderConfigured(SmsProvider provider) {
    final config = _configs[provider];
    return config != null && config.apiKey.isNotEmpty;
  }
}

/// 短信提供商
enum SmsProvider {
  jieMaWang,   // 接码王
  yiMaPing,    // 易码平台
  yuMa,        // 域名
  laiFenSms,   // 来分短信
}

/// 短信配置
class SmsConfig {
  final String name;
  final String apiUrl;
  String apiKey;
  
  SmsConfig({
    required this.name,
    required this.apiUrl,
    required this.apiKey,
  });
}

/// 手机号结果
class PhoneNumberResult {
  final bool success;
  final String message;
  final String? phoneNumber;
  
  PhoneNumberResult({
    required this.success,
    required this.message,
    this.phoneNumber,
  });
}

/// 验证码结果
class VerifyCodeResult {
  final bool success;
  final String message;
  final String? verifyCode;
  
  VerifyCodeResult({
    required this.success,
    required this.message,
    this.verifyCode,
  });
}
