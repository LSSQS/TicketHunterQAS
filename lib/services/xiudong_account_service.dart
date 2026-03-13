import 'package:dio/dio.dart';
import '../models/account.dart';
import '../models/platform_config.dart';
import '../utils/logger.dart';
import 'signature_service.dart';
import 'damai_account_service.dart'; // Reuse LoginResult

/// 秀动账号服务
class XiudongAccountService {
  final Dio _dio = Dio();
  final SignatureService _signatureService = SignatureService();
  final PlatformConfig _config = PlatformConfig.xiudong;

  XiudongAccountService() {
    _setupDio();
  }

  void _setupDio() {
    _dio.options = BaseOptions(
      baseUrl: _config.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: _config.headers,
    );

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        AppLogger.debug('Xiudong Account Request: ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        AppLogger.debug('Xiudong Account Response: ${response.statusCode}');
        handler.next(response);
      },
      onError: (error, handler) {
        AppLogger.error('Xiudong Account Request error: ${error.message}', error);
        handler.next(error);
      },
    ));
  }

  /// 登录
  Future<LoginResult> login(Account account) async {
    try {
      AppLogger.info('Attempting Xiudong login for account: ${account.username}');

      // 检查是否有 Cookie 或 Token
      if (account.cookies != null && account.cookies!.isNotEmpty) {
        final isValid = await _validateCookies(account.cookies!);
        if (isValid) {
          return LoginResult(
            success: true,
            message: 'Cookie有效',
            cookies: account.cookies?.cast<String, String>(),
          );
        }
      }

      // 秀动登录通常需要手机验证码
      // 这里模拟登录流程，实际需要用户手动导入 Cookie
      if (account.password.isNotEmpty) {
        // 尝试密码登录
        final result = await _attemptPasswordLogin(account);
        if (result.success) {
          return result;
        }
      }

      return LoginResult(
        success: false,
        message: '秀动暂不支持自动密码登录，请使用Cookie导入',
      );
    } catch (e) {
      return LoginResult(
        success: false,
        message: '登录异常: $e',
      );
    }
  }

  /// 尝试密码登录
  Future<LoginResult> _attemptPasswordLogin(Account account) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final deviceId = account.deviceId;

      final params = {
        'loginId': account.username,
        'password': account.password,
        'timestamp': timestamp.toString(),
      };

      // 生成签名
      final signature = await _generateSignature(params, deviceId);

      final response = await _dio.post(
        '/api/v2/users/login',
        data: params,
        queryParameters: {
          'sign': signature,
        },
        options: Options(
          headers: {
            'X-Device-ID': deviceId,
            'X-Timestamp': timestamp.toString(),
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['success'] == true || data['status'] == 0) {
          final cookies = _extractCookies(response);
          final token = data['data']?['token'];
          
          return LoginResult(
            success: true,
            message: '登录成功',
            cookies: cookies,
            token: token,
            userInfo: data['data'],
          );
        } else {
          return LoginResult(
            success: false,
            message: data['message'] ?? data['msg'] ?? '登录失败',
          );
        }
      }

      return LoginResult(
        success: false,
        message: '登录请求失败',
      );
    } catch (e) {
      AppLogger.error('Xiudong password login failed', e);
      return LoginResult(
        success: false,
        message: '登录异常: $e',
      );
    }
  }

  /// 验证 Cookie 是否有效
  Future<bool> _validateCookies(Map<String, dynamic> cookies) async {
    try {
      final cookieString = cookies.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');

      final response = await _dio.get(
        '/api/v2/users/info',
        options: Options(
          headers: {'Cookie': cookieString},
        ),
      );

      return response.statusCode == 200 && 
             (response.data['success'] == true || response.data['status'] == 0);
    } catch (e) {
      return false;
    }
  }

  /// 生成签名
  Future<String> _generateSignature(Map<String, dynamic> params, String deviceId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    return await _signatureService.generateXiudongSignature(
      params: params,
      deviceId: deviceId,
      timestamp: timestamp,
    );
  }

  /// 提取 Cookie
  Map<String, String> _extractCookies(Response response) {
    final cookies = <String, String>{};
    final setCookieHeaders = response.headers['set-cookie'];
    if (setCookieHeaders != null) {
      for (final cookieHeader in setCookieHeaders) {
        final parts = cookieHeader.split(';');
        if (parts.isNotEmpty) {
          final nameValue = parts[0].split('=');
          if (nameValue.length == 2) {
            cookies[nameValue[0].trim()] = nameValue[1].trim();
          }
        }
      }
    }
    return cookies;
  }

  /// 获取用户信息
  Future<Map<String, dynamic>?> getUserInfo(Map<String, dynamic> cookies) async {
    try {
      final cookieString = cookies.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');

      final response = await _dio.get(
        '/api/v2/users/info',
        options: Options(
          headers: {'Cookie': cookieString},
        ),
      );

      if (response.statusCode == 200 && 
          (response.data['success'] == true || response.data['status'] == 0)) {
        return response.data['data'];
      }

      return null;
    } catch (e) {
      AppLogger.error('Get Xiudong user info failed', e);
      return null;
    }
  }

  /// 验证账号
  Future<bool> validate(Account account) async {
    if (account.cookies == null || account.cookies!.isEmpty) {
      return false;
    }
    return await _validateCookies(account.cookies!);
  }
}
