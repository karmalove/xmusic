import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:msgpack_dart/msgpack_dart.dart';
import 'package:pointycastle/export.dart';

Future<void> main() async {
  final domainParams = ECDomainParameters('secp256r1');

  final secureRandom = FortunaRandom();
  final seed = Uint8List(32);
  final random = Random.secure();
  for (var i = 0; i < seed.length; i++) seed[i] = random.nextInt(256);
  secureRandom.seed(KeyParameter(seed));

  final keyGen = ECKeyGenerator()
    ..init(ParametersWithRandom(
      ECKeyGeneratorParameters(domainParams),
      secureRandom,
    ));
  final keyPair = keyGen.generateKeyPair();
  final publicKey = keyPair.publicKey as ECPublicKey;

  BigInt bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final b in bytes) result = (result << 8) | BigInt.from(b);
    return result;
  }

  Uint8List bigIntToBytes(BigInt value, int length) {
    final result = Uint8List(length);
    var v = value;
    for (var i = length - 1; i >= 0; i--) {
      result[i] = (v & BigInt.from(0xff)).toInt();
      v = v >> 8;
    }
    return result;
  }

  final x = bigIntToBytes(publicKey.Q!.x!.toBigInteger()!, 32);
  final y = bigIntToBytes(publicKey.Q!.y!.toBigInteger()!, 32);
  final clientPublicKey = base64Url.encode(Uint8List.fromList([0x04, ...x, ...y])).replaceAll('=', '');

  Uint8List decodeBase64Url(String input) {
    var normalized = input;
    final mod = input.length % 4;
    if (mod == 2) normalized += '==';
    else if (mod == 3) normalized += '=';
    return base64Url.decode(normalized);
  }

  final sessionRes = await http.post(
    Uri.parse('https://ios.25pan.com/api/v1/music/secure/session'),
    headers: {'Content-Type': 'application/json', 'X-TabOS-Client': 'web'},
    body: jsonEncode({'clientPublicKey': clientPublicKey, 'recipeVersion': '1'}),
  );

  final sessionJson = jsonDecode(sessionRes.body) as Map<String, dynamic>;
  print('session code: ${sessionJson['code']}');
  if (sessionJson['code'] != 0) return;

  final data = sessionJson['data'] as Map<String, dynamic>;
  final sessionId = data['sessionId'] as String;
  final serverKeyBytes = decodeBase64Url(data['serverPublicKey'] as String);

  final rx = bytesToBigInt(serverKeyBytes.sublist(1, 33));
  final ry = bytesToBigInt(serverKeyBytes.sublist(33, 65));
  final remotePoint = domainParams.curve.createPoint(rx, ry);
  final remotePublicKey = ECPublicKey(remotePoint, domainParams);

  final agreement = ECDHBasicAgreement()
    ..init(keyPair.privateKey as ECPrivateKey);
  final shared = agreement.calculateAgreement(remotePublicKey)!;
  final sharedSecret = bigIntToBytes(shared, 32);

  final salt = decodeBase64Url(data['salt'] as String);
  final deriveInfo = utf8.encode(
    (data['deriveInfo'] as String?)?.trim() ?? 'tabos-music-secure-v1',
  );

  final hkdf = HKDFKeyDerivator(SHA256Digest())
    ..init(HkdfParameters(sharedSecret, 32, salt, Uint8List.fromList(deriveInfo)));
  final aesKey = hkdf.process(Uint8List(0));

  final apiRes = await http.get(
    Uri.parse(
      'https://ios.25pan.com/api/music/recommend/personal-fm?t=${DateTime.now().millisecondsSinceEpoch}',
    ),
    headers: {
      'X-TabOS-Client': 'web',
      'X-TabOS-Music-Secure': '1',
      'X-TabOS-Music-Session': sessionId,
      'Accept': 'application/vnd.tabos.music+json; charset=utf-8',
    },
  );

  print('api status: ${apiRes.statusCode}');

  final body = apiRes.bodyBytes;
  final nonce = body.sublist(1, 13);
  final ctWithTag = body.sublist(13);

  final cipher = GCMBlockCipher(AESEngine())
    ..init(false, AEADParameters(KeyParameter(aesKey), 128, nonce, Uint8List(0)));
  final plainBytes = cipher.process(ctWithTag);

  final decoded = deserialize(plainBytes);
  if (decoded is Map) {
    final list = (decoded['data'] as Map?)?['list'];
    print('SUCCESS list length: ${list is List ? list.length : 0}');
    if (list is List && list.isNotEmpty) {
      print('first song: ${list.first['name']}');
    }
  }
}
