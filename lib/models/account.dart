import 'package:json_annotation/json_annotation.dart';
import 'platform_config.dart';

part 'account.g.dart';

@JsonSerializable()
class Account {
  final String id;
  final String username;
  final String password;
  final String? phone;
  final String? email;
  final AccountStatus status;
  final String deviceId;
  final DateTime? lastLoginTime;
  final DateTime? lastUsedTime;
  final int loginFailCount;
  final bool isActive;
  final Map<String, dynamic>? cookies;
  final String? token;
  final bool isEnabled;
  final String? province;
  final String? city;
  final int priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TicketPlatform platform;

  Account({
    required this.id,
    required this.username,
    required this.password,
    this.phone,
    this.email,
    this.status = AccountStatus.inactive,
    String? deviceId,
    this.lastLoginTime,
    this.lastUsedTime,
    this.loginFailCount = 0,
    this.isActive = true,
    this.cookies,
    this.token,
    this.isEnabled = true,
    this.province,
    this.city,
    this.priority = 1,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.platform = TicketPlatform.damai,
  })  : deviceId = deviceId ?? 'device_${DateTime.now().millisecondsSinceEpoch}',
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Account.fromJson(Map<String, dynamic> json) => _$AccountFromJson(json);

  Map<String, dynamic> toJson() => _$AccountToJson(this);

  Account copyWith({
    String? id,
    String? username,
    String? password,
    String? phone,
    String? email,
    AccountStatus? status,
    String? deviceId,
    DateTime? lastLoginTime,
    DateTime? lastUsedTime,
    int? loginFailCount,
    bool? isActive,
    Map<String, dynamic>? cookies,
    String? token,
    bool? isEnabled,
    String? province,
    String? city,
    int? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
    TicketPlatform? platform,
  }) {
    return Account(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      status: status ?? this.status,
      deviceId: deviceId ?? this.deviceId,
      lastLoginTime: lastLoginTime ?? this.lastLoginTime,
      lastUsedTime: lastUsedTime ?? this.lastUsedTime,
      loginFailCount: loginFailCount ?? this.loginFailCount,
      isActive: isActive ?? this.isActive,
      cookies: cookies ?? this.cookies,
      token: token ?? this.token,
      isEnabled: isEnabled ?? this.isEnabled,
      province: province ?? this.province,
      city: city ?? this.city,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      platform: platform ?? this.platform,
    );
  }

  bool get canUse => isActive && status == AccountStatus.active && loginFailCount < 3;
  
  String get statusText {
    switch (status) {
      case AccountStatus.active:
        return '正常';
      case AccountStatus.inactive:
        return '未激活';
      case AccountStatus.banned:
        return '已封禁';
      case AccountStatus.error:
        return '异常';
    }
  }
}

enum AccountStatus {
  active,
  inactive,
  banned,
  error,
}
