import 'dart:convert';
import 'package:http/http.dart' as http;

class Api {
  static const base = 'http://10.0.2.2:8000/api'; // emulator localhost
  String? access;

  Map<String, String> _authJson() {
    return {
      'Authorization': 'Bearer $access',
      'Content-Type': 'application/json',
    };
  }

  Future<bool> login(String username, String password) async {
    final r = await http.post(
      Uri.parse('$base/auth/token/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    print("DEBUG → login($username) ${r.statusCode} ${r.body}");
    if (r.statusCode == 200) {
      final json = jsonDecode(r.body);
      access = json['access'];
      return true;
    }
    return false;
  }

  Future<bool> register(String username, String email, String password) async {
    final r = await http.post(
      Uri.parse('$base/auth/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
          {'username': username, 'email': email, 'password': password}),
    );
    print("DEBUG → register($username) ${r.statusCode} ${r.body}");
    return r.statusCode == 201;
  }

  Future<Map<String, dynamic>> me() async {
    final r = await http.get(Uri.parse('$base/me/'), headers: _authJson());
    print("DEBUG → me() ${r.statusCode} ${r.body}");
    return jsonDecode(r.body);
  }

  Future<void> updateMe(Map<String, dynamic> data) async {
    final r = await http.patch(
      Uri.parse('$base/me/'),
      headers: _authJson(),
      body: jsonEncode(data),
    );
    print("DEBUG → updateMe ${r.statusCode} ${r.body}");
  }

  Future<List<dynamic>> getConversations() async {
    final r =
        await http.get(Uri.parse('$base/conversations/'), headers: _authJson());
    print("DEBUG → getConversations ${r.statusCode} ${r.body}");
    return jsonDecode(r.body);
  }

  Future<Map<String, dynamic>> createConversation(String peerUsername) async {
    final r = await http.post(
      Uri.parse('$base/conversations/'),
      headers: _authJson(),
      body: jsonEncode({
        "participants": [peerUsername], // must be a list
      }),
    );

    print("DEBUG → createConversation($peerUsername) ${r.statusCode} ${r.body}");

    if (r.statusCode == 200 || r.statusCode == 201) {
      return jsonDecode(r.body);
    } else {
      throw Exception("Failed to create conversation: ${r.body}");
    }
  }

  Future<Map<String, dynamic>?> getConversation(int convoId) async {
    final r = await http.get(
      Uri.parse('$base/conversations/$convoId/'),
      headers: _authJson(),
    );
    print("DEBUG → getConversation($convoId) ${r.statusCode} ${r.body}");
    if (r.statusCode == 200) {
      return jsonDecode(r.body);
    }
    return null;
  }

  Future<List<dynamic>> getMessages(int convoId) async {
    final r = await http.get(
      Uri.parse('$base/conversations/$convoId/messages/'),
      headers: _authJson(),
    );
    print("DEBUG → getMessages $convoId ${r.statusCode} ${r.body}");
    return r.statusCode == 200 ? jsonDecode(r.body) : [];
  }

  Future<void> sendMessage(int convoId, Map<String, dynamic> body) async {
    final r = await http.post(
      Uri.parse('$base/conversations/$convoId/messages/'),
      headers: _authJson(),
      body: jsonEncode(body),
    );
    print("DEBUG → sendMessage ${r.statusCode} ${r.body}");
  }

  Future<Map<String, dynamic>?> getPeerProfile(String username) async {
    final r = await http.get(Uri.parse('$base/profile/$username/'),
        headers: _authJson());
    print("DEBUG → getPeerProfile($username) ${r.statusCode} ${r.body}");
    if (r.statusCode == 200) return jsonDecode(r.body);
    return null;
  }

  // general-purpose POST
  Future<Map<String, dynamic>> postAuthed(
      String path, Map<String, dynamic> body) async {
    final r = await http.post(
      Uri.parse('$base$path'),
      headers: _authJson(),
      body: jsonEncode(body),
    );
    print("DEBUG → postAuthed($path) ${r.statusCode} ${r.body}");
    return jsonDecode(r.body);
  }

  // ✅ FIX: markViewed is now part of Api
  Future<void> markViewed(int msgId) async {
    final r = await http.post(
      Uri.parse('$base/messages/$msgId/view_once/'),
      headers: _authJson(),
    );
    if (r.statusCode != 200) {
      print("Failed to mark message $msgId as viewed → ${r.body}");
    } else {
      print("DEBUG → markViewed($msgId) success");
    }
  }
}

// global instance
final api = Api();
