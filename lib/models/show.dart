import 'package:json_annotation/json_annotation.dart';
import 'platform_config.dart';

part 'show.g.dart';

/// 统一的演出/电影模型
@JsonSerializable()
class Show {
  final String id;
  final String name;
  final String? artist; // 演出者/导演
  final String venue; // 场馆/影院
  final DateTime showTime;
  final DateTime saleStartTime;
  final String itemId;
  final TicketPlatform platform;
  final List<TicketSku> skus;
  final ShowStatus status;
  final ShowType type; // 演出类型
  final int maxConcurrency;
  final int retryCount;
  final Duration retryDelay;
  final bool autoStart;
  final String? description;
  final String? posterUrl;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  Show({
    required this.id,
    required this.name,
    this.artist,
    required this.venue,
    required this.showTime,
    required this.saleStartTime,
    required this.itemId,
    required this.platform,
    required this.skus,
    this.status = ShowStatus.pending,
    this.type = ShowType.concert,
    this.maxConcurrency = 50,
    this.retryCount = 5,
    this.retryDelay = const Duration(milliseconds: 100),
    this.autoStart = false,
    this.description,
    this.posterUrl,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Show.fromJson(Map<String, dynamic> json) => _$ShowFromJson(json);
  Map<String, dynamic> toJson() => _$ShowToJson(this);

  Show copyWith({
    String? id,
    String? name,
    String? artist,
    String? venue,
    DateTime? showTime,
    DateTime? saleStartTime,
    String? itemId,
    TicketPlatform? platform,
    List<TicketSku>? skus,
    ShowStatus? status,
    ShowType? type,
    int? maxConcurrency,
    int? retryCount,
    Duration? retryDelay,
    bool? autoStart,
    String? description,
    String? posterUrl,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Show(
      id: id ?? this.id,
      name: name ?? this.name,
      artist: artist ?? this.artist,
      venue: venue ?? this.venue,
      showTime: showTime ?? this.showTime,
      saleStartTime: saleStartTime ?? this.saleStartTime,
      itemId: itemId ?? this.itemId,
      platform: platform ?? this.platform,
      skus: skus ?? this.skus,
      status: status ?? this.status,
      type: type ?? this.type,
      maxConcurrency: maxConcurrency ?? this.maxConcurrency,
      retryCount: retryCount ?? this.retryCount,
      retryDelay: retryDelay ?? this.retryDelay,
      autoStart: autoStart ?? this.autoStart,
      description: description ?? this.description,
      posterUrl: posterUrl ?? this.posterUrl,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isEnabled => status == ShowStatus.active;
  bool get isUpcoming => DateTime.now().isBefore(saleStartTime);
  bool get isOnSale => DateTime.now().isAfter(saleStartTime) && 
                      DateTime.now().isBefore(showTime);
  bool get isExpired => DateTime.now().isAfter(showTime);
  
  Duration get timeToSale => saleStartTime.difference(DateTime.now());
  
  String get statusText {
    switch (status) {
      case ShowStatus.pending:
        return '待开售';
      case ShowStatus.active:
        return '抢票中';
      case ShowStatus.completed:
        return '已完成';
      case ShowStatus.cancelled:
        return '已取消';
    }
  }

  String get typeText {
    switch (type) {
      case ShowType.concert:
        return '演唱会';
      case ShowType.drama:
        return '话剧';
      case ShowType.movie:
        return '电影';
      case ShowType.sports:
        return '体育赛事';
      case ShowType.other:
        return '其他';
    }
  }

  String get platformName => PlatformConfig.getConfig(platform).platformName;
  String get platformIcon => PlatformConfig.getConfig(platform).platformIcon;
}

@JsonSerializable()
class TicketSku {
  final String skuId;
  final String name;
  final double price;
  final int quantity;
  final TicketPriority priority;
  final bool isEnabled;
  final String? seatInfo;
  final Map<String, dynamic>? metadata; // 平台特定数据

  TicketSku({
    required this.skuId,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.priority = TicketPriority.medium,
    this.isEnabled = true,
    this.seatInfo,
    this.metadata,
  });

  factory TicketSku.fromJson(Map<String, dynamic> json) => _$TicketSkuFromJson(json);
  Map<String, dynamic> toJson() => _$TicketSkuToJson(this);

  TicketSku copyWith({
    String? skuId,
    String? name,
    double? price,
    int? quantity,
    TicketPriority? priority,
    bool? isEnabled,
    String? seatInfo,
    Map<String, dynamic>? metadata,
  }) {
    return TicketSku(
      skuId: skuId ?? this.skuId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      priority: priority ?? this.priority,
      isEnabled: isEnabled ?? this.isEnabled,
      seatInfo: seatInfo ?? this.seatInfo,
      metadata: metadata ?? this.metadata,
    );
  }

  String get priorityText {
    switch (priority) {
      case TicketPriority.high:
        return '高优先级';
      case TicketPriority.medium:
        return '中优先级';
      case TicketPriority.low:
        return '低优先级';
    }
  }
}

enum ShowStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('active')
  active,
  @JsonValue('completed')
  completed,
  @JsonValue('cancelled')
  cancelled,
}

enum ShowType {
  @JsonValue('concert')
  concert,
  @JsonValue('drama')
  drama,
  @JsonValue('movie')
  movie,
  @JsonValue('sports')
  sports,
  @JsonValue('other')
  other,
}

enum TicketPriority {
  @JsonValue('high')
  high,
  @JsonValue('medium')
  medium,
  @JsonValue('low')
  low,
}