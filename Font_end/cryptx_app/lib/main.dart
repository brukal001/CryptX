// lib/main.dart
import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';

import 'api.dart';
import 'chat_screen.dart';
import 'crypto_helpers.dart';
import 'secure_store.dart';

void main() {
  runApp(const CryptXApp());
}

class CryptXApp extends StatelessWidget {
  const CryptXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CryptX Demo',
      theme: ThemeData(useMaterial3: true),
      home: const LoginScreen(),
    );
  }
}

final api = Api();

/// Example LoginScreen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final userCtrl = TextEditingController(text: "alice");
  final passCtrl = TextEditingController(text: "StrongPass123");
  final emailCtrl = TextEditingController(text: "alice@example.com");
  bool loading = false;
  String msg = "";

  Future<void> _login() async {
    setState(() {
      loading = true;
      msg = "";
    });
    final ok = await api.login(userCtrl.text.trim(), passCtrl.text);
    setState(() {
      loading = false;
      msg = ok ? "Logged in" : "Login failed";
    });
    if (ok && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    }
  }

  Future<void> _register() async {
    setState(() {
      loading = true;
      msg = "";
    });
    final ok = await api.register(
      userCtrl.text.trim(),
      emailCtrl.text.trim(),
      passCtrl.text,
    );
    setState(() {
      loading = false;
      msg = ok ? "Registered, now Login" : "Register failed";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("CryptX Login")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: userCtrl, decoration: const InputDecoration(labelText: "Username")),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: passCtrl, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
            const SizedBox(height: 12),
            if (loading) const CircularProgressIndicator(),
            if (!loading)
              Row(
                children: [
                  ElevatedButton(onPressed: _login, child: const Text("Login")),
                  const SizedBox(width: 12),
                  OutlinedButton(onPressed: _register, child: const Text("Register")),
                ],
              ),
            const SizedBox(height: 8),
            Text(msg),
          ],
        ),
      ),
    );
  }
}

/// ProfileScreen (fixed with imports)
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? myPubB64;
  KeyPair? myKey;
  String? myUsername;
  final peerCtrl = TextEditingController(text: 'bob');

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
  final me = await api.me();
  myUsername = me['username'];

  // Always use ensureKeyPair (saves if missing, loads if exists)
  myKey = await ensureKeyPair(myUsername!);

  // ✅ Reload to guarantee sync
  myKey = await loadPrivateKey(myUsername!);

  myPubB64 = await exportPublicKeyBase64(myKey!);
  await api.updateMe({'public_key': myPubB64});
  print("DEBUG → Uploaded public key for $myUsername = $myPubB64");

  if (mounted) setState(() {});
}


Future<void> _startChat() async {
  final peer = peerCtrl.text.trim();
  final allConvos = await api.getConversations();
  final existing = allConvos.firstWhere(
    (c) => List<String>.from(c['participants']).contains(peer),
    orElse: () => {},
  );

final convoId = existing.isNotEmpty
    ? existing['id']
    : (await api.createConversation(peer))['id'];
  print("DEBUG → Using convo ID $convoId with $peer");


  // Now navigate to the chat screen
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatScreen(
        convoId: convoId,
        myKeyPair: myKey!,   // or however you’re storing the logged-in user keypair
        peerUsername: peer,
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile & Keys')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Logged in as: $myUsername'),
            Text('Public key uploaded: ${myPubB64 != null}'),
            TextField(
              controller: peerCtrl,
              decoration: const InputDecoration(labelText: 'Peer username'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: myKey == null ? null : _startChat,
              child: const Text('Start Chat'),
            ),
          ],
        ),
      ),
    );
  }
}
