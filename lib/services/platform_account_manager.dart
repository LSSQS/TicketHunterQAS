import 'dart:async';
import 'dart:convert';
import '../models/account.dart';
import '../models/platform_config.dart';
import '../utils/logger.dart';
import 'storage_service.dart';

/// 多平台账号管理器
/// 每个平台维护独立的账号池，支持账号轮询、优先级管理
class PlatformAccountManager {
  static final PlatformAccountManager _instance = PlatformAccountManager._internal();
  factory PlatformAccountManager() => _instance;
  PlatformAccountManager._internal();

  // 平台 -> 账号列表
  final Map<TicketPlatform, List<Account>> _platformAccounts = {};
  
  // 平台 -> 当前账号索引 (用于轮询)
  final Map<TicketPlatform, int> _currentIndex = {};
  
  // 平台 -> 账号服务
  final Map<TicketPlatform, PlatformAccountService> _accountServices = {};
  
  bool _initialized = false;
  
  /// 初始化所有平台账号
  Future<void> initialize() async {
    if (_initialized) return;
    
    AppLogger.info('PlatformAccountManager initializing...');
    
    // 初始化所有平台
    for (final platform in TicketPlatform.values) {
      _platformAccounts[platform] = [];
      _currentIndex[platform] = 0;
      _accountServices[platform] = _createAccountService(platform);
    }
    
    // 从存储加载账号
    await _loadAccountsFromStorage();
    
    _initialized = true;
    AppLogger.info('PlatformAccountManager initialized');
  }
  
  /// 创建平台特定的账号服务
  PlatformAccountService _createAccountService(TicketPlatform platform) {
    switch (platform) {
      case TicketPlatform.damai:
        return DamaiPlatformAccountService();
      case TicketPlatform.maoyan:
        return MaoyanPlatformAccountService();
      case TicketPlatform.xiudong:
        return XiudongPlatformAccountService();
    }
  }
  
  /// 从存储加载账号
  Future<void> _loadAccountsFromStorage() async {
    try {
      final storage = StorageService();
      final accountsData = await storage.getConfig<Map<String, dynamic>>('platform_accounts', defaultValue: {});
      
      if (accountsData != null) {
        for (final entry in accountsData.entries) {
          final platform = _parsePlatform(entry.key);
          if (platform != null && entry.value is List) {
            final accounts = (entry.value as List)
                .map((json) => Account.fromJson(json as Map<String, dynamic>))
                .toList();
            _platformAccounts[platform] = accounts;
            AppLogger.info('Loaded ${accounts.length} accounts for ${platform.name}');
          }
        }
      }
    } catch (e) {
      AppLogger.error('Failed to load accounts from storage', e);
    }
  }
  
  /// 保存账号到存储
  Future<void> _saveAccountsToStorage() async {
    try {
      final storage = StorageService();
      final Map<String, dynamic> data = {};
      
      for (final entry in _platformAccounts.entries) {
        data[entry.key.name] = entry.value.map((a) => a.toJson()).toList();
      }
      
      await storage.saveConfig('platform_accounts', data);
      AppLogger.debug('Accounts saved to storage');
    } catch (e) {
      AppLogger.error('Failed to save accounts to storage', e);
    }
  }
  
  TicketPlatform? _parsePlatform(String name) {
    switch (name.toLowerCase()) {
      case 'damai':
        return TicketPlatform.damai;
      case 'maoyan':
        return TicketPlatform.maoyan;
      case 'xiudong':
        return TicketPlatform.xiudong;
      default:
        return null;
    }
  }
  
  // =============== 账号管理 API ===============
  
  /// 添加账号到指定平台
  Future<bool> addAccount(Account account) async {
    await initialize();
    
    final platform = account.platform;
    if (!_platformAccounts.containsKey(platform)) {
      _platformAccounts[platform] = [];
    }
    
    // 检查是否已存在相同用户名
    final exists = _platformAccounts[platform]!.any((a) => a.username == account.username);
    if (exists) {
      AppLogger.warning('Account ${account.username} already exists for ${platform.name}');
      return false;
    }
    
    _platformAccounts[platform]!.add(account);
    await _saveAccountsToStorage();
    
    AppLogger.info('Added account ${account.username} to ${platform.name}');
    return true;
  }
  
  /// 批量添加账号
  Future<int> addAccounts(List<Account> accounts) async {
    await initialize();
    
    int addedCount = 0;
    for (final account in accounts) {
      if (await addAccount(account)) {
        addedCount++;
      }
    }
    return addedCount;
  }
  
  /// 移除账号
  Future<bool> removeAccount(String accountId, TicketPlatform platform) async {
    await initialize();
    
    final accounts = _platformAccounts[platform];
    if (accounts == null) return false;
    
    final index = accounts.indexWhere((a) => a.id == accountId);
    if (index == -1) return false;
    
    accounts.removeAt(index);
    await _saveAccountsToStorage();
    
    AppLogger.info('Removed account $accountId from ${platform.name}');
    return true;
  }
  
  /// 更新账号
  Future<bool> updateAccount(Account account) async {
    await initialize();
    
    final platform = account.platform;
    final accounts = _platformAccounts[platform];
    if (accounts == null) return false;
    
    final index = accounts.indexWhere((a) => a.id == account.id);
    if (index == -1) return false;
    
    accounts[index] = account.copyWith(updatedAt: DateTime.now());
    await _saveAccountsToStorage();
    
    AppLogger.info('Updated account ${account.username} for ${platform.name}');
    return true;
  }
  
  /// 获取平台所有账号
  List<Account> getAccounts(TicketPlatform platform) {
    return List.unmodifiable(_platformAccounts[platform] ?? []);
  }
  
  /// 获取平台可用账号 (排除封禁、异常账号)
  List<Account> getAvailableAccounts(TicketPlatform platform) {
    return (_platformAccounts[platform] ?? [])
        .where((a) => a.canUse)
        .toList();
  }
  
  /// 获取所有平台的账号统计
  Map<TicketPlatform, int> getAccountStats() {
    return Map.fromEntries(
      _platformAccounts.entries.map((e) => MapEntry(e.key, e.value.length))
    );
  }
  
  /// 获取下一个可用账号 (轮询模式)
  Account? getNextAvailableAccount(TicketPlatform platform) {
    final available = getAvailableAccounts(platform);
    if (available.isEmpty) return null;
    
    final index = _currentIndex[platform] ?? 0;
    _currentIndex[platform] = (index + 1) % available.length;
    
    return available[index];
  }
  
  /// 获取最高优先级账号
  Account? getHighestPriorityAccount(TicketPlatform platform) {
    final available = getAvailableAccounts(platform);
    if (available.isEmpty) return null;
    
    available.sort((a, b) => b.priority.compareTo(a.priority));
    return available.first;
  }
  
  /// 标记账号为异常
  Future<void> markAccountError(String accountId, TicketPlatform platform, String error) async {
    await initialize();
    
    final accounts = _platformAccounts[platform];
    if (accounts == null) return;
    
    final index = accounts.indexWhere((a) => a.id == accountId);
    if (index == -1) return;
    
    final account = accounts[index];
    final newFailCount = account.loginFailCount + 1;
    
    // 超过失败次数限制，标记为异常
    AccountStatus newStatus = account.status;
    if (newFailCount >= 3) {
      newStatus = AccountStatus.error;
    }
    
    accounts[index] = account.copyWith(
      loginFailCount: newFailCount,
      status: newStatus,
      updatedAt: DateTime.now(),
    );
    
    await _saveAccountsToStorage();
    AppLogger.warning('Account ${account.username} error: $error, fail count: $newFailCount');
  }
  
  /// 重置账号状态
  Future<void> resetAccountStatus(String accountId, TicketPlatform platform) async {
    await initialize();
    
    final accounts = _platformAccounts[platform];
    if (accounts == null) return;
    
    final index = accounts.indexWhere((a) => a.id == accountId);
    if (index == -1) return;
    
    final account = accounts[index];
    accounts[index] = account.copyWith(
      loginFailCount: 0,
      status: AccountStatus.active,
      updatedAt: DateTime.now(),
    );
    
    await _saveAccountsToStorage();
    AppLogger.info('Reset account ${account.username} status');
  }
  
  // =============== 平台账号登录 ===============
  
  /// 登录指定平台的账号
  Future<PlatformLoginResult> loginAccount(Account account) async {
    await initialize();
    
    final service = _accountServices[account.platform];
    if (service == null) {
      return PlatformLoginResult(success: false, message: '平台不支持');
    }
    
    final result = await service.login(account);
    
    if (result.success) {
      // 更新账号信息
      await updateAccount(account.copyWith(
        status: AccountStatus.active,
        lastLoginTime: DateTime.now(),
        cookies: result.cookies != null ? Map<String, dynamic>.from(result.cookies!) : null,
        token: result.token,
        loginFailCount: 0,
      ));
    } else {
      await markAccountError(account.id, account.platform, result.message ?? '登录失败');
    }
    
    return result;
  }
  
  /// 批量登录平台账号
  Future<Map<Account, PlatformLoginResult>> batchLogin(TicketPlatform platform) async {
    await initialize();
    
    final accounts = getAvailableAccounts(platform);
    final results = <Account, PlatformLoginResult>{};
    
    for (final account in accounts) {
      results[account] = await loginAccount(account);
      // 延迟避免频繁请求
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    return results;
  }
  
  /// 验证账号是否有效
  Future<bool> validateAccount(Account account) async {
    await initialize();
    
    final service = _accountServices[account.platform];
    if (service == null) return false;
    
    return await service.validate(account);
  }
}

/// 平台账号服务抽象类
abstract class PlatformAccountService {
  Future<PlatformLoginResult> login(Account account);
  Future<bool> validate(Account account);
}

/// 登录结果
class PlatformLoginResult {
  final bool success;
  final String? message;
  final Map<String, String>? cookies;
  final String? token;
  final Map<String, dynamic>? userInfo;
  
  PlatformLoginResult({
    required this.success,
    this.message,
    this.cookies,
    this.token,
    this.userInfo,
  });
}

/// 大麦平台账号服务
class DamaiPlatformAccountService implements PlatformAccountService {
  @override
  Future<PlatformLoginResult> login(Account account) async {
    AppLogger.info('Damai login for ${account.username}');
    return PlatformLoginResult(
      success: false,
      message: '需要通过WebView登录获取Cookie',
    );
  }
  
  @override
  Future<bool> validate(Account account) async {
    if (account.cookies == null || account.cookies!.isEmpty) {
      return false;
    }
    return true;
  }
}

/// 猫眼平台账号服务
class MaoyanPlatformAccountService implements PlatformAccountService {
  @override
  Future<PlatformLoginResult> login(Account account) async {
    AppLogger.info('Maoyan login for ${account.username}');
    return PlatformLoginResult(
      success: false,
      message: '猫眼暂不支持密码登录，请使用Cookie导入',
    );
  }
  
  @override
  Future<bool> validate(Account account) async {
    if (account.token == null || account.token!.isEmpty) {
      return false;
    }
    return true;
  }
}

/// 秀动平台账号服务
class XiudongPlatformAccountService implements PlatformAccountService {
  @override
  Future<PlatformLoginResult> login(Account account) async {
    AppLogger.info('Xiudong login for ${account.username}');
    return PlatformLoginResult(
      success: false,
      message: '秀动需要通过WebView登录获取Cookie',
    );
  }
  
  @override
  Future<bool> validate(Account account) async {
    if (account.cookies == null || account.cookies!.isEmpty) {
      return false;
    }
    return true;
  }
}
