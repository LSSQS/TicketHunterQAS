import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../models/show.dart';
import '../models/platform_config.dart';
import '../models/hunting_result.dart';
import '../utils/logger.dart';
import 'signature_service.dart';
import 'behavior_simulation_service.dart';

/// 秀动抢票服务
class XiudongTicketService {
  final Dio _dio = Dio();
  final SignatureService _signatureService = SignatureService();
  final BehaviorSimulationService _behaviorService = BehaviorSimulationService();
  final PlatformConfig _config = PlatformConfig.xiudong;
  
  XiudongTicketService() {
    _setupDio();
  }

  void _setupDio() {
    _dio.options = BaseOptions(
      baseUrl: _config.baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
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
        AppLogger.debug('Xiudong request: ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        AppLogger.debug('Xiudong response: ${response.statusCode}');
        handler.next(response);
      },
      onError: (error, handler) {
        AppLogger.error('Xiudong request error: ${error.message}', error);
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
      AppLogger.info('Xiudong submitting order for: ${account.username}, show: ${show.name}');
      
      // 第一步：获取演出详情
      final activityDetail = await _getActivityDetail(show.itemId);
      if (activityDetail == null) {
        return HuntingResult(
          success: false,
          message: '获取演出详情失败',
          timestamp: DateTime.now(),
        );
      }

      // 第二步：选择场次和票档
      final sessionResult = await _selectSession(
        account: account,
        show: show,
        sku: sku,
        activityDetail: activityDetail,
        params: params,
      );

      if (!sessionResult.success) {
        return HuntingResult(
          success: false,
          message: sessionResult.message,
          timestamp: DateTime.now(),
          isBlocked: sessionResult.isBlocked,
        );
      }

      // 第三步：创建订单
      final orderResult = await _createOrder(
        account: account,
        show: show,
        sku: sku,
        sessionData: sessionResult.data!,
        params: params,
      );

      return HuntingResult(
        success: orderResult.success,
        message: orderResult.message,
        orderId: orderResult.orderId,
        timestamp: DateTime.now(),
        isBlocked: orderResult.isBlocked,
        metadata: {
          'activityDetail': activityDetail,
          'sessionResult': sessionResult.data,
          'orderResult': orderResult.data,
        },
      );
    } catch (e) {
      AppLogger.error('Xiudong submit order failed', e);
      return HuntingResult(
        success: false,
        message: '秀动抢票异常: $e',
        timestamp: DateTime.now(),
      );
    }
  }

  /// 获取演出详情
  Future<Map<String, dynamic>?> _getActivityDetail(String activityId) async {
    try {
      final response = await _dio.get(
        '${_config.apiEndpoints['activityDetail']}/$activityId',
        options: Options(
          headers: await _buildXiudongHeaders(),
        ),
      );

      if (response.statusCode == 200 && response.data['code'] == 0) {
        return response.data['data'];
      }

      return null;
    } catch (e) {
      AppLogger.error('Get activity detail failed', e);
      return null;
    }
  }

  /// 选择场次
  Future<XiudongOperationResult> _selectSession({
    required Account account,
    required Show show,
    required TicketSku sku,
    required Map<String, dynamic> activityDetail,
    required Map<String, dynamic> params,
  }) async {
    try {
      final sessions = activityDetail['sessions'] as List? ?? [];
      final selectedSession = sessions.firstWhere(
        (s) => s['id'].toString() == sku.skuId,
        orElse: () => sessions.isNotEmpty ? sessions.first : null,
      );

      if (selectedSession == null) {
        return XiudongOperationResult(
          success: false,
          message: '未找到可用场次',
        );
      }

      // 获取票档信息
      final ticketTypes = selectedSession['ticketTypes'] as List? ?? [];
      final selectedTicketType = ticketTypes.firstWhere(
        (t) => t['id'].toString() == sku.skuId,
        orElse: () => ticketTypes.isNotEmpty ? ticketTypes.first : null,
      );

      if (selectedTicketType == null) {
        return XiudongOperationResult(
          success: false,
          message: '未找到可用票档',
        );
      }

      // 检查库存
      final stock = selectedTicketType['stock'] as int? ?? 0;
      if (stock < sku.quantity) {
        return XiudongOperationResult(
          success: false,
          message: '库存不足，剩余 $stock 张',
        );
      }

      return XiudongOperationResult(
        success: true,
        message: '选择场次成功',
        data: {
          'session': selectedSession,
          'ticketType': selectedTicketType,
          'quantity': sku.quantity,
        },
      );
    } catch (e) {
      AppLogger.error('Select session failed', e);
      return XiudongOperationResult(
        success: false,
        message: '选择场次失败: $e',
      );
    }
  }

  /// 创建订单
  Future<XiudongOperationResult> _createOrder({
    required Account account,
    required Show show,
    required TicketSku sku,
    required Map<String, dynamic> sessionData,
    required Map<String, dynamic> params,
  }) async {
    try {
      final session = sessionData['session'];
      final ticketType = sessionData['ticketType'];
      final quantity = sessionData['quantity'] as int;

      final orderData = {
        'activityId': show.itemId,
        'sessionId': session['id'],
        'ticketTypeId': ticketType['id'],
        'quantity': quantity,
        'buyerInfo': {
          'name': params['buyerName'] ?? account.username,
          'phone': params['buyerPhone'] ?? account.phone,
          'idCard': params['buyerIdCard'] ?? '',
        },
        'deliveryMethod': params['deliveryMethod'] ?? 'pickup',
      };

      await _behaviorService.simulateHumanBehavior('order_create');

      final response = await _dio.post(
        _config.apiEndpoints['orderCreate']!,
        data: orderData,
        options: Options(
          headers: await _buildXiudongHeaders(account: account),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['code'] == 0) {
          return XiudongOperationResult(
            success: true,
            message: '创建订单成功',
            orderId: data['data']?['orderId']?.toString(),
            data: data['data'],
          );
        } else {
          final message = data['message'] ?? '创建订单失败';
          final isBlocked = _isXiudongBlockedError(message);
          
          return XiudongOperationResult(
            success: false,
            message: message,
            isBlocked: isBlocked,
          );
        }
      }

      return XiudongOperationResult(
        success: false,
        message: '创建订单失败',
      );
    } catch (e) {
      return XiudongOperationResult(
        success: false,
        message: '创建订单异常: $e',
      );
    }
  }

  /// 构建秀动请求头
  Future<Map<String, String>> _buildXiudongHeaders({Account? account}) async {
    final headers = Map<String, String>.from(kIsWeb ? {} : _config.headers);
    
    headers.addAll({
      'X-Platform': 'web',
      'X-Version': _config.version,
    });

    if (account != null && account.token != null && account.token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${account.token}';
    }

    return headers;
  }

  /// 判断是否被风控
  bool _isXiudongBlockedError(String message) {
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
      '抢购过于频繁',
    ];
    
    return blockedKeywords.any((keyword) => 
        message.toLowerCase().contains(keyword.toLowerCase()));
  }

  /// 搜索演出
  Future<List<Map<String, dynamic>>> searchActivities(String keyword) async {
    try {
      final response = await _dio.get(
        _config.apiEndpoints['search']!,
        queryParameters: {
          'keyword': keyword,
          'pageNo': 1,
          'pageSize': 20,
        },
        options: Options(
          headers: await _buildXiudongHeaders(),
        ),
      );

      if (response.statusCode == 200 && response.data['code'] == 0) {
        final list = response.data['data']?['list'] as List? ?? [];
        return list.cast<Map<String, dynamic>>();
      }

      return [];
    } catch (e) {
      AppLogger.error('Search activities failed', e);
      return [];
    }
  }

  /// 获取热门演出
  Future<List<Map<String, dynamic>>> getHotActivities() async {
    try {
      await _behaviorService.randomDelay();

      // 秀动演出列表API
      final params = {
        'cityCode': '10', // 北京
        'category': '1', // 演唱会
        'pageNo': '1',
        'pageSize': '20',
        'sortType': '1', // 热度排序
      };

      // Web 环境下使用 CORS 代理
      String apiUrl = '${_config.baseUrl}${_config.apiEndpoints['activityList']}';
      if (kIsWeb) {
        final queryString = params.entries.map((e) => '${e.key}=${e.value}').join('&');
        apiUrl = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent('$apiUrl?$queryString')}';
      }

      final response = await _dio.get(
        apiUrl,
        queryParameters: kIsWeb ? null : params,
        options: Options(
          headers: kIsWeb ? {} : await _buildXiudongHeaders(),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        // 处理演出列表数据
        List<dynamic> activityList = [];
        if (data is Map<String, dynamic>) {
          activityList = data['data']?['list'] as List? ?? 
                         data['list'] as List? ?? 
                         data['activityList'] as List? ?? [];
        } else if (data is List) {
          activityList = data;
        }

        return activityList.map((item) {
          // 提取价格信息
          final minPrice = item['minPrice'] ?? item['price'] ?? 0;
          final maxPrice = item['maxPrice'] ?? item['price'] ?? 0;
          
          return {
            'activityId': item['id']?.toString() ?? item['activityId']?.toString() ?? '',
            'name': item['name'] ?? item['activityName'] ?? item['title'] ?? '未知演出',
            'performer': item['performer'] ?? item['artist'] ?? item['actors'] ?? '',
            'showTime': item['showTime'] ?? item['startTime'] ?? item['timeRange'] ?? '',
            'venue': item['venue'] ?? item['venueName'] ?? item['address'] ?? '',
            'city': item['city'] ?? item['cityName'] ?? '',
            'minPrice': minPrice,
            'maxPrice': maxPrice,
            'price': minPrice,
            'cover': item['cover'] ?? item['poster'] ?? item['img'] ?? '',
            'status': item['status'] ?? item['activityStatus'] ?? '',
            'category': item['category'] ?? item['categoryName'] ?? '演唱会',
            'type': 'show',
          };
        }).toList();
      }
      return [];
    } catch (e) {
      AppLogger.error('Get hot activities failed', e);
      return [];
    }
  }

  /// 账号有效性检测
  Future<XiudongAccountCheckResult> checkAccount(Account account) async {
    try {
      AppLogger.info('Checking Xiudong account: ${account.username}');

      if (account.cookies == null || account.cookies!.isEmpty) {
        return XiudongAccountCheckResult(
          success: false,
          message: '账号未登录，请先登录或导入Cookie',
          isValid: false,
        );
      }

      final cookieString = account.cookies!.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');

      final response = await _dio.get(
        _config.getEndpoint('userCheck'),
        options: Options(
          headers: {
            'Cookie': cookieString,
            ...await _buildXiudongHeaders(),
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true || data['status'] == 0) {
          return XiudongAccountCheckResult(
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
          return XiudongAccountCheckResult(
            success: true,
            message: data['message'] ?? 'Cookie已过期',
            isValid: false,
          );
        }
      }

      return XiudongAccountCheckResult(
        success: false,
        message: '检测账号失败',
        isValid: false,
      );
    } catch (e) {
      AppLogger.error('Check Xiudong account failed', e);
      return XiudongAccountCheckResult(
        success: false,
        message: '检测账号异常: $e',
        isValid: false,
      );
    }
  }

  /// 获取演出场次列表
  Future<List<Map<String, dynamic>>> getActivitySessions(String activityId) async {
    try {
      final response = await _dio.get(
        _config.getEndpoint('activitySessions'),
        queryParameters: {'activityId': activityId},
        options: Options(
          headers: await _buildXiudongHeaders(),
        ),
      );

      if (response.statusCode == 200 && response.data['code'] == 0) {
        return List<Map<String, dynamic>>.from(response.data['data']?['sessions'] ?? []);
      }
      return [];
    } catch (e) {
      AppLogger.error('Get activity sessions failed', e);
      return [];
    }
  }

  /// 获取票价档位
  Future<List<Map<String, dynamic>>> getActivityPrices(String activityId, String sessionId) async {
    try {
      final response = await _dio.get(
        _config.getEndpoint('activityPrices'),
        queryParameters: {
          'activityId': activityId,
          'sessionId': sessionId,
        },
        options: Options(
          headers: await _buildXiudongHeaders(),
        ),
      );

      if (response.statusCode == 200 && response.data['code'] == 0) {
        return List<Map<String, dynamic>>.from(response.data['data']?['prices'] ?? []);
      }
      return [];
    } catch (e) {
      AppLogger.error('Get activity prices failed', e);
      return [];
    }
  }

  /// 创建支付订单
  Future<XiudongPayResult> createPayment({
    required Account account,
    required String orderId,
    required double amount,
    String payChannel = 'alipay',
  }) async {
    try {
      final orderData = {
        'orderId': orderId,
        'amount': amount,
        'payChannel': payChannel,
      };

      await _behaviorService.simulateHumanBehavior('pay_create');

      final response = await _dio.post(
        _config.getEndpoint('payCreate'),
        data: orderData,
        options: Options(
          headers: await _buildXiudongHeaders(account: account),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['code'] == 0 || data['success'] == true) {
          final payData = data['data'];
          return XiudongPayResult(
            success: true,
            message: '创建支付订单成功',
            payUrl: payData?['payUrl'],
            payToken: payData?['payToken'],
            qrCode: payData?['qrCode'],
            data: payData,
          );
        }
      }

      return XiudongPayResult(
        success: false,
        message: '创建支付订单失败',
      );
    } catch (e) {
      return XiudongPayResult(
        success: false,
        message: '创建支付订单异常: $e',
      );
    }
  }

  /// 拉起手机支付
  Future<XiudongPayLaunchResult> launchMobilePay({
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
        return XiudongPayLaunchResult(
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

      return XiudongPayLaunchResult(
        success: true,
        message: '获取支付链接成功',
        payUrl: payResult.payUrl,
        deepLink: deepLink,
        qrCode: payResult.qrCode,
        orderId: orderId,
      );
    } catch (e) {
      return XiudongPayLaunchResult(
        success: false,
        message: '拉起支付异常: $e',
      );
    }
  }

  /// 查询支付状态
  Future<XiudongPayQueryResult> queryPayment(Account account, String orderId) async {
    try {
      final response = await _dio.get(
        _config.getEndpoint('payQuery'),
        queryParameters: {'orderId': orderId},
        options: Options(
          headers: await _buildXiudongHeaders(account: account),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['code'] == 0 || data['success'] == true) {
          final payData = data['data'];
          return XiudongPayQueryResult(
            success: true,
            message: '查询支付状态成功',
            isPaid: payData?['status'] == 'PAID' || payData?['tradeStatus'] == 'TRADE_SUCCESS',
            status: payData?['status'] ?? payData?['tradeStatus'] ?? '',
            data: payData,
          );
        }
      }

      return XiudongPayQueryResult(
        success: false,
        message: '查询支付状态失败',
      );
    } catch (e) {
      return XiudongPayQueryResult(
        success: false,
        message: '查询支付状态异常: $e',
      );
    }
  }

  /// 获取观演人列表
  Future<List<Map<String, dynamic>>> getViewerList(Account account) async {
    try {
      final response = await _dio.get(
        _config.getEndpoint('viewerList'),
        options: Options(
          headers: await _buildXiudongHeaders(account: account),
        ),
      );

      if (response.statusCode == 200 && response.data['code'] == 0) {
        return List<Map<String, dynamic>>.from(response.data['data']?['viewers'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 获取订单列表
  Future<List<Map<String, dynamic>>> getOrderList(Account account, {int page = 1, int size = 20}) async {
    try {
      final response = await _dio.get(
        _config.getEndpoint('orderList'),
        queryParameters: {
          'pageNo': page,
          'pageSize': size,
        },
        options: Options(
          headers: await _buildXiudongHeaders(account: account),
        ),
      );

      if (response.statusCode == 200 && response.data['code'] == 0) {
        return List<Map<String, dynamic>>.from(response.data['data']?['orders'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

/// 秀动操作结果
class XiudongOperationResult {
  final bool success;
  final String message;
  final String? orderId;
  final Map<String, dynamic>? data;
  final bool isBlocked;

  XiudongOperationResult({
    required this.success,
    required this.message,
    this.orderId,
    this.data,
    this.isBlocked = false,
  });
}

/// 秀动账号检测结果
class XiudongAccountCheckResult {
  final bool success;
  final String message;
  final bool isValid;
  final Map<String, dynamic>? userInfo;

  XiudongAccountCheckResult({
    required this.success,
    required this.message,
    required this.isValid,
    this.userInfo,
  });
}

/// 秀动支付结果
class XiudongPayResult {
  final bool success;
  final String message;
  final String? payUrl;
  final String? payToken;
  final String? qrCode;
  final Map<String, dynamic>? data;

  XiudongPayResult({
    required this.success,
    required this.message,
    this.payUrl,
    this.payToken,
    this.qrCode,
    this.data,
  });
}

/// 秀动拉起支付结果
class XiudongPayLaunchResult {
  final bool success;
  final String message;
  final String? payUrl;
  final String? deepLink;
  final String? qrCode;
  final String? orderId;

  XiudongPayLaunchResult({
    required this.success,
    required this.message,
    this.payUrl,
    this.deepLink,
    this.qrCode,
    this.orderId,
  });
}

/// 秀动查询支付结果
class XiudongPayQueryResult {
  final bool success;
  final String message;
  final bool isPaid;
  final String status;
  final Map<String, dynamic>? data;

  XiudongPayQueryResult({
    required this.success,
    required this.message,
    this.isPaid = false,
    this.status = '',
    this.data,
  });
}
