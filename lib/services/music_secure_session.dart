import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:msgpack_dart/msgpack_dart.dart';
import 'package:pointycastle/export.dart';

import '../config/api_config.dart';

Uint8List _decodeBase64Url(String input) {
  var normalized = input;
  final mod = input.length % 4;
  if (mod == 2) {
    normalized += '==';
  } else if (mod == 3) {
    normalized += '=';
  }
  return base64Url.decode(normalized);
}

String _encodeBase64Url(Uint8List bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// 音乐 API 安全会话管理
/// 使用 Pointycastle 实现跨平台 ECDH P-256 + HKDF + AES-GCM
class MusicSecureSession {
  String? _sessionId;
  Uint8List? _aesKey;
  int _expiresAt = 0;
  Future<void>? _creatingSession;

  static final _domainParams = ECDomainParameters('secp256r1');

  bool get isValid =>
      _sessionId != null &&
      _aesKey != null &&
      DateTime.now().millisecondsSinceEpoch < _expiresAt - 60000;

  String? get sessionId => _sessionId;

  Future<void> ensureSession({bool force = false}) async {
    if (!force && isValid) return;

    if (_creatingSession != null) {
      await _creatingSession;
      if (!force && isValid) return;
    }

    final creating = _createSession();
    _creatingSession = creating;
    try {
      await creating;
    } finally {
      if (identical(_creatingSession, creating)) {
        _creatingSession = null;
      }
    }
  }

  Future<void> _createSession() async {
    final keyPair = _generateKeyPair();
    final publicKey = keyPair.publicKey;
    final rawPublic = _encodePublicKeyRaw(publicKey);
    final clientPublicKey = _encodeBase64Url(rawPublic);

    final response = await http.post(
      Uri.parse(ApiConfig.sessionApi),
      headers: {
        'Content-Type': 'application/json',
        'X-TabOS-Client': 'web',
      },
      body: jsonEncode({
        'clientPublicKey': clientPublicKey,
        'recipeVersion': '1',
      }),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['code'] != 0) {
      throw Exception('会话创建失败: ${json['message']}');
    }

    final data = json['data'] as Map<String, dynamic>;
    _sessionId = data['sessionId'] as String;

    final serverKeyBytes = _decodeBase64Url(data['serverPublicKey'] as String);
    final remotePublicKey = _decodePublicKeyRaw(serverKeyBytes);

    final privateKey = keyPair.privateKey;
    final agreement = ECDHBasicAgreement()..init(privateKey);
    final sharedBigInt = agreement.calculateAgreement(remotePublicKey);
    final sharedSecret = _bigIntToBytes(sharedBigInt!, 32);

    final salt = _decodeBase64Url(data['salt'] as String);
    final deriveInfo = utf8.encode(
      (data['deriveInfo'] as String?)?.trim() ?? 'tabos-music-secure-v1',
    );

    _aesKey = _hkdfDerive(sharedSecret, salt, deriveInfo, 32);
    _expiresAt = data['expiresAt'] is int
        ? data['expiresAt'] as int
        : DateTime.now().millisecondsSinceEpoch +
            ((data['ttlSeconds'] as int? ?? 1800) * 1000);
  }

  ({ECPublicKey publicKey, ECPrivateKey privateKey}) _generateKeyPair() {
    final secureRandom = FortunaRandom();
    final seed = Uint8List(32);
    final random = Random.secure();
    for (var i = 0; i < seed.length; i++) {
      seed[i] = random.nextInt(256);
    }
    secureRandom.seed(KeyParameter(seed));

    final keyGen = ECKeyGenerator()
      ..init(ParametersWithRandom(
        ECKeyGeneratorParameters(_domainParams),
        secureRandom,
      ));
    final pair = keyGen.generateKeyPair();
    return (
      publicKey: pair.publicKey as ECPublicKey,
      privateKey: pair.privateKey as ECPrivateKey,
    );
  }

  Uint8List _encodePublicKeyRaw(ECPublicKey publicKey) {
    final x = _bigIntToBytes(publicKey.Q!.x!.toBigInteger()!, 32);
    final y = _bigIntToBytes(publicKey.Q!.y!.toBigInteger()!, 32);
    return Uint8List.fromList([0x04, ...x, ...y]);
  }

  ECPublicKey _decodePublicKeyRaw(Uint8List bytes) {
    final x = _bytesToBigInt(bytes.sublist(1, 33));
    final y = _bytesToBigInt(bytes.sublist(33, 65));
    final point = _domainParams.curve.createPoint(x, y);
    return ECPublicKey(point, _domainParams);
  }

  Uint8List _bigIntToBytes(BigInt value, int length) {
    final result = Uint8List(length);
    var v = value;
    for (var i = length - 1; i >= 0; i--) {
      result[i] = (v & BigInt.from(0xff)).toInt();
      v = v >> 8;
    }
    return result;
  }

  BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final b in bytes) {
      result = (result << 8) | BigInt.from(b);
    }
    return result;
  }

  Uint8List _hkdfDerive(
    Uint8List ikm,
    Uint8List salt,
    List<int> info,
    int length,
  ) {
    final hkdf = HKDFKeyDerivator(SHA256Digest())
      ..init(HkdfParameters(ikm, length, salt, Uint8List.fromList(info)));
    return hkdf.process(Uint8List(0));
  }

  Map<String, String> get headers => {
        'X-TabOS-Client': 'web',
        'X-TabOS-Music-Secure': '1',
        if (_sessionId != null) 'X-TabOS-Music-Session': _sessionId!,
        'Accept': ApiConfig.acceptHeader,
      };

  Future<dynamic> decodeResponse(http.Response response) async {
    if (response.headers['x-tabos-music-encrypted'] != '1') {
      return jsonDecode(response.body);
    }

    if (_aesKey == null) throw Exception('会话未初始化');

    final data = response.bodyBytes;
    if (data.isEmpty || data[0] != 1) {
      throw Exception('加密响应格式无效');
    }

    final nonce = data.sublist(1, 13);
    final ctWithTag = data.sublist(13);
    if (ctWithTag.length < 16) throw Exception('加密数据过短');

    final plainBytes = _aesGcmDecrypt(_aesKey!, nonce, ctWithTag);
    return deserialize(plainBytes);
  }

  Uint8List _aesGcmDecrypt(Uint8List key, Uint8List nonce, Uint8List ctWithTag) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)),
      );
    return cipher.process(ctWithTag);
  }

  void invalidate() {
    _sessionId = null;
    _aesKey = null;
    _expiresAt = 0;
  }
}
