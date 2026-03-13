import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import '../utils/logger.dart';
import '../utils/device_utils.dart';
import '../models/platform_config.dart';
import '../config/app_config.dart';
import 'signature_service.dart';
import 'behavior_simulation_service.dart';
import 'device_fingerprint_service.dart';
import 'shield_breaker_service.dart';

class MaoyanApiService {
  final Dio _dio = Dio();
  final SignatureService _signatureService = SignatureService();
  final BehaviorSimulationService _behaviorService = BehaviorSimulationService();
  final DeviceFingerprintService _fingerprintService = DeviceFingerprintService();
  final ShieldBreakerService _shieldBreaker = ShieldBreakerService();
  final PlatformConfig _config = PlatformConfig.maoyan;
  
  final Map<String, String> _cookieJar = {};

  MaoyanApiService() {
    _setupDio();
  }

  void _setupDio() {
    _dio.options = BaseOptions(
      connectTimeout: Duration(seconds: AppConfig.defaultConnectTimeout),
      receiveTimeout: Duration(seconds: AppConfig.defaultReceiveTimeout),
      followRedirects: true,
      validateStatus: (status) => status! < 500,
    );

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        await _addCommonHeaders(options);
        
        if (_cookieJar.isNotEmpty) {
          final cookieString = _cookieJar.entries
              .map((e) => '${e.key}=${e.value}')
              .join('; ');
          options.headers['Cookie'] = cookieString;
        }
        
        await _behaviorService.randomDelay(minMs: 50, maxMs: 150);
        
        AppLogger.info('Maoyan Req: ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        _saveCookiesFromResponse(response);
        AppLogger.info('Maoyan Res: ${response.statusCode}');
        handler.next(response);
      },
      onError: (error, handler) {
        AppLogger.error('Maoyan Err: ${error.message}', error);
        handler.next(error);
      },
    ));
  }

  Future<void> _addCommonHeaders(RequestOptions options) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final mainDomain = _config.getDomain('main');
    
    options.headers.addAll({
      'User-Agent': await _generateUserAgent(),
      ..._config.headers,
      'Origin': mainDomain,
      'Referer': '$mainDomain/',
      'X-Client-Version': _config.version,
      'X-Channel-Id': _config.appKey,
      'X-Timestamp': timestamp.toString(),
    });
  }

  Future<String> _generateUserAgent() async {
    return 'Mozilla/5.0 (Linux; Android 11; Mi 11) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Mobile Safari/537.36 MaoyanApp/${_config.version}';
  }

  void _saveCookiesFromResponse(Response response) {
    final cookies = response.headers['set-cookie'];
    if (cookies != null) {
      for (final cookie in cookies) {
        final parts = cookie.split(';')[0].split('=');
        if (parts.length == 2) {
          _cookieJar[parts[0].trim()] = parts[1].trim();
        }
      }
    }
  }

  Future<Map<String, dynamic>> sendVerifyCode({
    required String phone,
    required String deviceId,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final nonce = _generateNonce();
      
      final params = {
        'mobile': phone,
        'timestamp': timestamp.toString(),
        'nonce': nonce,
      };
      
      final sign = await _generateMaoyanSign(params, deviceId);
      
      final response = await _dio.post(
        _config.getApiUrl('sendCode', domainKey: 'passport'),
        data: {
          ...params,
          'sign': sign,
        },
      );
      
      if (response.statusCode == 200 && response.data['status'] == 0) {
        return {
          'success': true,
          'message': 'Code Sent',
          'uuid': response.data['data']?['uuid'],
        };
      }
      
      return {
        'success': false,
        'message': response.data['msg'] ?? 'Code Send Failed',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Code Error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> login({
    required String phone,
    required String verifyCode,
    required String uuid,
    required String deviceId,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final nonce = _generateNonce();
      
      final params = {
        'mobile': phone,
        'verifyCode': verifyCode,
        'uuid': uuid,
        'timestamp': timestamp.toString(),
        'nonce': nonce,
      };
      
      final sign = await _generateMaoyanSign(params, deviceId);
      
      final response = await _dio.post(
        _config.getApiUrl('login', domainKey: 'passport'),
        data: {
          ...params,
          'sign': sign,
        },
      );
      
      if (response.statusCode == 200 && response.data['status'] == 0) {
        return {
          'success': true,
          'message': 'Login Success',
          'userId': response.data['data']?['userId'],
          'nickname': response.data['data']?['nickname'],
          'token': response.data['data']?['token'],
        };
      }
      
      return {
        'success': false,
        'message': response.data['msg'] ?? 'Login Failed',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Login Error: $e',
      };
    }
  }

  Future<List<Map<String, dynamic>>> searchMovies({
    required String keyword,
    int offset = 0,
    int limit = 20,
  }) async {
    final protocol = _shieldBreaker.getFallbackProtocol();
    if (protocol == 'H5_API') {
       return _searchMoviesH5(keyword, offset, limit);
    }

    try {
      final deviceId = await DeviceUtils.generateDeviceId();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final nonce = _generateNonce();
      
      final params = {
        'kw': keyword,
        'offset': offset.toString(),
        'limit': limit.toString(),
        'timestamp': timestamp.toString(),
        'nonce': nonce,
      };
      
      final sign = await _generateMaoyanSign(params, deviceId);
      
      final response = await _dio.get(
        _config.getApiUrl('search', domainKey: 'api'),
        queryParameters: {
          ...params,
          'sign': sign,
        },
      );

      final shieldLevel = _shieldBreaker.analyzeResponse(response, null);
      if (shieldLevel != ShieldLevel.none) {
        await _shieldBreaker.executeBreakerStrategy(shieldLevel, 'searchMovies');
        return _searchMoviesH5(keyword, offset, limit);
      }

      if (response.statusCode == 200 && response.data['status'] == 0) {
        final movies = response.data['data']?['movies'] as List? ?? [];
        return movies.map((movie) => _parseMovieItem(movie)).toList();
      }
      
      throw Exception('API Failed');
    } catch (e) {
      return _searchMoviesH5(keyword, offset, limit);
    }
  }

  Future<List<Map<String, dynamic>>> _searchMoviesH5(String keyword, int offset, int limit) async {
    try {
      final h5Url = 'https://m.maoyan.com/ajax/search';
      
      final headers = {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36',
        'Referer': 'https://m.maoyan.com/search?kw=$keyword',
        'X-Requested-With': 'XMLHttpRequest',
        'Cookie': '_lxsdk_cuid=18d4...; _lxsdk=18d4...; uuid_n_v=v1', 
      };

      final response = await _dio.get(
        h5Url,
        queryParameters: {
          'kw': keyword,
          'cityId': 1,
          'stype': -1,
        },
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final movies = response.data['movies']?['list'] as List? ?? [];
        return movies.map((item) => {
          'id': item['id']?.toString() ?? '',
          'name': item['nm'] ?? '',
          'enName': item['enm'] ?? '',
          'type': item['cat'] ?? '',
          'director': item['dir'] ?? '',
          'actors': item['star'] ?? '',
          'releaseDate': item['rt'] ?? '',
          'duration': '${item['dur']}分钟',
          'score': item['sc'] ?? 0.0,
          'wish': item['wish'] ?? 0,
          'posterUrl': item['img']?.replaceAll('w.h', '128.180') ?? '',
        }).toList();
      }
      
      return [];
    } catch (e) {
      rethrow;
    }
  }


  Map<String, dynamic> _parseMovieItem(Map<String, dynamic> movie) {
    return {
      'id': movie['id']?.toString() ?? '',
      'name': movie['nm'] ?? '',
      'enName': movie['enm'] ?? '',
      'type': movie['cat'] ?? '',
      'director': movie['dir'] ?? '',
      'actors': movie['star'] ?? '',
      'releaseDate': movie['rt'] ?? '',
      'duration': movie['dur'] ?? '',
      'score': movie['sc'] ?? 0.0,
      'wish': movie['wish'] ?? 0,
      'posterUrl': movie['img'] ?? '',
      'version': movie['version'] ?? '',
    };
  }

  Future<Map<String, dynamic>?> getMovieDetail(String movieId) async {
    try {
      final deviceId = await DeviceUtils.generateDeviceId();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final nonce = _generateNonce();
      
      final params = {
        'movieId': movieId,
        'timestamp': timestamp.toString(),
        'nonce': nonce,
      };
      
      final sign = await _generateMaoyanSign(params, deviceId);
      
      final response = await _dio.get(
        _config.getApiUrl('movieDetail', domainKey: 'api'),
        queryParameters: {
          ...params,
          'sign': sign,
        },
      );
      
      if (response.statusCode == 200 && response.data['status'] == 0) {
        return _parseMovieDetail(response.data['data']);
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> _parseMovieDetail(Map<String, dynamic> data) {
    final detailMovie = data['detailMovie'] ?? {};
    
    return {
      'id': detailMovie['id']?.toString() ?? '',
      'name': detailMovie['nm'] ?? '',
      'enName': detailMovie['enm'] ?? '',
      'type': detailMovie['cat'] ?? '',
      'director': detailMovie['dir'] ?? '',
      'actors': detailMovie['star'] ?? '',
      'releaseDate': detailMovie['rt'] ?? '',
      'duration': detailMovie['dur'] ?? 0,
      'score': detailMovie['sc'] ?? 0.0,
      'wish': detailMovie['wish'] ?? 0,
      'posterUrl': detailMovie['img'] ?? '',
      'description': detailMovie['dra'] ?? '',
      'photos': detailMovie['photos'] ?? [],
      'videos': detailMovie['videos'] ?? [],
    };
  }

  Future<List<Map<String, dynamic>>> getCinemas({
    required String movieId,
    required String cityId,
    int offset = 0,
    int limit = 20,
  }) async {
    try {
      final deviceId = await DeviceUtils.generateDeviceId();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final nonce = _generateNonce();
      
      final params = {
        'movieId': movieId,
        'cityId': cityId,
        'offset': offset.toString(),
        'limit': limit.toString(),
        'timestamp': timestamp.toString(),
        'nonce': nonce,
      };
      
      final sign = await _generateMaoyanSign(params, deviceId);
      
      final response = await _dio.get(
        _config.getApiUrl('cinemaList', domainKey: 'api'),
        queryParameters: {
          ...params,
          'sign': sign,
        },
      );
      
      if (response.statusCode == 200 && response.data['status'] == 0) {
        final cinemas = response.data['data']?['cinemas'] as List? ?? [];
        return cinemas.map((cinema) => _parseCinemaItem(cinema)).toList();
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }

  Map<String, dynamic> _parseCinemaItem(Map<String, dynamic> cinema) {
    return {
      'id': cinema['id']?.toString() ?? '',
      'name': cinema['nm'] ?? '',
      'address': cinema['addr'] ?? '',
      'distance': cinema['distance'] ?? '',
      'lowestPrice': cinema['sellPrice'] ?? 0.0,
      'services': cinema['services'] ?? [],
    };
  }

  Future<List<Map<String, dynamic>>> getShows({
    required String movieId,
    required String cinemaId,
  }) async {
    try {
      final deviceId = await DeviceUtils.generateDeviceId();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final nonce = _generateNonce();
      
      final params = {
        'movieId': movieId,
        'cinemaId': cinemaId,
        'timestamp': timestamp.toString(),
        'nonce': nonce,
      };
      
      final sign = await _generateMaoyanSign(params, deviceId);
      
      final response = await _dio.get(
        _config.getApiUrl('showList', domainKey: 'api'),
        queryParameters: {
          ...params,
          'sign': sign,
        },
      );
      
      if (response.statusCode == 200 && response.data['status'] == 0) {
        final shows = response.data['data']?['shows'] as List? ?? [];
        return shows.map((show) => _parseShowItem(show)).toList();
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }

  Map<String, dynamic> _parseShowItem(Map<String, dynamic> show) {
    return {
      'showId': show['showId']?.toString() ?? '',
      'showTime': show['tm'] ?? '',
      'hallName': show['hn'] ?? '',
      'language': show['lang'] ?? '',
      'version': show['tp'] ?? '',
      'price': show['sellPrice'] ?? 0.0,
      'seatCount': show['seatCount'] ?? 0,
    };
  }

  Future<Map<String, dynamic>?> getSeatMap({
    required String showId,
    required String cinemaId,
    required String deviceId,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final nonce = _generateNonce();
      
      final params = {
        'showId': showId,
        'cinemaId': cinemaId,
        'timestamp': timestamp.toString(),
        'nonce': nonce,
      };
      
      final sign = await _generateMaoyanSign(params, deviceId);
      
      final response = await _dio.get(
        _config.getApiUrl('seatMap', domainKey: 'api'),
        queryParameters: {
          ...params,
          'sign': sign,
        },
      );
      
      if (response.statusCode == 200 && response.data['status'] == 0) {
        return {
          'success': true,
          'seatMap': response.data['data']?['seatMap'],
          'seats': response.data['data']?['seats'],
          'soldSeats': response.data['data']?['soldSeats'],
        };
      }
      
      return {
        'success': false,
        'message': response.data['msg'] ?? 'SeatMap Failed',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'SeatMap Error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> lockSeats({
    required String showId,
    required List<String> seatIds,
    required String deviceId,
  }) async {
    try {
      await _behaviorService.simulateHumanBehavior('click');
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final nonce = _generateNonce();
      
      final params = {
        'showId': showId,
        'seatIds': seatIds.join(','),
        'timestamp': timestamp.toString(),
        'nonce': nonce,
      };
      
      final sign = await _generateMaoyanSign(params, deviceId);
      
      final response = await _dio.post(
        _config.getApiUrl('lockSeat', domainKey: 'api'),
        data: {
          ...params,
          'sign': sign,
        },
      );
      
      if (response.statusCode == 200 && response.data['status'] == 0) {
        return {
          'success': true,
          'message': 'Lock Success',
          'lockToken': response.data['data']?['lockToken'],
          'orderId': response.data['data']?['orderId'],
        };
      }
      
      final errorMessage = response.data['msg'] ?? 'Lock Failed';
      return {
        'success': false,
        'message': errorMessage,
        'isBlocked': _isBlockedError(errorMessage),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Lock Error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> submitOrder({
    required String showId,
    required String orderId,
    required String lockToken,
    required List<String> seatIds,
    required String deviceId,
  }) async {
    try {
      await _behaviorService.simulateHumanBehavior('order_create');
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final nonce = _generateNonce();
      
      final params = {
        'showId': showId,
        'orderId': orderId,
        'lockToken': lockToken,
        'seatIds': seatIds.join(','),
        'timestamp': timestamp.toString(),
        'nonce': nonce,
      };
      
      final sign = await _generateMaoyanSign(params, deviceId);
      
      final response = await _dio.post(
        _config.getApiUrl('submitOrder', domainKey: 'api'),
        data: {
          ...params,
          'sign': sign,
        },
      );
      
      if (response.statusCode == 200 && response.data['status'] == 0) {
        return {
          'success': true,
          'message': 'Submit Success',
          'orderId': response.data['data']?['orderId'],
          'orderNo': response.data['data']?['orderNo'],
          'payUrl': response.data['data']?['payUrl'],
        };
      }
      
      final errorMessage = response.data['msg'] ?? 'Submit Failed';
      return {
        'success': false,
        'message': errorMessage,
        'isBlocked': _isBlockedError(errorMessage),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Submit Error: $e',
      };
    }
  }

  Future<String> _generateMaoyanSign(
    Map<String, dynamic> params,
    String deviceId,
  ) async {
    final sortedKeys = params.keys.toList()..sort();
    final signStr = sortedKeys.map((key) => '$key=${params[key]}').join('&');
    
    final token = _cookieJar['token'] ?? '';
    final fullStr = '$signStr&token=$token&deviceId=$deviceId&secret=maoyan_secret_key_2024';
    
    final bytes = utf8.encode(fullStr);
    final digest = md5.convert(bytes);
    
    return digest.toString().toLowerCase();
  }

  String _generateNonce() {
    return Random().nextInt(999999).toString().padLeft(6, '0');
  }

  bool _isBlockedError(String message) {
    final blockedKeywords = [
      '风控',
      '限制',
      '异常',
      '封禁',
      '验证',
      'blocked',
      'limit',
      'risk',
      '频繁',
      '稍后再试',
      '请求过快',
    ];
    
    return blockedKeywords.any((keyword) =>
        message.toLowerCase().contains(keyword.toLowerCase()));
  }

  void setCookies(Map<String, String> cookies) {
    _cookieJar.addAll(cookies);
  }

  Map<String, String> getCookies() {
    return Map.from(_cookieJar);
  }

  void clearCookies() {
    _cookieJar.clear();
  }
}
