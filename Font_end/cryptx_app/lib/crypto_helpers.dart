import 'dart:convert';
import 'package:cryptography/cryptography.dart';

final X25519 x25519 = X25519();
final Hkdf hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
final AesGcm aes = AesGcm.with256bits();

Future<KeyPair> generateKeyPair() => x25519.newKeyPair();

Future<String> exportPublicKeyBase64(KeyPair keyPair) async {
  final SimplePublicKey pub = await keyPair.extractPublicKey() as SimplePublicKey;
  return base64Encode(pub.bytes);
}

/// 🔧 Hardened ECDH+HKDF: reconstructs a concrete SimpleKeyPairData to ensure
/// the private key bytes are present, then asserts the shared secret is non-empty.
Future<SecretKey> deriveAesKey({
  required KeyPair myKeyPair,
  required SimplePublicKey peerPublicKey,
}) async {
  // Rebuild a guaranteed x25519 keypair that carries the private bytes.
  final SimpleKeyPair simple = await myKeyPair.extract() as SimpleKeyPair;
  final List<int> priv = await simple.extractPrivateKeyBytes();
  final SimplePublicKey myPub = await simple.extractPublicKey() as SimplePublicKey;

  if (priv.length != 32) {
    throw StateError('My private key seed invalid length: ${priv.length}');
  }

  final SimpleKeyPairData concrete = SimpleKeyPairData(
    priv,
    publicKey: myPub,
    type: KeyPairType.x25519,
  );

  // ECDH
  final SecretKey shared = await x25519.sharedSecretKey(
    keyPair: concrete,
    remotePublicKey: peerPublicKey,
  );

  // Sanity-check shared secret
  final sharedBytes = await shared.extractBytes();
  if (sharedBytes.isEmpty) {
    throw StateError('ECDH produced empty shared secret (buggy key objects)');
  }

  // HKDF-SHA256 → 32-byte AES key (salt non-empty to avoid odd engine quirks)
  final SecretKey aesKey = await hkdf.deriveKey(
    secretKey: SecretKey(sharedBytes),
    nonce: utf8.encode('cryptx-hkdf-salt'),  // non-empty salt
    info: utf8.encode('cryptx-demo-chat'),
  );

  final k = await aesKey.extractBytes();
  if (k.isEmpty) throw StateError('Derived AES key is empty');
  return aesKey;
}

Future<Map<String, String>> encryptText({
  required SecretKey aesKey,
  required String plaintext,
}) async {
  final nonce = aes.newNonce();
  final box = await aes.encrypt(
    utf8.encode(plaintext),
    secretKey: aesKey,
    nonce: nonce,
  );
  return {
    'ciphertext': base64Encode(box.cipherText),
    'nonce': base64Encode(nonce),
    'tag': base64Encode(box.mac.bytes),
  };
}

Future<String> decryptText({
  required SecretKey aesKey,
  required String b64Ciphertext,
  required String b64Nonce,
  required String b64Tag,
}) async {
  final cipher = base64Decode(b64Ciphertext);
  final nonce = base64Decode(b64Nonce);
  final mac = Mac(base64Decode(b64Tag));
  final clear = await aes.decrypt(
    SecretBox(cipher, nonce: nonce, mac: mac),
    secretKey: aesKey,
  );
  return utf8.decode(clear);
}
