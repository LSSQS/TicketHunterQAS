import 'package:flutter/foundation.dart';
import '../models/concert.dart';
import '../services/storage_service.dart';
import '../utils/logger.dart';

class ConcertProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  
  List<Concert> _concerts = [];
  Concert? _selectedConcert;
  bool _isLoading = false;
  String? _error;

  List<Concert> get concerts => _concerts;
  Concert? get selectedConcert => _selectedConcert;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  List<Concert> get upcomingConcerts => 
      _concerts.where((concert) => concert.isUpcoming).toList();
  
  List<Concert> get activeConcerts => 
      _concerts.where((concert) => concert.isOnSale).toList();
  
  List<Concert> get completedConcerts => 
      _concerts.where((concert) => concert.status == ConcertStatus.completed).toList();

  ConcertProvider() {
    _loadConcerts();
  }

  Future<void> _loadConcerts() async {
    try {
      _setLoading(true);
      _concerts = await _storageService.loadConcerts();
      _clearError();
      AppLogger.info('Loaded ${_concerts.length} concerts');
    } catch (e) {
      _setError('加载演唱会配置失败: $e');
      AppLogger.error('Failed to load concerts', e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addConcert(Concert concert) async {
    try {
      _setLoading(true);

      _concerts.add(concert);
      await _storageService.saveConcerts(_concerts);
      _clearError();

      AppLogger.info('Added new concert: ${concert.name}');
      notifyListeners();
    } catch (e) {
      _setError('添加演唱会失败: $e');
      AppLogger.error('Failed to add concert', e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateConcert(Concert concert) async {
    try {
      final index = _concerts.indexWhere((c) => c.id == concert.id);
      if (index != -1) {
        _concerts[index] = concert.copyWith(updatedAt: DateTime.now());
        await _storageService.saveConcerts(_concerts);
        
        if (_selectedConcert?.id == concert.id) {
          _selectedConcert = _concerts[index];
        }
        
        _clearError();
        AppLogger.info('Updated concert: ${concert.name}');
        notifyListeners();
      }
    } catch (e) {
      _setError('更新演唱会失败: $e');
      AppLogger.error('Failed to update concert', e);
    }
  }

  Future<void> removeConcert(String concertId) async {
    try {
      _concerts.removeWhere((concert) => concert.id == concertId);
      await _storageService.saveConcerts(_concerts);
      
      if (_selectedConcert?.id == concertId) {
        _selectedConcert = null;
      }
      
      _clearError();
      AppLogger.info('Removed concert: $concertId');
      notifyListeners();
    } catch (e) {
      _setError('删除演唱会失败: $e');
      AppLogger.error('Failed to remove concert', e);
    }
  }

  void selectConcert(String concertId) {
    _selectedConcert = _concerts.firstWhere(
      (concert) => concert.id == concertId,
      orElse: () => throw Exception('演唱会不存在'),
    );
    notifyListeners();
  }

  Future<void> updateConcertStatus(String concertId, ConcertStatus status) async {
    try {
      final index = _concerts.indexWhere((c) => c.id == concertId);
      if (index != -1) {
        _concerts[index] = _concerts[index].copyWith(
          status: status,
          updatedAt: DateTime.now(),
        );
        await _storageService.saveConcerts(_concerts);
        
        if (_selectedConcert?.id == concertId) {
          _selectedConcert = _concerts[index];
        }
        
        _clearError();
        notifyListeners();
      }
    } catch (e) {
      _setError('更新演唱会状态失败: $e');
      AppLogger.error('Failed to update concert status', e);
    }
  }

  Future<void> addTicketSku(String concertId, TicketSku sku) async {
    try {
      final index = _concerts.indexWhere((c) => c.id == concertId);
      if (index != -1) {
        final concert = _concerts[index];
        final updatedSkus = List<TicketSku>.from(concert.skus)..add(sku);
        
        _concerts[index] = concert.copyWith(
          skus: updatedSkus,
          updatedAt: DateTime.now(),
        );
        
        await _storageService.saveConcerts(_concerts);
        
        if (_selectedConcert?.id == concertId) {
          _selectedConcert = _concerts[index];
        }
        
        _clearError();
        notifyListeners();
      }
    } catch (e) {
      _setError('添加票档失败: $e');
      AppLogger.error('Failed to add ticket sku', e);
    }
  }

  Future<void> updateTicketSku(String concertId, TicketSku sku) async {
    try {
      final index = _concerts.indexWhere((c) => c.id == concertId);
      if (index != -1) {
        final concert = _concerts[index];
        final updatedSkus = concert.skus.map((s) => 
            s.skuId == sku.skuId ? sku : s).toList();
        
        _concerts[index] = concert.copyWith(
          skus: updatedSkus,
          updatedAt: DateTime.now(),
        );
        
        await _storageService.saveConcerts(_concerts);
        
        if (_selectedConcert?.id == concertId) {
          _selectedConcert = _concerts[index];
        }
        
        _clearError();
        notifyListeners();
      }
    } catch (e) {
      _setError('更新票档失败: $e');
      AppLogger.error('Failed to update ticket sku', e);
    }
  }

  Future<void> removeTicketSku(String concertId, String skuId) async {
    try {
      final index = _concerts.indexWhere((c) => c.id == concertId);
      if (index != -1) {
        final concert = _concerts[index];
        final updatedSkus = concert.skus.where((s) => s.skuId != skuId).toList();
        
        _concerts[index] = concert.copyWith(
          skus: updatedSkus,
          updatedAt: DateTime.now(),
        );
        
        await _storageService.saveConcerts(_concerts);
        
        if (_selectedConcert?.id == concertId) {
          _selectedConcert = _concerts[index];
        }
        
        _clearError();
        notifyListeners();
      }
    } catch (e) {
      _setError('删除票档失败: $e');
      AppLogger.error('Failed to remove ticket sku', e);
    }
  }

  Concert? getConcertById(String concertId) {
    try {
      return _concerts.firstWhere((concert) => concert.id == concertId);
    } catch (e) {
      return null;
    }
  }

  List<Concert> getConcertsByStatus(ConcertStatus status) {
    return _concerts.where((concert) => concert.status == status).toList();
  }

  List<Concert> searchConcerts(String query) {
    if (query.isEmpty) return _concerts;
    
    final lowerQuery = query.toLowerCase();
    return _concerts.where((concert) =>
        concert.name.toLowerCase().contains(lowerQuery) ||
        (concert.artist?.toLowerCase() ?? '').contains(lowerQuery) ||
        concert.venue.toLowerCase().contains(lowerQuery)
    ).toList();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  void clearError() => _clearError();
}