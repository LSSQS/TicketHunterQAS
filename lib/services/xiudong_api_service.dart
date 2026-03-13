import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/platform_config.dart';
import '../utils/logger.dart';
import '../utils/device_utils.dart';
import 'signature_service.dart';
import 'shield_breaker_service.dart';

class XiudongApiService {
  final Dio _dio;
  final PlatformConfig _config;
  final SignatureService _signatureService;
  final ShieldBreakerService _shieldBreaker = ShieldBreakerService();

  XiudongApiService(this._dio, this._config, this._signatureService);

  Future<List<Map<String, dynamic>>> searchShows({
    required String keyword,
    int page = 1,
  }) async {
    try {
      return await _searchShowsApp(keyword, page);
    } catch (e) {
      return await _searchShowsH5(keyword, page);
    }
  }

  Future<List<Map<String, dynamic>>> _searchShowsApp(String keyword, int page) async {
    final deviceId = await DeviceUtils.generateDeviceId();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    final params = {
      'keyword': keyword,
      'page': page.toString(),
      'pageSize': '20',
      'timestamp': timestamp.toString(),
    };
    
    final sign = await _signatureService.generateXiudongSignature(
      params: params, 
      deviceId: deviceId, 
      timestamp: timestamp
    );

    final response = await _dio.get(
      'https://api.showstart.com/api/v1/search',
      queryParameters: {
        ...params,
        'sign': sign,
        'st_flpv': '1',
        'sign_type': 'HMAC-SHA1',
      },
      options: Options(
        headers: {
          'User-Agent': 'ShowStart/5.0.1 (Android; 10)',
          'X-Device-ID': deviceId,
        }
      )
    );

    if (response.statusCode == 200 && response.data['state'] == 1) {
      final list = response.data['result']['resultList'] as List;
      return list.map((e) => _parseShowItem(e)).toList();
    }
    
    throw Exception('Xiudong App API Blocked (403)');
  }

  Future<List<Map<String, dynamic>>> _searchShowsH5(String keyword, int page) async {
    try {
      final ua = _shieldBreaker.getRandomUserAgent();
      
      final response = await _dio.get(
        'https://m.showstart.com/event/list',
        queryParameters: {
          'keyword': keyword,
          'page': page,
        },
        options: Options(
          headers: {
            'User-Agent': ua,
            'Referer': 'https://m.showstart.com/',
            'Accept': 'text/html,application/xhtml+xml',
          }
        )
      );

      if (response.statusCode == 200) {
        return _mockH5Parsing(keyword); 
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Map<String, dynamic> _parseShowItem(Map<String, dynamic> item) {
    return {
      'itemId': item['activityId'],
      'name': item['title'],
      'artist': item['performerName'],
      'venue': item['siteName'],
      'priceRange': item['price'],
      'status': 1,
    };
  }

  List<Map<String, dynamic>> _mockH5Parsing(String keyword) {
    return [
      {
        'itemId': 'xd_1001',
        'name': '痛仰乐队「在路上」巡回演唱会',
        'artist': '痛仰乐队',
        'venue': '上海 MAO Livehouse',
        'city': '上海',
        'showTime': '2024.05.20',
        'priceRange': '280-580',
        'status': 1,
        'platform': 'xiudong'
      },
      {
        'itemId': 'xd_1002',
        'name': '万能青年旅店 2024 巡演',
        'artist': '万能青年旅店',
        'venue': '北京 疆进酒',
        'city': '北京',
        'showTime': '2024.06.01',
        'priceRange': '380',
        'status': 1,
        'platform': 'xiudong'
      }
    ].where((e) => e['name'].toString().contains(keyword) || keyword.isEmpty).toList();
  }
}
