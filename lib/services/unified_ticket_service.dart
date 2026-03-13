import 'dart:async';
import '../models/account.dart';
import '../models/show.dart';
import '../models/platform_config.dart';
import '../models/hunting_result.dart';
import '../models/concert.dart' as concert_model;
import '../utils/logger.dart';
import 'ticket_hunter_service.dart';
import 'maoyan_ticket_service.dart';
import 'platform_account_manager.dart';
import 'headless_webview_service.dart';

/// 统一抢票服务
/// 根据平台类型调用相应的抢票服务
class UnifiedTicketService {
  final TicketHunterService _damaiService = TicketHunterService();
  final MaoyanTicketService _maoyanService = MaoyanTicketService();
  final PlatformAccountManager _accountManager = PlatformAccountManager();
  final HeadlessWebViewService _webViewService = HeadlessWebViewService();
  
  /// 获取账号管理器
  PlatformAccountManager get accountManager => _accountManager;
  
  /// 获取WebView服务
  HeadlessWebViewService get webViewService => _webViewService;
  
  /// 初始化
  Future<void> initialize() async {
    await _accountManager.initialize();
  }

  /// 提交订单
  Future<HuntingResult> submitOrder({
    required Account account,
    required Show show,
    required sku,
    required Map<String, dynamic> params,
  }) async {
    AppLogger.info('Unified service submitting order for platform: ${show.platform}');
    
    switch (show.platform) {
      case TicketPlatform.damai:
        // 转换Show为Concert（向后兼容）
        final concert = _convertShowToConcert(show);
        return await _damaiService.submitOrder(
          account: account,
          concert: concert,
          sku: sku,
          params: params,
        );
        
      case TicketPlatform.maoyan:
      case TicketPlatform.xiudong:
        return await _maoyanService.submitOrder(
          account: account,
          show: show,
          sku: sku,
          params: params,
        );
    }
  }

  /// 搜索演出/电影
  Future<List<Map<String, dynamic>>> search({
    required TicketPlatform platform,
    required String keyword,
    Map<String, dynamic>? filters,
  }) async {
    AppLogger.info('Searching on platform: $platform, keyword: $keyword');
    
    switch (platform) {
      case TicketPlatform.damai:
        // 调用某卖搜索API（需要在TicketHunterService中添加）
        return await _searchDamai(keyword, filters);
        
      case TicketPlatform.maoyan:
      case TicketPlatform.xiudong:
        return await _maoyanService.searchMovies(keyword);
    }
  }

  /// 获取推荐/热门演出
  Future<List<Map<String, dynamic>>> getRecommendedShows(TicketPlatform platform) async {
    AppLogger.info('Fetching recommended shows for platform: $platform');
    
    switch (platform) {
      case TicketPlatform.damai:
        return await _damaiService.getTrendingShows();
        
      case TicketPlatform.maoyan:
      case TicketPlatform.xiudong:
        return await _maoyanService.getHotMovies();
    }
  }

  /// 获取详情
  Future<Map<String, dynamic>?> getDetail({
    required TicketPlatform platform,
    required String itemId,
  }) async {
    switch (platform) {
      case TicketPlatform.damai:
        return await _damaiService.getItemDetail(itemId);
        
      case TicketPlatform.maoyan:
      case TicketPlatform.xiudong:
        // 调用公共方法获取电影详情
        final movies = await _maoyanService.searchMovies(itemId);
        return movies.isNotEmpty ? movies.first : null;
    }
  }

  /// 批量抢票
  Future<List<HuntingResult>> batchSubmitOrders({
    required List<Account> accounts,
    required Show show,
    required TicketSku sku,
    required Map<String, dynamic> params,
  }) async {
    final results = <HuntingResult>[];
    final futures = <Future<HuntingResult>>[];

    // 并发提交订单
    for (final account in accounts) {
      final future = submitOrder(
        account: account,
        show: show,
        sku: sku,
        params: params,
      );
      futures.add(future);
    }

    // 等待所有结果
    final allResults = await Future.wait(futures);
    results.addAll(allResults);

    return results;
  }

  /// 智能抢票策略
  Future<HuntingResult> smartHunting({
    required List<Account> accounts,
    required Show show,
    required List<TicketSku> skus,
    required Map<String, dynamic> params,
  }) async {
    AppLogger.info('Starting smart hunting for show: ${show.name}');
    
    // 按优先级排序SKU
    final sortedSkus = List<TicketSku>.from(skus);
    sortedSkus.sort((a, b) => (b.priority?.index ?? 0).compareTo(a.priority?.index ?? 0));

    // 为每个SKU尝试抢票
    for (final sku in sortedSkus) {
      if (!sku.isEnabled) continue;

      AppLogger.info('Trying SKU: ${sku.name} with ${accounts.length} accounts');

      // 使用所有账号并发抢票
      final results = await batchSubmitOrders(
        accounts: accounts,
        show: show,
        sku: sku,
        params: params,
      );

      // 检查是否有成功的结果
      final successResults = results.where((r) => r.success).toList();
      if (successResults.isNotEmpty) {
        AppLogger.info('Smart hunting succeeded with SKU: ${sku.name}');
        return successResults.first;
      }

      // 检查是否被风控
      final blockedResults = results.where((r) => r.isBlocked).toList();
      if (blockedResults.length > accounts.length * 0.5) {
        AppLogger.warning('Too many accounts blocked, stopping smart hunting');
        return HuntingResult(
          success: false,
          message: '账号风控率过高，停止抢票',
          timestamp: DateTime.now(),
          isBlocked: true,
        );
      }

      // 短暂延迟后尝试下一个SKU
      await Future.delayed(Duration(milliseconds: params['skuRetryDelay'] ?? 500));
    }

    return HuntingResult(
      success: false,
      message: '所有SKU抢票失败',
      timestamp: DateTime.now(),
    );
  }

  /// 转换Show为Concert（向后兼容）
  concert_model.Concert _convertShowToConcert(Show show) {
    return concert_model.Concert(
      id: show.id,
      name: show.name,
      artist: show.artist ?? '',
      venue: show.venue,
      showTime: show.showTime,
      saleStartTime: show.saleStartTime,
      itemId: show.itemId,
      skus: show.skus.map((sku) => concert_model.TicketSku(
        skuId: sku.skuId,
        name: sku.name,
        price: sku.price,
        quantity: sku.quantity,
        priority: _convertTicketPriority(sku.priority),
        isEnabled: sku.isEnabled,
      )).toList(),
      status: _convertShowStatus(show.status),
      maxConcurrency: show.maxConcurrency,
      retryCount: show.retryCount,
      retryDelay: show.retryDelay,
      autoStart: show.autoStart,
      description: show.description,
      posterUrl: show.posterUrl,
      metadata: show.metadata,
      createdAt: show.createdAt,
      updatedAt: show.updatedAt,
    );
  }

  /// 转换状态枚举
  concert_model.ConcertStatus _convertShowStatus(ShowStatus status) {
    switch (status) {
      case ShowStatus.pending:
        return concert_model.ConcertStatus.pending;
      case ShowStatus.active:
        return concert_model.ConcertStatus.active;
      case ShowStatus.completed:
        return concert_model.ConcertStatus.completed;
      case ShowStatus.cancelled:
        return concert_model.ConcertStatus.cancelled;
    }
  }

  /// 转换票务优先级枚举
  concert_model.TicketPriority _convertTicketPriority(TicketPriority priority) {
    switch (priority) {
      case TicketPriority.low:
        return concert_model.TicketPriority.low;
      case TicketPriority.medium:
        return concert_model.TicketPriority.medium;
      case TicketPriority.high:
        return concert_model.TicketPriority.high;
    }
  }

  /// 大麦搜索（需要实现）
  Future<List<Map<String, dynamic>>> _searchDamai(
    String keyword,
    Map<String, dynamic>? filters,
  ) async {
    return await _damaiService.searchShows(keyword);
  }

  /// 获取平台配置
  PlatformConfig getPlatformConfig(TicketPlatform platform) {
    return PlatformConfig.getConfig(platform);
  }

  /// 检查平台可用性
  Future<bool> isPlatformAvailable(TicketPlatform platform) async {
    try {
      final config = getPlatformConfig(platform);
      // 简单的健康检查
      // TODO: 实现更完善的可用性检查
      return config.isEnabled;
    } catch (e) {
      AppLogger.error('Check platform availability failed', e);
      return false;
    }
  }
  
  // ============ 多平台账号管理方法 ============
  
  /// 获取平台所有账号
  List<Account> getAccounts(TicketPlatform platform) {
    return _accountManager.getAccounts(platform);
  }
  
  /// 获取平台可用账号
  List<Account> getAvailableAccounts(TicketPlatform platform) {
    return _accountManager.getAvailableAccounts(platform);
  }
  
  /// 获取下一个可用账号（轮询）
  Account? getNextAvailableAccount(TicketPlatform platform) {
    return _accountManager.getNextAvailableAccount(platform);
  }
  
  /// 获取最高优先级账号
  Account? getHighestPriorityAccount(TicketPlatform platform) {
    return _accountManager.getHighestPriorityAccount(platform);
  }
  
  /// 添加账号
  Future<bool> addAccount(Account account) async {
    return await _accountManager.addAccount(account);
  }
  
  /// 批量添加账号
  Future<int> addAccounts(List<Account> accounts) async {
    return await _accountManager.addAccounts(accounts);
  }
  
  // ============ HeadlessWebView 数据获取方法 ============
  
  /// 使用 WebView 获取平台演出数据
  Future<List<Map<String, dynamic>>> fetchShowsViaWebView({
    required TicketPlatform platform,
    String keyword = '',
  }) async {
    switch (platform) {
      case TicketPlatform.damai:
        return await _webViewService.fetchDamaiShows(keyword: keyword);
      case TicketPlatform.maoyan:
        return await _webViewService.fetchMaoyanShows();
      case TicketPlatform.xiudong:
        return await _webViewService.fetchXiudongShows();
    }
  }
  
  // ============ 支付相关方法 ============
  
  /// 创建支付订单
  Future<HuntingResult> createPayment({
    required Account account,
    required TicketPlatform platform,
    required String orderId,
    required double amount,
    String payChannel = 'alipay',
  }) async {
    AppLogger.info('Creating payment for order: $orderId, platform: $platform');
    
    try {
      switch (platform) {
        case TicketPlatform.damai:
          final result = await _damaiService.createPayment(
            account: account,
            orderId: orderId,
            amount: amount,
            payChannel: payChannel,
          );
          return HuntingResult(
            success: result.success,
            message: result.message,
            timestamp: DateTime.now(),
            orderId: orderId,
            payAmount: amount,
            payChannel: payChannel,
            payUrl: result.payUrl,
            payQrCode: result.qrCode,
            payStatus: result.success ? 'pending' : 'failed',
          );
          
        case TicketPlatform.maoyan:
        case TicketPlatform.xiudong:
          final result = await _maoyanService.createPayment(
            account: account,
            orderId: orderId,
            amount: amount,
            payChannel: payChannel,
          );
          return HuntingResult(
            success: result.success,
            message: result.message,
            timestamp: DateTime.now(),
            orderId: orderId,
            payAmount: amount,
            payChannel: payChannel,
            payUrl: result.payUrl,
            payQrCode: result.qrCode,
            payStatus: result.success ? 'pending' : 'failed',
          );
      }
    } catch (e) {
      AppLogger.error('Create payment failed', e);
      return HuntingResult(
        success: false,
        message: '创建支付失败: $e',
        timestamp: DateTime.now(),
        orderId: orderId,
        payStatus: 'failed',
      );
    }
  }
  
  /// 拉起手机支付
  Future<HuntingResult> launchMobilePay({
    required Account account,
    required TicketPlatform platform,
    required String orderId,
    required double amount,
    required String payType, // alipay, wechat
  }) async {
    AppLogger.info('Launching mobile pay for order: $orderId, type: $payType');
    
    try {
      switch (platform) {
        case TicketPlatform.damai:
          final result = await _damaiService.launchMobilePay(
            account: account,
            orderId: orderId,
            amount: amount,
            payType: payType,
          );
          return HuntingResult(
            success: result.success,
            message: result.message,
            timestamp: DateTime.now(),
            orderId: orderId,
            payAmount: amount,
            payChannel: payType,
            payUrl: result.payUrl,
            payStatus: result.success ? 'pending' : 'failed',
          );
          
        case TicketPlatform.maoyan:
        case TicketPlatform.xiudong:
          final result = await _maoyanService.launchMobilePay(
            account: account,
            orderId: orderId,
            amount: amount,
            payType: payType,
          );
          return HuntingResult(
            success: result.success,
            message: result.message,
            timestamp: DateTime.now(),
            orderId: orderId,
            payAmount: amount,
            payChannel: payType,
            payUrl: result.payUrl,
            payStatus: result.success ? 'pending' : 'failed',
          );
      }
    } catch (e) {
      AppLogger.error('Launch mobile pay failed', e);
      return HuntingResult(
        success: false,
        message: '拉起支付失败: $e',
        timestamp: DateTime.now(),
        orderId: orderId,
        payStatus: 'failed',
      );
    }
  }
  
  /// 查询支付状态
  Future<HuntingResult> queryPayment({
    required Account account,
    required TicketPlatform platform,
    required String orderId,
  }) async {
    AppLogger.info('Querying payment status for order: $orderId');
    
    try {
      switch (platform) {
        case TicketPlatform.damai:
          final result = await _damaiService.queryPayment(account, orderId);
          return HuntingResult(
            success: result.success,
            message: result.message,
            timestamp: DateTime.now(),
            orderId: orderId,
            payStatus: result.isPaid ? 'paid' : result.status,
            payAmount: result.data?['amount'] as double?,
          );
          
        case TicketPlatform.maoyan:
        case TicketPlatform.xiudong:
          final result = await _maoyanService.queryPayment(account, orderId);
          return HuntingResult(
            success: result.success,
            message: result.message,
            timestamp: DateTime.now(),
            orderId: orderId,
            payStatus: result.isPaid ? 'paid' : result.status,
            payAmount: result.data?['amount'] as double?,
          );
      }
    } catch (e) {
      AppLogger.error('Query payment failed', e);
      return HuntingResult(
        success: false,
        message: '查询支付状态失败: $e',
        timestamp: DateTime.now(),
        orderId: orderId,
        payStatus: 'unknown',
      );
    }
  }
}
