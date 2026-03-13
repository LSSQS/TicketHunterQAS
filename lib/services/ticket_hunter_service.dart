import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../models/concert.dart';
import '../models/hunting_result.dart';
import '../models/platform_config.dart';
import '../utils/logger.dart';
import '../utils/device_utils.dart';
import '../config/app_config.dart';
import 'signature_service.dart';
import 'behavior_simulation_service.dart';

class TicketHunterService {
  final Dio _dio = Dio();
  final SignatureService _signatureService = SignatureService();
  final BehaviorSimulationService _behaviorService = BehaviorSimulationService();
  
  // 使用集中配置
  final PlatformConfig _config = PlatformConfig.damai;

  TicketHunterService() {
    _setupDio();
  }

  void _setupDio() {
    _dio.options = BaseOptions(
      baseUrl: _config.baseUrl,
      connectTimeout: Duration(seconds: AppConfig.huntingConnectTimeout),
      receiveTimeout: Duration(seconds: AppConfig.huntingReceiveTimeout),
      // Web环境下不设置这些headers，避免CORS预检问题
      headers: kIsWeb ? {} : _config.headers,
    );

    // 添加拦截器
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 添加随机延迟模拟人类行为
        await _behaviorService.randomDelay();
        
        AppLogger.debug('Ticket request: ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        AppLogger.debug('Ticket response: ${response.statusCode}');
        handler.next(response);
      },
      onError: (error, handler) {
        AppLogger.error('Ticket request error: ${error.message}', error);
        handler.next(error);
      },
    ));
  }

  Future<HuntingResult> submitOrder({
    required Account account,
    required Concert concert,
    required TicketSku sku,
    required Map<String, dynamic> params,
  }) async {
    try {
      AppLogger.info('Submitting order for account: ${account.username}, sku: ${sku.name}');
      
      // 第一步：构建订单
      final buildResult = await _buildOrder(
        account: account,
        concert: concert,
        sku: sku,
        params: params,
      );

      if (!buildResult.success) {
        return HuntingResult(
          success: false,
          message: buildResult.message,
          timestamp: DateTime.now(),
          isBlocked: buildResult.isBlocked,
        );
      }

      // 第二步：创建订单
      final createResult = await _createOrder(
        account: account,
        concert: concert,
        sku: sku,
        buildData: buildResult.data!,
        params: params,
      );

      return HuntingResult(
        success: createResult.success,
        message: createResult.message,
        orderId: createResult.orderId,
        timestamp: DateTime.now(),
        isBlocked: createResult.isBlocked,
        metadata: {
          'buildResult': buildResult.data,
          'createResult': createResult.data,
        },
      );
    } catch (e) {
      AppLogger.error('Submit order failed', e);
      return HuntingResult(
        success: false,
        message: '提交订单异常: $e',
        timestamp: DateTime.now(),
      );
    }
  }

  Future<OrderBuildResult> _buildOrder({
    required Account account,
    required Concert concert,
    required TicketSku sku,
    required Map<String, dynamic> params,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final requestParams = {
        'itemId': concert.itemId,
        'skuId': sku.skuId,
        'quantity': sku.quantity,
        'exParams': jsonEncode({
          'channel': 'damai_app',
          'umpChannel': 'damai_app',
          'subChannel': 'damai',
          'atomSplit': '1',
          'serviceVersion': '2.0.0',
        }),
      };

      // 生成签名
      final signature = await _signatureService.generateSignature(
        params: requestParams,
        deviceId: account.deviceId,
        timestamp: timestamp,
      );

      final headers = await _buildHeaders(
        account: account,
        timestamp: timestamp,
        signature: signature,
        params: params,
      );

      // 模拟人类行为延迟
      await _behaviorService.simulateHumanBehavior('order_build');

      final response = await _dio.post(
        _config.getEndpoint('orderBuild'),
        data: requestParams,
        options: Options(headers: headers),
      );

      return _parseOrderBuildResponse(response);
    } catch (e) {
      AppLogger.error('Build order failed', e);
      return OrderBuildResult(
        success: false,
        message: '构建订单失败: $e',
      );
    }
  }

  Future<OrderCreateResult> _createOrder({
    required Account account,
    required Concert concert,
    required TicketSku sku,
    required Map<String, dynamic> buildData,
    required Map<String, dynamic> params,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final requestParams = {
        'itemId': concert.itemId,
        'skuId': sku.skuId,
        'quantity': sku.quantity,
        'buyNow': 'true',
        'exParams': jsonEncode({
          ...buildData,
          'channel': 'damai_app',
          'umpChannel': 'damai_app',
          'atomSplit': '1',
        }),
      };

      // 生成签名
      final signature = await _signatureService.generateSignature(
        params: requestParams,
        deviceId: account.deviceId,
        timestamp: timestamp,
      );

      final headers = await _buildHeaders(
        account: account,
        timestamp: timestamp,
        signature: signature,
        params: params,
      );

      // 模拟人类行为延迟
      await _behaviorService.simulateHumanBehavior('order_create');

      final response = await _dio.post(
        _config.getEndpoint('orderCreate'),
        data: requestParams,
        options: Options(headers: headers),
      );

      return _parseOrderCreateResponse(response);
    } catch (e) {
      AppLogger.error('Create order failed', e);
      return OrderCreateResult(
        success: false,
        message: '创建订单失败: $e',
      );
    }
  }

  Future<Map<String, String>> _buildHeaders({
    required Account account,
    required int timestamp,
    required String signature,
    required Map<String, dynamic> params,
  }) async {
    final userAgent = params['userAgent'] ?? await DeviceUtils.getUserAgent();
    final umid = await DeviceUtils.generateUmid(account.deviceId);
    
    final headers = <String, String>{
      'User-Agent': userAgent,
      'X-DEVICE-ID': account.deviceId,
      'X-T': timestamp.toString(),
      'X-APP-KEY': _config.appKey,
      'X-SIGN': signature,
      'X-UMID': umid,
      'X-FEATURES': '27',
      'X-APP-VER': _config.version,
      'X-LOCATION': '116.397128,39.916527',
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
    };

    // 添加cookies
    if (account.cookies != null && account.cookies!.isNotEmpty) {
      final cookieString = account.cookies!.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');
      headers['Cookie'] = cookieString;
    }

    // 添加设备指纹
    if (params['deviceFingerprint'] != null) {
      headers['X-MINI-WUA'] = params['deviceFingerprint'];
    }

    return headers;
  }

  OrderBuildResult _parseOrderBuildResponse(Response response) {
    try {
      if (response.statusCode != 200) {
        return OrderBuildResult(
          success: false,
          message: 'HTTP ${response.statusCode}',
        );
      }

      final data = response.data;
      final ret = data['ret'] as List?;
      
      if (ret != null && ret.isNotEmpty) {
        final retCode = ret[0] as String;
        
        if (retCode.startsWith('SUCCESS')) {
          return OrderBuildResult(
            success: true,
            message: '构建订单成功',
            data: data['data'],
          );
        } else {
          final message = ret.length > 1 ? ret[1] as String : retCode;
          final isBlocked = _isBlockedError(message);
          
          return OrderBuildResult(
            success: false,
            message: message,
            isBlocked: isBlocked,
          );
        }
      }

      return OrderBuildResult(
        success: false,
        message: '未知响应格式',
      );
    } catch (e) {
      return OrderBuildResult(
        success: false,
        message: '解析响应失败: $e',
      );
    }
  }

  OrderCreateResult _parseOrderCreateResponse(Response response) {
    try {
      if (response.statusCode != 200) {
        return OrderCreateResult(
          success: false,
          message: 'HTTP ${response.statusCode}',
        );
      }

      final data = response.data;
      final ret = data['ret'] as List?;
      
      if (ret != null && ret.isNotEmpty) {
        final retCode = ret[0] as String;
        
        if (retCode.startsWith('SUCCESS')) {
          final orderData = data['data'];
          return OrderCreateResult(
            success: true,
            message: '创建订单成功',
            orderId: orderData?['orderId'],
            data: orderData,
          );
        } else {
          final message = ret.length > 1 ? ret[1] as String : retCode;
          final isBlocked = _isBlockedError(message);
          
          return OrderCreateResult(
            success: false,
            message: message,
            isBlocked: isBlocked,
          );
        }
      }

      return OrderCreateResult(
        success: false,
        message: '未知响应格式',
      );
    } catch (e) {
      return OrderCreateResult(
        success: false,
        message: '解析响应失败: $e',
      );
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
    ];
    
    return blockedKeywords.any((keyword) => 
        message.toUpperCase().contains(keyword.toUpperCase()));
  }

  Future<Map<String, dynamic>?> getItemDetail(String itemId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
// ... existing code ...
      return null;
    } catch (e) {
      AppLogger.error('Get item detail failed', e);
      return null;
    }
  }

  /// 搜索演出
  Future<List<Map<String, dynamic>>> searchShows(String keyword) async {
    return _fetchDamaiShows(keyword: keyword);
  }

  /// 获取热门/推荐演出 (真实数据)
  Future<List<Map<String, dynamic>>> getTrendingShows() async {
    return _fetchDamaiShows();
  }

  Future<List<Map<String, dynamic>>> _fetchDamaiShows({String keyword = ''}) async {
    try {
      // 模拟人类行为延迟
      await _behaviorService.randomDelay();

      // Web 环境下使用 CORS 代理
      String apiUrl = 'https://search.damai.cn/searchajax.html';
      if (kIsWeb) {
        // 使用公开的 CORS 代理服务
        apiUrl = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(apiUrl)}';
      }

      final response = await _dio.get(
        apiUrl,
        queryParameters: kIsWeb ? null : {
          'keyword': keyword,
          'cty': '',
          'ctl': '',
          'sctl': '',
          'tsg': '0',
          'st': '',
          'et': '',
          'order': '1',
          'pageSize': '30',
          'currPage': '1',
          'tn': '',
        },
        options: Options(
          headers: kIsWeb ? {} : {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'https://search.damai.cn/',
          },
          responseType: ResponseType.plain,
        ),
      );

      if (response.statusCode == 200) {
        dynamic responseData;
        if (response.data is String) {
          try {
            responseData = jsonDecode(response.data);
          } catch (e) {
            AppLogger.error('Failed to parse damai response string', e);
            return [];
          }
        } else {
          responseData = response.data;
        }

        if (responseData is Map<String, dynamic>) {
          return _parseDamaiTrendingResponse(responseData);
        }
      }
      return [];
    } catch (e) {
      AppLogger.error('Fetch shows failed', e);
      return [];
    }
  }

  List<Map<String, dynamic>> _parseDamaiTrendingResponse(Map<String, dynamic> data) {
    final List<Map<String, dynamic>> results = [];
    final pageData = data['pageData'];
    if (pageData != null && pageData['resultData'] != null) {
      final list = pageData['resultData'] as List;
      for (var item in list) {
        if (item is Map<String, dynamic>) {
           results.add({
             'itemId': item['projectid']?.toString() ?? '',
             'name': item['name'] ?? '',
             'title': item['nameNoHtml'] ?? item['name'] ?? '',
             'artist': item['actors'] ?? '',
             'venue': item['venue'] ?? '',
             'showTime': item['showtime'] ?? '',
             'minPrice': item['price_str'] ?? '', 
             'maxPrice': '', 
             'cover': item['verticalPic'] ?? '',
             'status': _parseDamaiStatus(item['showstatus']),
           });
        }
      }
    }
    return results;
  }
  
  int _parseDamaiStatus(dynamic status) {
    if (status == null) return 0;
    final s = status.toString();
    if (s.contains('售票中') || s.contains('预售')) return 1;
    return 0;
  }

  /// 获取演出详情（场次、票档信息）
  Future<ShowDetailResult> getShowDetail(String itemId, Account account) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final params = {
        'itemId': itemId,
        'dataType': '2',
      };

      final signature = await _signatureService.generateSignature(
        params: params,
        deviceId: account.deviceId,
        timestamp: timestamp,
      );

      final headers = await _buildHeaders(
        account: account,
        timestamp: timestamp,
        signature: signature,
        params: {},
      );

      final response = await _dio.get(
        _config.getEndpoint('itemDetail'),
        queryParameters: params,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['ret']?[0]?.toString().startsWith('SUCCESS') == true) {
          return ShowDetailResult(
            success: true,
            message: '获取演出详情成功',
            data: data['data'],
          );
        }
      }

      return ShowDetailResult(
        success: false,
        message: '获取演出详情失败',
      );
    } catch (e) {
      AppLogger.error('Get show detail failed', e);
      return ShowDetailResult(
        success: false,
        message: '获取演出详情异常: $e',
      );
    }
  }

  /// 获取场次列表
  Future<List<Map<String, dynamic>>> getPerformList(String itemId, Account account) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final params = {
        'itemId': itemId,
      };

      final signature = await _signatureService.generateSignature(
        params: params,
        deviceId: account.deviceId,
        timestamp: timestamp,
      );

      final headers = await _buildHeaders(
        account: account,
        timestamp: timestamp,
        signature: signature,
        params: {},
      );

      final response = await _dio.get(
        _config.getEndpoint('performList'),
        queryParameters: params,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['ret']?[0]?.toString().startsWith('SUCCESS') == true) {
          return List<Map<String, dynamic>>.from(data['data']?['performList'] ?? []);
        }
      }
      return [];
    } catch (e) {
      AppLogger.error('Get perform list failed', e);
      return [];
    }
  }

  /// 获取票档信息
  Future<List<Map<String, dynamic>>> getSkuInfo(String itemId, String performId, Account account) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final params = {
        'itemId': itemId,
        'performId': performId,
      };

      final signature = await _signatureService.generateSignature(
        params: params,
        deviceId: account.deviceId,
        timestamp: timestamp,
      );

      final headers = await _buildHeaders(
        account: account,
        timestamp: timestamp,
        signature: signature,
        params: {},
      );

      final response = await _dio.get(
        _config.getEndpoint('skuInfo'),
        queryParameters: params,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['ret']?[0]?.toString().startsWith('SUCCESS') == true) {
          return List<Map<String, dynamic>>.from(data['data']?['skuList'] ?? []);
        }
      }
      return [];
    } catch (e) {
      AppLogger.error('Get sku info failed', e);
      return [];
    }
  }

  /// 创建支付订单
  Future<PayCreateResult> createPayment({
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
        'returnUrl': '',
        'notifyUrl': '',
      };

      final signature = await _signatureService.generateSignature(
        params: params,
        deviceId: account.deviceId,
        timestamp: timestamp,
      );

      final headers = await _buildHeaders(
        account: account,
        timestamp: timestamp,
        signature: signature,
        params: {},
      );

      await _behaviorService.simulateHumanBehavior('pay_create');

      final response = await _dio.post(
        _config.getEndpoint('payCreate'),
        data: params,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['ret']?[0]?.toString().startsWith('SUCCESS') == true) {
          final payData = data['data'];
          return PayCreateResult(
            success: true,
            message: '创建支付订单成功',
            payUrl: payData?['payUrl'],
            payToken: payData?['payToken'],
            qrCode: payData?['qrCode'],
            data: payData,
          );
        }
      }

      return PayCreateResult(
        success: false,
        message: '创建支付订单失败',
      );
    } catch (e) {
      AppLogger.error('Create payment failed', e);
      return PayCreateResult(
        success: false,
        message: '创建支付订单异常: $e',
      );
    }
  }

  /// 拉起手机支付（获取支付跳转URL）
  Future<PayLaunchResult> launchMobilePay({
    required Account account,
    required String orderId,
    required double amount,
    required String payType, // alipay, wechat
  }) async {
    try {
      AppLogger.info('Launching mobile pay for order: $orderId, type: $payType');
      
      // 1. 先创建支付订单
      final payResult = await createPayment(
        account: account,
        orderId: orderId,
        amount: amount,
        payChannel: payType,
      );

      if (!payResult.success) {
        return PayLaunchResult(
          success: false,
          message: payResult.message,
        );
      }

      // 2. 构建支付跳转URL或scheme
      String? launchUrl;
      String? deepLink;
      
      if (payType == 'alipay') {
        // 支付宝支付
        launchUrl = payResult.payUrl;
        // 支付宝scheme
        if (payResult.payToken != null) {
          deepLink = 'alipays://platformapi/startapp?appId=20000067&url=${Uri.encodeComponent(payResult.payUrl ?? '')}';
        }
      } else if (payType == 'wechat') {
        // 微信支付
        launchUrl = payResult.payUrl;
        // 微信scheme
        if (payResult.data?['appId'] != null) {
          deepLink = 'weixin://wap/pay?prepayid=${payResult.data?['prepayId']}&package=${payResult.data?['package']}&noncestr=${payResult.data?['nonceStr']}&sign=${payResult.data?['sign']}';
        }
      }

      return PayLaunchResult(
        success: true,
        message: '获取支付链接成功',
        payUrl: launchUrl,
        deepLink: deepLink,
        qrCode: payResult.qrCode,
        orderId: orderId,
      );
    } catch (e) {
      AppLogger.error('Launch mobile pay failed', e);
      return PayLaunchResult(
        success: false,
        message: '拉起支付异常: $e',
      );
    }
  }

  /// 查询支付状态
  Future<PayQueryResult> queryPayment(Account account, String orderId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final params = {
        'orderId': orderId,
      };

      final signature = await _signatureService.generateSignature(
        params: params,
        deviceId: account.deviceId,
        timestamp: timestamp,
      );

      final headers = await _buildHeaders(
        account: account,
        timestamp: timestamp,
        signature: signature,
        params: {},
      );

      final response = await _dio.get(
        _config.getEndpoint('payQuery'),
        queryParameters: params,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['ret']?[0]?.toString().startsWith('SUCCESS') == true) {
          final payData = data['data'];
          return PayQueryResult(
            success: true,
            message: '查询支付状态成功',
            isPaid: payData?['status'] == 'PAID' || payData?['tradeStatus'] == 'TRADE_SUCCESS',
            status: payData?['status'] ?? payData?['tradeStatus'] ?? '',
            data: payData,
          );
        }
      }

      return PayQueryResult(
        success: false,
        message: '查询支付状态失败',
      );
    } catch (e) {
      AppLogger.error('Query payment failed', e);
      return PayQueryResult(
        success: false,
        message: '查询支付状态异常: $e',
      );
    }
  }

  /// 获取订单列表
  Future<List<Map<String, dynamic>>> getOrderList(Account account, {int page = 1, int size = 20}) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final params = {
        'pageNo': page.toString(),
        'pageSize': size.toString(),
      };

      final signature = await _signatureService.generateSignature(
        params: params,
        deviceId: account.deviceId,
        timestamp: timestamp,
      );

      final headers = await _buildHeaders(
        account: account,
        timestamp: timestamp,
        signature: signature,
        params: {},
      );

      final response = await _dio.get(
        _config.getEndpoint('orderList'),
        queryParameters: params,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['ret']?[0]?.toString().startsWith('SUCCESS') == true) {
          return List<Map<String, dynamic>>.from(data['data']?['orderList'] ?? []);
        }
      }
      return [];
    } catch (e) {
      AppLogger.error('Get order list failed', e);
      return [];
    }
  }
}

class OrderBuildResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  final bool isBlocked;

  OrderBuildResult({
    required this.success,
    required this.message,
    this.data,
    this.isBlocked = false,
  });
}

class OrderCreateResult {
  final bool success;
  final String message;
  final String? orderId;
  final Map<String, dynamic>? data;
  final bool isBlocked;

  OrderCreateResult({
    required this.success,
    required this.message,
    this.orderId,
    this.data,
    this.isBlocked = false,
  });
}

/// 演出详情结果
class ShowDetailResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  ShowDetailResult({
    required this.success,
    required this.message,
    this.data,
  });
}

/// 创建支付结果
class PayCreateResult {
  final bool success;
  final String message;
  final String? payUrl;
  final String? payToken;
  final String? qrCode;
  final Map<String, dynamic>? data;

  PayCreateResult({
    required this.success,
    required this.message,
    this.payUrl,
    this.payToken,
    this.qrCode,
    this.data,
  });
}

/// 拉起支付结果
class PayLaunchResult {
  final bool success;
  final String message;
  final String? payUrl;
  final String? deepLink;
  final String? qrCode;
  final String? orderId;

  PayLaunchResult({
    required this.success,
    required this.message,
    this.payUrl,
    this.deepLink,
    this.qrCode,
    this.orderId,
  });
}

/// 查询支付结果
class PayQueryResult {
  final bool success;
  final String message;
  final bool isPaid;
  final String status;
  final Map<String, dynamic>? data;
  final String payStatus;   // 支付状态
  final double? payAmount;  // 支付金额

  PayQueryResult({
    required this.success,
    required this.message,
    this.isPaid = false,
    this.status = '',
    this.data,
    this.payStatus = 'unknown',
    this.payAmount,
  });
}