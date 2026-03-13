import 'package:json_annotation/json_annotation.dart';

part 'platform_config.g.dart';

/// 平台配置枚举
enum TicketPlatform {
  @JsonValue('damai')
  damai,
  @JsonValue('maoyan')
  maoyan,
  @JsonValue('xiudong')
  xiudong,
}

/// 平台配置类 - 集中管理所有平台API配置
@JsonSerializable()
class PlatformConfig {
  final TicketPlatform platform;
  final String name;
  final String baseUrl;
  final String appKey;
  final String version;
  final String apiVersion;
  final Map<String, String> headers;
  final Map<String, dynamic> apiEndpoints;
  final Map<String, String> domains;
  final bool isEnabled;

  PlatformConfig({
    required this.platform,
    required this.name,
    required this.baseUrl,
    required this.appKey,
    required this.version,
    this.apiVersion = '1.0',
    required this.headers,
    required this.apiEndpoints,
    this.domains = const {},
    this.isEnabled = true,
  });

  factory PlatformConfig.fromJson(Map<String, dynamic> json) => 
      _$PlatformConfigFromJson(json);
  Map<String, dynamic> toJson() => _$PlatformConfigToJson(this);

  /// 大麦配置
  static PlatformConfig get damai => PlatformConfig(
    platform: TicketPlatform.damai,
    name: '大麦票务',
    baseUrl: 'https://mtop.damai.cn',
    appKey: '12574478',
    version: '8.6.2',
    apiVersion: '1.0',
    headers: {
      'Accept': 'application/json',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'keep-alive',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    domains: {
      'main': 'https://www.damai.cn',
      'mtop': 'https://mtop.damai.cn',
      'h5': 'https://m.damai.cn',
      'search': 'https://search.damai.cn',
    },
    apiEndpoints: {
      // 订单相关
      'orderBuild': '/h5/mtop.trade.order.build/4.0/',
      'orderCreate': '/h5/mtop.trade.order.create/4.0/',
      'orderList': '/h5/mtop.trade.order.list/1.0/',
      'orderDetail': '/h5/mtop.trade.order.detail/4.0/',
      'orderCancel': '/h5/mtop.trade.order.cancel/1.0/',
      // 演出相关
      'itemDetail': '/h5/mtop.damai.item.detail/1.2/',
      'itemSearch': '/h5/mtop.damai.item.search/1.0/',
      'performList': '/h5/mtop.damai.wireless.perform.list/1.0/',
      'performInfo': '/h5/mtop.damai.wireless.perform.info/1.0/',
      'skuInfo': '/h5/mtop.damai.wireless.sku.info/1.0/',
      'priceInfo': '/h5/mtop.damai.wireless.price.info/1.0/',
      // 用户相关
      'login': '/h5/mtop.user.login/1.0/',
      'loginPage': '/h5/mtop.damai.login.getloginpage/1.0/',
      'loginSubmit': '/h5/mtop.damai.login.login/1.0/',
      'userInfo': '/h5/mtop.damai.user.get/1.0/',
      'userCheck': '/h5/mtop.damai.user.check/1.0/',
      'broadcastList': '/h5/mtop.damai.wireless.search.broadcast.list/1.0/',
      // 验证码
      'captchaGet': '/h5/mtop.alibaba.security.captcha.get/1.0/',
      // 支付相关
      'payCreate': '/h5/mtop.trade.pay.create/4.0/',
      'payQuery': '/h5/mtop.trade.pay.query/1.0/',
      'payChannel': '/h5/mtop.trade.pay.channel/1.0/',
      // 地址相关
      'addressList': '/h5/mtop.damai.address.list/1.0/',
      'addressSave': '/h5/mtop.damai.address.save/1.0/',
      // 观演人
      'viewerList': '/h5/mtop.damai.viewer.list/1.0/',
      'viewerAdd': '/h5/mtop.damai.viewer.add/1.0/',
    },
  );

  /// 猫眼配置
  static PlatformConfig get maoyan => PlatformConfig(
    platform: TicketPlatform.maoyan,
    name: '猫眼票务',
    baseUrl: 'https://m.maoyan.com',
    appKey: 'maoyan_app',
    version: '10.8.0',
    apiVersion: '1.0',
    headers: {
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'zh-CN,zh;q=0.9',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'keep-alive',
      'Content-Type': 'application/json',
    },
    domains: {
      'main': 'https://m.maoyan.com',
      'api': 'https://api.maoyan.com',
      'passport': 'https://passport.maoyan.com',
      'show': 'https://show.maoyan.com',
    },
    apiEndpoints: {
      // 用户相关
      'sendCode': '/ajax/sendCode',
      'login': '/ajax/login',
      'userInfo': '/ajax/user/info',
      'userCheck': '/ajax/user/check',
      'logout': '/ajax/logout',
      // 电影相关
      'search': '/ajax/search',
      'movieDetail': '/ajax/detailmovie',
      // 影院和场次
      'cinemaList': '/ajax/cinemaList',
      'showList': '/ajax/showList',
      'seatMap': '/ajax/seatMap',
      'seatMapApi': '/ajax/seat/map',
      // 订单相关
      'lockSeat': '/ajax/lockSeat',
      'lockSeatApi': '/ajax/seat/lock',
      'unlockSeat': '/ajax/seat/unlock',
      'submitOrder': '/ajax/submitOrder',
      'orderBuild': '/ajax/order/build',
      'orderCreate': '/ajax/order/create',
      'orderList': '/ajax/order/list',
      'orderDetail': '/ajax/order/detail',
      'orderCancel': '/ajax/order/cancel',
      // 支付相关
      'payCreate': '/ajax/pay/create',
      'payQuery': '/ajax/pay/query',
      'payChannel': '/ajax/pay/channel',
      // 演出相关
      'hotShows': '/mmdb/shows',
      'showDetail': '/mmdb/shows/detail',
      'showSessions': '/mmdb/shows/sessions',
      'showPrices': '/mmdb/shows/prices',
      // 观演人
      'viewerList': '/ajax/viewer/list',
      'viewerAdd': '/ajax/viewer/add',
    },
  );

  /// 秀动配置
  static PlatformConfig get xiudong => PlatformConfig(
    platform: TicketPlatform.xiudong,
    name: '秀洞',
    baseUrl: 'https://www.showstart.com',
    appKey: 'showstart_app',
    version: '2.5.0',
    headers: {
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'zh-CN,zh;q=0.9',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'keep-alive',
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36',
      'Referer': 'https://www.showstart.com/',
    },
    domains: {
      'main': 'https://www.showstart.com',
      'api': 'https://www.showstart.com/api/v2',
    },
    apiEndpoints: {
      // 演出相关
      'activityList': '/api/v2/activities',
      'activityDetail': '/api/v2/activities',
      'activitySessions': '/api/v2/activities/sessions',
      'activityPrices': '/api/v2/activities/prices',
      'search': '/api/v2/activities/search',
      'venueList': '/api/v2/venues',
      // 用户相关
      'login': '/api/v2/users/login',
      'userInfo': '/api/v2/users/info',
      'userCheck': '/api/v2/users/check',
      'logout': '/api/v2/users/logout',
      // 订单相关
      'orderCreate': '/api/v2/orders',
      'orderList': '/api/v2/orders/list',
      'orderDetail': '/api/v2/orders/detail',
      'orderCancel': '/api/v2/orders/cancel',
      // 支付相关
      'payCreate': '/api/v2/pay/create',
      'payQuery': '/api/v2/pay/query',
      'payChannel': '/api/v2/pay/channels',
      // 观演人
      'viewerList': '/api/v2/viewers',
      'viewerAdd': '/api/v2/viewers/add',
    },
  );

  /// 获取所有支持的平台配置
  static List<PlatformConfig> get allPlatforms => [damai, maoyan, xiudong];

  /// 根据平台类型获取配置
  static PlatformConfig getConfig(TicketPlatform platform) {
    switch (platform) {
      case TicketPlatform.damai:
        return damai;
      case TicketPlatform.maoyan:
        return maoyan;
      case TicketPlatform.xiudong:
        return xiudong;
    }
  }

  String get platformName {
    switch (platform) {
      case TicketPlatform.damai:
        return '大麦票务';
      case TicketPlatform.maoyan:
        return '猫眼票务';
      case TicketPlatform.xiudong:
        return '秀洞';
    }
  }

  String get platformIcon {
    switch (platform) {
      case TicketPlatform.damai:
        return '🎵';
      case TicketPlatform.maoyan:
        return '🎬';
      case TicketPlatform.xiudong:
        return '🎭';
    }
  }
  
  /// 获取指定域名的完整URL
  String getDomain(String key) => domains[key] ?? baseUrl;
  
  /// 获取指定API端点的完整URL
  String getApiUrl(String endpointKey, {String? domainKey}) {
    final domain = domainKey != null ? getDomain(domainKey) : baseUrl;
    final endpoint = apiEndpoints[endpointKey];
    if (endpoint == null) {
      throw ArgumentError('Unknown endpoint: $endpointKey for platform $name');
    }
    return '$domain$endpoint';
  }
  
  /// 获取API端点路径
  String getEndpoint(String key) {
    final endpoint = apiEndpoints[key];
    if (endpoint == null) {
      throw ArgumentError('Unknown endpoint: $key for platform $name');
    }
    return endpoint;
  }
}