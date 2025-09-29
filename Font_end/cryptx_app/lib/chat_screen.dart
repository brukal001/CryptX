// lib/chat_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
import 'dart:async';
import 'crypto_helpers.dart';
import 'main.dart' show api;

class ChatScreen extends StatefulWidget {
  final int convoId;
  final KeyPair myKeyPair;
  final String peerUsername;

  const ChatScreen({
    super.key,
    required this.convoId,
    required this.myKeyPair,
    required this.peerUsername,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final textCtrl = TextEditingController();
  final List<Map<String, dynamic>> messages = [];
  bool viewOnce = false;

  SecretKey? sessionKey;
  bool sessionReady = false;
  String? sessionErr;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      loading = true;
      sessionErr = null;
      sessionReady = false;
    });

    try {
      await _ensureSessionKey();
      if (mounted) await _refresh();
      if (mounted) setState(() => loading = false);
    } catch (e, st) {
      debugPrint("CRASH in _initialize → $e\n$st");
      if (mounted) {
        setState(() {
          sessionErr = e.toString();
          loading = false;
        });
      }
    }
  }

  Future<void> _ensureSessionKey() async {
    final profile = await api.getPeerProfile(widget.peerUsername);
    if (profile == null) throw Exception("Peer profile not found");

    final peerPubB64 = (profile['public_key'] as String?) ?? "";
    if (peerPubB64.isEmpty) throw Exception("Peer has no public key");

    final peerBytes = base64Decode(peerPubB64);
    if (peerBytes.length != 32) {
      throw Exception("Peer public key invalid length: ${peerBytes.length}");
    }

    final peerPub = SimplePublicKey(peerBytes, type: KeyPairType.x25519);

    // sanity check my seed
    final simple = await widget.myKeyPair.extract() as SimpleKeyPair;
    final mySeed = await simple.extractPrivateKeyBytes();
    if (mySeed.length != 32) {
      throw Exception("My private key seed invalid (len=${mySeed.length})");
    }

    try {
      sessionKey = await Future.any<SecretKey>([
        deriveAesKey(myKeyPair: widget.myKeyPair, peerPublicKey: peerPub),
        Future<SecretKey>.delayed(
          const Duration(seconds: 5),
          () => throw TimeoutException("ECDH/HKDF timed out"),
        ),
      ]);
    } catch (e) {
      throw Exception("Failed to derive session key: $e");
    }

    final k = await sessionKey!.extractBytes();
    debugPrint("✅ Session key ready, len=${k.length}");

    if (mounted) setState(() => sessionReady = true);
  }

  Future<void> _refresh() async {
    final data = await api.getMessages(widget.convoId);
    if (mounted) {
      setState(() {
        messages
          ..clear()
          ..addAll(List<Map<String, dynamic>>.from(data));
      });
    }
  }

  Future<void> _send() async {
    if (!sessionReady || sessionKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Session not ready yet')),
      );
      return;
    }

    final txt = textCtrl.text.trim();
    if (txt.isEmpty) return;

    final enc = await encryptText(
      aesKey: sessionKey!,
      plaintext: txt,
    );

    await api.sendMessage(widget.convoId, {
      'ciphertext': enc['ciphertext'],
      'nonce': enc['nonce'],
      'tag': enc['tag'],
      'view_once': viewOnce,
    });

    textCtrl.clear();
    await _refresh();
  }

  void _handleViewed(int id) {
    api.markViewed(id); // backend call
    setState(() {
      messages.removeWhere((msg) => msg['id'] == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (sessionErr != null) {
      return Scaffold(
        appBar: AppBar(title: Text("Chat with ${widget.peerUsername}")),
        body: Center(child: Text('❌ $sessionErr')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.peerUsername}'),
        actions: [
          if (sessionErr != null)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.error, color: Colors.red),
            ),
          if (sessionErr == null && !sessionReady)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (sessionReady)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.lock, color: Colors.green),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final m = messages[i];
                final isMe = m['sender'] != widget.peerUsername;

                if (m['view_once'] == true && m['viewed'] == true) {
                  return const ListTile(title: Text('[Deleted after view]'));
                }

                if (!sessionReady || sessionKey == null) {
                  return const ListTile(
                    title: Text('❌ Cannot decrypt (no session key)'),
                  );
                }

                return FutureBuilder<String>(
                  future: decryptText(
                    aesKey: sessionKey!,
                    b64Ciphertext: m['ciphertext'],
                    b64Nonce: m['nonce'],
                    b64Tag: m['tag'],
                  ),
                  builder: (_, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const ListTile(title: Text('Decrypting...'));
                    }
                    if (!snap.hasData) {
                      return const ListTile(
                        title: Text('❌ Failed to decrypt'),
                      );
                    }

                    final text = snap.data!;

                    if (m['view_once'] == true && m['viewed'] != true) {
                      // trigger post-frame deletion
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _handleViewed(m['id']);
                      });
                    }

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue[400] : Colors.grey[300],
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: isMe
                                ? const Radius.circular(12)
                                : const Radius.circular(0),
                            bottomRight: isMe
                                ? const Radius.circular(0)
                                : const Radius.circular(12),
                          ),
                        ),
                        child: Text(
                          text,
                          style: TextStyle(
                            fontSize: 16,
                            color: isMe ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: textCtrl,
                        decoration:
                            const InputDecoration(hintText: 'Message...'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _send,
                      child: const Text('Send'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Checkbox(
                      value: viewOnce,
                      onChanged: (v) =>
                          setState(() => viewOnce = v ?? false),
                    ),
                    const Text('Send confidentially (view-once)'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
