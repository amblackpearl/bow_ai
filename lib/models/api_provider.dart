import 'package:flutter/material.dart';

/// Defines a known API provider with its configuration.
class ApiProviderDef {
  final String id;
  final String displayName;
  final String baseUrl;
  final IconData icon;
  final Color color;
  final String modelsEndpoint;
  final String chatEndpoint;
  final String authType; // 'bearer', 'x-api-key', 'query'
  final String responseFormat; // 'openai', 'anthropic', 'gemini'
  final String? extraHeader; // e.g., 'anthropic-version'
  final String? extraHeaderValue;
  final String description;
  final bool requiresBaseUrl;

  const ApiProviderDef({
    required this.id,
    required this.displayName,
    required this.baseUrl,
    required this.icon,
    required this.color,
    required this.modelsEndpoint,
    required this.chatEndpoint,
    required this.authType,
    required this.responseFormat,
    this.extraHeader,
    this.extraHeaderValue,
    required this.description,
    this.requiresBaseUrl = false,
  });
}

/// Static registry of all supported providers.
class ApiProviderRegistry {
  static const List<String> providerIds = [
    'openrouter',
    'openai',
    'gemini',
    'anthropic',
    'groq',
    'qwen',
    'glm',
    'kimi',
    'custom',
  ];

  static final Map<String, ApiProviderDef> providers = {
    'openrouter': const ApiProviderDef(
      id: 'openrouter',
      displayName: 'OpenRouter',
      baseUrl: 'https://openrouter.ai/api/v1',
      icon: Icons.router_rounded,
      color: Color(0xFF6366F1),
      modelsEndpoint: '/models',
      chatEndpoint: '/chat/completions',
      authType: 'bearer',
      responseFormat: 'openai',
      description: 'Access 100+ models via OpenRouter',
    ),
    'openai': const ApiProviderDef(
      id: 'openai',
      displayName: 'OpenAI',
      baseUrl: 'https://api.openai.com/v1',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFF10A37F),
      modelsEndpoint: '/models',
      chatEndpoint: '/chat/completions',
      authType: 'bearer',
      responseFormat: 'openai',
      description: 'GPT-4o, GPT-4, GPT-3.5 & more',
    ),
    'gemini': const ApiProviderDef(
      id: 'gemini',
      displayName: 'Google Gemini',
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      icon: Icons.diamond_rounded,
      color: Color(0xFF4285F4),
      modelsEndpoint: '/models',
      chatEndpoint: '/models/{model}:generateContent',
      authType: 'query',
      responseFormat: 'gemini',
      description: 'Gemini Pro, Flash & Ultra',
    ),
    'anthropic': const ApiProviderDef(
      id: 'anthropic',
      displayName: 'Anthropic',
      baseUrl: 'https://api.anthropic.com/v1',
      icon: Icons.psychology_rounded,
      color: Color(0xFFD97757),
      modelsEndpoint: '/models',
      chatEndpoint: '/messages',
      authType: 'x-api-key',
      responseFormat: 'anthropic',
      extraHeader: 'anthropic-version',
      extraHeaderValue: '2023-06-01',
      description: 'Claude 3.5, Claude 3 & more',
    ),
    'groq': const ApiProviderDef(
      id: 'groq',
      displayName: 'Groq',
      baseUrl: 'https://api.groq.com/openai/v1',
      icon: Icons.bolt_rounded,
      color: Color(0xFFF55036),
      modelsEndpoint: '/models',
      chatEndpoint: '/chat/completions',
      authType: 'bearer',
      responseFormat: 'openai',
      description: 'Ultra-fast inference with LPU',
    ),
    'qwen': const ApiProviderDef(
      id: 'qwen',
      displayName: 'Qwen (Alibaba Cloud)',
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      icon: Icons.cloud_rounded,
      color: Color(0xFF615CED),
      modelsEndpoint: '/models',
      chatEndpoint: '/chat/completions',
      authType: 'bearer',
      responseFormat: 'openai',
      description: 'Qwen Max, Qwen Plus, Qwen Turbo & more',
    ),
    'glm': const ApiProviderDef(
      id: 'glm',
      displayName: 'GLM (Zhipu AI)',
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      icon: Icons.spa_rounded,
      color: Color(0xFF3D5AFE),
      modelsEndpoint: '/models',
      chatEndpoint: '/chat/completions',
      authType: 'bearer',
      responseFormat: 'openai',
      description: 'GLM-4, GLM-4V, GLM-3-Turbo & more',
    ),
    'kimi': const ApiProviderDef(
      id: 'kimi',
      displayName: 'Kimi (Moonshot AI)',
      baseUrl: 'https://api.moonshot.cn/v1',
      icon: Icons.nights_stay_rounded,
      color: Color(0xFF1A1A1A),
      modelsEndpoint: '/models',
      chatEndpoint: '/chat/completions',
      authType: 'bearer',
      responseFormat: 'openai',
      description: 'Moonshot-v1 8k, 32k, 128k context & more',
    ),
    'custom': const ApiProviderDef(
      id: 'custom',
      displayName: 'Custom (OpenAI-Compatible)',
      baseUrl: '',
      icon: Icons.tune_rounded,
      color: Color(0xFF8B5CF6),
      modelsEndpoint: '/models',
      chatEndpoint: '/chat/completions',
      authType: 'bearer',
      responseFormat: 'openai',
      description: 'Ollama, LM Studio, Together AI, etc.',
      requiresBaseUrl: true,
    ),
  };

  static ApiProviderDef getProvider(String id) {
    return providers[id] ?? providers['openrouter']!;
  }

  static List<ApiProviderDef> get allProviders =>
      providerIds.map((id) => providers[id]!).toList();
}
