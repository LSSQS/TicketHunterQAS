import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/account.dart';
import '../models/platform_config.dart';
import '../utils/logger.dart';
import 'damai_account_service.dart';
import 'maoyan_account_service.dart';
import 'xiudong_account_service.dart';
import 'platform_account_manager.dart';

// 导出 LoginResult 和 LoginPageResult 以便兼容旧代码
export 'damai_account_service.dart' show LoginResult, LoginPageResult;
export 'platform_account_manager.dart' show PlatformAccountManager, PlatformLoginResult;

/// 统一账号服务
/// 支持多平台账号管理
class AccountService {
  final DamaiAccountService _damaiService = DamaiAccountService();
  final MaoyanAccountService _maoyanService = MaoyanAccountService();
  final XiudongAccountService _xiudongService = XiudongAccountService();
  
  // 使用新的平台账号管理器
  final PlatformAccountManager _platformManager = PlatformAccountManager();

  /// 登录账号
  Future<LoginResult> login(Account account) async {
    AppLogger.info('Unified AccountService login for platform: ${account.platform}');
    
    switch (account.platform) {
      case TicketPlatform.damai:
        return await _damaiService.login(account);
      case TicketPlatform.maoyan:
        return await _maoyanService.login(account);
      case TicketPlatform.xiudong:
        return await _xiudongService.login(account);
    }
  }

  /// 获取平台账号管理器
  PlatformAccountManager get platformManager => _platformManager;
  
  /// 初始化账号管理器
  Future<void> initialize() async {
    await _platformManager.initialize();
  }

  /// 添加账号
  Future<bool> addAccount(Account account) async {
    return await _platformManager.addAccount(account);
  }
  
  /// 批量添加账号
  Future<int> addAccounts(List<Account> accounts) async {
    return await _platformManager.addAccounts(accounts);
  }
  
  /// 移除账号
  Future<bool> removeAccount(String accountId, TicketPlatform platform) async {
    return await _platformManager.removeAccount(accountId, platform);
  }
  
  /// 更新账号
  Future<bool> updateAccount(Account account) async {
    return await _platformManager.updateAccount(account);
  }
  
  /// 获取平台所有账号
  List<Account> getAccounts(TicketPlatform platform) {
    return _platformManager.getAccounts(platform);
  }
  
  /// 获取平台可用账号
  List<Account> getAvailableAccounts(TicketPlatform platform) {
    return _platformManager.getAvailableAccounts(platform);
  }
  
  /// 获取下一个可用账号（轮询）
  Account? getNextAvailableAccount(TicketPlatform platform) {
    return _platformManager.getNextAvailableAccount(platform);
  }
  
  /// 获取最高优先级账号
  Account? getHighestPriorityAccount(TicketPlatform platform) {
    return _platformManager.getHighestPriorityAccount(platform);
  }

  /// 从文件内容导入账号（Web兼容）
  Future<List<Map<String, dynamic>>> importFromContent(String content, {
    String fileType = 'txt',
    TicketPlatform defaultPlatform = TicketPlatform.damai,
  }) async {
    try {
      final accounts = <Map<String, dynamic>>[];

      if (fileType == 'json') {
        final jsonData = jsonDecode(content);
        if (jsonData is List) {
          accounts.addAll(jsonData.cast<Map<String, dynamic>>());
        }
      } else {
        final lines = content.split('\n');
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
          
          final parts = trimmed.contains(':') 
              ? trimmed.split(':')
              : trimmed.split(',');
          
          if (parts.length >= 2) {
            // 解析平台标识（如果存在）
            TicketPlatform platform = defaultPlatform;
            String? platformStr;
            
            if (parts.length >= 5) {
              platformStr = parts[4].trim().toLowerCase();
              if (platformStr == 'maoyan') {
                platform = TicketPlatform.maoyan;
              } else if (platformStr == 'xiudong') {
                platform = TicketPlatform.xiudong;
              }
            }
            
            final accountData = {
              'username': parts[0].trim(),
              'password': parts[1].trim(),
              'phone': parts.length > 2 ? parts[2].trim() : null,
              'email': parts.length > 3 ? parts[3].trim() : null,
              'platform': platform.name,
            };
            accounts.add(accountData);
          }
        }
      }

      AppLogger.info('Imported ${accounts.length} accounts from content');
      return accounts;
    } catch (e) {
      AppLogger.error('Import accounts from content failed', e);
      throw Exception('导入账号失败: $e');
    }
  }

  /// 从文件导入账号（仅非Web平台）
  Future<List<Map<String, dynamic>>> importFromFile(String filePath, {
    TicketPlatform defaultPlatform = TicketPlatform.damai,
  }) async {
    if (kIsWeb) {
      throw Exception('Web平台不支持文件导入，请使用importFromContent');
    }
    // 非Web平台的实现需要在条件编译的文件中
    throw Exception('请使用importFromContent方法');
  }

  /// 验证账号
  Future<bool> validateAccount(Account account) async {
    try {
      final loginResult = await login(account);
      return loginResult.success;
    } catch (e) {
      AppLogger.error('Validate account failed', e);
      return false;
    }
  }
  
  /// 获取账号统计
  Map<TicketPlatform, int> getAccountStats() {
    return _platformManager.getAccountStats();
  }
}
