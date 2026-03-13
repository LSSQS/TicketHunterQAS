import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/platform_config.dart';
import '../utils/logger.dart';

/// Headless WebView 数据获取服务
/// 用于获取平台数据、模拟登录、执行JS脚本
/// 注意：Web平台不支持，需要移动端运行
class HeadlessWebViewService {
  static final HeadlessWebViewService _instance = HeadlessWebViewService._internal();
  factory HeadlessWebViewService() => _instance;
  HeadlessWebViewService._internal();
  
  // 平台 -> Cookie
  final Map<TicketPlatform, Map<String, String>> _platformCookies = {};
  
  // 初始化状态
  final Map<TicketPlatform, bool> _initialized = {};
  
  /// 初始化指定平台的 HeadlessWebView
  Future<bool> initialize(TicketPlatform platform) async {
    if (_initialized[platform] == true) return true;
    
    if (kIsWeb) {
      AppLogger.warning('HeadlessWebView is not supported on web platform');
      _initialized[platform] = false;
      return false;
    }
    
    // 非Web平台的初始化由native实现处理
    _initialized[platform] = true;
    return true;
  }
  
  /// 获取平台Cookie
  Map<String, String> getCookies(TicketPlatform platform) {
    return _platformCookies[platform] ?? {};
  }
  
  /// 设置平台Cookie
  Future<void> setCookies(TicketPlatform platform, Map<String, String> cookies, String domain) async {
    _platformCookies[platform] = {...?_platformCookies[platform], ...cookies};
    AppLogger.info('[${platform.name}] Set ${cookies.length} cookies');
  }
  
  /// 清除平台Cookie
  Future<void> clearCookies(TicketPlatform platform) async {
    _platformCookies[platform] = {};
    AppLogger.info('[${platform.name}] Cookies cleared');
  }
  
  /// 获取大麦演出列表 (Web返回空列表)
  Future<List<Map<String, dynamic>>> fetchDamaiShows({
    String keyword = '',
    int page = 1,
    int pageSize = 30,
  }) async {
    if (kIsWeb) {
      AppLogger.warning('fetchDamaiShows not supported on web');
      return [];
    }
    return [];
  }
  
  /// 获取猫眼演出列表 (Web返回空列表)
  Future<List<Map<String, dynamic>>> fetchMaoyanShows({
    int cityCode = 10,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (kIsWeb) {
      AppLogger.warning('fetchMaoyanShows not supported on web');
      return [];
    }
    return [];
  }
  
  /// 获取秀动演出列表 (Web返回空列表)
  Future<List<Map<String, dynamic>>> fetchXiudongShows({
    String cityId = '',
    int page = 1,
    int size = 20,
  }) async {
    if (kIsWeb) {
      AppLogger.warning('fetchXiudongShows not supported on web');
      return [];
    }
    return [];
  }
  
  /// 销毁指定平台的WebView
  Future<void> dispose(TicketPlatform platform) async {
    _initialized[platform] = false;
    AppLogger.info('HeadlessWebView disposed for ${platform.name}');
  }
  
  /// 销毁所有WebView
  Future<void> disposeAll() async {
    for (final platform in TicketPlatform.values) {
      await dispose(platform);
    }
  }
}
