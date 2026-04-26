import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenRouterService {
  final String apiKey;
  final String baseUrl = 'https://openrouter.ai/api/v1';

  OpenRouterService({required this.apiKey});

  Future<String> generateResponse({
    String? message,
    List<Map<String, dynamic>>? rawMessages,
    required String model,
    double temperature = 0.7,
    int maxTokens = 16000,
  }) async {
    final url = Uri.parse('$baseUrl/chat/completions');

    final Map<String, dynamic> requestBody = {
      'model': model,
      'messages': rawMessages ?? [
        {'role': 'user', 'content': message ?? ''},
      ],
      'temperature': temperature,
      'max_tokens': maxTokens,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer':
              'https://github.com/amblackpearl/saingandolladanciciai',
          'X-Title': 'Flutter AI Assistant',
        },
        body: jsonEncode(requestBody),
      );

      // DEBUG: Print raw response
      // print('=== OPENROUTER DEBUG ===');
      // print('Status: ${response.statusCode}');
      // print('Body: ${response.body}');
      // print('========================');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Coba ambil content dengan berbagai cara
        String? content = _extractContent(responseData);

        if (content != null && content.trim().isNotEmpty) {
          return content.trim();
        } else {
          // Jika tetap kosong, coba lagi dengan max_tokens lebih kecil
          print('⚠️ Content kosong, response: $responseData');
          throw Exception(
            'No text in API response. Raw: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}',
          );
        }
      } else {
        String errorBody = response.body;
        try {
          final errJson = jsonDecode(response.body);
          errorBody = errJson['error']?['message'] ?? response.body;
        } catch (_) {}

        throw Exception('API Error ${response.statusCode}: $errorBody');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('No text in API response')) {
        rethrow;
      }
      throw Exception('Error communicating with OpenRouter: $e');
    }
  }

  /// Extract content dari berbagai format response
  String? _extractContent(Map<String, dynamic> responseData) {
    try {
      // Format standar OpenAI/OpenRouter
      if (responseData['choices'] != null &&
          (responseData['choices'] as List).isNotEmpty) {
        final choice = responseData['choices'][0];

        // Path 1: choices[0].message.content
        var content = choice['message']?['content'];
        if (content != null && content.toString().trim().isNotEmpty) {
          return content.toString();
        }

        // Path 2: choices[0].text (beberapa model lama)
        content = choice['text'];
        if (content != null && content.toString().trim().isNotEmpty) {
          return content.toString();
        }
      }

      // Path 3: Beberapa model return langsung di response
      if (responseData['content'] != null) {
        return responseData['content'].toString();
      }

      // Path 4: Format Anthropic-style
      if (responseData['completion'] != null) {
        return responseData['completion'].toString();
      }

      return null;
    } catch (e) {
      print('Error extracting content: $e');
      return null;
    }
  }
}
