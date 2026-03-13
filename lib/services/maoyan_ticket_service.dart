import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../models/show.dart';
import '../models/platform_config.dart';
import '../models/hunting_result.dart';
import '../config/app_config.dart';
import '../providers/ticket_hunter_provider.dart';
import '../utils/logger.dart';
import '../utils/device_utils.dart';
import 'signature_service.dart';
import 'behavior_simulation_service.dart';

/// 某眼抢票服务
class MaoyanTicketService {
  final Dio _dio = Dio();
  final SignatureService _signatureService = SignatureService();
  final BehaviorSimulationService _behaviorService = BehaviorSimulationService();
  final PlatformConfig _config = PlatformConfig.maoyan;
  
  MaoyanTicketService() {
    _setupDio();
  }

  void _setupDio() {
    _dio.options = BaseOptions(
      baseUrl: _config.baseUrl,
      connectTimeout: Duration(seconds: AppConfig.huntingConnectTimeout),
      receiveTimeout: Duration(seconds: AppConfig.huntingReceiveTimeout),
      // Web环境下不设置headers，避免CORS预检问题
      headers: kIsWeb ? {} : _config.headers,
    );

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        await _behaviorService.randomDelay();
        // Web环境下清除所有可能导致CORS问题的headers
        if (kIsWeb) {
          options.headers.remove('Accept-Encoding');
          options.headers.remove('Connection');
          options.headers.remove('Cache-Control');
          options.headers.remove('Pragma');
        }
        AppLogger.debug('Maoyan request: ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        AppLogger.debug('Maoyan response: ${response.statusCode}');
        handler.next(response);
      },
      onError: (error, handler) {
        AppLogger.error('Maoyan request error: ${error.message}', error);
        handler.next(error);
      },
    ));
  }

  /// 提交订单
  Future<HuntingResult> submitOrder({
    required Account account,
    required Show show,
    required TicketSku sku,
    required Map<String, dynamic> params,
  }) async {
    try {
      AppLogger.info('Maoyan submitting order for: ${account.username}, show: ${show.name}');
      
      // 第一步：获取电影详情和场次信息
      final movieDetail = await _getMovieDetail(show.itemId);
      if (movieDetail == null) {
        return HuntingResult(
          success: false,
          message: '获取电影详情失败',
          timestamp: DateTime.now(),
        );
      }

      // 第二步：选择场次和座位
      final seatResult = await _selectSeats(
        account: account,
        show: show,
        sku: sku,
        movieDetail: movieDetail,
        params: params,
      );

      if (!seatResult.success) {
        return HuntingResult(
          success: false,
          message: seatResult.message,
          timestamp: DateTime.now(),
          isBlocked: seatResult.isBlocked,
        );
      }

      // 第三步：创建订单
      final orderResult = await _createOrder(
        account: account,
        show: show,
        sku: sku,
        seatData: seatResult.data!,
        params: params,
      );

      return HuntingResult(
        success: orderResult.success,
        message: orderResult.message,
        orderId: orderResult.orderId,
        timestamp: DateTime.now(),
        isBlocked: orderResult.isBlocked,
        metadata: {
          'movieDetail': movieDetail,
          'seatResult': seatResult.data,
          'orderResult': orderResult.data,
        },
      );
    } catch (e) {
      AppLogger.error('Maoyan submit order failed', e);
      return HuntingResult(
        success: false,
        message: '某眼抢票异常: $e',
        timestamp: DateTime.now(),
      );
    }
  }

  /// 获取电影详情
  Future<Map<String, dynamic>?> _getMovieDetail(String movieId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final deviceId = await DeviceUtils.generateDeviceId();
      
      final params = {
        'movieId': movieId,
        'timestamp': timestamp.toString(),
      };

      final signature = await _generateMaoyanSignature(params, deviceId);
      
      final response = await _dio.get(
        _config.apiEndpoints['movieDetail']!,
        queryParameters: {
          ...params,
          'sign': signature,
        },
        options: Options(
          headers: await _buildMaoyanHeaders(deviceId, timestamp),
        ),
      );

      if (response.statusCode == 200 && response.data['status'] == 0) {
        return response.data['data'];
      }

      return null;
    } catch (e) {
      AppLogger.error('Get movie detail failed', e);
      return null;
    }
  }

  /// 选择座位
  Future<MaoyanOperationResult> _selectSeats({
    required Account account,
    required Show show,
    required TicketSku sku,
    required Map<String, dynamic> movieDetail,
    required Map<String, dynamic> params,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // 获取场次信息
      final showInfo = movieDetail['shows']?.firstWhere(
        (s) => s['showId'].toString() == sku.skuId,
        orElse: () => null,
      );

      if (showInfo == null) {
        return MaoyanOperationResult(
          success: false,
          message: '场次信息不存在',
        );
      }

      // 获取座位图
      final seatMapResponse = await _getSeatMap(
        showId: sku.skuId,
        cinemaId: showInfo['cinemaId'].toString(),
        deviceId: account.deviceId,
      );

      if (!seatMapResponse.success) {
        return seatMapResponse;
      }

      // 智能选座
      final selectedSeats = await _intelligentSeatSelection(
        seatMap: seatMapResponse.data!,
        quantity: sku.quantity,
        preferences: params['seatPreferences'] ?? {},
      );

      if (selectedSeats.isEmpty) {
        return MaoyanOperationResult(
          success: false,
          message: '没有可选座位',
        );
      }

      // 锁定座位
      final lockResult = await _lockSeats(
        showId: sku.skuId,
        seats: selectedSeats,
        account: account,
      );

      return lockResult;
    } catch (e) {
      AppLogger.error('Select seats failed', e);
      return MaoyanOperationResult(
        success: false,
        message: '选座失败: $e',
      );
    }
  }

  /// 获取座位图
  Future<MaoyanOperationResult> _getSeatMap({
    required String showId,
    required String cinemaId,
    required String deviceId,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final params = {
        'showId': showId,
        'cinemaId': cinemaId,
        'timestamp': timestamp.toString(),
      };

      final signature = await _generateMaoyanSignature(params, deviceId);
      
      final response = await _dio.get(
        _config.getEndpoint('seatMapApi'),
        queryParameters: {
          ...params,
          'sign': signature,
        },
        options: Options(
          headers: await _buildMaoyanHeaders(deviceId, timestamp),
        ),
      );

      if (response.statusCode == 200 && response.data['status'] == 0) {
        return MaoyanOperationResult(
          success: true,
          message: '获取座位图成功',
          data: response.data['data'],
        );
      }

      return MaoyanOperationResult(
        success: false,
        message: response.data['msg'] ?? '获取座位图失败',
      );
    } catch (e) {
      return MaoyanOperationResult(
        success: false,
        message: '获取座位图异常: $e',
      );
    }
  }

  /// 智能选座算法
  Future<List<Map<String, dynamic>>> _intelligentSeatSelection({
    required Map<String, dynamic> seatMap,
    required int quantity,
    required Map<String, dynamic> preferences,
  }) async {
    final seats = seatMap['seats'] as List? ?? [];
    final availableSeats = seats.where((seat) => 
        seat['status'] == 'available' || seat['status'] == 0).toList();

    if (availableSeats.length < quantity) {
      return [];
    }

    // 按偏好排序座位
    availableSeats.sort((a, b) {
      final scoreA = _calculateSeatScore(a, preferences);
      final scoreB = _calculateSeatScore(b, preferences);
      return scoreB.compareTo(scoreA);
    });

    // 选择连续座位
    final selectedSeats = <Map<String, dynamic>>[];
    
    if (quantity == 1) {
      selectedSeats.add(availableSeats.first);
    } else {
      // 寻找连续座位
      for (int i = 0; i <= availableSeats.length - quantity; i++) {
        final consecutiveSeats = <Map<String, dynamic>>[];
        
        for (int j = 0; j < quantity; j++) {
          final currentSeat = availableSeats[i + j];
          final nextSeat = j < quantity - 1 ? availableSeats[i + j + 1] : null;
          
          consecutiveSeats.add(currentSeat);
          
          // 检查是否连续
          if (nextSeat != null) {
            final currentRow = currentSeat['row'];
            final currentCol = currentSeat['col'];
            final nextRow = nextSeat['row'];
            final nextCol = nextSeat['col'];
            
            if (currentRow != nextRow || nextCol != currentCol + 1) {
              break;
            }
          }
        }
        
        if (consecutiveSeats.length == quantity) {
          selectedSeats.addAll(consecutiveSeats);
          break;
        }
      }
      
      // 如果找不到连续座位，选择评分最高的座位
      if (selectedSeats.isEmpty) {
        selectedSeats.addAll(availableSeats.take(quantity).cast<Map<String, dynamic>>());
      }
    }

    return selectedSeats;
  }

  /// 计算座位评分
  double _calculateSeatScore(Map<String, dynamic> seat, Map<String, dynamic> preferences) {
    double score = 0.0;
    
    final row = seat['row'] as int? ?? 0;
    final col = seat['col'] as int? ?? 0;
    final price = seat['price'] as double? ?? 0.0;
    
    // 中间位置加分
    if (preferences['preferCenter'] == true) {
      final totalCols = preferences['totalCols'] as int? ?? 20;
      final centerDistance = (col - totalCols / 2).abs();
      score += (10 - centerDistance).clamp(0, 10);
    }
    
    // 前排位置加分
    if (preferences['preferFront'] == true) {
      score += (20 - row).clamp(0, 20);
    }
    
    // 价格偏好
    final maxPrice = preferences['maxPrice'] as double?;
    final minPrice = preferences['minPrice'] as double?;
    
    if (maxPrice != null && price <= maxPrice) {
      score += 5;
    }
    if (minPrice != null && price >= minPrice) {
      score += 5;
    }
    
    return score;
  }

  /// 锁定座位
  Future<MaoyanOperationResult> _lockSeats({
    required String showId,
    required List<Map<String, dynamic>> seats,
    required Account account,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final seatIds = seats.map((s) => s['seatId'].toString()).toList();
      
      final params = {
        'showId': showId,
        'seatIds': seatIds.join(','),
        'timestamp': timestamp.toString(),
      };

      final signature = await _generateMaoyanSignature(params, account.deviceId);
      
      final response = await _dio.post(
        _config.getEndpoint('lockSeatApi'),
        data: params,
        options: Options(
          headers: await _buildMaoyanHeaders(account.deviceId, timestamp),
        ),
      );

      if (response.statusCode == 200 && response.data['status'] == 0) {
        return MaoyanOperationResult(
          success: true,
          message: '锁定座位成功',
          data: {
            'seats': seats,
            'lockToken': response.data['data']['lockToken'],
          },
        );
      }

      final message = response.data['msg'] ?? '锁定座位失败';
      final isBlocked = _isMaoyanBlockedError(message);

      return MaoyanOperationResult(
        success: false,
        message: message,
        isBlocked: isBlocked,
      );
    } catch (e) {
      return MaoyanOperationResult(
        success: false,
        message: '锁定座位异常: $e',
      );
    }
  }

  /// 创建订单
  Future<MaoyanOperationResult> _createOrder({
    required Account account,
    required Show show,
    required TicketSku sku,
    required Map<String, dynamic> seatData,
    required Map<String, dynamic> params,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final orderParams = {
        'showId': sku.skuId,
        'seats': jsonEncode(seatData['seats']),
        'lockToken': seatData['lockToken'],
        'totalPrice': (sku.price * sku.quantity).toString(),
        'timestamp': timestamp.toString(),
      };

      final signature = await _generateMaoyanSignature(orderParams, account.deviceId);
      
      // 模拟人类行为延迟
      await _behaviorService.simulateHumanBehavior('order_create');

      final response = await _dio.post(
        _config.apiEndpoints['orderCreate']!,
        data: orderParams,
        options: Options(
          headers: await _buildMaoyanHeaders(account.deviceId, timestamp),
        ),
      );

      if (response.statusCode == 200 && response.data['status'] == 0) {
        return MaoyanOperationResult(
          success: true,
          message: '创建订单成功',
          orderId: response.data['data']['orderId'],
          data: response.data['data'],
        );
      }

      final message = response.data['msg'] ?? '创建订单失败';
      final isBlocked = _isMaoyanBlockedError(message);

      return MaoyanOperationResult(
        success: false,
        message: message,
        isBlocked: isBlocked,
      );
    } catch (e) {
      return MaoyanOperationResult(
        success: false,
        message: '创建订单异常: $e',
      );
    }
  }

  /// 生成某眼签名
  Future<String> _generateMaoyanSignature(
    Map<String, dynamic> params,
    String deviceId,
  ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final nonce = Random().nextInt(999999).toString().padLeft(6, '0');
    
    return await _signatureService.generateMaoyanSignature(
      params: params,
      deviceId: deviceId,
      timestamp: timestamp,
      nonce: nonce,
    );
  }

  /// 构建猫眼请求头
  Future<Map<String, String>> _buildMaoyanHeaders(String deviceId, int timestamp) async {
    final headers = Map<String, String>.from(_config.headers);
    final mainDomain = _config.getDomain('main');
    
    headers.addAll({
      'X-Device-ID': deviceId,
      'X-Timestamp': timestamp.toString(),
      'X-App-Version': _config.version,
      'Referer': '$mainDomain/',
      'Origin': mainDomain,
    });

    return headers;
  }

  /// 判断是否被风控
  bool _isMaoyanBlockedError(String message) {
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
    ];
    
    return blockedKeywords.any((keyword) => 
        message.toLowerCase().contains(keyword.toLowerCase()));
  }

  /// 搜索电影
  Future<List<Map<String, dynamic>>> searchMovies(String keyword) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final deviceId = await DeviceUtils.generateDeviceId();
      
      final params = {
        'keyword': keyword,
        'timestamp': timestamp.toString(),
      };

      final signature = await _generateMaoyanSignature(params, deviceId);
      
      final response = await _dio.get(
        _config.apiEndpoints['search']!,
        queryParameters: {
          ...params,
          'sign': signature,
        },
        options: Options(
          headers: await _buildMaoyanHeaders(deviceId, timestamp),
        ),
      );

      if (response.statusCode == 200 && response.data['status'] == 0) {
        return List<Map<String, dynamic>>.from(response.data['data']['movies'] ?? []);
      }

      return [];
    } catch (e) {
      AppLogger.error('Search movies failed', e);
      return [];
    }
  }

  /// 获取热门演出 (演唱会/音乐节等)
  Future<List<Map<String, dynamic>>> getHotShows() async {
    try {
      await _behaviorService.randomDelay();

      // 猫眼演出列表API - 获取演唱会类型
      // categoryType: 35=演唱会, 36=音乐节, 37=话剧歌剧, 38=体育赛事
      final params = {
        'categoryType': '35',
        'cityCode': '10', // 北京
        'pageNo': '1',
        'pageSize': '20',
      };

      // Web 环境下使用 CORS 代理
      String apiUrl = _config.getApiUrl('hotShows', domainKey: 'show');
      if (kIsWeb) {
        final queryString = params.entries.map((e) => '${e.key}=${e.value}').join('&');
        apiUrl = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent('$apiUrl?$queryString')}';
      }

      final response = await _dio.get(
        apiUrl,
        queryParameters: kIsWeb ? null : params,
        options: Options(
          headers: kIsWeb ? {} : {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36',
            'Referer': 'https://show.maoyan.com/',
          }
        )
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        // 处理演出列表数据
        List<dynamic> showList = [];
        if (data is Map<String, dynamic>) {
          // 尝试从不同的数据结构中获取列表
          showList = data['data']?['shows'] as List? ?? 
                     data['shows'] as List? ?? 
                     data['showList'] as List? ?? 
                     data['list'] as List? ?? 
                     data['movieList'] as List? ?? [];
        } else if (data is List) {
          showList = data;
        }

        return showList.map((item) {
          // 提取价格信息
          String? priceText = item['price']?.toString() ?? 
                             item['minPrice']?.toString() ?? 
                             item['priceRange']?.toString();
          double minPrice = 0.0;
          double maxPrice = 0.0;
          
          if (priceText != null) {
            // 尝试解析价格范围，如 "¥180-1280"
            final priceMatch = RegExp(r'(\d+(?:\.\d+)?)').allMatches(priceText);
            final prices = priceMatch.map((m) => double.tryParse(m.group(1)!) ?? 0.0).toList();
            if (prices.isNotEmpty) {
              minPrice = prices.reduce((a, b) => a < b ? a : b);
              maxPrice = prices.reduce((a, b) => a > b ? a : b);
            }
          }

          // 提取演出时间
          String? showTime = item['showTime']?.toString() ?? 
                            item['startTime']?.toString() ?? 
                            item['timeRange']?.toString() ?? 
                            item['showBeginTime']?.toString() ?? '';

          // 提取场馆信息
          String? venue = item['venue']?.toString() ?? 
                         item['venueName']?.toString() ?? 
                         item['hallName']?.toString() ?? 
                         item['address']?.toString() ?? '';

          // 提取城市
          String? city = item['city']?.toString() ?? 
                        item['cityName']?.toString() ?? 
                        item['cityNameList']?.toString() ?? '';

          // 图片处理
          String cover = item['cover']?.toString() ?? 
                        item['img']?.toString() ?? 
                        item['pic']?.toString() ?? 
                        item['poster']?.toString() ?? '';
          if (cover.contains('w.h')) {
            cover = cover.replaceAll('w.h', '220.300');
          }

          return {
            'showId': item['showId']?.toString() ?? item['id']?.toString() ?? '',
            'name': item['name']?.toString() ?? item['showName']?.toString() ?? item['title']?.toString() ?? '未知演出',
            'movieName': item['name']?.toString() ?? item['showName']?.toString() ?? '未知演出',
            'performer': item['performer']?.toString() ?? item['artist']?.toString() ?? item['actors']?.toString() ?? '',
            'showTime': showTime,
            'venue': venue,
            'city': city,
            'minPrice': minPrice,
            'maxPrice': maxPrice,
            'price': minPrice,
            'priceRange': priceText,
            'cover': cover,
            'status': item['status']?.toString() ?? item['showStatus']?.toString() ?? '',
            'category': item['category']?.toString() ?? item['categoryName']?.toString() ?? '演唱会',
            'type': 'show', // 标记为演出类型
          };
        }).toList();
      }
      return [];
    } catch (e) {
      AppLogger.error('Get hot shows failed', e);
      return [];
    }
  }

  /// 获取热映电影 (保留兼容)
  Future<List<Map<String, dynamic>>> getHotMovies() async {
    return getHotShows(); // 统一返回演出数据
  }

  /// 账号有效性检测
  Future<MaoyanAccountCheckResult> checkAccount(Account account) async {
    try {
      AppLogger.info('Checking Maoyan account: ${account.username}');
      
      if (account.token == null || account.token!.isEmpty) {
        return MaoyanAccountCheckResult(
          success: false,
          message: '账号未登录，请先登录或导入Token',
          isValid: false,
        );
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final deviceId = account.deviceId;

      final params = {
        'token': account.token,
        'timestamp': timestamp.toString(),
      };

      final signature = await _generateMaoyanSignature(params, deviceId);

      final response = await _dio.get(
        _config.getEndpoint('userCheck'),
        queryParameters: {
          ...params,
          'sign': signature,
        },
        options: Options(
          headers: await _buildMaoyanHeaders(deviceId, timestamp),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['status'] == 0) {
          return MaoyanAccountCheckResult(
            success: true,
            message: '账号有效',
            isValid: true,
            userInfo: {
              'userId': data['data']?['userId']?.toString() ?? '',
              'username': data['data']?['username'] ?? data['data']?['nickName'] ?? '',
              'phone': data['data']?['phone'] ?? '',
              'vipLevel': data['data']?['vipLevel'] ?? 0,
            },
          );
        } else {
          return MaoyanAccountCheckResult(
            success: true,
            message: data['msg'] ?? 'Token已过期',
            isValid: false,
          );
        }
      }

      return MaoyanAccountCheckResult(
        success: false,
        message: '检测账号失败',
        isValid: false,
      );
    } catch (e) {
      AppLogger.error('Check Maoyan account failed', e);
      return MaoyanAccountCheckResult(
        success: false,
        message: '检测账号异常: $e',
        isValid: false,
      );
    }
  }

  /// 获取演出详情和场次
  Future<Map<String, dynamic>?> getShowDetail(String showId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final deviceId = await DeviceUtils.generateDeviceId();

      final params = {
        'showId': showId,
        'timestamp': timestamp.toString(),
      };

      final signature = await _generateMaoyanSignature(params, deviceId);

      final response = await _dio.get(
        _config.getEndpoint('showDetail'),
        queryParameters: {
          ...params,
          'sign': signature,
        },
        options: Options(
          headers: await _buildMaoyanHeaders(deviceId, timestamp),
        ),
      );

      if (response.statusCode == 200 && response.data['status'] == 0) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      AppLogger.error('Get show detail failed', e);
      return null;
    }
  }

  /// 获取场次列表
  Future<List<Map<String, dynamic>>> getShowSessions(String showId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final deviceId = await DeviceUtils.generateDeviceId();

      final params = {
        'showId': showId,
        'timestamp': timestamp.toString(),
      };

      final signature = await _generateMaoyanSignature(params, deviceId);

      final response = await _dio.get(
        _config.getEndpoint('showSessions'),
        queryParameters: {
          ...params,
          'sign': signature,
        },
        options: Options(
          headers: await _buildMaoyanHeaders(deviceId, timestamp),
        ),
      );

      if (response.statusCode == 200 && response.data['status'] == 0) {
        return List<Map<String, dynamic>>.from(response.data['data']?['sessions'] ?? []);
      }
      return [];
    } catch (e) {
      AppLogger.error('Get show sessions failed', e);
      return [];
    }
  }

  /// 获取票价档位
  Future<List<Map<String, dynamic>>> getShowPrices(String showId, String sessionId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final deviceId = await DeviceUtils.generateDeviceId();

      final params = {
        'showId': showId,
        'sessionId': sessionId,
        'timestamp': timestamp.toString(),
      };

      final signature = await _generateMaoyanSignature(params, deviceId);

      final response = await _dio.get(
        _config.getEndpoint('showPrices'),
        queryParameters: {
          ...params,
          'sign': signature,
        },
        options: Options(
          headers: await _buildMaoyanHeaders(deviceId, timestamp),
        ),
      );

      if (response.statusCode == 200 && response.data['status'] == 0) {
        return List<Map<String, dynamic>>.from(response.data['data']?['prices'] ?? []);
      }
      return [];
    } catch (e) {
      AppLogger.error('Get show prices failed', e);
      return [];
    }
  }

  /// 创建支付订单
  Future<MaoyanPayResult> createPayment({
    required Account account,
    required String orderId,
    required double amount,
    String payChannel = 'alipay',
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final params = {
        'orderId': orderId,
        'amount': amount.toString(),
        'payChannel': payChannel,
        'timestamp': timestamp.toString(),
      };

      final signature = await _generateMaoyanSignature(params, account.deviceId);

      await _behaviorService.simulateHumanBehavior('pay_create');

      final response = await _dio.post(
        _config.getEndpoint('payCreate'),
        data: params,
        options: Options(
          headers: await _buildMaoyanHeaders(account.deviceId, timestamp),
        ),
      );

      if (response.statusCode == 200 && response.data['status'] == 0) {
        final payData = response.data['data'];
        return MaoyanPayResult(
          success: true,
          message: '创建支付订单成功',
          payUrl: payData?['payUrl'],
          payToken: payData?['payToken'],
          qrCode: payData?['qrCode'],
          data: payData,
        );
      }

      return MaoyanPayResult(
        success: false,
        message: response.data['msg'] ?? '创建支付订单失败',
      );
    } catch (e) {
      return MaoyanPayResult(
        success: false,
        message: '创建支付订单异常: $e',
      );
    }
  }

  /// 拉起手机支付
  Future<MaoyanPayLaunchResult> launchMobilePay({
    required Account account,
    required String orderId,
    required double amount,
    required String payType,
  }) async {
    try {
      final payResult = await createPayment(
        account: account,
        orderId: orderId,
        amount: amount,
        payChannel: payType,
      );

      if (!payResult.success) {
        return MaoyanPayLaunchResult(
          success: false,
          message: payResult.message,
        );
      }

      String? deepLink;
      if (payType == 'alipay') {
        deepLink = 'alipays://platformapi/startapp?appId=20000067&url=${Uri.encodeComponent(payResult.payUrl ?? '')}';
      } else if (payType == 'wechat') {
        deepLink = 'weixin://wap/pay?prepayid=${payResult.data?['prepayId']}&package=${payResult.data?['package']}&noncestr=${payResult.data?['nonceStr']}&sign=${payResult.data?['sign']}';
      }

      return MaoyanPayLaunchResult(
        success: true,
        message: '获取支付链接成功',
        payUrl: payResult.payUrl,
        deepLink: deepLink,
        qrCode: payResult.qrCode,
        orderId: orderId,
      );
    } catch (e) {
      return MaoyanPayLaunchResult(
        success: false,
        message: '拉起支付异常: $e',
      );
    }
  }

  /// 查询支付状态
  Future<MaoyanPayQueryResult> queryPayment(Account account, String orderId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final params = {
        'orderId': orderId,
        'timestamp': timestamp.toString(),
      };

      final signature = await _generateMaoyanSignature(params, account.deviceId);

      final response = await _dio.get(
        _config.getEndpoint('payQuery'),
        queryParameters: {
          ...params,
          'sign': signature,
        },
        options: Options(
          headers: await _buildMaoyanHeaders(account.deviceId, timestamp),
        ),
      );

      if (response.statusCode == 200 && response.data['status'] == 0) {
        final payData = response.data['data'];
        return MaoyanPayQueryResult(
          success: true,
          message: '查询支付状态成功',
          isPaid: payData?['status'] == 'PAID',
          status: payData?['status'] ?? '',
          data: payData,
        );
      }

      return MaoyanPayQueryResult(
        success: false,
        message: '查询支付状态失败',
      );
    } catch (e) {
      return MaoyanPayQueryResult(
        success: false,
        message: '查询支付状态异常: $e',
      );
    }
  }

  /// 获取观演人列表
  Future<List<Map<String, dynamic>>> getViewerList(Account account) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final params = {
        'timestamp': timestamp.toString(),
      };

      final signature = await _generateMaoyanSignature(params, account.deviceId);

      final response = await _dio.get(
        _config.getEndpoint('viewerList'),
        queryParameters: {
          ...params,
          'sign': signature,
        },
        options: Options(
          headers: await _buildMaoyanHeaders(account.deviceId, timestamp),
        ),
      );

      if (response.statusCode == 200 && response.data['status'] == 0) {
        return List<Map<String, dynamic>>.from(response.data['data']?['viewers'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

/// 猫眼操作结果
class MaoyanOperationResult {
  final bool success;
  final String message;
  final String? orderId;
  final Map<String, dynamic>? data;
  final bool isBlocked;

  MaoyanOperationResult({
    required this.success,
    required this.message,
    this.orderId,
    this.data,
    this.isBlocked = false,
  });
}

/// 猫眼账号检测结果
class MaoyanAccountCheckResult {
  final bool success;
  final String message;
  final bool isValid;
  final Map<String, dynamic>? userInfo;

  MaoyanAccountCheckResult({
    required this.success,
    required this.message,
    required this.isValid,
    this.userInfo,
  });
}

/// 猫眼支付结果
class MaoyanPayResult {
  final bool success;
  final String message;
  final String? payUrl;
  final String? payToken;
  final String? qrCode;
  final Map<String, dynamic>? data;

  MaoyanPayResult({
    required this.success,
    required this.message,
    this.payUrl,
    this.payToken,
    this.qrCode,
    this.data,
  });
}

/// 猫眼拉起支付结果
class MaoyanPayLaunchResult {
  final bool success;
  final String message;
  final String? payUrl;
  final String? deepLink;
  final String? qrCode;
  final String? orderId;

  MaoyanPayLaunchResult({
    required this.success,
    required this.message,
    this.payUrl,
    this.deepLink,
    this.qrCode,
    this.orderId,
  });
}

/// 猫眼查询支付结果
class MaoyanPayQueryResult {
  final bool success;
  final String message;
  final bool isPaid;
  final String status;
  final Map<String, dynamic>? data;
  final String payStatus;   // 支付状态
  final double? payAmount;  // 支付金额

  MaoyanPayQueryResult({
    required this.success,
    required this.message,
    this.isPaid = false,
    this.status = '',
    this.data,
    this.payStatus = 'unknown',
    this.payAmount,
  });
}