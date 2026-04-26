// File: lib/services/conversation_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';

class ConversationService {
  static const String _keyChatHistory = 'chat_history';
  static const String _keyConversationId = 'conversation_id';
  static const String _keyModelPreference = 'selected_model_key';

  // Simpan riwayat pesan
  static Future<void> saveChatHistory(List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> jsonList = messages
        .map((msg) => jsonEncode(msg.toJson()))
        .toList();
    await prefs.setStringList(_keyChatHistory, jsonList);
  }

  // Ambil riwayat pesan
  static Future<List<ChatMessage>> getChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jsonList = prefs.getStringList(_keyChatHistory);
    if (jsonList == null || jsonList.isEmpty) {
      return [];
    }
    return jsonList
        .map(
          (jsonStr) =>
              ChatMessage.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>),
        )
        .toList();
  }

  // Simpan preferensi model agar tiap session tetap ingat
  static Future<void> saveModelPreference(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyModelPreference, model);
  }

  // Baca preferensi model
  static Future<String?> getModelPreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyModelPreference);
  }

  // Simpan conversation_id (buat baru jika kosong)
  static Future<String> getOrCreateConversationId() async {
    final prefs = await SharedPreferences.getInstance();
    String? conversationId = prefs.getString(_keyConversationId);
    if (conversationId == null || conversationId.isEmpty) {
      conversationId = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString(_keyConversationId, conversationId);
    }
    return conversationId;
  }

  // Dapatkan beberapa turn terbaru (termasuk user dan assistant)
  /// [turns] jumlah turn terbaru yang ingin dikirim (misal 6 untuk 3 round)
  static List<ChatMessage> getRecentTurns(
    List<ChatMessage> messages,
    int turns,
  ) {
    if (messages.length <= turns) return messages;
    return messages.sublist(messages.length - turns);
  }

  // Hapus riwayat (misal new chat)
  static Future<void> clearChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyChatHistory);
    await prefs.remove(_keyConversationId);
  }
}
