import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../utils/logger.dart';

/// 验证码识别服务
/// 集成多个第三方验证码识别平台
class CaptchaRecognitionService {
  final Dio _dio = Dio();
  
  // 支持的识别平台
  static const List<CaptchaProvider> _providers = [
    CaptchaProvider.tuChao,
    CaptchaProvider.jiJiMa,
    CaptchaProvider.chaoDaDaMa,
    CaptchaProvider.yiMa,
  ];
  
  // 当前使用的平台
  CaptchaProvider _currentProvider = CaptchaProvider.tuChao;
  
  // API配置
  final Map<CaptchaProvider, CaptchaConfig> _configs = {};
  
  CaptchaRecognitionService() {
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
    // 图超 - http://www.tuchao8.com/
    _configs[CaptchaProvider.tuChao] = CaptchaConfig(
      name: '图超',
      apiUrl: 'http://api.tuchao8.com/api/recognize',
      apiKey: '', // 需要用户配置
      supportedTypes: [
        CaptchaType.text,
        CaptchaType.click,
        CaptchaType.slide,
      ],
    );
    
    // 极简码 - http://www.jijima.com/
    _configs[CaptchaProvider.jiJiMa] = CaptchaConfig(
      name: '极简码',
      apiUrl: 'http://api.jijima.com/api/recognize',
      apiKey: '', // 需要用户配置
      supportedTypes: [
        CaptchaType.text,
        CaptchaType.click,
        CaptchaType.slide,
      ],
    );
    
    // 超打打码 - http://www.chaodadama.com/
    _configs[CaptchaProvider.chaoDaDaMa] = CaptchaConfig(
      name: '超打打码',
      apiUrl: 'http://api.chaodadama.com/api/recognize',
      apiKey: '', // 需要用户配置
      supportedTypes: [
        CaptchaType.text,
        CaptchaType.click,
      ],
    );
    
    // 易码 - http://www.yimacode.com/
    _configs[CaptchaProvider.yiMa] = CaptchaConfig(
      name: '易码',
      apiUrl: 'http://api.yimacode.com/api/recognize',
      apiKey: '', // 需要用户配置
      supportedTypes: [
        CaptchaType.text,
        CaptchaType.slide,
      ],
    );
  }
  
  /// 配置API密钥
  void configureApiKey(CaptchaProvider provider, String apiKey) {
    if (_configs.containsKey(provider)) {
      _configs[provider]!.apiKey = apiKey;
      AppLogger.info('Configured API key for ${_configs[provider]!.name}');
    }
  }
  
  /// 设置当前使用的平台
  void setProvider(CaptchaProvider provider) {
    _currentProvider = provider;
    AppLogger.info('Switched to captcha provider: ${_configs[provider]?.name}');
  }
  
  /// 识别文本验证码
  Future<CaptchaResult> recognizeText({
    required Uint8List imageBytes,
    CaptchaProvider? provider,
    int? length,
    bool? caseSensitive,
  }) async {
    final useProvider = provider ?? _currentProvider;
    final config = _configs[useProvider];
    
    if (config == null || config.apiKey.isEmpty) {
      return CaptchaResult(
        success: false,
        message: '未配置${config?.name ?? ''}的API密钥',
      );
    }
    
    try {
      AppLogger.info('Recognizing text captcha using ${config.name}');
      
      final base64Image = base64Encode(imageBytes);
      
      final response = await _dio.post(
        config.apiUrl,
        data: {
          'apiKey': config.apiKey,
          'type': 'text',
          'image': base64Image,
          'length': length,
          'caseSensitive': caseSensitive ?? false,
        },
      );
      
      return _parseResponse(response, useProvider);
    } catch (e) {
      AppLogger.error('Failed to recognize text captcha', e);
      return CaptchaResult(
        success: false,
        message: '识别失败: $e',
      );
    }
  }
  
  /// 识别滑块验证码
  Future<CaptchaResult> recognizeSlide({
    required Uint8List backgroundImage,
    required Uint8List sliderImage,
    CaptchaProvider? provider,
  }) async {
    final useProvider = provider ?? _currentProvider;
    final config = _configs[useProvider];
    
    if (config == null || config.apiKey.isEmpty) {
      return CaptchaResult(
        success: false,
        message: '未配置${config?.name ?? ''}的API密钥',
      );
    }
    
    try {
      AppLogger.info('Recognizing slide captcha using ${config.name}');
      
      final base64Background = base64Encode(backgroundImage);
      final base64Slider = base64Encode(sliderImage);
      
      final response = await _dio.post(
        config.apiUrl,
        data: {
          'apiKey': config.apiKey,
          'type': 'slide',
          'backgroundImage': base64Background,
          'sliderImage': base64Slider,
        },
      );
      
      return _parseResponse(response, useProvider);
    } catch (e) {
      AppLogger.error('Failed to recognize slide captcha', e);
      return CaptchaResult(
        success: false,
        message: '识别失败: $e',
      );
    }
  }
  
  /// 识别点选验证码
  Future<CaptchaResult> recognizeClick({
    required Uint8List imageBytes,
    required String question,
    CaptchaProvider? provider,
  }) async {
    final useProvider = provider ?? _currentProvider;
    final config = _configs[useProvider];
    
    if (config == null || config.apiKey.isEmpty) {
      return CaptchaResult(
        success: false,
        message: '未配置${config?.name ?? ''}的API密钥',
      );
    }
    
    try {
      AppLogger.info('Recognizing click captcha using ${config.name}');
      
      final base64Image = base64Encode(imageBytes);
      
      final response = await _dio.post(
        config.apiUrl,
        data: {
          'apiKey': config.apiKey,
          'type': 'click',
          'image': base64Image,
          'question': question,
        },
      );
      
      return _parseResponse(response, useProvider);
    } catch (e) {
      AppLogger.error('Failed to recognize click captcha', e);
      return CaptchaResult(
        success: false,
        message: '识别失败: $e',
      );
    }
  }
  
  /// 识别旋转验证码
  Future<CaptchaResult> recognizeRotate({
    required Uint8List imageBytes,
    CaptchaProvider? provider,
  }) async {
    final useProvider = provider ?? _currentProvider;
    final config = _configs[useProvider];
    
    if (config == null || config.apiKey.isEmpty) {
      return CaptchaResult(
        success: false,
        message: '未配置${config?.name ?? ''}的API密钥',
      );
    }
    
    try {
      AppLogger.info('Recognizing rotate captcha using ${config.name}');
      
      final base64Image = base64Encode(imageBytes);
      
      final response = await _dio.post(
        config.apiUrl,
        data: {
          'apiKey': config.apiKey,
          'type': 'rotate',
          'image': base64Image,
        },
      );
      
      return _parseResponse(response, useProvider);
    } catch (e) {
      AppLogger.error('Failed to recognize rotate captcha', e);
      return CaptchaResult(
        success: false,
        message: '识别失败: $e',
      );
    }
  }
  
  /// 自动识别（根据图片自动判断类型）
  Future<CaptchaResult> recognizeAuto({
    required Uint8List imageBytes,
    CaptchaProvider? provider,
  }) async {
    final useProvider = provider ?? _currentProvider;
    final config = _configs[useProvider];
    
    if (config == null || config.apiKey.isEmpty) {
      return CaptchaResult(
        success: false,
        message: '未配置${config?.name ?? ''}的API密钥',
      );
    }
    
    try {
      AppLogger.info('Auto recognizing captcha using ${config.name}');
      
      final base64Image = base64Encode(imageBytes);
      
      final response = await _dio.post(
        config.apiUrl,
        data: {
          'apiKey': config.apiKey,
          'type': 'auto',
          'image': base64Image,
        },
      );
      
      return _parseResponse(response, useProvider);
    } catch (e) {
      AppLogger.error('Failed to auto recognize captcha', e);
      return CaptchaResult(
        success: false,
        message: '识别失败: $e',
      );
    }
  }
  
  /// 解析响应
  CaptchaResult _parseResponse(Response response, CaptchaProvider provider) {
    try {
      final data = response.data;
      
      // 根据不同平台解析响应格式
      switch (provider) {
        case CaptchaProvider.tuChao:
          return _parseTuChaoResponse(data);
        case CaptchaProvider.jiJiMa:
          return _parseJiJiMaResponse(data);
        case CaptchaProvider.chaoDaDaMa:
          return _parseChaoDaDaMaResponse(data);
        case CaptchaProvider.yiMa:
          return _parseYiMaResponse(data);
      }
    } catch (e) {
      AppLogger.error('Failed to parse captcha response', e);
      return CaptchaResult(
        success: false,
        message: '解析响应失败: $e',
      );
    }
  }
  
  /// 解析图超响应
  CaptchaResult _parseTuChaoResponse(dynamic data) {
    if (data['code'] == 0 || data['success'] == true) {
      return CaptchaResult(
        success: true,
        message: '识别成功',
        result: data['data']?['result']?.toString() ?? '',
        taskId: data['data']?['taskId']?.toString(),
        confidence: (data['data']?['confidence'] ?? 0.0).toDouble(),
      );
    }
    
    return CaptchaResult(
      success: false,
      message: data['message'] ?? data['msg'] ?? '识别失败',
    );
  }
  
  /// 解析极简码响应
  CaptchaResult _parseJiJiMaResponse(dynamic data) {
    if (data['status'] == 200 || data['code'] == 0) {
      return CaptchaResult(
        success: true,
        message: '识别成功',
        result: data['result']?.toString() ?? '',
        taskId: data['taskId']?.toString(),
        confidence: (data['confidence'] ?? 0.0).toDouble(),
      );
    }
    
    return CaptchaResult(
      success: false,
      message: data['msg'] ?? data['message'] ?? '识别失败',
    );
  }
  
  /// 解析超打打码响应
  CaptchaResult _parseChaoDaDaMaResponse(dynamic data) {
    if (data['RetCode'] == 0 || data['success'] == true) {
      return CaptchaResult(
        success: true,
        message: '识别成功',
        result: data['Data']?.toString() ?? '',
        taskId: data['TaskId']?.toString(),
        confidence: (data['Score'] ?? 0.0).toDouble(),
      );
    }
    
    return CaptchaResult(
      success: false,
      message: data['RetMsg'] ?? '识别失败',
    );
  }
  
  /// 解析易码响应
  CaptchaResult _parseYiMaResponse(dynamic data) {
    if (data['code'] == 200) {
      return CaptchaResult(
        success: true,
        message: '识别成功',
        result: data['data']?.toString() ?? '',
        taskId: data['id']?.toString(),
      );
    }
    
    return CaptchaResult(
      success: false,
      message: data['message'] ?? '识别失败',
    );
  }
  
  /// 查询余额
  Future<double> queryBalance(CaptchaProvider? provider) async {
    final useProvider = provider ?? _currentProvider;
    final config = _configs[useProvider];
    
    if (config == null || config.apiKey.isEmpty) {
      return 0.0;
    }
    
    try {
      final response = await _dio.post(
        config.apiUrl.replaceAll('/recognize', '/balance'),
        data: {'apiKey': config.apiKey},
      );
      
      return (response.data['balance'] ?? 0.0).toDouble();
    } catch (e) {
      AppLogger.error('Failed to query balance', e);
      return 0.0;
    }
  }
  
  /// 获取支持的平台列表
  List<String> getSupportedProviders() {
    return _configs.keys.map((p) => _configs[p]!.name).toList();
  }
  
  /// 检查平台是否已配置
  bool isProviderConfigured(CaptchaProvider provider) {
    final config = _configs[provider];
    return config != null && config.apiKey.isNotEmpty;
  }
}

/// 验证码提供商
enum CaptchaProvider {
  tuChao,      // 图超
  jiJiMa,      // 极简码
  chaoDaDaMa,  // 超打打码
  yiMa,        // 易码
}

/// 验证码类型
enum CaptchaType {
  text,    // 文本验证码
  slide,   // 滑块验证码
  click,   // 点选验证码
  rotate,  // 旋转验证码
}

/// 验证码配置
class CaptchaConfig {
  final String name;
  final String apiUrl;
  String apiKey;
  final List<CaptchaType> supportedTypes;
  
  CaptchaConfig({
    required this.name,
    required this.apiUrl,
    required this.apiKey,
    required this.supportedTypes,
  });
}

/// 验证码识别结果
class CaptchaResult {
  final bool success;
  final String message;
  final String? result;
  final String? taskId;
  final double? confidence;
  final Map<String, dynamic>? extra;
  
  CaptchaResult({
    required this.success,
    required this.message,
    this.result,
    this.taskId,
    this.confidence,
    this.extra,
  });
}
