import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:romeo/secrets.dart';

class GroqServices {
  final List<Map<String, String>> messages = [];

  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  /// Detect whether prompt wants image generation
  Future<String> isArtPrompt(String prompt) async {
    try {
      final res = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "messages": [
            {
              "role": "user",
              "content":
              "Does this prompt ask to generate an image, art, picture, illustration, or visual content? "
                  "Answer only YES or NO.\n\nPrompt: $prompt"
            }
          ]
        }),
      );

      if (res.statusCode != 200) {
        return res.body;
      }

      final text = jsonDecode(res.body)['choices'][0]['message']['content']
          .toString()
          .trim()
          .toLowerCase();

      return text.startsWith("yes")
          ? "Image generation requested (image generation not supported)"
          : await groqChat(prompt);
    } catch (e) {
      return e.toString();
    }
  }

  /// Groq text chat
  Future<String> groqChat(String prompt) async {
    messages.add({
      "role": "user",
      "content": prompt,
    });

    try {
      final res = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "messages": messages,
        }),
      );

      if (res.statusCode != 200) {
        return res.body;
      }

      final content =
      jsonDecode(res.body)['choices'][0]['message']['content']
          .toString()
          .trim();

      messages.add({
        "role": "assistant",
        "content": content,
      });

      return content;
    } catch (e) {
      return e.toString();
    }
  }
}
