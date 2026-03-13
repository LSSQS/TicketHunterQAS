import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart';
import '../models/account.dart';
import '../models/concert.dart';
import '../utils/logger.dart';
import '../config/app_config.dart';

class StorageService {
  static Database? _dbInstance;
  static const String _dbName = 'damai_hunter.db';
  static const int _dbVersion = 1;
  
  // 使用集中配置的加密密钥
  late final Encrypter _encrypter;
  late final IV _iv;

  StorageService() {
    final key = Key.fromBase64(base64Encode(AppConfig.storageEncryptionKey.codeUnits.take(32).toList()));
    _encrypter = Encrypter(AES(key));
    _iv = IV.fromSecureRandom(16);
  }

  Future<Database> get _database async {
    _dbInstance ??= await _initDatabase();
    return _dbInstance!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createTables,
      onUpgrade: _upgradeTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // 账号表
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        status TEXT NOT NULL DEFAULT 'inactive',
        device_id TEXT NOT NULL,
        last_login_time INTEGER,
        last_used_time INTEGER,
        login_fail_count INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        cookies TEXT,
        token TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 演唱会表
    await db.execute('''
      CREATE TABLE concerts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        artist TEXT NOT NULL,
        venue TEXT NOT NULL,
        show_time INTEGER NOT NULL,
        sale_start_time INTEGER NOT NULL,
        item_id TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        max_concurrency INTEGER DEFAULT 50,
        retry_count INTEGER DEFAULT 5,
        retry_delay INTEGER DEFAULT 100,
        auto_start INTEGER DEFAULT 0,
        description TEXT,
        poster_url TEXT,
        metadata TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 票档表
    await db.execute('''
      CREATE TABLE ticket_skus (
        id TEXT PRIMARY KEY,
        concert_id TEXT NOT NULL,
        sku_id TEXT NOT NULL,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        quantity INTEGER DEFAULT 1,
        priority TEXT DEFAULT 'medium',
        is_enabled INTEGER DEFAULT 1,
        seat_info TEXT,
        FOREIGN KEY (concert_id) REFERENCES concerts (id) ON DELETE CASCADE
      )
    ''');

    // 抢票记录表
    await db.execute('''
      CREATE TABLE hunting_records (
        id TEXT PRIMARY KEY,
        concert_id TEXT NOT NULL,
        account_id TEXT NOT NULL,
        sku_id TEXT NOT NULL,
        success INTEGER NOT NULL,
        message TEXT,
        order_id TEXT,
        timestamp INTEGER NOT NULL,
        is_blocked INTEGER DEFAULT 0,
        metadata TEXT,
        FOREIGN KEY (concert_id) REFERENCES concerts (id),
        FOREIGN KEY (account_id) REFERENCES accounts (id)
      )
    ''');

    // 创建索引
    await db.execute('CREATE INDEX idx_accounts_username ON accounts (username)');
    await db.execute('CREATE INDEX idx_accounts_status ON accounts (status)');
    await db.execute('CREATE INDEX idx_concerts_status ON concerts (status)');
    await db.execute('CREATE INDEX idx_concerts_sale_time ON concerts (sale_start_time)');
    await db.execute('CREATE INDEX idx_ticket_skus_concert ON ticket_skus (concert_id)');
    await db.execute('CREATE INDEX idx_hunting_records_concert ON hunting_records (concert_id)');
    await db.execute('CREATE INDEX idx_hunting_records_account ON hunting_records (account_id)');

    AppLogger.info('Database tables created successfully');
  }

  Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
    // 数据库升级逻辑
    AppLogger.info('Upgrading database from version $oldVersion to $newVersion');
  }

  // 账号相关操作
  Future<List<Account>> loadAccounts() async {
    try {
      final db = await _database;
      final List<Map<String, dynamic>> maps = await db.query('accounts');
      
      return maps.map((map) => _mapToAccount(map)).toList();
    } catch (e) {
      AppLogger.error('Load accounts failed', e);
      return [];
    }
  }

  Future<void> saveAccounts(List<Account> accounts) async {
    try {
      final db = await _database;
      
      await db.transaction((txn) async {
        // 清空现有数据
        await txn.delete('accounts');
        
        // 插入新数据
        for (final account in accounts) {
          await txn.insert('accounts', _accountToMap(account));
        }
      });
      
      AppLogger.info('Saved ${accounts.length} accounts');
    } catch (e) {
      AppLogger.error('Save accounts failed', e);
      throw Exception('保存账号失败: $e');
    }
  }

  Future<void> saveAccount(Account account) async {
    try {
      final db = await _database;
      await db.insert(
        'accounts',
        _accountToMap(account),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      AppLogger.info('Saved account: ${account.username}');
    } catch (e) {
      AppLogger.error('Save account failed', e);
      throw Exception('保存账号失败: $e');
    }
  }

  Future<void> deleteAccount(String accountId) async {
    try {
      final db = await _database;
      await db.delete('accounts', where: 'id = ?', whereArgs: [accountId]);
      
      AppLogger.info('Deleted account: $accountId');
    } catch (e) {
      AppLogger.error('Delete account failed', e);
      throw Exception('删除账号失败: $e');
    }
  }

  // 演唱会相关操作
  Future<List<Concert>> loadConcerts() async {
    try {
      final db = await _database;
      final List<Map<String, dynamic>> concertMaps = await db.query('concerts');
      
      final concerts = <Concert>[];
      for (final concertMap in concertMaps) {
        final skus = await _loadTicketSkus(concertMap['id']);
        concerts.add(_mapToConcert(concertMap, skus));
      }
      
      return concerts;
    } catch (e) {
      AppLogger.error('Load concerts failed', e);
      return [];
    }
  }

  Future<void> saveConcerts(List<Concert> concerts) async {
    try {
      final db = await _database;
      
      await db.transaction((txn) async {
        // 清空现有数据
        await txn.delete('ticket_skus');
        await txn.delete('concerts');
        
        // 插入新数据
        for (final concert in concerts) {
          await txn.insert('concerts', _concertToMap(concert));
          
          // 保存票档
          for (final sku in concert.skus) {
            await txn.insert('ticket_skus', _ticketSkuToMap(concert.id, sku));
          }
        }
      });
      
      AppLogger.info('Saved ${concerts.length} concerts');
    } catch (e) {
      AppLogger.error('Save concerts failed', e);
      throw Exception('保存演唱会失败: $e');
    }
  }

  Future<void> saveConcert(Concert concert) async {
    try {
      final db = await _database;
      
      await db.transaction((txn) async {
        await txn.insert(
          'concerts',
          _concertToMap(concert),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        
        // 删除旧的票档
        await txn.delete('ticket_skus', where: 'concert_id = ?', whereArgs: [concert.id]);
        
        // 插入新的票档
        for (final sku in concert.skus) {
          await txn.insert('ticket_skus', _ticketSkuToMap(concert.id, sku));
        }
      });
      
      AppLogger.info('Saved concert: ${concert.name}');
    } catch (e) {
      AppLogger.error('Save concert failed', e);
      throw Exception('保存演唱会失败: $e');
    }
  }

  Future<void> deleteConcert(String concertId) async {
    try {
      final db = await _database;
      
      await db.transaction((txn) async {
        await txn.delete('ticket_skus', where: 'concert_id = ?', whereArgs: [concertId]);
        await txn.delete('concerts', where: 'id = ?', whereArgs: [concertId]);
      });
      
      AppLogger.info('Deleted concert: $concertId');
    } catch (e) {
      AppLogger.error('Delete concert failed', e);
      throw Exception('删除演唱会失败: $e');
    }
  }

  Future<List<TicketSku>> _loadTicketSkus(String concertId) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      'ticket_skus',
      where: 'concert_id = ?',
      whereArgs: [concertId],
    );
    
    return maps.map((map) => _mapToTicketSku(map)).toList();
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
    try {
      final db = await _database;
      
      await db.insert('hunting_records', {
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
      
      AppLogger.info('Saved hunting record for concert: $concertId');
    } catch (e) {
      AppLogger.error('Save hunting record failed', e);
    }
  }

  Future<List<Map<String, dynamic>>> getHuntingRecords({
    String? concertId,
    String? accountId,
    int? limit,
  }) async {
    try {
      final db = await _database;
      
      String whereClause = '';
      List<dynamic> whereArgs = [];
      
      if (concertId != null) {
        whereClause = 'concert_id = ?';
        whereArgs.add(concertId);
      }
      
      if (accountId != null) {
        if (whereClause.isNotEmpty) whereClause += ' AND ';
        whereClause += 'account_id = ?';
        whereArgs.add(accountId);
      }
      
      final List<Map<String, dynamic>> maps = await db.query(
        'hunting_records',
        where: whereClause.isNotEmpty ? whereClause : null,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'timestamp DESC',
        limit: limit,
      );
      
      return maps;
    } catch (e) {
      AppLogger.error('Get hunting records failed', e);
      return [];
    }
  }

  // 配置相关操作
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

  // 数据转换方法
  Account _mapToAccount(Map<String, dynamic> map) {
    return Account(
      id: map['id'],
      username: map['username'],
      password: _decrypt(map['password']),
      phone: map['phone'],
      email: map['email'],
      status: AccountStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => AccountStatus.inactive,
      ),
      deviceId: map['device_id'],
      lastLoginTime: map['last_login_time'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['last_login_time'])
          : null,
      lastUsedTime: map['last_used_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_used_time'])
          : null,
      loginFailCount: map['login_fail_count'] ?? 0,
      isActive: map['is_active'] == 1,
      cookies: map['cookies'] != null 
          ? Map<String, String>.from(jsonDecode(_decrypt(map['cookies'])))
          : null,
      token: map['token'] != null ? _decrypt(map['token']) : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }

  Map<String, dynamic> _accountToMap(Account account) {
    return {
      'id': account.id,
      'username': account.username,
      'password': _encrypt(account.password),
      'phone': account.phone,
      'email': account.email,
      'status': account.status.toString().split('.').last,
      'device_id': account.deviceId,
      'last_login_time': account.lastLoginTime?.millisecondsSinceEpoch,
      'last_used_time': account.lastUsedTime?.millisecondsSinceEpoch,
      'login_fail_count': account.loginFailCount,
      'is_active': account.isActive ? 1 : 0,
      'cookies': account.cookies != null ? _encrypt(jsonEncode(account.cookies)) : null,
      'token': account.token != null ? _encrypt(account.token!) : null,
      'created_at': account.createdAt.millisecondsSinceEpoch,
      'updated_at': account.updatedAt.millisecondsSinceEpoch,
    };
  }

  Concert _mapToConcert(Map<String, dynamic> map, List<TicketSku> skus) {
    return Concert(
      id: map['id'],
      name: map['name'],
      artist: map['artist'],
      venue: map['venue'],
      showTime: DateTime.fromMillisecondsSinceEpoch(map['show_time']),
      saleStartTime: DateTime.fromMillisecondsSinceEpoch(map['sale_start_time']),
      itemId: map['item_id'],
      skus: skus,
      status: ConcertStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => ConcertStatus.pending,
      ),
      maxConcurrency: map['max_concurrency'] ?? 50,
      retryCount: map['retry_count'] ?? 5,
      retryDelay: Duration(milliseconds: map['retry_delay'] ?? 100),
      autoStart: map['auto_start'] == 1,
      description: map['description'],
      posterUrl: map['poster_url'],
      metadata: map['metadata'] != null 
          ? Map<String, dynamic>.from(jsonDecode(map['metadata']))
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }

  Map<String, dynamic> _concertToMap(Concert concert) {
    return {
      'id': concert.id,
      'name': concert.name,
      'artist': concert.artist,
      'venue': concert.venue,
      'show_time': concert.showTime.millisecondsSinceEpoch,
      'sale_start_time': concert.saleStartTime.millisecondsSinceEpoch,
      'item_id': concert.itemId,
      'status': concert.status.toString().split('.').last,
      'max_concurrency': concert.maxConcurrency,
      'retry_count': concert.retryCount,
      'retry_delay': concert.retryDelay.inMilliseconds,
      'auto_start': concert.autoStart ? 1 : 0,
      'description': concert.description,
      'poster_url': concert.posterUrl,
      'metadata': concert.metadata != null ? jsonEncode(concert.metadata) : null,
      'created_at': concert.createdAt.millisecondsSinceEpoch,
      'updated_at': concert.updatedAt.millisecondsSinceEpoch,
    };
  }

  TicketSku _mapToTicketSku(Map<String, dynamic> map) {
    return TicketSku(
      skuId: map['sku_id'],
      name: map['name'],
      price: map['price'],
      quantity: map['quantity'] ?? 1,
      priority: TicketPriority.values.firstWhere(
        (e) => e.toString().split('.').last == map['priority'],
        orElse: () => TicketPriority.medium,
      ),
      isEnabled: map['is_enabled'] == 1,
      seatInfo: map['seat_info'],
    );
  }

  Map<String, dynamic> _ticketSkuToMap(String concertId, TicketSku sku) {
    return {
      'id': '${concertId}_${sku.skuId}',
      'concert_id': concertId,
      'sku_id': sku.skuId,
      'name': sku.name,
      'price': sku.price,
      'quantity': sku.quantity,
      'priority': sku.priority.toString().split('.').last,
      'is_enabled': sku.isEnabled ? 1 : 0,
      'seat_info': sku.seatInfo,
    };
  }

  // 加密解密方法
  String _encrypt(String text) {
    try {
      final encrypted = _encrypter.encrypt(text, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      AppLogger.error('Encrypt failed', e);
      return text; // 加密失败时返回原文
    }
  }

  String _decrypt(String encryptedText) {
    try {
      final encrypted = Encrypted.fromBase64(encryptedText);
      return _encrypter.decrypt(encrypted, iv: _iv);
    } catch (e) {
      AppLogger.error('Decrypt failed', e);
      return encryptedText; // 解密失败时返回原文
    }
  }

  // 数据库维护
  Future<void> clearAllData() async {
    try {
      final db = await _database;
      
      await db.transaction((txn) async {
        await txn.delete('hunting_records');
        await txn.delete('ticket_skus');
        await txn.delete('concerts');
        await txn.delete('accounts');
      });
      
      AppLogger.info('All data cleared');
    } catch (e) {
      AppLogger.error('Clear all data failed', e);
      throw Exception('清空数据失败: $e');
    }
  }

  Future<void> exportData(String filePath) async {
    try {
      final accounts = await loadAccounts();
      final concerts = await loadConcerts();
      
      final exportData = {
        'accounts': accounts.map((a) => a.toJson()).toList(),
        'concerts': concerts.map((c) => c.toJson()).toList(),
        'exportTime': DateTime.now().toIso8601String(),
        'version': '1.0',
      };
      
      final file = File(filePath);
      await file.writeAsString(jsonEncode(exportData));
      
      AppLogger.info('Data exported to: $filePath');
    } catch (e) {
      AppLogger.error('Export data failed', e);
      throw Exception('导出数据失败: $e');
    }
  }

  Future<void> importData(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('文件不存在');
      }
      
      final content = await file.readAsString();
      final data = jsonDecode(content);
      
      // 导入账号
      if (data['accounts'] != null) {
        final accounts = (data['accounts'] as List)
            .map((json) => Account.fromJson(json))
            .toList();
        await saveAccounts(accounts);
      }
      
      // 导入演唱会
      if (data['concerts'] != null) {
        final concerts = (data['concerts'] as List)
            .map((json) => Concert.fromJson(json))
            .toList();
        await saveConcerts(concerts);
      }
      
      AppLogger.info('Data imported from: $filePath');
    } catch (e) {
      AppLogger.error('Import data failed', e);
      throw Exception('导入数据失败: $e');
    }
  }

  Future<void> close() async {
    if (_dbInstance != null) {
      await _dbInstance!.close();
      _dbInstance = null;
    }
  }
}
