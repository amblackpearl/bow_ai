import 'dart:convert';

class ApiProfile {
  final String id;
  String name;
  String provider; // 'openrouter', 'openai', 'gemini', 'anthropic', 'groq', 'custom'
  String apiKey;
  String? baseUrl; // Only for 'custom' provider
  String? selectedModel;
  int maxTokens;
  DateTime createdAt;
  DateTime updatedAt;

  ApiProfile({
    required this.id,
    required this.name,
    required this.provider,
    required this.apiKey,
    this.baseUrl,
    this.selectedModel,
    this.maxTokens = 16000,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Create a new profile with an auto-generated ID
  factory ApiProfile.create({
    required String name,
    required String provider,
    required String apiKey,
    String? baseUrl,
    int maxTokens = 16000,
  }) {
    final now = DateTime.now();
    return ApiProfile(
      id: '${now.millisecondsSinceEpoch}_${now.microsecond}',
      name: name,
      provider: provider,
      apiKey: apiKey,
      baseUrl: baseUrl,
      maxTokens: maxTokens,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'provider': provider,
      'apiKey': apiKey,
      'baseUrl': baseUrl,
      'selectedModel': selectedModel,
      'maxTokens': maxTokens,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ApiProfile.fromJson(Map<String, dynamic> json) {
    return ApiProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      provider: json['provider'] as String,
      apiKey: json['apiKey'] as String,
      baseUrl: json['baseUrl'] as String?,
      selectedModel: json['selectedModel'] as String?,
      maxTokens: json['maxTokens'] as int? ?? 16000,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory ApiProfile.fromJsonString(String jsonStr) {
    return ApiProfile.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
  }

  /// Masked API key for display (e.g., "sk-...3xYz")
  String get maskedKey {
    if (apiKey.length <= 8) return '••••••••';
    return '${apiKey.substring(0, 4)}...${apiKey.substring(apiKey.length - 4)}';
  }

  ApiProfile copyWith({
    String? name,
    String? provider,
    String? apiKey,
    String? baseUrl,
    String? selectedModel,
    int? maxTokens,
  }) {
    return ApiProfile(
      id: id,
      name: name ?? this.name,
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      selectedModel: selectedModel ?? this.selectedModel,
      maxTokens: maxTokens ?? this.maxTokens,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
