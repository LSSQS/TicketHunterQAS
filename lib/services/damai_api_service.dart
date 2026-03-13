import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import '../models/platform_config.dart';
import '../utils/logger.dart';
import '../utils/device_utils.dart';
import '../config/app_config.dart';
import 'signature_service.dart';
import 'behavior_simulation_service.dart';
import 'device_fingerprint_service.dart';
import 'rsa_encryption_service.dart';
import 'shield_breaker_service.dart';

class DamaiApiService {
  final Dio _dio = Dio();
  final SignatureService _signatureService = SignatureService();
  final BehaviorSimulationService _behaviorService = BehaviorSimulationService();
  final DeviceFingerprintService _fingerprintService = DeviceFingerprintService();
  final ShieldBreakerService _shieldBreaker = ShieldBreakerService();

  final PlatformConfig _config = PlatformConfig.damai;
  
  final Map<String, String> _cookieJar = {};

  DamaiApiService() {
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
        
        AppLogger.info('Damai Req: ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        _saveCookiesFromResponse(response);
        AppLogger.info('Damai Res: ${response.statusCode}');
        handler.next(response);
      },
      onError: (error, handler) {
        AppLogger.error('Damai Err: ${error.message}', error);
        handler.next(error);
      },
    ));
  }

  Future<void> _addCommonHeaders(RequestOptions options) async {
    final mainDomain = _config.getDomain('main');
    
    options.headers.addAll({
      'User-Agent': await _generateUserAgent(),
      ..._config.headers,
      'Origin': mainDomain,
      'Referer': '$mainDomain/',
      'Sec-Fetch-Dest': 'empty',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Site': 'same-site',
      'X-Requested-With': 'XMLHttpRequest',
    });
  }

  Future<String> _generateUserAgent() async {
    final deviceId = await DeviceUtils.generateDeviceId();
    return await _fingerprintService.getUserAgent(deviceId);
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

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    required String deviceId,
  }) async {
    try {
      await _getLoginPage();
      
      final captchaResult = await _getCaptcha(deviceId);
      
      final loginResult = await _submitLogin(
        username: username,
        password: password,
        deviceId: deviceId,
        captchaToken: captchaResult['token'],
      );
      
      return loginResult;
    } catch (e) {
      return {
        'success': false,
        'message': 'Login Failed: $e',
      };
    }
  }

  Future<void> _getLoginPage() async {
    try {
      final mainDomain = _config.getDomain('main');
      await _dio.get(
        '$mainDomain/login',
        options: Options(
          headers: {
            'Referer': mainDomain,
            'User-Agent': await _generateUserAgent(),
          },
        ),
      );
    } catch (e) {
      AppLogger.error('Get login page failed', e);
    }
  }

  Future<Map<String, dynamic>> _getCaptcha(String deviceId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final mtopDomain = _config.getDomain('mtop');
      
      final response = await _dio.post(
        '$mtopDomain${_config.getEndpoint('captchaGet')}',
        queryParameters: {
          'jsv': '2.6.1',
          'appKey': _config.appKey,
          't': timestamp,
          'sign': await _generateSign({}, timestamp, deviceId),
          'v': '1.0',
          'type': 'originaljson',
          'dataType': 'json',
        },
        data: {
          'sceneId': 'login',
          'appKey': _config.appKey,
        },
      );
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'token': response.data['data']?['token'] ?? '',
          'captchaUrl': response.data['data']?['captchaUrl'] ?? '',
        };
      }
      
      return {
        'success': false,
        'message': 'Captcha Failed',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Captcha Error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _submitLogin({
    required String username,
    required String password,
    required String deviceId,
    required String captchaToken,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final mtopDomain = _config.getDomain('mtop');
      
      final encryptedPassword = _encryptPassword(password);
      
      final response = await _dio.post(
        '$mtopDomain${_config.getEndpoint('login')}',
        queryParameters: {
          'jsv': '2.6.1',
          'appKey': _config.appKey,
          't': timestamp,
          'sign': await _generateSign({
            'loginId': username,
            'password': encryptedPassword,
          }, timestamp, deviceId),
          'v': _config.apiVersion,
          'type': 'originaljson',
          'dataType': 'json',
        },
        data: {
          'loginId': username,
          'password': encryptedPassword,
          'captchaToken': captchaToken,
          'umidToken': await _generateUmidToken(deviceId),
        },
      );
      
      if (response.statusCode == 200 && response.data['ret']?[0] == 'SUCCESS::调用成功') {
        return {
          'success': true,
          'message': 'Login Success',
          'userId': response.data['data']?['userId'],
          'nick': response.data['data']?['nick'],
          'token': response.data['data']?['token'],
        };
      }
      
      return {
        'success': false,
        'message': response.data['ret']?[1] ?? 'Login Failed',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Login Error: $e',
      };
    }
  }

  Future<List<Map<String, dynamic>>> searchShows({
    required String keyword,
    String? city,
    String? category,
    int page = 1,
    int pageSize = 20,
  }) async {
    final protocol = _shieldBreaker.getFallbackProtocol();
    
    if (protocol == 'H5_API') {
       return _searchShowsH5(keyword, city, page);
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final deviceId = await DeviceUtils.generateDeviceId();
      final mtopDomain = _config.getDomain('mtop');
      
      final params = {
        'keyword': keyword,
        'cityName': city ?? '全国',
        'cty': category ?? '',
        'pageNum': page.toString(),
        'pageSize': pageSize.toString(),
      };
      
      final response = await _dio.get(
        '$mtopDomain${_config.getEndpoint('itemSearch')}',
        queryParameters: {
          'jsv': '2.6.1',
          'appKey': _config.appKey,
          't': timestamp,
          'sign': await _generateSign(params, timestamp, deviceId),
          'v': _config.apiVersion,
          'type': 'originaljson',
          'dataType': 'json',
          'data': jsonEncode(params),
        },
      );
      
      final shieldLevel = _shieldBreaker.analyzeResponse(response, null);
      if (shieldLevel != ShieldLevel.none) {
        await _shieldBreaker.executeBreakerStrategy(shieldLevel, 'searchShows');
        return _searchShowsH5(keyword, city, page);
      }

      if (response.statusCode == 200 && response.data['ret']?[0] == 'SUCCESS::调用成功') {
        final items = response.data['data']?['itemList'] as List? ?? [];
        return items.map((item) => _parseShowItem(item)).toList();
      }
      
      return _searchShowsH5(keyword, city, page);
      
    } catch (e) {
      return _searchShowsH5(keyword, city, page);
    }
  }

  Future<List<Map<String, dynamic>>> _searchShowsH5(String keyword, String? city, int page) async {
    try {
      final h5Url = 'https://search.damai.cn/search.html';
      
      final headers = {
        'User-Agent': _shieldBreaker.getRandomUserAgent(),
        'Referer': 'https://m.damai.cn/',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
        'Cookie': 'cna=RecLHToken; isg=BPN_Real_Token_Placeholder',
      };

      final response = await _dio.get(
        h5Url,
        queryParameters: {
          'keyword': keyword,
          'destCity': city ?? '全国',
        },
        options: Options(headers: headers),
      );

      _shieldBreaker.resetH5Status();

      if (response.statusCode == 200) {
        final html = response.data.toString();
        final regex = RegExp(r'"projectInfo"\s*:\s*(\[\{.*?\}\])');
        final match = regex.firstMatch(html);
        
        if (match != null) {
          final jsonStr = match.group(1);
          if (jsonStr != null) {
            final List<dynamic> items = jsonDecode(jsonStr);
            return items.map((item) => {
              'itemId': item['id']?.toString() ?? '',
              'name': item['name'] ?? '',
              'artist': item['actors'] ?? '',
              'venue': item['venueName'] ?? '',
              'city': item['cityName'] ?? '',
              'showTime': item['showTime'] ?? '',
              'priceRange': item['price'] ?? 'TBD',
              'posterUrl': item['projectImg'] ?? '',
              'status': item['status'] ?? 1,
              'category': item['categoryName'] ?? 'Concert',
            }).toList();
          }
        }
        
        if (html.contains('滑动验证') || html.contains('baxia-dialog-content')) {
             _shieldBreaker.recordH5Failure();
             throw Exception('Captcha Detected');
        }
      } else {
        _shieldBreaker.recordH5Failure();
      }
      
      return [];
    } catch (e) {
      _shieldBreaker.recordH5Failure();
      rethrow;
    }
  }


  Map<String, dynamic> _parseShowItem(Map<String, dynamic> item) {
    return {
      'itemId': item['itemId']?.toString() ?? '',
      'name': item['name'] ?? '',
      'artist': item['performerName'] ?? '',
      'venue': item['venueName'] ?? '',
      'city': item['cityName'] ?? '',
      'showTime': item['performDate'] ?? '',
      'saleStartTime': item['saleTime'] ?? '',
      'priceRange': item['priceStr'] ?? '',
      'posterUrl': item['verticalPicUrl'] ?? item['picUrl'] ?? '',
      'status': item['saleFlag'] ?? 0,
      'category': item['categoryName'] ?? '',
    };
  }

  Future<Map<String, dynamic>?> getShowDetail(String itemId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final deviceId = await DeviceUtils.generateDeviceId();
      final mtopDomain = _config.getDomain('mtop');
      
      final params = {'itemId': itemId};
      
      final response = await _dio.get(
        '$mtopDomain${_config.getEndpoint('itemDetail')}',
        queryParameters: {
          'jsv': '2.6.1',
          'appKey': _config.appKey,
          't': timestamp,
          'sign': await _generateSign(params, timestamp, deviceId),
          'v': '1.2',
          'type': 'originaljson',
          'dataType': 'json',
          'data': jsonEncode(params),
        },
      );
      
      if (response.statusCode == 200 && response.data['ret']?[0] == 'SUCCESS::调用成功') {
        return _parseShowDetail(response.data['data']);
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> _parseShowDetail(Map<String, dynamic> data) {
    final detail = data['detail'] ?? {};
    final perform = data['perform'] ?? {};
    
    return {
      'itemId': detail['itemId']?.toString() ?? '',
      'name': detail['itemName'] ?? '',
      'artist': perform['artistName'] ?? '',
      'venue': perform['venueName'] ?? '',
      'city': perform['cityName'] ?? '',
      'showTime': perform['performDate'] ?? '',
      'saleStartTime': perform['saleTime'] ?? '',
      'description': detail['description'] ?? '',
      'posterUrl': detail['picUrl'] ?? '',
      'skus': _parseSkus(data['sku'] ?? {}),
      'notice': detail['notice'] ?? '',
      'realName': detail['realName'] == '1',
    };
  }

  List<Map<String, dynamic>> _parseSkus(Map<String, dynamic> skuData) {
    final skuList = <Map<String, dynamic>>[];
    
    if (skuData['skuList'] != null) {
      for (final sku in skuData['skuList']) {
        skuList.add({
          'skuId': sku['skuId']?.toString() ?? '',
          'name': sku['priceName'] ?? '',
          'price': (sku['price'] ?? 0) / 100.0,
          'priceStr': sku['priceStr'] ?? '',
          'stock': sku['canBuy'] ? 1 : 0,
        });
      }
    }
    
    return skuList;
  }

  Future<Map<String, dynamic>> buildOrder({
    required String itemId,
    required String skuId,
    required int quantity,
    required String deviceId,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final mtopDomain = _config.getDomain('mtop');
      
      final params = {
        'itemId': itemId,
        'skuId': skuId,
        'quantity': quantity.toString(),
        'dmChannel': 'damai@damaih5_h5',
        'osType': '2',
        'umpChannel': 'damai@damaih5_h5',
        'subChannel': 'damai@damaih5_h5',
        'atomSplit': '1',
      };
      
      final response = await _dio.post(
        '$mtopDomain${_config.getEndpoint('orderBuild')}',
        queryParameters: {
          'jsv': '2.6.1',
          'appKey': _config.appKey,
          't': timestamp,
          'sign': await _generateSign(params, timestamp, deviceId),
          'v': '4.0',
          'type': 'originaljson',
          'dataType': 'json',
        },
        data: params,
      );
      
      if (response.statusCode == 200 && response.data['ret']?[0]?.startsWith('SUCCESS') == true) {
        return {
          'success': true,
          'message': 'Build Order Success',
          'data': response.data['data'],
        };
      }
      
      return {
        'success': false,
        'message': response.data['ret']?[1] ?? 'Build Order Failed',
        'isBlocked': _isBlockedError(response.data['ret']?[1] ?? ''),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Build Order Error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> createOrder({
    required String itemId,
    required String skuId,
    required int quantity,
    required Map<String, dynamic> buildData,
    required String deviceId,
  }) async {
    try {
      await _behaviorService.simulateHumanBehavior('order_create');
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final mtopDomain = _config.getDomain('mtop');
      
      final params = {
        'itemId': itemId,
        'skuId': skuId,
        'quantity': quantity.toString(),
        'buyNow': 'true',
        'exParams': jsonEncode({
          ...buildData,
          'dmChannel': 'damai@damaih5_h5',
        }),
      };
      
      final response = await _dio.post(
        '$mtopDomain${_config.getEndpoint('orderCreate')}',
        queryParameters: {
          'jsv': '2.6.1',
          'appKey': _config.appKey,
          't': timestamp,
          'sign': await _generateSign(params, timestamp, deviceId),
          'v': '4.0',
          'type': 'originaljson',
          'dataType': 'json',
        },
        data: params,
      );
      
      if (response.statusCode == 200 && response.data['ret']?[0]?.startsWith('SUCCESS') == true) {
        return {
          'success': true,
          'message': 'Create Order Success',
          'orderId': response.data['data']?['orderId'],
          'data': response.data['data'],
        };
      }
      
      final errorMessage = response.data['ret']?[1] ?? 'Create Order Failed';
      return {
        'success': false,
        'message': errorMessage,
        'isBlocked': _isBlockedError(errorMessage),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Create Order Error: $e',
      };
    }
  }

  Future<String> _generateSign(
    Map<String, dynamic> params,
    int timestamp,
    String deviceId,
  ) async {
    final token = _cookieJar['_m_h5_tk']?.split('_')[0] ?? '';
    
    final sortedParams = Map.fromEntries(
      params.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
    );
    
    final dataStr = jsonEncode(sortedParams);
    final signStr = '$token&$timestamp&${_config.appKey}&$dataStr';
    
    final bytes = utf8.encode(signStr);
    final digest = md5.convert(bytes);
    
    return digest.toString();
  }

  Future<String> _generateUmidToken(String deviceId) async {
    final fingerprint = await _fingerprintService.generateFingerprint(deviceId);
    final fingerprintHash = _fingerprintService.generateFingerprintHash(fingerprint);
    
    return fingerprintHash.substring(0, 32);
  }

  String _encryptPassword(String password) {
    try {
      if (RsaEncryptionService.instance.isInitialized) {
        return RsaEncryptionService.instance.encryptWithPublicKey(password);
      } else {
        final bytes = utf8.encode(password);
        return base64Encode(bytes);
      }
    } catch (e) {
      final bytes = utf8.encode(password);
      return base64Encode(bytes);
    }
  }

  bool _isBlockedError(String message) {
    final blockedKeywords = [
      'RISK_CONTROL',
      'FREQUENCY_LIMIT',
      'DEVICE_ABNORMAL',
      'ACCOUNT_RISK',
      'IP_BLOCKED',
      '风控',
      '限制',
      '异常',
      '封禁',
      '频繁',
      '验证',
    ];
    
    return blockedKeywords.any((keyword) =>
        message.toUpperCase().contains(keyword.toUpperCase()));
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
