import 'package:json_annotation/json_annotation.dart';

part 'hunting_result.g.dart';

@JsonSerializable()
class HuntingResult {
  final bool success;
  final String message;
  final DateTime timestamp;
  final bool isBlocked;
  final String? orderId;
  final Map<String, dynamic>? metadata;
  
  // 支付相关字段
  final String? payUrl;           // 支付跳转URL
  final String? payQrCode;        // 支付二维码
  final double? payAmount;        // 支付金额
  final String? payStatus;        // 支付状态: pending, paid, failed, expired
  final String? payChannel;       // 支付渠道: alipay, wechat

  const HuntingResult({
    required this.success,
    required this.message,
    required this.timestamp,
    this.isBlocked = false,
    this.orderId,
    this.metadata,
    this.payUrl,
    this.payQrCode,
    this.payAmount,
    this.payStatus,
    this.payChannel,
  });

  factory HuntingResult.fromJson(Map<String, dynamic> json) => _$HuntingResultFromJson(json);
  Map<String, dynamic> toJson() => _$HuntingResultToJson(this);

  HuntingResult copyWith({
    bool? success,
    String? message,
    DateTime? timestamp,
    bool? isBlocked,
    String? orderId,
    Map<String, dynamic>? metadata,
    String? payUrl,
    String? payQrCode,
    double? payAmount,
    String? payStatus,
    String? payChannel,
  }) {
    return HuntingResult(
      success: success ?? this.success,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isBlocked: isBlocked ?? this.isBlocked,
      orderId: orderId ?? this.orderId,
      metadata: metadata ?? this.metadata,
      payUrl: payUrl ?? this.payUrl,
      payQrCode: payQrCode ?? this.payQrCode,
      payAmount: payAmount ?? this.payAmount,
      payStatus: payStatus ?? this.payStatus,
      payChannel: payChannel ?? this.payChannel,
    );
  }

  @override
  String toString() {
    return 'HuntingResult(success: $success, message: $message, orderId: $orderId, payStatus: $payStatus)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HuntingResult &&
        other.success == success &&
        other.message == message &&
        other.timestamp == timestamp &&
        other.isBlocked == isBlocked &&
        other.orderId == orderId &&
        other.payUrl == payUrl &&
        other.payStatus == payStatus;
  }

  @override
  int get hashCode {
    return success.hashCode ^
        message.hashCode ^
        timestamp.hashCode ^
        isBlocked.hashCode ^
        orderId.hashCode ^
        payUrl.hashCode ^
        payStatus.hashCode;
  }
}