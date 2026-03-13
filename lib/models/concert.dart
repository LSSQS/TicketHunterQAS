import 'package:json_annotation/json_annotation.dart';

part 'concert.g.dart';

@JsonSerializable()
class Concert {
  final String id;
  final String name;
  final String? artist;
  final String venue;
  final DateTime showTime;
  final DateTime saleStartTime;
  final String? url;
  final String itemId;
  final List<TicketSku> skus;
  final ConcertStatus status;
  final List<String> targetPrices;
  final List<String> targetSessions;
  final int priority;
  final int maxTickets;
  final bool isEnabled;
  final bool autoRefresh;
  final int refreshInterval;
  final int maxRetries;
  final int maxConcurrency;
  final int retryCount;
  final Duration retryDelay;
  final bool autoStart;
  final String? description;
  final String? posterUrl;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  Concert({
    required this.id,
    required this.name,
    this.artist,
    required this.venue,
    DateTime? showTime,
    required this.saleStartTime,
    this.url,
    String? itemId,
    List<TicketSku>? skus,
    this.status = ConcertStatus.pending,
    this.targetPrices = const [],
    this.targetSessions = const [],
    this.priority = 5,
    this.maxTickets = 2,
    this.isEnabled = true,
    this.autoRefresh = true,
    this.refreshInterval = 1000,
    this.maxRetries = 10,
    this.maxConcurrency = 50,
    this.retryCount = 5,
    this.retryDelay = const Duration(milliseconds: 100),
    this.autoStart = false,
    this.description,
    this.posterUrl,
    this.metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : showTime = showTime ?? saleStartTime.add(const Duration(days: 1)),
        itemId = itemId ?? 'item_${DateTime.now().millisecondsSinceEpoch}',
        skus = skus ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Concert.fromJson(Map<String, dynamic> json) => _$ConcertFromJson(json);
  Map<String, dynamic> toJson() => _$ConcertToJson(this);

  Concert copyWith({
    String? id,
    String? name,
    String? artist,
    String? venue,
    DateTime? showTime,
    DateTime? saleStartTime,
    String? url,
    String? itemId,
    List<TicketSku>? skus,
    ConcertStatus? status,
    List<String>? targetPrices,
    List<String>? targetSessions,
    int? priority,
    int? maxTickets,
    bool? isEnabled,
    bool? autoRefresh,
    int? refreshInterval,
    int? maxRetries,
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
    return Concert(
      id: id ?? this.id,
      name: name ?? this.name,
      artist: artist ?? this.artist,
      venue: venue ?? this.venue,
      showTime: showTime ?? this.showTime,
      saleStartTime: saleStartTime ?? this.saleStartTime,
      url: url ?? this.url,
      itemId: itemId ?? this.itemId,
      skus: skus ?? this.skus,
      status: status ?? this.status,
      targetPrices: targetPrices ?? this.targetPrices,
      targetSessions: targetSessions ?? this.targetSessions,
      priority: priority ?? this.priority,
      maxTickets: maxTickets ?? this.maxTickets,
      isEnabled: isEnabled ?? this.isEnabled,
      autoRefresh: autoRefresh ?? this.autoRefresh,
      refreshInterval: refreshInterval ?? this.refreshInterval,
      maxRetries: maxRetries ?? this.maxRetries,
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

  bool get isUpcoming => DateTime.now().isBefore(saleStartTime);
  bool get isOnSale => DateTime.now().isAfter(saleStartTime) && 
                      DateTime.now().isBefore(showTime);
  bool get isExpired => DateTime.now().isAfter(showTime);
  
  Duration get timeToSale => saleStartTime.difference(DateTime.now());
  
  String get statusText {
    switch (status) {
      case ConcertStatus.pending:
        return '待开售';
      case ConcertStatus.active:
        return '抢票中';
      case ConcertStatus.completed:
        return '已完成';
      case ConcertStatus.cancelled:
        return '已取消';
    }
  }
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

  TicketSku({
    required this.skuId,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.priority = TicketPriority.medium,
    this.isEnabled = true,
    this.seatInfo,
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
  }) {
    return TicketSku(
      skuId: skuId ?? this.skuId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      priority: priority ?? this.priority,
      isEnabled: isEnabled ?? this.isEnabled,
      seatInfo: seatInfo ?? this.seatInfo,
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

enum ConcertStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('active')
  active,
  @JsonValue('completed')
  completed,
  @JsonValue('cancelled')
  cancelled,
}

enum TicketPriority {
  @JsonValue('high')
  high,
  @JsonValue('medium')
  medium,
  @JsonValue('low')
  low,
}
