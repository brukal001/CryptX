import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const FlutterSecureStorage _storage = FlutterSecureStorage();

String _userScopedKey(String username) => 'cryptx_x25519_private_seed_$username';

Future<void> savePrivateKey(KeyPair keyPair, String username) async {
  final SimpleKeyPair simple = await keyPair.extract() as SimpleKeyPair;
  final List<int> seed = await simple.extractPrivateKeyBytes();
  await _storage.write(key: _userScopedKey(username), value: base64Encode(seed));
  print("DEBUG → Saved private key for $username");
}

Future<KeyPair?> loadPrivateKey(String username) async {
  final b64 = await _storage.read(key: _userScopedKey(username));
  if (b64 == null) {
    print("DEBUG → No private key found for $username");
    return null;
  }
  final seed = base64Decode(b64);
  print("DEBUG → Loaded private key for $username, length=${seed.length}");
  return X25519().newKeyPairFromSeed(seed);
}


Future<KeyPair> ensureKeyPair(String username) async {
  final existing = await loadPrivateKey(username);
  if (existing != null) return existing;
  print("DEBUG → Generating new keypair for $username");
  final fresh = await X25519().newKeyPair();
  await savePrivateKey(fresh, username);
  return fresh;
}
