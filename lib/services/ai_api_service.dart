import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/api_profile.dart';
import '../models/api_provider.dart';

/// Unified AI API Service that handles all providers.
class AiApiService {
  final ApiProfile profile;
  late final ApiProviderDef _provider;
  late final String _baseUrl;

  AiApiService({required this.profile}) {
    _provider = ApiProviderRegistry.getProvider(profile.provider);
    _baseUrl = profile.provider == 'custom'
        ? (profile.baseUrl ?? '').replaceAll(RegExp(r'/+$'), '')
        : _provider.baseUrl;
  }

  // ═══════════════════════════════════════
  // HEADERS
  // ═══════════════════════════════════════
  Map<String, String> _buildHeaders({bool isJson = true}) {
    final headers = <String, String>{};
    if (isJson) headers['Content-Type'] = 'application/json';

    switch (_provider.authType) {
      case 'bearer':
        headers['Authorization'] = 'Bearer ${profile.apiKey}';
        break;
      case 'x-api-key':
        headers['x-api-key'] = profile.apiKey;
        break;
      case 'query':
        // Key is added as query parameter, not header
        break;
    }

    // Extra headers (e.g., anthropic-version)
    if (_provider.extraHeader != null && _provider.extraHeaderValue != null) {
      headers[_provider.extraHeader!] = _provider.extraHeaderValue!;
    }

    // OpenRouter-specific headers
    if (profile.provider == 'openrouter') {
      headers['HTTP-Referer'] =
          'https://github.com/amblackpearl/saingandolladanciciai';
      headers['X-Title'] = 'Flutter AI Assistant';
    }

    return headers;
  }

  Uri _buildUri(String path, {Map<String, String>? queryParams}) {
    final baseUri = Uri.parse('$_baseUrl$path');
    final params = <String, String>{};

    if (_provider.authType == 'query') {
      params['key'] = profile.apiKey;
    }
    if (queryParams != null) params.addAll(queryParams);

    return baseUri.replace(queryParameters: params.isNotEmpty ? params : null);
  }

  // ═══════════════════════════════════════
  // FETCH AVAILABLE MODELS
  // ═══════════════════════════════════════
  Future<List<Map<String, String>>> fetchAvailableModels() async {
    try {
      final uri = _buildUri(_provider.modelsEndpoint);
      final response = await http.get(uri, headers: _buildHeaders(isJson: false));

      if (response.statusCode == 200) {
        final data = _parseJsonResponse(response.body);
        return _parseModelList(data);
      } else {
        debugPrint('Model fetch error ${response.statusCode}: ${response.body}');
        // Return fallback models for OpenRouter if fetch fails
        if (profile.provider == 'openrouter') {
          return _openRouterFallbackModels;
        }
        throw Exception('Failed to fetch models: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching models: $e');
      if (profile.provider == 'openrouter') {
        return _openRouterFallbackModels;
      }
      rethrow;
    }
  }

  List<Map<String, String>> _parseModelList(dynamic data) {
    switch (_provider.responseFormat) {
      case 'gemini':
        return _parseGeminiModels(data);
      case 'anthropic':
        return _parseAnthropicModels(data);
      default: // 'openai' format (OpenRouter, OpenAI, Groq, Custom)
        return _parseOpenAiModels(data);
    }
  }

  List<Map<String, String>> _parseOpenAiModels(dynamic data) {
    final models = <Map<String, String>>[];
    final List<dynamic> dataList = data['data'] ?? [];

    for (final model in dataList) {
      final id = model['id']?.toString() ?? '';
      if (id.isEmpty) continue;

      // Skip non-chat models for OpenAI
      if (profile.provider == 'openai') {
        if (!id.contains('gpt') &&
            !id.contains('o1') &&
            !id.contains('o3') &&
            !id.contains('o4') &&
            !id.contains('chatgpt')) continue;
        // Skip fine-tune models, embeddings, etc.
        if (id.contains('embedding') ||
            id.contains('tts') ||
            id.contains('whisper') ||
            id.contains('dall-e') ||
            id.contains('davinci') ||
            id.contains('babbage') ||
            id.contains('moderation')) continue;
      }

      // Skip non-chat models for Groq
      if (profile.provider == 'groq') {
        if (id.contains('whisper') || id.contains('guard')) continue;
      }

      final name = id.split('/').last;
      final provider = id.contains('/') ? id.split('/').first : profile.provider;

      // Detect capabilities
      String capabilities = 'text';
      final idLower = id.toLowerCase();
      if (idLower.contains('vision') ||
          idLower.contains('gpt-4o') ||
          idLower.contains('gpt-4-turbo') ||
          idLower.contains('claude-3') ||
          idLower.contains('gemini') ||
          idLower.contains('llava') ||
          (model['architecture']?['modality']?.toString().contains('image') ?? false)) {
        capabilities = 'text,image';
      }

      // Detect category
      String note = '💬 General Chat';
      if (idLower.contains('code') || idLower.contains('coder')) {
        note = '💻 Coding';
      } else if (idLower.contains('r1') ||
          idLower.contains('reasoning') ||
          idLower.contains('o1') ||
          idLower.contains('o3') ||
          idLower.contains('qwq') ||
          idLower.contains('thinking')) {
        note = '🧠 Reasoning';
      } else if (idLower.contains('mini') ||
          idLower.contains('small') ||
          idLower.contains('tiny') ||
          idLower.contains('phi')) {
        note = '🔧 Lightweight';
      }

      // Check pricing for OpenRouter
      String type = 'paid';
      if (profile.provider == 'openrouter') {
        final pricing = model['pricing'];
        if (pricing != null) {
          final prompt = double.tryParse(pricing['prompt']?.toString() ?? '1') ?? 1;
          final completion = double.tryParse(pricing['completion']?.toString() ?? '1') ?? 1;
          if (prompt == 0 && completion == 0) type = 'free';
        }
      }

      models.add({
        'name': id,
        'displayName': name,
        'provider': provider,
        'type': type,
        'note': note,
        'capabilities': capabilities,
      });
    }

    // Sort: free first (for OpenRouter), then alphabetically
    models.sort((a, b) {
      if (a['type'] != b['type']) {
        return a['type'] == 'free' ? -1 : 1;
      }
      return (a['displayName'] ?? '').compareTo(b['displayName'] ?? '');
    });

    return models;
  }

  List<Map<String, String>> _parseGeminiModels(dynamic data) {
    final models = <Map<String, String>>[];
    final List<dynamic> modelList = data['models'] ?? [];

    for (final model in modelList) {
      final name = model['name']?.toString() ?? '';
      if (name.isEmpty) continue;

      // Only include generateContent-capable models
      final methods = (model['supportedGenerationMethods'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      if (!methods.contains('generateContent')) continue;

      // Strip "models/" prefix
      final modelId = name.replaceFirst('models/', '');
      final displayName = model['displayName']?.toString() ?? modelId;

      models.add({
        'name': modelId,
        'displayName': displayName,
        'provider': 'google',
        'type': 'paid',
        'note': '💬 General Chat',
        'capabilities': 'text,image',
      });
    }

    return models;
  }

  List<Map<String, String>> _parseAnthropicModels(dynamic data) {
    final models = <Map<String, String>>[];

    // Anthropic /v1/models returns { data: [...] }
    final List<dynamic> dataList = data['data'] ?? [];

    if (dataList.isEmpty) {
      // Fallback - Anthropic model list endpoint might not be available
      return _anthropicFallbackModels;
    }

    for (final model in dataList) {
      final id = model['id']?.toString() ?? '';
      if (id.isEmpty) continue;

      final displayName = model['display_name']?.toString() ?? id;

      models.add({
        'name': id,
        'displayName': displayName,
        'provider': 'anthropic',
        'type': 'paid',
        'note': '💬 General Chat',
        'capabilities': 'text,image',
      });
    }

    return models;
  }

  // ═══════════════════════════════════════
  // GENERATE RESPONSE
  // ═══════════════════════════════════════
  Future<String> generateResponse({
    String? message,
    List<Map<String, dynamic>>? rawMessages,
    required String model,
    double temperature = 0.7,
    int? maxTokens,
  }) async {
    switch (_provider.responseFormat) {
      case 'gemini':
        return _generateGemini(
          message: message,
          rawMessages: rawMessages,
          model: model,
          temperature: temperature,
          maxTokens: maxTokens,
        );
      case 'anthropic':
        return _generateAnthropic(
          message: message,
          rawMessages: rawMessages,
          model: model,
          temperature: temperature,
          maxTokens: maxTokens,
        );
      default:
        return _generateOpenAi(
          message: message,
          rawMessages: rawMessages,
          model: model,
          temperature: temperature,
          maxTokens: maxTokens,
        );
    }
  }

  // ═══════════════════════════════════════
  // OPENAI-COMPATIBLE (OpenRouter, OpenAI, Groq, Custom)
  // ═══════════════════════════════════════
  Future<String> _generateOpenAi({
    String? message,
    List<Map<String, dynamic>>? rawMessages,
    required String model,
    double temperature = 0.7,
    int? maxTokens,
  }) async {
    final uri = _buildUri(_provider.chatEndpoint);
    final body = {
      'model': model,
      'messages': rawMessages ??
          [
            {'role': 'user', 'content': message ?? ''},
          ],
      'temperature': temperature,
      'max_tokens': maxTokens ?? profile.maxTokens,
      'stream': false,
    };

    try {
      final response = await http.post(
        uri,
        headers: _buildHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = _parseJsonResponse(response.body);
        if (data is Map<String, dynamic>) {
          final content = _extractOpenAiContent(data);
          if (content != null && content.trim().isNotEmpty) {
            return content.trim();
          }
        }
        throw Exception('No text in API response');
      } else {
        String errorMsg = response.body;
        try {
          final errJson = _parseJsonResponse(response.body);
          if (errJson is Map<String, dynamic>) {
            errorMsg = errJson['error']?['message'] ?? errJson['message'] ?? response.body;
          }
        } catch (_) {}
        throw Exception('API Error ${response.statusCode}: $errorMsg');
      }
    } catch (e) {
      if (e.toString().contains('No text in API response')) rethrow;
      throw Exception('Error communicating with ${_provider.displayName}: $e');
    }
  }

  String? _extractOpenAiContent(Map<String, dynamic> data) {
    try {
      if (data['choices'] != null && (data['choices'] as List).isNotEmpty) {
        final choice = data['choices'][0];

        // 1. Standard message content
        var content = choice['message']?['content'];
        if (content != null && content.toString().trim().isNotEmpty) {
          return content.toString();
        }

        // 2. Delta content (streaming chunk format)
        content = choice['delta']?['content'];
        if (content != null && content.toString().trim().isNotEmpty) {
          return content.toString();
        }

        // 3. Reasoning / thinking content (DeepSeek R1 / V3 / reasoning models)
        content = choice['message']?['reasoning_content'] ??
            choice['delta']?['reasoning_content'] ??
            choice['message']?['reasoning'] ??
            choice['message']?['thinking'];
        if (content != null && content.toString().trim().isNotEmpty) {
          return content.toString();
        }

        // 4. Legacy text field
        content = choice['text'];
        if (content != null && content.toString().trim().isNotEmpty) {
          return content.toString();
        }
      }
      if (data['content'] != null) return data['content'].toString();
      if (data['completion'] != null) return data['completion'].toString();
      return null;
    } catch (e) {
      debugPrint('Error extracting OpenAI content: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════
  // ANTHROPIC
  // ═══════════════════════════════════════
  Future<String> _generateAnthropic({
    String? message,
    List<Map<String, dynamic>>? rawMessages,
    required String model,
    double temperature = 0.7,
    int? maxTokens,
  }) async {
    final uri = _buildUri(_provider.chatEndpoint);

    // Anthropic requires separating system messages
    String? systemPrompt;
    final messages = <Map<String, dynamic>>[];

    if (rawMessages != null) {
      for (final msg in rawMessages) {
        if (msg['role'] == 'system') {
          systemPrompt = msg['content'].toString();
        } else {
          messages.add(msg);
        }
      }
    } else {
      messages.add({'role': 'user', 'content': message ?? ''});
    }

    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'max_tokens': maxTokens ?? profile.maxTokens,
      'temperature': temperature,
    };
    if (systemPrompt != null) body['system'] = systemPrompt;

    try {
      final response = await http.post(
        uri,
        headers: _buildHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = _extractAnthropicContent(data);
        if (content != null && content.trim().isNotEmpty) {
          return content.trim();
        }
        throw Exception('No text in API response');
      } else {
        String errorMsg = response.body;
        try {
          final errJson = jsonDecode(response.body);
          errorMsg = errJson['error']?['message'] ?? response.body;
        } catch (_) {}
        throw Exception('API Error ${response.statusCode}: $errorMsg');
      }
    } catch (e) {
      if (e.toString().contains('No text in API response')) rethrow;
      throw Exception('Error communicating with Anthropic: $e');
    }
  }

  String? _extractAnthropicContent(Map<String, dynamic> data) {
    try {
      final content = data['content'];
      if (content is List && content.isNotEmpty) {
        // Concatenate all text blocks
        final buffer = StringBuffer();
        for (final block in content) {
          if (block['type'] == 'text') {
            buffer.write(block['text']);
          }
        }
        final text = buffer.toString();
        if (text.isNotEmpty) return text;
      }
      return null;
    } catch (e) {
      debugPrint('Error extracting Anthropic content: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════
  // GEMINI
  // ═══════════════════════════════════════
  Future<String> _generateGemini({
    String? message,
    List<Map<String, dynamic>>? rawMessages,
    required String model,
    double temperature = 0.7,
    int? maxTokens,
  }) async {
    // Gemini uses a different endpoint pattern
    final endpoint = _provider.chatEndpoint.replaceAll('{model}', model);
    final uri = _buildUri(endpoint);

    // Convert messages to Gemini format
    final contents = <Map<String, dynamic>>[];

    if (rawMessages != null) {
      for (final msg in rawMessages) {
        if (msg['role'] == 'system') continue; // Handle separately

        final role = msg['role'] == 'assistant' ? 'model' : 'user';
        final content = msg['content'];

        if (content is List) {
          // Multi-modal content
          final parts = <Map<String, dynamic>>[];
          for (final part in content) {
            if (part['type'] == 'text') {
              parts.add({'text': part['text']});
            } else if (part['type'] == 'image_url') {
              final url = part['image_url']?['url'] ?? '';
              if (url.startsWith('data:')) {
                final base64Data = url.split(',').last;
                final mimeType = url.split(';').first.split(':').last;
                parts.add({
                  'inline_data': {
                    'mime_type': mimeType,
                    'data': base64Data,
                  },
                });
              }
            }
          }
          contents.add({'role': role, 'parts': parts});
        } else {
          contents.add({
            'role': role,
            'parts': [
              {'text': content.toString()},
            ],
          });
        }
      }
    } else {
      contents.add({
        'role': 'user',
        'parts': [
          {'text': message ?? ''},
        ],
      });
    }

    // Extract system instruction
    String? systemInstruction;
    if (rawMessages != null) {
      for (final msg in rawMessages) {
        if (msg['role'] == 'system') {
          systemInstruction = msg['content'].toString();
          break;
        }
      }
    }

    final body = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxTokens ?? profile.maxTokens,
      },
    };
    if (systemInstruction != null) {
      body['systemInstruction'] = {
        'parts': [
          {'text': systemInstruction},
        ],
      };
    }

    try {
      final response = await http.post(
        uri,
        headers: _buildHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = _extractGeminiContent(data);
        if (content != null && content.trim().isNotEmpty) {
          return content.trim();
        }
        throw Exception('No text in API response');
      } else {
        String errorMsg = response.body;
        try {
          final errJson = jsonDecode(response.body);
          errorMsg = errJson['error']?['message'] ?? response.body;
        } catch (_) {}
        throw Exception('API Error ${response.statusCode}: $errorMsg');
      }
    } catch (e) {
      if (e.toString().contains('No text in API response')) rethrow;
      throw Exception('Error communicating with Gemini: $e');
    }
  }

  String? _extractGeminiContent(Map<String, dynamic> data) {
    try {
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'];
        if (content != null) {
          final parts = content['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            final buffer = StringBuffer();
            for (final part in parts) {
              if (part['text'] != null) {
                buffer.write(part['text']);
              }
            }
            final text = buffer.toString();
            if (text.isNotEmpty) return text;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error extracting Gemini content: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════
  // TEST CONNECTION
  // ═══════════════════════════════════════
  Future<bool> testConnection() async {
    try {
      final models = await fetchAvailableModels();
      return models.isNotEmpty;
    } catch (e) {
      debugPrint('Connection test failed: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════
  // FALLBACK MODEL LISTS
  // ═══════════════════════════════════════
  static final List<Map<String, String>> _openRouterFallbackModels = [
    {'name': 'anthropic/claude-3-haiku', 'displayName': 'claude-3-haiku', 'provider': 'anthropic', 'type': 'free', 'note': '⭐ Recommended', 'capabilities': 'text,image'},
    {'name': 'deepseek/deepseek-chat', 'displayName': 'deepseek-chat', 'provider': 'deepseek', 'type': 'free', 'note': '⭐ Recommended', 'capabilities': 'text'},
    {'name': 'meta-llama/llama-3.1-8b-instruct', 'displayName': 'llama-3.1-8b-instruct', 'provider': 'meta-llama', 'type': 'free', 'note': '⭐ Recommended', 'capabilities': 'text'},
    {'name': 'meta-llama/llama-3.3-70b-instruct', 'displayName': 'llama-3.3-70b-instruct', 'provider': 'meta-llama', 'type': 'free', 'note': '💬 General Chat', 'capabilities': 'text'},
    {'name': 'qwen/qwen-2.5-72b-instruct', 'displayName': 'qwen-2.5-72b-instruct', 'provider': 'qwen', 'type': 'free', 'note': '💬 General Chat', 'capabilities': 'text'},
    {'name': 'deepseek/deepseek-r1', 'displayName': 'deepseek-r1', 'provider': 'deepseek', 'type': 'free', 'note': '🧠 Reasoning', 'capabilities': 'text'},
    {'name': 'qwen/qwen-2.5-coder-32b-instruct', 'displayName': 'qwen-2.5-coder-32b-instruct', 'provider': 'qwen', 'type': 'free', 'note': '💻 Coding', 'capabilities': 'text'},
    {'name': 'microsoft/phi-4', 'displayName': 'phi-4', 'provider': 'microsoft', 'type': 'free', 'note': '🔧 Lightweight', 'capabilities': 'text'},
  ];

  static final List<Map<String, String>> _anthropicFallbackModels = [
    {'name': 'claude-sonnet-4-20250514', 'displayName': 'Claude Sonnet 4', 'provider': 'anthropic', 'type': 'paid', 'note': '⭐ Recommended', 'capabilities': 'text,image'},
    {'name': 'claude-3-5-sonnet-20241022', 'displayName': 'Claude 3.5 Sonnet', 'provider': 'anthropic', 'type': 'paid', 'note': '⭐ Recommended', 'capabilities': 'text,image'},
    {'name': 'claude-3-5-haiku-20241022', 'displayName': 'Claude 3.5 Haiku', 'provider': 'anthropic', 'type': 'paid', 'note': '💬 General Chat', 'capabilities': 'text,image'},
    {'name': 'claude-3-haiku-20240307', 'displayName': 'Claude 3 Haiku', 'provider': 'anthropic', 'type': 'paid', 'note': '🔧 Lightweight', 'capabilities': 'text,image'},
    {'name': 'claude-3-opus-20240229', 'displayName': 'Claude 3 Opus', 'provider': 'anthropic', 'type': 'paid', 'note': '🧠 Reasoning', 'capabilities': 'text,image'},
  ];

  /// Robust JSON response parser for OpenAI-compatible and custom API endpoints.
  /// Handles standard JSON, trailing `data: [DONE]`, SSE streams, and wrapped responses.
  dynamic _parseJsonResponse(String bodyStr) {
    final trimmed = bodyStr.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Response body is empty');
    }

    // 1. Direct try (Fast path for standard valid JSON)
    try {
      return jsonDecode(trimmed);
    } catch (_) {}

    // 2. Clean trailing 'data: [DONE]' or trailing SSE artifacts
    // E.g., {"id":"..."}data: [DONE] or {"id":"..."}\n\ndata: [DONE]
    final cleanedDone = trimmed
        .replaceAll(RegExp(r'data:\s*\[DONE\]\s*$', caseSensitive: false), '')
        .trim();
    if (cleanedDone.isNotEmpty) {
      try {
        return jsonDecode(cleanedDone);
      } catch (_) {}
    }

    // 3. Handle SSE Stream format lines (lines starting with data:)
    if (trimmed.contains('data:')) {
      final lines = trimmed.split('\n');
      Map<String, dynamic>? lastMap;
      final StringBuffer contentBuffer = StringBuffer();
      final StringBuffer reasoningBuffer = StringBuffer();

      for (var line in lines) {
        var l = line.trim();
        if (l.startsWith('data:')) {
          l = l.substring(5).trim();
        }
        if (l.isEmpty || l == '[DONE]') continue;

        try {
          final parsed = jsonDecode(l);
          if (parsed is Map<String, dynamic>) {
            lastMap = parsed;
            if (parsed.containsKey('choices')) {
              final choices = parsed['choices'];
              if (choices is List && choices.isNotEmpty) {
                final choice = choices[0];
                final msg = choice['message'] ?? choice['delta'];
                if (msg != null) {
                  final text = msg['content'] ?? msg['text'];
                  if (text != null) contentBuffer.write(text);
                  final reasoning = msg['reasoning_content'] ??
                      msg['reasoning'] ??
                      msg['thinking'];
                  if (reasoning != null) reasoningBuffer.write(reasoning);
                }
              }
            }
          }
        } catch (_) {}
      }

      final text = contentBuffer.toString();
      final reasoning = reasoningBuffer.toString();
      if (text.isNotEmpty || reasoning.isNotEmpty) {
        final content = text.isNotEmpty ? text : reasoning;
        return {
          'choices': [
            {
              'message': {
                'role': 'assistant',
                'content': content,
                if (reasoning.isNotEmpty) 'reasoning_content': reasoning,
              }
            }
          ]
        };
      } else if (lastMap != null) {
        return lastMap;
      }
    }

    // 4. Try extracting substring between the first '{' and last '}'
    final firstBrace = trimmed.indexOf('{');
    final lastBrace = trimmed.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace > firstBrace) {
      final jsonSub = trimmed.substring(firstBrace, lastBrace + 1);
      try {
        return jsonDecode(jsonSub);
      } catch (_) {}
    }

    // Fallback: throw standard jsonDecode error on bodyStr
    return jsonDecode(bodyStr);
  }
}
