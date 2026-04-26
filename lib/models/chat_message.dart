class ChatMessage {
  final String content;
  final String role;
  final DateTime timestamp;
  final String id;
  final String? modelName;
  final bool isFile;
  final String? fileName;
  final bool isImage;
  final String? base64Data;

  ChatMessage({
    required this.content,
    required this.role,
    this.modelName,
    DateTime? timestamp,
    String? id,
    this.isFile = false,
    this.fileName,
    this.isImage = false,
    this.base64Data,
  }) : timestamp = timestamp ?? DateTime.now(),
       id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'role': role,
      'timestamp': timestamp.toIso8601String(),
      'modelName': modelName,
      'isFile': isFile,
      'fileName': fileName,
      'isImage': isImage,
      'base64Data': base64Data,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: json['content'],
      role: json['role'],
      timestamp: DateTime.parse(json['timestamp']),
      modelName: json['modelName'] as String?,
      isFile: json['isFile'] as bool? ?? false,
      fileName: json['fileName'] as String?,
      isImage: json['isImage'] as bool? ?? false,
      base64Data: json['base64Data'] as String?,
    );
  }
}
