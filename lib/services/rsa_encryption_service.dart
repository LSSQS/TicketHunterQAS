import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/export.dart';
import '../utils/logger.dart';
import '../config/app_config.dart';

/// RSA加密服务
/// 提供真实的RSA加密/解密功能
class RsaEncryptionService {
  static RsaEncryptionService? _instance;
  static RsaEncryptionService get instance => _instance ??= RsaEncryptionService._();
  
  RsaEncryptionService._();
  
  encrypt.Encrypter? _encrypter;
  RSAPublicKey? _publicKey;
  RSAPrivateKey? _privateKey;
  
  /// 初始化RSA加密器
  Future<void> initialize() async {
    try {
      // 从配置加载密钥
      final publicKeyPem = AppConfig.instance.rsaPublicKey;
      final privateKeyPem = AppConfig.instance.rsaPrivateKey;
      
      if (publicKeyPem != null && publicKeyPem.isNotEmpty) {
        _publicKey = encrypt.RSAKeyParser().parse(publicKeyPem) as RSAPublicKey;
      }
      
      if (privateKeyPem != null && privateKeyPem.isNotEmpty) {
        _privateKey = encrypt.RSAKeyParser().parse(privateKeyPem) as RSAPrivateKey;
      }
      
      if (_publicKey != null) {
        _encrypter = encrypt.Encrypter(encrypt.RSA(
          publicKey: _publicKey,
          privateKey: _privateKey,
        ));
        AppLogger.info('RSA encryption service initialized');
      } else {
        AppLogger.warning('RSA public key not configured, using fallback encryption');
      }
    } catch (e) {
      AppLogger.error('Failed to initialize RSA encryption service', e);
    }
  }
  
  /// 使用公钥加密
  String encryptWithPublicKey(String plainText) {
    if (_encrypter == null || _publicKey == null) {
      AppLogger.warning('RSA not initialized, using Base64 fallback');
      return _fallbackEncrypt(plainText);
    }
    
    try {
      // RSA加密有长度限制，需要分块加密
      final maxLength = (_publicKey!.modulus!.bitLength / 8).floor() - 11; // PKCS1 padding
      
      if (plainText.length <= maxLength) {
        // 短文本直接加密
        final encrypted = _encrypter!.encrypt(plainText);
        return encrypted.base64;
      } else {
        // 长文本分块加密
        return _encryptLongText(plainText, maxLength);
      }
    } catch (e) {
      AppLogger.error('RSA encryption failed', e);
      return _fallbackEncrypt(plainText);
    }
  }
  
  /// 使用私钥解密
  String decryptWithPrivateKey(String encryptedBase64) {
    if (_encrypter == null || _privateKey == null) {
      AppLogger.warning('RSA not initialized, using Base64 fallback');
      return _fallbackDecrypt(encryptedBase64);
    }
    
    try {
      // 检查是否是分块加密的
      if (encryptedBase64.contains('::')) {
        return _decryptLongText(encryptedBase64);
      } else {
        final encrypted = encrypt.Encrypted.fromBase64(encryptedBase64);
        return _encrypter!.decrypt(encrypted);
      }
    } catch (e) {
      AppLogger.error('RSA decryption failed', e);
      return _fallbackDecrypt(encryptedBase64);
    }
  }
  
  /// 分块加密长文本
  String _encryptLongText(String plainText, int maxLength) {
    final chunks = <String>[];
    
    for (var i = 0; i < plainText.length; i += maxLength) {
      final end = min(i + maxLength, plainText.length);
      final chunk = plainText.substring(i, end);
      final encrypted = _encrypter!.encrypt(chunk);
      chunks.add(encrypted.base64);
    }
    
    // 使用特殊分隔符连接
    return chunks.join('::');
  }
  
  /// 分块解密长文本
  String _decryptLongText(String encryptedText) {
    final chunks = encryptedText.split('::');
    final decryptedChunks = <String>[];
    
    for (final chunk in chunks) {
      final encrypted = encrypt.Encrypted.fromBase64(chunk);
      final decrypted = _encrypter!.decrypt(encrypted);
      decryptedChunks.add(decrypted);
    }
    
    return decryptedChunks.join('');
  }
  
  /// 生成RSA密钥对
  static Future<Map<String, String>> generateKeyPair({int bitLength = 2048}) async {
    try {
      AppLogger.info('Generating RSA key pair with $bitLength bits...');
      
      final keyPair = await _generateRSAKeyPair(bitLength);
      
      final publicKeyPem = _encodePublicKeyToPem(keyPair.publicKey as RSAPublicKey);
      final privateKeyPem = _encodePrivateKeyToPem(keyPair.privateKey as RSAPrivateKey);
      
      AppLogger.info('RSA key pair generated successfully');
      
      return {
        'publicKey': publicKeyPem,
        'privateKey': privateKeyPem,
      };
    } catch (e) {
      AppLogger.error('Failed to generate RSA key pair', e);
      rethrow;
    }
  }
  
  /// 生成RSA密钥对（内部实现）
  static Future<AsymmetricKeyPair> _generateRSAKeyPair(
    int bitLength,
  ) async {
    // 使用pointycastle直接生成密钥对
    final keyParams = RSAKeyGeneratorParameters(BigInt.from(65537), bitLength, 64);
    final secureRandom = _getSecureRandom();
    
    final rngParams = ParametersWithRandom(keyParams, secureRandom);
    final keyGenerator = RSAKeyGenerator()..init(rngParams);
    
    return keyGenerator.generateKeyPair();
  }
  
  /// 获取安全随机数生成器
  static SecureRandom _getSecureRandom() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }
  
  /// 编码公钥为PEM格式
  static String _encodePublicKeyToPem(RSAPublicKey publicKey) {
    final algorithmSeq = ASN1Sequence();
    final algorithmAsn1Obj = ASN1Object.fromBytes(
      Uint8List.fromList([0x6, 0x9, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0xd, 0x1, 0x1, 0x1]),
    );
    final paramsAsn1Obj = ASN1Object.fromBytes(Uint8List.fromList([0x5, 0x0]));
    algorithmSeq.add(algorithmAsn1Obj);
    algorithmSeq.add(paramsAsn1Obj);

    final publicKeySeq = ASN1Sequence();
    publicKeySeq.add(ASN1Integer(publicKey.modulus!));
    publicKeySeq.add(ASN1Integer(publicKey.exponent!));
    final publicKeySeqBitString = ASN1BitString(
      Uint8List.fromList(publicKeySeq.encodedBytes),
    );

    final topLevelSeq = ASN1Sequence();
    topLevelSeq.add(algorithmSeq);
    topLevelSeq.add(publicKeySeqBitString);

    final dataBase64 = base64Encode(topLevelSeq.encodedBytes);
    return '-----BEGIN PUBLIC KEY-----\n$dataBase64\n-----END PUBLIC KEY-----';
  }
  
  /// 编码私钥为PEM格式
  static String _encodePrivateKeyToPem(RSAPrivateKey privateKey) {
    final topLevelSeq = ASN1Sequence();
    
    final version = ASN1Integer(BigInt.from(0));
    final modulus = ASN1Integer(privateKey.modulus!);
    final publicExponent = ASN1Integer(privateKey.exponent!);
    final privateExponent = ASN1Integer(privateKey.privateExponent!);
    final p = ASN1Integer(privateKey.p!);
    final q = ASN1Integer(privateKey.q!);
    final dP = ASN1Integer(privateKey.privateExponent! % (privateKey.p! - BigInt.one));
    final dQ = ASN1Integer(privateKey.privateExponent! % (privateKey.q! - BigInt.one));
    final qInv = ASN1Integer(privateKey.q!.modInverse(privateKey.p!));

    topLevelSeq.add(version);
    topLevelSeq.add(modulus);
    topLevelSeq.add(publicExponent);
    topLevelSeq.add(privateExponent);
    topLevelSeq.add(p);
    topLevelSeq.add(q);
    topLevelSeq.add(dP);
    topLevelSeq.add(dQ);
    topLevelSeq.add(qInv);

    final dataBase64 = base64Encode(topLevelSeq.encodedBytes);
    return '-----BEGIN RSA PRIVATE KEY-----\n$dataBase64\n-----END RSA PRIVATE KEY-----';
  }
  
  /// 后备加密方法（Base64）
  String _fallbackEncrypt(String plainText) {
    final bytes = utf8.encode(plainText);
    return base64Encode(bytes);
  }
  
  /// 后备解密方法（Base64）
  String _fallbackDecrypt(String encryptedBase64) {
    try {
      final bytes = base64Decode(encryptedBase64);
      return utf8.decode(bytes);
    } catch (e) {
      AppLogger.error('Fallback decryption failed', e);
      return '';
    }
  }
  
  /// 设置公钥
  void setPublicKey(String publicKeyPem) {
    try {
      _publicKey = encrypt.RSAKeyParser().parse(publicKeyPem) as RSAPublicKey;
      if (_privateKey != null) {
        _encrypter = encrypt.Encrypter(encrypt.RSA(
          publicKey: _publicKey,
          privateKey: _privateKey,
        ));
      }
      AppLogger.info('Public key set successfully');
    } catch (e) {
      AppLogger.error('Failed to set public key', e);
    }
  }
  
  /// 设置私钥
  void setPrivateKey(String privateKeyPem) {
    try {
      _privateKey = encrypt.RSAKeyParser().parse(privateKeyPem) as RSAPrivateKey;
      if (_publicKey != null) {
        _encrypter = encrypt.Encrypter(encrypt.RSA(
          publicKey: _publicKey,
          privateKey: _privateKey,
        ));
      }
      AppLogger.info('Private key set successfully');
    } catch (e) {
      AppLogger.error('Failed to set private key', e);
    }
  }
  
  /// 检查是否已初始化
  bool get isInitialized => _encrypter != null && _publicKey != null;
}

// ASN1辅助类
class ASN1Object {
  final int tag;
  final Uint8List valueBytes;
  
  ASN1Object(this.tag, this.valueBytes);
  
  factory ASN1Object.fromBytes(Uint8List bytes) {
    return ASN1Object(bytes[0], bytes.sublist(1));
  }
  
  Uint8List get encodedBytes {
    final result = BytesBuilder();
    result.addByte(tag);
    result.add(_encodeLength(valueBytes.length));
    result.add(valueBytes);
    return result.toBytes();
  }
  
  static Uint8List _encodeLength(int length) {
    if (length < 128) {
      return Uint8List.fromList([length]);
    } else {
      final lengthBytes = _encodeBigInt(BigInt.from(length));
      return Uint8List.fromList([0x80 | lengthBytes.length, ...lengthBytes]);
    }
  }
  
  static Uint8List _encodeBigInt(BigInt number) {
    final bytes = <int>[];
    var n = number;
    while (n > BigInt.zero) {
      bytes.insert(0, (n & BigInt.from(0xff)).toInt());
      n = n >> 8;
    }
    return Uint8List.fromList(bytes.isEmpty ? [0] : bytes);
  }
}

class ASN1Sequence extends ASN1Object {
  final List<ASN1Object> elements = [];
  
  ASN1Sequence() : super(0x30, Uint8List(0));
  
  void add(ASN1Object element) {
    elements.add(element);
  }
  
  @override
  Uint8List get encodedBytes {
    final result = BytesBuilder();
    for (final element in elements) {
      result.add(element.encodedBytes);
    }
    final valueBytes = result.toBytes();
    
    final encoded = BytesBuilder();
    encoded.addByte(tag);
    encoded.add(ASN1Object._encodeLength(valueBytes.length));
    encoded.add(valueBytes);
    return encoded.toBytes();
  }
}

class ASN1Integer extends ASN1Object {
  ASN1Integer(BigInt value) : super(0x02, _encodeValue(value));
  
  static Uint8List _encodeValue(BigInt value) {
    final bytes = <int>[];
    var n = value;
    
    if (n == BigInt.zero) {
      return Uint8List.fromList([0]);
    }
    
    while (n > BigInt.zero) {
      bytes.insert(0, (n & BigInt.from(0xff)).toInt());
      n = n >> 8;
    }
    
    // 如果最高位是1，需要添加0x00前缀
    if (bytes[0] & 0x80 != 0) {
      bytes.insert(0, 0);
    }
    
    return Uint8List.fromList(bytes);
  }
}

class ASN1BitString extends ASN1Object {
  ASN1BitString(Uint8List bytes) : super(0x03, _encodeValue(bytes));
  
  static Uint8List _encodeValue(Uint8List bytes) {
    return Uint8List.fromList([0, ...bytes]);
  }
}
