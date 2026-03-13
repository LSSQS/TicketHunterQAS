import 'package:flutter/foundation.dart';
import '../models/show.dart';
import '../models/account.dart';
import '../models/platform_config.dart';
import '../models/hunting_result.dart';
import '../services/unified_ticket_service.dart';
import '../services/platform_account_manager.dart';
import '../services/headless_webview_service.dart';

enum TicketHunterStatus {
  idle,
  running,
  paused,
  error,
  success,
  paying,      // 支付中
  paid,        // 支付完成
}

class TicketHunterProvider extends ChangeNotifier {
  final UnifiedTicketService _ticketService;
  final PlatformAccountManager _accountManager = PlatformAccountManager();
  final HeadlessWebViewService _webViewService = HeadlessWebViewService();
  
  bool _initialized = false;
  
  TicketHunterProvider({UnifiedTicketService? ticketService}) 
      : _ticketService = ticketService ?? UnifiedTicketService();
  
  /// 初始化
  Future<void> initialize() async {
    if (_initialized) return;
    await _accountManager.initialize();
    _initialized = true;
    notifyListeners();
  }
  
  /// 获取账号管理器
  PlatformAccountManager get accountManager => _accountManager;
  
  /// 获取WebView服务
  HeadlessWebViewService get webViewService => _webViewService;
  
  TicketHunterStatus _status = TicketHunterStatus.idle;
  Show? _currentShow;
  double _progress = 0.0;
  String _statusMessage = '准备就绪';
  int _attemptCount = 0;
  int _successCount = 0;
  int _errorCount = 0;
  int _totalAttempts = 0;
  int _totalSuccesses = 0;
  int _totalErrors = 0;
  bool _isHunting = false;
  
  // 支付相关
  String? _lastOrderId;
  String? _payUrl;
  String? _payQrCode;
  double? _payAmount;
  String? _payChannel;
  Account? _payAccount;
  
  // 抢票日志
  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  // Getters
  TicketHunterStatus get status => _status;
  Show? get currentShow => _currentShow;
  double get progress => _progress;
  String get statusMessage => _statusMessage;
  int get attemptCount => _attemptCount;
  int get successCount => _successCount;
  int get errorCount => _errorCount;
  int get totalAttempts => _totalAttempts;
  int get totalSuccesses => _totalSuccesses;
  int get totalErrors => _totalErrors;
  bool get isHunting => _isHunting;
  
  // 支付相关 Getters
  String? get lastOrderId => _lastOrderId;
  String? get payUrl => _payUrl;
  String? get payQrCode => _payQrCode;
  double? get payAmount => _payAmount;
  String? get payChannel => _payChannel;
  
  // 兼容性属性
  int get activeTasks => _isHunting ? 1 : 0;
  int get failureCount => _errorCount;

  /// 开始抢票
  Future<void> startHunting({
    required Show show,
    TicketSku? sku,
    required List<Account> accounts,
    Map<String, dynamic>? params,
  }) async {
    if (_isHunting) return;

    _isHunting = true;
    _status = TicketHunterStatus.running;
    _currentShow = show;
    _progress = 0.0;
    _statusMessage = '正在初始化抢票任务...';
    _attemptCount = 0;
    _successCount = 0;
    _errorCount = 0;
    _logs.clear();
    _addLog('开始抢票任务: ${show.name}');
    notifyListeners();

    try {
      while (_isHunting) {
        _attemptCount++;
        _totalAttempts++;
        _statusMessage = '正在进行第 $_attemptCount 次尝试...';
        _progress = (_attemptCount % 100) / 100.0; // 简单的进度条动画
        notifyListeners();

        HuntingResult result;
        
        // 构建参数
        final taskParams = Map<String, dynamic>.from(params ?? {});
        taskParams['retryCount'] = show.retryCount;
        
        if (sku != null) {
          _addLog('尝试抢购 SKU: ${sku.name}, 账号数: ${accounts.length}');
          // 单 SKU 批量抢票
          final results = await _ticketService.batchSubmitOrders(
            accounts: accounts,
            show: show,
            sku: sku,
            params: taskParams,
          );
          
          // 汇总结果
          final successResults = results.where((r) => r.success).toList();
          if (successResults.isNotEmpty) {
            result = successResults.first;
          } else {
            // 优先展示被风控的错误，或者是第一个错误
            result = results.firstWhere(
              (r) => r.isBlocked, 
              orElse: () => results.first
            );
          }
        } else {
          _addLog('智能抢购 (多SKU扫描)...');
          // 智能抢票（多 SKU）
          result = await _ticketService.smartHunting(
            accounts: accounts,
            show: show,
            skus: show.skus,
            params: taskParams,
          );
        }

        if (result.success) {
          _successCount++;
          _totalSuccesses++;
          _lastOrderId = result.orderId;
          _statusMessage = '抢票成功！订单号: ${result.orderId}';
          _addLog('✅ 抢票成功! 订单号: ${result.orderId}');
          
          // 自动触发支付流程
          if (result.orderId != null && sku != null && accounts.isNotEmpty) {
            _addLog('💰 自动发起支付...');
            await _autoPay(
              account: accounts.first,
              platform: show.platform,
              orderId: result.orderId!,
              amount: sku.price,
              skuName: sku.name,
            );
          }
          
          _status = TicketHunterStatus.success;
          _isHunting = false;
          notifyListeners();
          return;
        } else {
          _errorCount++;
          _totalErrors++;
          
          if (result.isBlocked) {
            _statusMessage = '账号风控: ${result.message}';
            _addLog('⚠️ 账号被风控: ${result.message}');
            
            // 如果所有账号都被风控，则暂停
            // 这里简化逻辑，只要有一个返回风控就记录，实际可以根据比例判断
            // 在 smartHunting 中已经有比例判断逻辑
             if (result.message.contains('停止抢票')) {
                _status = TicketHunterStatus.paused;
                _isHunting = false;
                notifyListeners();
                return;
             }
          } else {
            _statusMessage = '尝试失败: ${result.message}';
            _addLog('❌ 失败: ${result.message}');
          }
        }
        
        // 检查是否手动停止
        if (!_isHunting) break;

        // 失败后延迟重试
        final delayMs = show.retryDelay.inMilliseconds > 0 ? show.retryDelay.inMilliseconds : 1000;
        _addLog('等待 ${delayMs}ms 后重试...');
        await Future.delayed(Duration(milliseconds: delayMs));
      }

    } catch (e, stackTrace) {
      _errorCount++;
      _totalErrors++;
      _status = TicketHunterStatus.error;
      _statusMessage = '系统异常: $e';
      _addLog('🔴 系统异常: $e');
      debugPrint('Hunting error: $e\n$stackTrace');
      _isHunting = false;
    } finally {
      if (_status == TicketHunterStatus.running && !_isHunting) {
        _status = TicketHunterStatus.idle;
      }
      notifyListeners();
    }
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().split('.')[0];
    _logs.insert(0, '[$timestamp] $message');
    if (_logs.length > 100) {
      _logs.removeLast();
    }
    notifyListeners();
  }

  /// 停止抢票
  void stopHunting() {
    _isHunting = false;
    _status = TicketHunterStatus.idle;
    _statusMessage = '已停止';
    notifyListeners();
  }

  /// 暂停抢票
  void pauseHunting() {
    if (_status == TicketHunterStatus.running) {
      _status = TicketHunterStatus.paused;
      _statusMessage = '已暂停';
      notifyListeners();
    }
  }

  /// 恢复抢票
  void resumeHunting() {
    if (_status == TicketHunterStatus.paused) {
      _status = TicketHunterStatus.running;
      _statusMessage = '继续抢票...';
      notifyListeners();
    }
  }

  /// 重置统计
  void resetStats() {
    _totalAttempts = 0;
    _totalSuccesses = 0;
    _totalErrors = 0;
    notifyListeners();
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
  
  /// 添加账号
  Future<bool> addAccount(Account account) async {
    final result = await _accountManager.addAccount(account);
    notifyListeners();
    return result;
  }
  
  /// 批量添加账号
  Future<int> addAccounts(List<Account> accounts) async {
    final count = await _accountManager.addAccounts(accounts);
    notifyListeners();
    return count;
  }
  
  /// 移除账号
  Future<bool> removeAccount(String accountId, TicketPlatform platform) async {
    final result = await _accountManager.removeAccount(accountId, platform);
    notifyListeners();
    return result;
  }
  
  /// 更新账号
  Future<bool> updateAccount(Account account) async {
    final result = await _accountManager.updateAccount(account);
    notifyListeners();
    return result;
  }
  
  /// 获取账号统计
  Map<TicketPlatform, int> getAccountStats() {
    return _accountManager.getAccountStats();
  }
  
  // ============ HeadlessWebView 数据获取方法 ============
  
  /// 使用 WebView 获取平台演出数据
  Future<List<Map<String, dynamic>>> fetchShows({
    required TicketPlatform platform,
    String? keyword,
  }) async {
    switch (platform) {
      case TicketPlatform.damai:
        return await _webViewService.fetchDamaiShows(keyword: keyword ?? '');
      case TicketPlatform.maoyan:
        return await _webViewService.fetchMaoyanShows();
      case TicketPlatform.xiudong:
        return await _webViewService.fetchXiudongShows();
    }
  }
  
  // ============ 支付相关方法 ============
  
  /// 自动支付（抢票成功后调用）
  Future<void> _autoPay({
    required Account account,
    required TicketPlatform platform,
    required String orderId,
    required double amount,
    String skuName = '',
  }) async {
    try {
      _status = TicketHunterStatus.paying;
      _statusMessage = '正在创建支付订单...';
      _payAmount = amount;
      _payAccount = account;
      notifyListeners();
      
      // 默认使用支付宝
      _payChannel = 'alipay';
      
      // 创建支付并获取支付URL
      final payResult = await _ticketService.launchMobilePay(
        account: account,
        platform: platform,
        orderId: orderId,
        amount: amount,
        payType: _payChannel!,
      );
      
      if (payResult.success && payResult.payUrl != null) {
        _payUrl = payResult.payUrl;
        _statusMessage = '支付订单已创建，请完成支付';
        _addLog('💳 支付链接已生成: ${_payUrl!.substring(0, _payUrl!.length > 50 ? 50 : _payUrl!.length)}...');
        _addLog('📱 请在手机上打开支付链接完成支付');
        
        // 开始轮询支付状态
        _startPaymentPolling(account, platform, orderId);
      } else {
        _addLog('⚠️ 创建支付失败: ${payResult.message}');
        _statusMessage = '创建支付失败: ${payResult.message}';
      }
      
      notifyListeners();
    } catch (e) {
      _addLog('🔴 自动支付异常: $e');
      _statusMessage = '支付异常: $e';
      notifyListeners();
    }
  }
  
  /// 手动发起支付
  Future<bool> startPayment({
    required Account account,
    required TicketPlatform platform,
    required String orderId,
    required double amount,
    String payChannel = 'alipay',
  }) async {
    try {
      _status = TicketHunterStatus.paying;
      _statusMessage = '正在创建支付订单...';
      _payAmount = amount;
      _payAccount = account;
      _payChannel = payChannel;
      notifyListeners();
      
      final payResult = await _ticketService.launchMobilePay(
        account: account,
        platform: platform,
        orderId: orderId,
        amount: amount,
        payType: payChannel,
      );
      
      if (payResult.success && payResult.payUrl != null) {
        _payUrl = payResult.payUrl;
        _lastOrderId = orderId;
        _statusMessage = '支付订单已创建';
        _addLog('💳 支付链接: $_payUrl');
        
        // 开始轮询支付状态
        _startPaymentPolling(account, platform, orderId);
        
        notifyListeners();
        return true;
      } else {
        _statusMessage = '创建支付失败: ${payResult.message}';
        _addLog('⚠️ 创建支付失败: ${payResult.message}');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _statusMessage = '支付异常: $e';
      _addLog('🔴 支付异常: $e');
      notifyListeners();
      return false;
    }
  }
  
  /// 开始轮询支付状态
  void _startPaymentPolling(Account account, TicketPlatform platform, String orderId) {
    _addLog('🔄 开始轮询支付状态...');
    
    // 每3秒查询一次支付状态，最多查询60次（3分钟）
    int pollCount = 0;
    const maxPolls = 60;
    
    Future.delayed(Duration(seconds: 3), () async {
      while (pollCount < maxPolls && _status == TicketHunterStatus.paying) {
        pollCount++;
        
        try {
          final queryResult = await _ticketService.queryPayment(
            account: account,
            platform: platform,
            orderId: orderId,
          );
          
          if (queryResult.payStatus == 'paid') {
            _status = TicketHunterStatus.paid;
            _statusMessage = '支付成功！';
            _addLog('✅ 支付成功! 订单号: $orderId');
            notifyListeners();
            return;
          } else if (queryResult.payStatus == 'failed') {
            _addLog('❌ 支付失败: ${queryResult.message}');
            notifyListeners();
            return;
          } else if (queryResult.payStatus == 'expired') {
            _addLog('⏰ 支付已过期');
            notifyListeners();
            return;
          }
          
          // 继续等待
          if (pollCount % 10 == 0) {
            _addLog('⏳ 等待支付中... (${pollCount * 3}秒)');
          }
        } catch (e) {
          _addLog('⚠️ 查询支付状态异常: $e');
        }
        
        await Future.delayed(Duration(seconds: 3));
      }
      
      if (pollCount >= maxPolls) {
        _addLog('⏰ 支付轮询超时，请手动确认支付状态');
      }
    });
  }
  
  /// 查询支付状态
  Future<HuntingResult> checkPaymentStatus({
    required Account account,
    required TicketPlatform platform,
    required String orderId,
  }) async {
    return await _ticketService.queryPayment(
      account: account,
      platform: platform,
      orderId: orderId,
    );
  }
  
  /// 获取支付账户
  Account? get payAccount => _payAccount;
}