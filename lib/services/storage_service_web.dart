import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart';
import '../models/account.dart';
import '../models/concert.dart';
import '../utils/logger.dart';
import '../config/app_config.dart';

class StorageService {
  // In-memory storage for Web preview
  static final List<Account> _webAccounts = [];
  static final List<Concert> _webConcerts = [];
  static final List<Map<String, dynamic>> _webHuntingRecords = [];

  Encrypter? _encrypter;
  IV? _iv;
  bool _initialized = false;

  StorageService() {
    _initEncryption();
  }
  
  void _initEncryption() {
    if (_initialized) return;
    try {
      final key = Key.fromBase64(base64Encode(AppConfig.storageEncryptionKey.codeUnits.take(32).toList()));
      _encrypter = Encrypter(AES(key));
      // 使用集中配置的IV
      _iv = IV.fromUtf8(AppConfig.storageEncryptionIv);
      _initialized = true;
    } catch (e) {
      AppLogger.error('Failed to init encryption', e);
    }
  }

  // 账号相关操作
  Future<List<Account>> loadAccounts() async {
    return _webAccounts;
  }

  Future<void> saveAccounts(List<Account> accounts) async {
    _webAccounts.clear();
    _webAccounts.addAll(accounts);
    AppLogger.info('Web: Saved ${accounts.length} accounts');
  }

  Future<void> saveAccount(Account account) async {
    final index = _webAccounts.indexWhere((a) => a.id == account.id);
    if (index != -1) {
      _webAccounts[index] = account;
    } else {
      _webAccounts.add(account);
    }
    AppLogger.info('Web: Saved account: ${account.username}');
  }

  Future<void> deleteAccount(String accountId) async {
    _webAccounts.removeWhere((a) => a.id == accountId);
    AppLogger.info('Web: Deleted account: $accountId');
  }

  // 演唱会相关操作
  Future<List<Concert>> loadConcerts() async {
    if (_webConcerts.isEmpty) {
      _initMockConcerts();
    }
    return _webConcerts;
  }

  void _initMockConcerts() {
    _webConcerts.addAll([
      Concert(
        id: '1',
        name: '周杰伦【嘉年华】世界巡回演唱会',
        artist: '周杰伦',
        venue: '北京国家体育场（鸟巢）',
        showTime: DateTime.now().add(const Duration(days: 30)),
        saleStartTime: DateTime.now().add(const Duration(days: 1)),
        itemId: '123456',
        skus: [
          TicketSku(
            skuId: '101',
            name: '看台 580',
            price: 580,
            quantity: 1,
            isEnabled: true,
          ),
          TicketSku(
            skuId: '102',
            name: '看台 780',
            price: 780,
            quantity: 1,
            isEnabled: true,
          ),
          TicketSku(
            skuId: '103',
            name: '内场 1280',
            price: 1280,
            quantity: 1,
            isEnabled: true,
          ),
        ],
        status: ConcertStatus.pending,
        posterUrl: 'https://p0.pipi.cn/mmdb/d533631d8c1c54b032d8495c37854612845c4.jpg?imageView2/1/w/464/h/644',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Concert(
        id: '2',
        name: '五月天 [回到那一天] 25周年巡回演唱会',
        artist: '五月天',
        venue: '上海八万人体育场',
        showTime: DateTime.now().add(const Duration(days: 45)),
        saleStartTime: DateTime.now().add(const Duration(days: 5)),
        itemId: '234567',
        skus: [
          TicketSku(
            skuId: '201',
            name: '看台 355',
            price: 355,
            quantity: 1,
            isEnabled: true,
          ),
          TicketSku(
            skuId: '202',
            name: '看台 855',
            price: 855,
            quantity: 1,
            isEnabled: true,
          ),
           TicketSku(
            skuId: '203',
            name: '内场 1555',
            price: 1555,
            quantity: 1,
            isEnabled: true,
          ),
        ],
        status: ConcertStatus.pending,
        posterUrl: 'https://p0.pipi.cn/mmdb/d533631d8c1c54b032d8495c37854612845c4.jpg?imageView2/1/w/464/h/644',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Concert(
        id: '3',
        name: '陈奕迅 Fear and Dreams 世界巡回演唱会',
        artist: '陈奕迅',
        venue: '广州宝能观致文化中心',
        showTime: DateTime.now().add(const Duration(days: 60)),
        saleStartTime: DateTime.now().subtract(const Duration(days: 1)),
        itemId: '345678',
        skus: [
           TicketSku(
            skuId: '301',
            name: '看台 980',
            price: 980,
            quantity: 1,
            isEnabled: true,
          ),
        ],
        status: ConcertStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ]);
  }


  Future<void> saveConcerts(List<Concert> concerts) async {
    _webConcerts.clear();
    _webConcerts.addAll(concerts);
    AppLogger.info('Web: Saved ${concerts.length} concerts');
  }

  Future<void> saveConcert(Concert concert) async {
    final index = _webConcerts.indexWhere((c) => c.id == concert.id);
    if (index != -1) {
      _webConcerts[index] = concert;
    } else {
      _webConcerts.add(concert);
    }
    AppLogger.info('Web: Saved concert: ${concert.name}');
  }

  Future<void> deleteConcert(String concertId) async {
    _webConcerts.removeWhere((c) => c.id == concertId);
    AppLogger.info('Web: Deleted concert: $concertId');
  }

  // 抢票记录相关操作
  Future<void> saveHuntingRecord({
    required String concertId,
    required String accountId,
    required String skuId,
    required bool success,
    String? message,
    String? orderId,
    bool isBlocked = false,
    Map<String, dynamic>? metadata,
  }) async {
    _webHuntingRecords.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'concert_id': concertId,
      'account_id': accountId,
      'sku_id': skuId,
      'success': success ? 1 : 0,
      'message': message,
      'order_id': orderId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'is_blocked': isBlocked ? 1 : 0,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
    });
    AppLogger.info('Web: Saved hunting record for concert: $concertId');
  }

  Future<List<Map<String, dynamic>>> getHuntingRecords({
    String? concertId,
    String? accountId,
    int? limit,
  }) async {
    var records = _webHuntingRecords;
    if (concertId != null) {
      records = records.where((r) => r['concert_id'] == concertId).toList();
    }
    if (accountId != null) {
      records = records.where((r) => r['account_id'] == accountId).toList();
    }
    records.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
    if (limit != null && records.length > limit) {
      return records.sublist(0, limit);
    }
    return records;
  }

  // 配置相关操作 (Reuse SharedPreferences implementation as it works on Web)
  Future<void> saveConfig(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedValue = _encrypt(jsonEncode(value));
      await prefs.setString(key, encryptedValue);
      AppLogger.debug('Saved config: $key');
    } catch (e) {
      AppLogger.error('Save config failed', e);
    }
  }

  Future<T?> getConfig<T>(String key, {T? defaultValue}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedValue = prefs.getString(key);
      if (encryptedValue == null) return defaultValue;
      final decryptedValue = _decrypt(encryptedValue);
      final value = jsonDecode(decryptedValue);
      return value as T?;
    } catch (e) {
      AppLogger.error('Get config failed', e);
      return defaultValue;
    }
  }

  Future<void> removeConfig(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      AppLogger.debug('Removed config: $key');
    } catch (e) {
      AppLogger.error('Remove config failed', e);
    }
  }

  // 加密解密方法
  String _encrypt(String text) {
    try {
      if (_encrypter == null || _iv == null) {
        _initEncryption();
      }
      if (_encrypter == null || _iv == null) {
        return base64Encode(text.codeUnits);
      }
      final encrypted = _encrypter!.encrypt(text, iv: _iv!);
      return encrypted.base64;
    } catch (e) {
      AppLogger.error('Encrypt failed', e);
      return base64Encode(text.codeUnits);
    }
  }

  String _decrypt(String encryptedText) {
    try {
      if (_encrypter == null || _iv == null) {
        _initEncryption();
      }
      if (_encrypter == null || _iv == null) {
        return String.fromCharCodes(base64Decode(encryptedText));
      }
      final encrypted = Encrypted.fromBase64(encryptedText);
      return _encrypter!.decrypt(encrypted, iv: _iv!);
    } catch (e) {
      AppLogger.error('Decrypt failed', e);
      try {
        return String.fromCharCodes(base64Decode(encryptedText));
      } catch (_) {
        return encryptedText;
      }
    }
  }

  // 数据库维护
  Future<void> clearAllData() async {
    _webAccounts.clear();
    _webConcerts.clear();
    _webHuntingRecords.clear();
    AppLogger.info('Web: All data cleared');
  }

  Future<void> exportData(String filePath) async {
    AppLogger.info('Web: Export data not supported');
  }

  Future<void> importData(String filePath) async {
    AppLogger.info('Web: Import data not supported');
  }

  Future<void> close() async {
    // No-op
  }
}
