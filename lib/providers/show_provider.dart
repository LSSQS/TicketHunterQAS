import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/show.dart';
import '../models/platform_config.dart';
import '../services/unified_ticket_service.dart';

class ShowProvider extends ChangeNotifier {
  List<Show> _shows = [];
  TicketPlatform? _selectedPlatform;
  bool _isLoading = false;
  
  final UnifiedTicketService _ticketService = UnifiedTicketService();
  final Map<TicketPlatform, List<Map<String, dynamic>>> _searchResults = {};
  final Map<TicketPlatform, List<Map<String, dynamic>>> _recommendations = {};

  List<Show> get shows => _shows;
  List<Show> get activeShows => _shows.where((show) => show.isEnabled).toList();
  TicketPlatform? get selectedPlatform => _selectedPlatform;
  bool get isLoading => _isLoading;
  
  Map<TicketPlatform, List<Map<String, dynamic>>> get searchResults => _searchResults;
  Map<TicketPlatform, List<Map<String, dynamic>>> get recommendations => _recommendations;

  /// 设置选中的平台
  void setSelectedPlatform(TicketPlatform platform) {
    _selectedPlatform = platform;
    notifyListeners();
    _saveSelectedPlatform();
  }

  /// 获取平台统计
  Map<TicketPlatform, int> getPlatformStats() {
    final stats = <TicketPlatform, int>{};
    for (final platform in TicketPlatform.values) {
      stats[platform] = _shows.where((show) => show.platform == platform).length;
    }
    return stats;
  }

  /// 根据平台筛选演出
  List<Show> getShowsByPlatform(TicketPlatform platform) {
    return _shows.where((show) => show.platform == platform).toList();
  }

  /// 远程搜索演出
  Future<void> search({
    required TicketPlatform platform,
    required String keyword,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await _ticketService.search(
        platform: platform,
        keyword: keyword,
      );
      _searchResults[platform] = results;
    } catch (e) {
      debugPrint('Error searching shows: $e');
      _searchResults[platform] = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 加载推荐/热门演出
  Future<void> loadRecommendations(TicketPlatform platform) async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await _ticketService.getRecommendedShows(platform);
      _recommendations[platform] = results;
    } catch (e) {
      debugPrint('Error loading recommendations: $e');
      _recommendations[platform] = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 从搜索结果创建演出
  Future<Show?> createShowFromSearchResult({
    required TicketPlatform platform,
    required Map<String, dynamic> searchResult,
    required Map<String, dynamic> config,
  }) async {
    try {
      String itemId;
      String name;
      String venue;
      String? posterUrl;
      DateTime showTime;
      DateTime saleStartTime;
      
      if (platform == TicketPlatform.damai) {
        itemId = searchResult['itemId'] ?? '';
        name = searchResult['name'] ?? '未知演出';
        venue = searchResult['venue'] ?? '未知场馆';
        posterUrl = searchResult['cover'];
        showTime = DateTime.tryParse(searchResult['showTime'] ?? '') ?? DateTime.now().add(const Duration(days: 30));
        saleStartTime = DateTime.now().add(const Duration(days: 1)); // 默认为明天
      } else {
        itemId = searchResult['movieId']?.toString() ?? '';
        name = searchResult['movieName'] ?? '未知电影';
        venue = searchResult['cinemaName'] ?? '任意影院';
        posterUrl = searchResult['cover'];
        showTime = DateTime.tryParse(searchResult['releaseDate'] ?? '') ?? DateTime.now();
        saleStartTime = DateTime.now();
      }

      final show = Show(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        venue: venue,
        itemId: itemId,
        platform: platform,
        type: platform == TicketPlatform.damai ? ShowType.concert : ShowType.movie,
        showTime: showTime,
        saleStartTime: saleStartTime,
        posterUrl: posterUrl,
        skus: [
          TicketSku(
            skuId: 'default',
            name: '默认票档',
            price: 0.0,
            priority: TicketPriority.high,
          )
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        maxConcurrency: config['maxConcurrency'] ?? 10,
        retryCount: config['retryCount'] ?? 10,
        retryDelay: Duration(milliseconds: config['retryDelay'] ?? 1000),
      );

      addShow(show);
      return show;
    } catch (e) {
      debugPrint('Error creating show from result: $e');
      return null;
    }
  }

  /// 添加演出
  void addShow(Show show) {
    _shows.add(show);
    notifyListeners();
    _saveShows();
  }

  /// 更新演出
  void updateShow(Show updatedShow) {
    final index = _shows.indexWhere((show) => show.id == updatedShow.id);
    if (index != -1) {
      _shows[index] = updatedShow;
      notifyListeners();
      _saveShows();
    }
  }

  /// 删除演出
  void removeShow(String showId) {
    _shows.removeWhere((show) => show.id == showId);
    notifyListeners();
    _saveShows();
  }

  /// 切换演出启用状态
  void toggleShow(String showId) {
    final index = _shows.indexWhere((show) => show.id == showId);
    if (index != -1) {
      _shows[index] = _shows[index].copyWith(
        status: _shows[index].isEnabled ? ShowStatus.pending : ShowStatus.active
      );
      notifyListeners();
      _saveShows();
    }
  }

  /// 批量启用/禁用演出
  void toggleAllShows(bool enabled) {
    for (int i = 0; i < _shows.length; i++) {
      _shows[i] = _shows[i].copyWith(
        status: enabled ? ShowStatus.active : ShowStatus.pending
      );
    }
    notifyListeners();
    _saveShows();
  }

  /// 根据平台批量启用/禁用演出
  void toggleShowsByPlatform(TicketPlatform platform, bool enabled) {
    for (int i = 0; i < _shows.length; i++) {
      if (_shows[i].platform == platform) {
        _shows[i] = _shows[i].copyWith(
          status: enabled ? ShowStatus.active : ShowStatus.pending
        );
      }
    }
    notifyListeners();
    _saveShows();
  }

  /// 本地搜索演出
  List<Show> searchLocalShows(String query) {
    if (query.isEmpty) return _shows;
    
    final lowerQuery = query.toLowerCase();
    return _shows.where((show) {
      return show.name.toLowerCase().contains(lowerQuery) ||
             show.venue.toLowerCase().contains(lowerQuery) ||
             show.platformName.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// 加载演出数据
  Future<void> loadShows() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 加载选中的平台
      final platformString = prefs.getString('selected_platform');
      if (platformString != null) {
        _selectedPlatform = TicketPlatform.values.firstWhere(
          (platform) => platform.toString() == platformString,
          orElse: () => TicketPlatform.damai,
        );
      }

      // 加载演出列表
      final showsJson = prefs.getString('shows');
      if (showsJson != null) {
        final List<dynamic> showsList = json.decode(showsJson);
        _shows = showsList.map((json) => Show.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error loading shows: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 保存演出数据
  Future<void> _saveShows() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final showsJson = json.encode(_shows.map((show) => show.toJson()).toList());
      await prefs.setString('shows', showsJson);
    } catch (e) {
      debugPrint('Error saving shows: $e');
    }
  }

  /// 保存选中的平台
  Future<void> _saveSelectedPlatform() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_selectedPlatform != null) {
        await prefs.setString('selected_platform', _selectedPlatform.toString());
      }
    } catch (e) {
      debugPrint('Error saving selected platform: $e');
    }
  }

  /// 清空所有数据
  Future<void> clearAll() async {
    _shows.clear();
    _selectedPlatform = null;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('shows');
    await prefs.remove('selected_platform');
  }

  /// 导出数据
  Map<String, dynamic> exportData() {
    return {
      'shows': _shows.map((show) => show.toJson()).toList(),
      'selectedPlatform': _selectedPlatform?.toString(),
      'exportTime': DateTime.now().toIso8601String(),
    };
  }

  /// 导入数据
  Future<void> importData(Map<String, dynamic> data) async {
    try {
      if (data['shows'] != null) {
        final List<dynamic> showsList = data['shows'];
        _shows = showsList.map((json) => Show.fromJson(json)).toList();
      }

      if (data['selectedPlatform'] != null) {
        _selectedPlatform = TicketPlatform.values.firstWhere(
          (platform) => platform.toString() == data['selectedPlatform'],
          orElse: () => TicketPlatform.damai,
        );
      }

      notifyListeners();
      await _saveShows();
      await _saveSelectedPlatform();
    } catch (e) {
      debugPrint('Error importing data: $e');
      rethrow;
    }
  }
}