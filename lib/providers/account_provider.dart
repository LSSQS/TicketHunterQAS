import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/account.dart';
import '../models/platform_config.dart';
import '../services/account_service.dart';

class AccountProvider extends ChangeNotifier {
  List<Account> _accounts = [];
  bool _isLoading = false;
  final AccountService _accountService = AccountService();

  List<Account> get accounts => _accounts;
  bool get isLoading => _isLoading;

  /// 添加账号
  void addAccount(Account account) {
    _accounts.add(account);
    notifyListeners();
    _saveAccounts();
  }

  /// 更新账号
  void updateAccount(Account updatedAccount) {
    final index = _accounts.indexWhere((account) => account.id == updatedAccount.id);
    if (index != -1) {
      _accounts[index] = updatedAccount;
      notifyListeners();
      _saveAccounts();
    }
  }

  /// 删除账号
  void removeAccount(String accountId) {
    _accounts.removeWhere((account) => account.id == accountId);
    notifyListeners();
    _saveAccounts();
  }

  /// 验证账号
  Future<bool> verifyAccount(Account account) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final isValid = await _accountService.validateAccount(account);
      
      // 更新账号状态
      final newStatus = isValid ? AccountStatus.active : AccountStatus.error;
      final updatedAccount = account.copyWith(
        status: newStatus,
        lastLoginTime: isValid ? DateTime.now() : account.lastLoginTime,
        loginFailCount: isValid ? 0 : account.loginFailCount + 1,
      );
      
      updateAccount(updatedAccount);
      return isValid;
    } catch (e) {
      debugPrint('Verify account error: $e');
      updateAccount(account.copyWith(status: AccountStatus.error));
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 获取可用账号
  List<Account> get availableAccounts {
    return _accounts.where((account) => account.canUse).toList();
  }

  /// 加载账号数据
  Future<void> loadAccounts() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (kIsWeb) {
        // Mock web accounts if empty
        if (_accounts.isEmpty) {
           // Simulate loading delay
           await Future.delayed(const Duration(milliseconds: 500));
           _accounts = [
             Account(
               id: 'mock_1',
               username: 'damai_test_user',
               password: 'password123',
               platform: TicketPlatform.damai,
               status: AccountStatus.active,
               deviceId: 'web_device_001',
               createdAt: DateTime.now(),
               updatedAt: DateTime.now(),
               cookies: {'cookie_key': 'mock_cookie_value'},
             ),
             Account(
               id: 'mock_2',
               username: 'maoyan_test_user',
               password: 'password456',
               platform: TicketPlatform.maoyan,
               status: AccountStatus.inactive,
               deviceId: 'web_device_002',
               createdAt: DateTime.now(),
               updatedAt: DateTime.now(),
             ),
           ];
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        final accountsJson = prefs.getString('accounts');
        if (accountsJson != null) {
          final List<dynamic> accountsList = json.decode(accountsJson);
          _accounts = accountsList.map((json) => Account.fromJson(json)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error loading accounts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 保存账号数据
  Future<void> _saveAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountsJson = json.encode(_accounts.map((account) => account.toJson()).toList());
      await prefs.setString('accounts', accountsJson);
    } catch (e) {
      debugPrint('Error saving accounts: $e');
    }
  }

  /// 清空所有账号
  Future<void> clearAll() async {
    _accounts.clear();
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accounts');
  }
}