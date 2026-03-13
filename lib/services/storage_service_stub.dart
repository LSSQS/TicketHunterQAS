import '../models/account.dart';
import '../models/concert.dart';

class StorageService {
  Future<List<Account>> loadAccounts() => throw UnimplementedError();
  Future<void> saveAccounts(List<Account> accounts) => throw UnimplementedError();
  Future<void> saveAccount(Account account) => throw UnimplementedError();
  Future<void> deleteAccount(String accountId) => throw UnimplementedError();

  Future<List<Concert>> loadConcerts() => throw UnimplementedError();
  Future<void> saveConcerts(List<Concert> concerts) => throw UnimplementedError();
  Future<void> saveConcert(Concert concert) => throw UnimplementedError();
  Future<void> deleteConcert(String concertId) => throw UnimplementedError();

  Future<void> saveHuntingRecord({
    required String concertId,
    required String accountId,
    required String skuId,
    required bool success,
    String? message,
    String? orderId,
    bool isBlocked = false,
    Map<String, dynamic>? metadata,
  }) => throw UnimplementedError();

  Future<List<Map<String, dynamic>>> getHuntingRecords({
    String? concertId,
    String? accountId,
    int? limit,
  }) => throw UnimplementedError();

  Future<void> saveConfig(String key, dynamic value) => throw UnimplementedError();
  Future<T?> getConfig<T>(String key, {T? defaultValue}) => throw UnimplementedError();
  Future<void> removeConfig(String key) => throw UnimplementedError();

  Future<void> clearAllData() => throw UnimplementedError();
  Future<void> exportData(String filePath) => throw UnimplementedError();
  Future<void> importData(String filePath) => throw UnimplementedError();
  Future<void> close() => throw UnimplementedError();
}
