import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GroqServices {
  final List<Map<String, String>> messages = [];
  static const int _maxHistory = 20; // keep last 20 messages (10 exchanges)

  static const String _proxyUrl = 'https://groq-proxy-8ly1.onrender.com/chat';
  static const String _appSecret = 'ced5914cf67a9060e68e83ee614c75a9';

  Future<String> isArtPrompt(String prompt) async {
    final result = await _callProxy([
      {
        "role": "user",
        "content":
        "Does this prompt ask to generate an image, art, picture, illustration, or visual content? "
            "Answer only YES or NO.\n\nPrompt: $prompt"
      }
    ]);

    if (result == null) return "Something went wrong. Please try again.";

    final lower = result.trim().toLowerCase();
    return lower.startsWith("yes")
        ? "Image generation requested (image generation not supported)"
        : await groqChat(prompt);
  }

  Future<String> groqChat(String prompt) async {
    messages.add({"role": "user", "content": prompt});
    _trimHistory();

    final content = await _callProxy(messages);
    if (content == null) {
      messages.removeLast();
      return "Something went wrong. Please try again.";
    }

    messages.add({"role": "assistant", "content": content});
    _trimHistory();
    return content;
  }

  void _trimHistory() {
    if (messages.length > _maxHistory) {
      messages.removeRange(0, messages.length - _maxHistory);
    }
  }

  Future<String?> _callProxy(List<Map<String, String>> msgs) async {
    try {
      final res = await http
          .post(
        Uri.parse(_proxyUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-app-secret': _appSecret,
        },
        body: jsonEncode({"messages": msgs}),
      )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode != 200) {
        return null;
      }

      return jsonDecode(res.body)['content'].toString().trim();
    } catch (_) {
      return null;
    }
  }
}