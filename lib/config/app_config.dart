import 'dart:convert';
import 'package:flutter/services.dart';
import '../utils/logger.dart';

/// 应用配置管理
/// 集中管理所有应用级配置：加密密钥、API密钥等
class AppConfig {
  static AppConfig? _instance;
  static AppConfig get instance => _instance ??= AppConfig._();
  
  AppConfig._();
  
  // ========== 安全配置 ==========
  
  /// 存储加密密钥（用于本地数据加密）
  static const String storageEncryptionKey = 'DamaiHunter2024SecretKey1234567890';
  
  /// 存储加密IV
  static const String storageEncryptionIv = '1234567890123456';
  
  /// RSA公钥配置（运行时可更新）
  String? _rsaPublicKey;
  String? _rsaPrivateKey;
  
  // ========== API密钥配置 ==========
  
  final Map<String, String> _apiKeys = {};
  
  // ========== 平台配置 ==========
  
  final Map<String, dynamic> _platformConfig = {};
  
  // ========== 网络配置 ==========
  
  /// 默认连接超时（秒）
  static const int defaultConnectTimeout = 10;
  
  /// 默认接收超时（秒）
  static const int defaultReceiveTimeout = 15;
  
  /// 抢票模式连接超时（秒）
  static const int huntingConnectTimeout = 5;
  
  /// 抢票模式接收超时（秒）
  static const int huntingReceiveTimeout = 10;
  
  // ========== 抢票配置 ==========
  
  /// 默认最大并发数
  static const int defaultMaxConcurrency = 50;
  
  /// 默认重试次数
  static const int defaultRetryCount = 5;
  
  /// 默认重试延迟（毫秒）
  static const int defaultRetryDelay = 100;
  
  bool _initialized = false;
  
  /// 初始化配置
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // 加载配置文件
      await _loadConfig();
      
      _initialized = true;
      AppLogger.info('App config initialized');
    } catch (e) {
      AppLogger.error('Failed to initialize app config', e);
    }
  }
  
  /// 加载配置文件
  Future<void> _loadConfig() async {
    try {
      // 尝试加载config.json
      final configString = await rootBundle.loadString('assets/config/config.json');
      final config = jsonDecode(configString) as Map<String, dynamic>;
      
      // 加载RSA密钥
      if (config['rsa'] != null) {
        _rsaPublicKey = config['rsa']['publicKey'];
        _rsaPrivateKey = config['rsa']['privateKey'];
      }
      
      // 加载API密钥
      if (config['apiKeys'] != null) {
        final apiKeys = config['apiKeys'] as Map<String, dynamic>;
        apiKeys.forEach((key, value) {
          _apiKeys[key] = value.toString();
        });
      }
      
      // 加载平台配置
      if (config['platforms'] != null) {
        _platformConfig.addAll(config['platforms'] as Map<String, dynamic>);
      }
      
      AppLogger.info('Config loaded successfully');
    } catch (e) {
      AppLogger.warning('Failed to load config.json, using defaults: $e');
      // 使用默认配置
      _loadDefaultConfig();
    }
  }
  
  /// 加载默认配置
  void _loadDefaultConfig() {
    // 默认配置可以为空，由用户在运行时配置
    AppLogger.info('Using default config');
  }
  
  // Getters
  String? get rsaPublicKey => _rsaPublicKey;
  String? get rsaPrivateKey => _rsaPrivateKey;
  
  String? getApiKey(String provider) => _apiKeys[provider];
  
  dynamic getPlatformConfig(String platform, String key) {
    final platformData = _platformConfig[platform];
    if (platformData is Map) {
      return platformData[key];
    }
    return null;
  }
  
  // Setters
  void setRsaPublicKey(String key) {
    _rsaPublicKey = key;
    AppLogger.info('RSA public key updated');
  }
  
  void setRsaPrivateKey(String key) {
    _rsaPrivateKey = key;
    AppLogger.info('RSA private key updated');
  }
  
  void setApiKey(String provider, String apiKey) {
    _apiKeys[provider] = apiKey;
    AppLogger.info('API key updated for provider: $provider');
  }
  
  void setPlatformConfig(String platform, String key, dynamic value) {
    if (!_platformConfig.containsKey(platform)) {
      _platformConfig[platform] = {};
    }
    (_platformConfig[platform] as Map)[key] = value;
    AppLogger.info('Platform config updated: $platform.$key');
  }
  
  /// 保存配置到本地
  Future<void> saveConfig() async {
    // TODO: 实现配置持久化到SharedPreferences或安全存储
    AppLogger.info('Config saved (not implemented yet)');
  }
  
  /// 清除所有配置
  void clearConfig() {
    _rsaPublicKey = null;
    _rsaPrivateKey = null;
    _apiKeys.clear();
    _platformConfig.clear();
    AppLogger.info('Config cleared');
  }
  
  /// 检查配置是否完整
  bool isConfigured() {
    return _rsaPublicKey != null && _rsaPublicKey!.isNotEmpty;
  }
  
  /// 获取所有配置的JSON表示
  Map<String, dynamic> toJson() {
    return {
      'rsa': {
        'publicKey': _rsaPublicKey,
        // 注意：私钥不应该导出
      },
      'apiKeys': _apiKeys,
      'platforms': _platformConfig,
    };
  }
}
