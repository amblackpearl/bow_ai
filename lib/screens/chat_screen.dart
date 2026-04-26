// File: lib/screens/chat_screen.dart
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:iconly/iconly.dart';
import 'package:file_selector/file_selector.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/chat_message.dart';
import '../services/openrouter_service.dart';
import '../services/conversation_service.dart';
import '../services/document_parser_service.dart';
import '../services/theme_service.dart';
import '../widgets/chat_message_widget.dart';

// ═══════════════════════════════════════════════════
// DESIGN SYSTEM
// ═══════════════════════════════════════════════════
class _Design {
  final BuildContext context;
  const _Design(this.context);

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  Color get primary => Theme.of(context).colorScheme.primary;
  Color get primarySoft => Theme.of(context).colorScheme.secondary;
  Color get secondary => Theme.of(context).colorScheme.secondary;

  Color get surface => Theme.of(context).colorScheme.surface;
  Color get background => Theme.of(context).scaffoldBackgroundColor;
  Color get backgroundEnd =>
      isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9);

  Color get textPrimary => Theme.of(context).colorScheme.onSurface;
  Color get textSecondary =>
      isDark ? Colors.grey[400]! : const Color(0xFF64748B);
  Color get textTertiary =>
      isDark ? Colors.grey[600]! : const Color(0xFF94A3B8);

  Color get border => Theme.of(context).colorScheme.outlineVariant;
  Color get inputBg =>
      isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF1F5F9);

  Color get error => Theme.of(context).colorScheme.error;
  Color get errorDark => Theme.of(context).colorScheme.error;
  Color get success => const Color(0xFF10B981);
  Color get dotLight => Theme.of(context).colorScheme.primaryContainer;

  LinearGradient get primaryGradient => LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  LinearGradient get bgGradient => LinearGradient(
    colors: [background, backgroundEnd],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  LinearGradient get drawerGradient => LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BorderRadius get radiusSm => BorderRadius.circular(8);
  static BorderRadius get radiusMd => BorderRadius.circular(12);
  static BorderRadius get radiusLg => BorderRadius.circular(16);
  static BorderRadius get radiusXl => BorderRadius.circular(24);
  static BorderRadius get radiusInput => BorderRadius.circular(26);

  static BoxShadow get shadowSm => BoxShadow(
    color: Colors.black.withOpacity(0.04),
    blurRadius: 6,
    offset: const Offset(0, 1),
  );

  static BoxShadow get shadowMd => BoxShadow(
    color: Colors.black.withOpacity(0.06),
    blurRadius: 12,
    offset: const Offset(0, 3),
  );

  static BoxShadow get shadowLg => BoxShadow(
    color: Colors.black.withOpacity(0.08),
    blurRadius: 20,
    offset: const Offset(0, 4),
  );

  BoxShadow get shadowPrimary => BoxShadow(
    color: primary.withOpacity(0.3),
    blurRadius: 14,
    offset: const Offset(0, 3),
  );

  BoxShadow get shadowError => BoxShadow(
    color: error.withOpacity(0.3),
    blurRadius: 14,
    offset: const Offset(0, 3),
  );
}

class ChatScreen extends StatefulWidget {
  final ThemeService? themeService;
  const ChatScreen({super.key, this.themeService});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _pulseController;
  late AnimationController _dotsController;
  late AnimationController _listeningController;

  final OpenRouterService _openRouterService = OpenRouterService(
    apiKey: 'api key',
  );

  // ── State ──
  int? _editingMessageIndex;
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _showScrollFab = false;
  String _currentConversationId = '';
  List<Map<String, dynamic>> _chatHistoryList = [];

  // ── File & Voice State ──
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String? _selectedFilePath;
  String? _selectedFileName;
  String? _selectedFileContent;
  String? _selectedFileBase64;
  bool _selectedFileIsImage = false;

  // ── Request Guard ──
  int _requestId = 0;
  String? _stoppedUserContent;

  static const int _recentTurns = 6;
  static const String _historyKey = 'bowai_history_list';

  // ── Models ──
  // Capabilities legend:
  //   'text'       → text-only input (TXT, PDF, DOCX, PPTX via text extraction)
  //   'text,image' → text + image input (JPG, PNG, GIF, WEBP via base64)
  final List<Map<String, String>> _models = [
    {
      'name': 'anthropic/claude-3-haiku',
      'type': 'free',
      'note': '⭐ Recommended',
      'capabilities': 'text,image',
    },
    {
      'name': 'deepseek/deepseek-chat',
      'type': 'free',
      'note': '⭐ Recommended',
      'capabilities': 'text',
    },
    {
      'name': 'meta-llama/llama-3.1-8b-instruct',
      'type': 'free',
      'note': '⭐ Recommended',
      'capabilities': 'text',
    },
    {
      'name': 'meta-llama/llama-3.3-70b-instruct',
      'type': 'free',
      'note': '💬 Chat Umum',
      'capabilities': 'text',
    },
    {
      'name': 'meta-llama/llama-3.1-70b-instruct',
      'type': 'free',
      'note': '💬 Chat Umum',
      'capabilities': 'text',
    },
    {
      'name': 'qwen/qwen-2.5-72b-instruct',
      'type': 'free',
      'note': '💬 Chat Umum',
      'capabilities': 'text',
    },
    {
      'name': 'qwen/qwen-2.5-7b-instruct',
      'type': 'free',
      'note': '💬 Chat Umum',
      'capabilities': 'text',
    },
    {
      'name': 'mistralai/mistral-small-24b-instruct-2501',
      'type': 'free',
      'note': '💬 Chat Umum',
      'capabilities': 'text',
    },
    {
      'name': 'nvidia/llama-3.1-nemotron-70b-instruct',
      'type': 'free',
      'note': '💬 Chat Umum',
      'capabilities': 'text',
    },
    {
      'name': 'qwen/qwen-2.5-coder-32b-instruct',
      'type': 'free',
      'note': '💻 Coding',
      'capabilities': 'text',
    },
    {
      'name': 'google/gemma-2-27b-it',
      'type': 'free',
      'note': '💻 Coding',
      'capabilities': 'text',
    },
    {
      'name': 'deepseek/deepseek-r1',
      'type': 'free',
      'note': '🧠 Reasoning',
      'capabilities': 'text',
    },
    {
      'name': 'deepseek/deepseek-r1-distill-llama-70b',
      'type': 'free',
      'note': '🧠 Reasoning',
      'capabilities': 'text',
    },
    {
      'name': 'deepseek/deepseek-r1-distill-qwen-32b',
      'type': 'free',
      'note': '🧠 Reasoning',
      'capabilities': 'text',
    },
    {
      'name': 'deepseek/deepseek-r1-0528',
      'type': 'free',
      'note': '🧠 Reasoning',
      'capabilities': 'text',
    },
    {
      'name': 'z-ai/glm-4.5-air',
      'type': 'free',
      'note': '🧠 Reasoning',
      'capabilities': 'text',
    },
    {
      'name': 'qwen/qwq-32b',
      'type': 'free',
      'note': '🧠 Reasoning',
      'capabilities': 'text',
    },
    {
      'name': 'microsoft/phi-4',
      'type': 'free',
      'note': '🔧 Ringan',
      'capabilities': 'text',
    },
    {
      'name': 'arcee-ai/trinity-mini',
      'type': 'free',
      'note': '🔧 Ringan',
      'capabilities': 'text',
    },
    {
      'name': 'nousresearch/hermes-3-llama-3.1-405b',
      'type': 'free',
      'note': '🧪 Eksperimental',
      'capabilities': 'text',
    },
    {
      'name': 'rekaai/reka-flash-3',
      'type': 'free',
      'note': '🧪 Eksperimental',
      'capabilities': 'text',
    },
    {
      'name': 'inflection/inflection-3-pi',
      'type': 'free',
      'note': '🧪 Eksperimental',
      'capabilities': 'text',
    },
  ];

  String _selectedModel = 'anthropic/claude-3-haiku';
  String get _shortModel => _selectedModel.split('/').last;

  /// Get capabilities of the currently selected model
  String get _selectedModelCapabilities {
    final model = _models.firstWhere(
      (m) => m['name'] == _selectedModel,
      orElse: () => {'capabilities': 'text'},
    );
    return model['capabilities'] ?? 'text';
  }

  /// Check if the selected model supports image input
  bool get _modelSupportsImages => _selectedModelCapabilities.contains('image');

  // ═══════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════
  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _listeningController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();

    _scrollController.addListener(_onScroll);
    _currentConversationId = DateTime.now().millisecondsSinceEpoch.toString();

    _initSpeechToText();
    _initLoad();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dotsController.dispose();
    _listeningController.dispose();
    _scrollController.removeListener(_onScroll);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    if (_isListening) {
      _speechToText.stop();
    }
    super.dispose();
  }

  // ═══════════════════════════════════════
  // PERSISTENCE
  // ═══════════════════════════════════════
  Future<void> _initSpeechToText() async {
    try {
      _speechAvailable = await _speechToText.initialize(
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');
          if (mounted) setState(() => _isListening = false);
        },
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' ||
              status == 'notListening' ||
              status == 'inactive') {
            if (mounted && _isListening) {
              setState(() => _isListening = false);
            }
          }
        },
      );
      debugPrint('Speech to text available: $_speechAvailable');
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Failed to initialize speech: $e');
      _speechAvailable = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _initLoad() async {
    try {
      final m = await ConversationService.getModelPreference();
      if (m != null && _models.any((x) => x['name'] == m)) {
        _selectedModel = m;
      }
    } catch (e) {
      debugPrint('Error loading model preference: $e');
    }
    await _loadHistoryList();
    if (_chatHistoryList.isNotEmpty) {
      await _loadConvMsgs(_chatHistoryList.first['id'] as String);
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadHistoryList() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_historyKey);
      if (s != null) {
        _chatHistoryList = (jsonDecode(s) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Error loading history list: $e');
      _chatHistoryList = [];
    }
  }

  Future<void> _saveHistoryList() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_historyKey, jsonEncode(_chatHistoryList));
    } catch (e) {
      debugPrint('Error saving history list: $e');
    }
  }

  Future<void> _persistChat() async {
    if (_messages.isEmpty) return;
    try {
      final title = _messages.first.content.length > 45
          ? '${_messages.first.content.substring(0, 45)}...'
          : _messages.first.content;
      final now = DateTime.now().toIso8601String();
      final i = _chatHistoryList.indexWhere(
        (c) => c['id'] == _currentConversationId,
      );
      if (i >= 0) {
        _chatHistoryList[i]['title'] = title;
        _chatHistoryList[i]['updatedAt'] = now;
      } else {
        _chatHistoryList.insert(0, {
          'id': _currentConversationId,
          'title': title,
          'updatedAt': now,
        });
      }
      await _saveHistoryList();
      final p = await SharedPreferences.getInstance();
      await p.setString(
        'conv_$_currentConversationId',
        jsonEncode(
          _messages.map((m) => {'content': m.content, 'role': m.role}).toList(),
        ),
      );
    } catch (e) {
      debugPrint('Error persisting chat: $e');
    }
  }

  Future<void> _loadConvMsgs(String id) async {
    _currentConversationId = id;
    _stoppedUserContent = null;
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString('conv_$id');
      if (s != null) {
        final list = jsonDecode(s) as List;
        _messages.clear();
        _messages.addAll(
          list.map((j) => ChatMessage(content: j['content'], role: j['role'])),
        );
      } else {
        _messages.clear();
      }
    } catch (e) {
      debugPrint('Error loading conversation messages: $e');
      _messages.clear();
    }
  }

  Future<void> _switchConv(String id) async {
    await _persistChat();
    await _loadConvMsgs(id);
    if (mounted) {
      setState(() {});
      Navigator.pop(context);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  Future<void> _deleteConv(String id) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove('conv_$id');
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
    }
    if (mounted) {
      setState(() => _chatHistoryList.removeWhere((c) => c['id'] == id));
    }
    await _saveHistoryList();
    if (id == _currentConversationId) {
      Navigator.pop(context);
      _newChat();
    }
  }

  Future<void> _renameConv(String id, String oldTitle) async {
    final c = TextEditingController(text: oldTitle);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: _Design.radiusLg),
        title: Text(
          'Rename Chat',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _Design(context).textPrimary,
          ),
        ),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(fontSize: 15, color: _Design(context).textPrimary),
          decoration: InputDecoration(
            hintText: 'Nama chat...',
            hintStyle: TextStyle(color: _Design(context).textTertiary),
            filled: true,
            fillColor: _Design(context).inputBg,
            border: OutlineInputBorder(
              borderRadius: _Design.radiusMd,
              borderSide: BorderSide(color: _Design(context).border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: _Design.radiusMd,
              borderSide: BorderSide(color: _Design(context).border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: _Design.radiusMd,
              borderSide: BorderSide(
                color: _Design(context).primary,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: TextStyle(color: _Design(context).textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              final v = c.text.trim();
              Navigator.pop(ctx, v.isNotEmpty ? v : null);
            },
            style: TextButton.styleFrom(
              foregroundColor: _Design(context).primary,
            ),
            child: const Text(
              'Simpan',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final i = _chatHistoryList.indexWhere((c) => c['id'] == id);
      if (i >= 0) {
        if (mounted) setState(() => _chatHistoryList[i]['title'] = result);
        await _saveHistoryList();
      }
    }
    c.dispose();
  }

  // ═══════════════════════════════════════
  // NEW CHAT - FIXED
  // ═══════════════════════════════════════
  void _newChat() {
    _persistChat(); // Don't await - let it run in background
    if (mounted) {
      setState(() {
        _currentConversationId = DateTime.now().millisecondsSinceEpoch
            .toString();
        _messages.clear();
        _editingMessageIndex = null;
        _isLoading = false;
        _stoppedUserContent = null;
        _clearFileSelection();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat baru dimulai!'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
    }
  }

  // ═══════════════════════════════════════
  // FILE HANDLING
  // ═══════════════════════════════════════
  void _clearFileSelection() {
    _selectedFilePath = null;
    _selectedFileName = null;
    _selectedFileContent = null;
    _selectedFileBase64 = null;
    _selectedFileIsImage = false;
  }

  Future<void> _pickFile() async {
    if (_isLoading) return;

    final XTypeGroup typeGroup = XTypeGroup(
      label: 'All Supported Files',
      extensions: [
        // Text & Data
        'txt', 'md', 'mdx', 'csv', 'tsv', 'json', 'xml', 'yaml', 'yml',
        'toml', 'ini', 'cfg', 'conf', 'log', 'rst', 'adoc',

        // Web Frontend
        'html', 'htm', 'css', 'scss', 'less', 'js', 'jsx', 'ts', 'tsx',
        'vue', 'svelte',

        // Backend & Systems
        'dart', 'py', 'java', 'c', 'cpp', 'cc', 'cxx', 'h', 'hpp',
        'cs', 'fs', 'go', 'rs', 'rb', 'php', 'swift', 'kt', 'kts',
        'scala', 'ex', 'exs', 'erl', 'clj', 'lua', 'r', 'pl',

        // Scripts & Configs
        'sh', 'bash', 'zsh', 'bat', 'cmd', 'ps1', 'sql', 'env',
        'plist', 'gradle', 'properties',

        // Office & PDF (Note: Binary files)
        'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',

        // Images (Note: Binary files)
        'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp',
      ],
    );

    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file != null) {
      try {
        final ext = file.path.split('.').last.toLowerCase();
        final isImage = [
          'png',
          'jpg',
          'jpeg',
          'webp',
          'gif',
          'bmp',
        ].contains(ext);

        String? base64Str;
        String content = '';

        if (isImage) {
          if (!_modelSupportsImages) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Model yang dipilih tidak mendukung input gambar.',
                  ),
                  backgroundColor: _Design(context).error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            return;
          }
          // Menampilkan loading indikator selagi encode base64
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Memproses gambar...'),
                duration: Duration(milliseconds: 500),
              ),
            );
          }
          final bytes = await file.readAsBytes();
          base64Str = base64Encode(bytes);
          content = '[Image Attached: ${file.name}]';
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Membaca file...'),
                duration: Duration(milliseconds: 500),
              ),
            );
          }
          content = await _readFileContent(file);
        }

        final String truncatedContent = content.length > 50000
            ? '${content.substring(0, 50000)}\n\n... [File truncated due to size - showing first 50,000 characters]'
            : content;

        if (mounted) {
          setState(() {
            _selectedFilePath = file.path;
            _selectedFileName = file.name;
            _selectedFileContent = truncatedContent;
            _selectedFileBase64 = base64Str;
            _selectedFileIsImage = isImage;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'File attached: ${file.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: _Design(context).success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error reading file: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to read file: ${e.toString()}'),
              duration: const Duration(seconds: 3),
              backgroundColor: _Design(context).error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }
  }

  Future<String> _readFileContent(XFile file) async {
    try {
      final ext = file.path.split('.').last.toLowerCase();
      if (['pdf', 'docx', 'pptx', 'xlsx'].contains(ext)) {
        return await DocumentParserService.parseDocument(File(file.path));
      }
      return await file.readAsString();
    } catch (e) {
      debugPrint('Read error: $e');
      return '[Binary file - content cannot be displayed as text]\nFile: ${file.name}\nSize: ${await file.length()} bytes';
    }
  }

  // ═══════════════════════════════════════
  // API CALL - FIXED (Proper conversation context)
  // ═══════════════════════════════════════
  Future<void> _doApiCall(int rid) async {
    try {
      final recent = ConversationService.getRecentTurns(
        _messages,
        _recentTurns,
      );

      // Build valid conversation turns
      final validTurns = <ChatMessage>[];
      for (int i = 0; i < recent.length; i++) {
        if (recent[i].role == 'user') {
          // Include user message if it's the last one or followed by assistant
          if (i == recent.length - 1 ||
              (i + 1 < recent.length && recent[i + 1].role == 'assistant')) {
            validTurns.add(recent[i]);
          }
        } else {
          validTurns.add(recent[i]);
        }
      }

      final apiMessages = validTurns.map((m) {
        if (m.isImage && m.base64Data != null) {
          return {
            'role': m.role,
            'content': [
              {'type': 'text', 'text': m.content},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,${m.base64Data}'},
              },
            ],
          };
        } else {
          return {'role': m.role, 'content': m.content};
        }
      }).toList();

      debugPrint('Sending API call with ${validTurns.length} turns');

      final response = await _openRouterService.generateResponse(
        rawMessages: apiMessages,
        model: _selectedModel,
      );

      if (rid != _requestId) return;

      final safe = response.trim();
      if (safe.isEmpty) throw Exception('Received empty response from BowAI');
      if (rid != _requestId) return;

      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              content: safe,
              role: 'assistant',
              modelName: _shortModel,
            ),
          );
          _isLoading = false;
        });
      }
      await _persistChat();
      _scrollToBottom();
    } catch (e) {
      debugPrint('[Chat] API Error: $e');
      if (rid != _requestId) return;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _messages.add(
            ChatMessage(
              content: '⚠️ Error: ${e.toString()}',
              role: 'assistant',
              modelName: _shortModel,
            ),
          );
        });
      }
      await _persistChat();
      _scrollToBottom();
    }
  }

  // ═══════════════════════════════════════
  // SEND FILE MESSAGE - FIXED
  // ═══════════════════════════════════════
  Future<void> _sendFileMessage() async {
    if (_selectedFileContent == null || _selectedFileName == null) return;
    if (_isLoading || _selectedModel.isEmpty) return;

    final userText = _controller.text.trim();
    final fileName = _selectedFileName!;
    final fileContent = _selectedFileContent!;
    final isImage = _selectedFileIsImage;
    final base64Str = _selectedFileBase64;

    String combinedContent = '';
    if (isImage) {
      combinedContent = '🖼️ **Image:** $fileName\n\n';
      if (userText.isNotEmpty) {
        combinedContent += userText;
      } else {
        combinedContent += 'Please describe this image.';
      }
    } else {
      combinedContent = '📎 **File:** $fileName\n\n```\n$fileContent\n```\n\n';
      if (userText.isNotEmpty) {
        combinedContent += userText;
      } else {
        combinedContent += 'Please analyze this file.';
      }
    }

    final rid = ++_requestId;

    if (mounted) {
      setState(() {
        _messages.add(
          ChatMessage(
            content: combinedContent,
            role: 'user',
            modelName: _shortModel,
            isFile: !isImage,
            fileName: fileName,
            isImage: isImage,
            base64Data: base64Str,
          ),
        );
        _isLoading = true;
        _controller.clear();
        _clearFileSelection();
      });
    }
    _scrollToBottom();
    await _persistChat();

    await _doApiCall(rid);
  }

  // ═══════════════════════════════════════
  // SEND - FIXED (Uses _doApiCall)
  // ═══════════════════════════════════════
  void _send() async {
    // Stop listening if active
    if (_isListening) {
      _stopListening();
    }

    // If a file is attached, use file message handler
    if (_selectedFileContent != null) {
      await _sendFileMessage();
      return;
    }

    final text = _controller.text.trim();

    // Auto-retry when field is empty but there's a stopped message
    if (text.isEmpty) {
      if (_stoppedUserContent != null && !_isLoading) {
        _retryStoppedMessage();
      }
      return;
    }

    if (_isLoading || _selectedModel.isEmpty) return;

    final rid = ++_requestId;
    final isResend =
        _stoppedUserContent == text &&
        _messages.isNotEmpty &&
        _messages.last.role == 'user' &&
        _messages.last.content == text;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _stoppedUserContent = null;
        if (_editingMessageIndex != null) {
          final idx = _editingMessageIndex!;
          _messages[idx] = ChatMessage(content: text, role: 'user');
          if (idx + 1 < _messages.length) {
            _messages.removeRange(idx + 1, _messages.length);
          }
          _editingMessageIndex = null;
        } else if (!isResend) {
          _messages.add(
            ChatMessage(content: text, role: 'user', modelName: _shortModel),
          );
        }
        _controller.clear();
      });
    }
    _scrollToBottom();
    await _persistChat();

    // Use proper API call with conversation context
    await _doApiCall(rid);
  }

  // ═══════════════════════════════════════
  // RETRY - FIXED (Uses _doApiCall)
  // ═══════════════════════════════════════
  void _doRetry(int index) {
    int keepIndex = index;
    if (_messages[index].role == 'assistant') {
      keepIndex = index - 1;
    }
    if (keepIndex < 0) return;

    final before = _messages.sublist(0, keepIndex + 1);

    if (mounted) {
      setState(() {
        _messages.clear();
        _messages.addAll(before);
        _stoppedUserContent = null;
        _isLoading = true;
        _requestId++;
      });
    }
    _scrollToBottom();
    _persistChat();

    final rid = _requestId;
    _doApiCall(rid);
  }

  // ═══════════════════════════════════════
  // STOP
  // ═══════════════════════════════════════
  void _stop() {
    if (_isListening) {
      _stopListening();
    }

    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].role == 'user') {
        _stoppedUserContent = _messages[i].content;
        break;
      }
    }
    _requestId++;
    if (mounted) setState(() => _isLoading = false);
  }

  void _retryStoppedMessage() {
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].role == 'user' &&
          _messages[i].content == _stoppedUserContent) {
        _doRetry(i);
        return;
      }
    }
  }

  // ═══════════════════════════════════════
  // VOICE INPUT
  // ═══════════════════════════════════════
  Future<void> _toggleListening() async {
    if (_isLoading) return;

    if (_isListening) {
      await _speechToText.stop();
      if (mounted) setState(() => _isListening = false);
    } else {
      // Check if speech is available, try to initialize if not
      if (!_speechAvailable) {
        try {
          _speechAvailable = await _speechToText.initialize(
            onError: (error) {
              debugPrint('Speech error: ${error.errorMsg}');
              if (mounted) setState(() => _isListening = false);
            },
            onStatus: (status) {
              if (status == 'done' ||
                  status == 'notListening' ||
                  status == 'inactive') {
                if (mounted && _isListening) {
                  setState(() => _isListening = false);
                }
              }
            },
          );
        } catch (e) {
          debugPrint('Error initializing speech: $e');
          _speechAvailable = false;
        }
      }

      if (!_speechAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.mic_off, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Speech recognition tidak tersedia di perangkat ini'),
                ],
              ),
              duration: Duration(seconds: 3),
              backgroundColor: _Design(context).error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
          );
        }
        return;
      }

      // Check if Indonesian locale is available, fallback to default
      String localeId = 'id_ID';
      try {
        final locales = await _speechToText.locales();
        if (!locales.any((l) => l.localeId == localeId)) {
          if (!locales.any((l) => l.localeId.startsWith('id'))) {
            localeId = ''; // Use system default
          } else {
            localeId = locales
                .firstWhere((l) => l.localeId.startsWith('id'))
                .localeId;
          }
        }
      } catch (e) {
        debugPrint('Error getting locales: $e');
        localeId = '';
      }

      if (mounted) setState(() => _isListening = true);

      try {
        await _speechToText.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _controller.text = result.recognizedWords;
                _controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: _controller.text.length),
                );
              });
            }
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          listenMode: stt.ListenMode.dictation,
          localeId: localeId,
          cancelOnError: true,
        );
      } catch (e) {
        debugPrint('Error starting speech recognition: $e');
        if (mounted) {
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memulai speech recognition: $e'),
              duration: const Duration(seconds: 2),
              backgroundColor: _Design(context).error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _stopListening() {
    if (_isListening) {
      _speechToText.stop();
      if (mounted) setState(() => _isListening = false);
    }
  }

  // ═══════════════════════════════════════
  // MESSAGE ACTIONS
  // ═══════════════════════════════════════
  void _handleEdit(int index) {
    if (_messages[index].role != 'user') return;
    if (mounted) {
      setState(() {
        _editingMessageIndex = index;
        _stoppedUserContent = null;
        _controller.text = _messages[index].content;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      });
    }
    FocusScope.of(context).requestFocus(_focusNode);
  }

  void _cancelEdit() {
    if (mounted) {
      setState(() {
        _editingMessageIndex = null;
        _controller.clear();
        _stoppedUserContent = null;
      });
    }
    _focusNode.unfocus();
  }

  void _handleDelete(int index) {
    final deleted = _messages[index];
    if (mounted) setState(() => _messages.removeAt(index));
    if (deleted.content == _stoppedUserContent) _stoppedUserContent = null;
    _persistChat();
  }

  void _handleCopy(String c) {
    Clipboard.setData(ClipboardData(text: c));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Disalin ke clipboard!'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
    );
  }

  void _handleShare(String c) => Share.share(c);
  void _handleRetry(int index) => _doRetry(index);

  // ═══════════════════════════════════════
  // SCROLL
  // ═══════════════════════════════════════
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final show =
        _scrollController.position.maxScrollExtent - _scrollController.offset >
        120;
    if (show != _showScrollFab) {
      if (mounted) setState(() => _showScrollFab = show);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _saveModelPref() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('selected_model_key', _selectedModel);
    } catch (e) {
      debugPrint('Error saving model preference: $e');
    }
  }

  // ═══════════════════════════════════════
  // UI COMPONENTS
  // ═══════════════════════════════════════
  Widget _buildWaveBars() {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (i) {
            final delay = i * 0.15;
            final t = (_dotsController.value + delay) % 1.0;
            final curve = sin(t * pi * 2) * 0.5 + 0.5;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 3,
              height: 4.0 + curve * 14.0,
              decoration: BoxDecoration(
                color: Color.lerp(
                  _Design(context).dotLight,
                  _Design(context).primary,
                  curve,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildListeningIndicator() {
    return AnimatedBuilder(
      animation: _listeningController,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final t = (_listeningController.value + delay) % 1.0;
            final scale = 0.5 + sin(t * pi * 2) * 0.5;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8 * scale + 4,
              decoration: BoxDecoration(
                color: Color.lerp(
                  _Design(context).error.withOpacity(0.3),
                  _Design(context).error,
                  scale,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildThinkingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 4, right: 60, bottom: 8, top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _Design(context).surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: _Design(context).border),
          boxShadow: [_Design.shadowSm],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildWaveBars(),
            const SizedBox(width: 12),
            Text(
              _shortModel,
              style: TextStyle(
                fontSize: 11,
                color: _Design(context).textTertiary,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileChip() {
    if (_selectedFileName == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _Design(context).primary.withOpacity(0.05),
        borderRadius: _Design.radiusMd,
        border: Border.all(color: _Design(context).primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _Design(context).primary.withOpacity(0.1),
              borderRadius: _Design.radiusSm,
            ),
            child: Icon(
              Icons.description_rounded,
              color: _Design(context).primary,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedFileName!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _Design(context).primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Tap send to analyze',
                  style: TextStyle(
                    fontSize: 11,
                    color: _Design(context).textTertiary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              if (mounted) setState(() => _clearFileSelection());
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _Design(context).error.withOpacity(0.08),
                borderRadius: _Design.radiusSm,
              ),
              child: Icon(
                Icons.close_rounded,
                color: _Design(context).error,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListeningBanner() {
    if (!_isListening) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _Design(context).error.withOpacity(0.05),
        borderRadius: _Design.radiusMd,
        border: Border.all(color: _Design(context).error.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          _buildListeningIndicator(),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _controller.text.isEmpty
                  ? 'Listening... speak now'
                  : _controller.text,
              style: TextStyle(
                fontSize: 13,
                color: _controller.text.isEmpty
                    ? _Design(context).error
                    : _Design(context).textPrimary,
                fontWeight: _controller.text.isEmpty
                    ? FontWeight.w500
                    : FontWeight.w400,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: _stopListening,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _Design(context).error,
                borderRadius: _Design.radiusSm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stop_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Stop',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final hasText = _controller.text.trim().isNotEmpty;
    final hasFile = _selectedFileContent != null;
    final loading = _isLoading;
    final isEditing = _editingMessageIndex != null;
    final canSend = hasText || hasFile || isEditing;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      decoration: BoxDecoration(
        color: _Design(context).surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isEditing)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _Design(context).primary.withOpacity(0.05),
                borderRadius: _Design.radiusMd,
                border: Border.all(
                  color: _Design(context).primary.withOpacity(0.15),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_rounded,
                    color: _Design(context).primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mengedit pesan...',
                      style: TextStyle(
                        fontSize: 13,
                        color: _Design(context).primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _cancelEdit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _Design(context).error.withOpacity(0.08),
                        borderRadius: _Design.radiusSm,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.close,
                            color: _Design(context).error,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Batal',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _Design(context).error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _buildFileChip(),
          _buildListeningBanner(),
          Container(
            decoration: BoxDecoration(
              color: _Design(context).inputBg,
              borderRadius: _Design.radiusInput,
              border: Border.all(
                color: _isListening
                    ? _Design(context).error.withOpacity(0.5)
                    : isEditing
                    ? _Design(context).primary.withOpacity(0.3)
                    : hasFile
                    ? _Design(context).success.withOpacity(0.5)
                    : _Design(context).border,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 4, bottom: 6),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _isLoading ? null : _pickFile,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: hasFile
                                  ? _Design(context).success.withOpacity(0.1)
                                  : _Design(context).inputBg,
                              borderRadius: BorderRadius.circular(19),
                            ),
                            child: Icon(
                              Icons.attach_file_rounded,
                              color: hasFile
                                  ? _Design(context).success
                                  : _Design(context).textSecondary,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 4, bottom: 6),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _isLoading ? null : _toggleListening,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _isListening
                                  ? _Design(context).error.withOpacity(0.1)
                                  : _Design(context).inputBg,
                              borderRadius: BorderRadius.circular(19),
                            ),
                            child: _isListening
                                ? AnimatedBuilder(
                                    animation: _listeningController,
                                    builder: (context, _) {
                                      return Icon(
                                        Icons.mic_rounded,
                                        color: Color.lerp(
                                          _Design(context).error,
                                          Colors.redAccent,
                                          _listeningController.value,
                                        ),
                                        size: 20,
                                      );
                                    },
                                  )
                                : Icon(
                                    Icons.mic_none_rounded,
                                    color: _speechAvailable
                                        ? _Design(context).textSecondary
                                        : _Design(context).textTertiary,
                                    size: 20,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: 6,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) {
                      if (mounted) setState(() {});
                    },
                    onSubmitted: (_) => loading ? _stop() : _send(),
                    decoration: InputDecoration(
                      hintText: _isListening
                          ? 'Listening...'
                          : hasFile
                          ? 'Add a message about the file (optional)...'
                          : isEditing
                          ? 'Edit pesan...'
                          : 'Tanya sesuatu...',
                      hintStyle: TextStyle(
                        color: _isListening
                            ? _Design(context).error.withOpacity(0.7)
                            : _Design(context).textTertiary,
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 13,
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 15,
                      color: _Design(context).textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: isEditing
                          ? _Design(context).primaryGradient
                          : loading
                          ? LinearGradient(
                              colors: [
                                _Design(context).error,
                                _Design(context).errorDark,
                              ],
                            )
                          : canSend
                          ? _Design(context).primaryGradient
                          : null,
                      color: (!canSend && !loading)
                          ? _Design(context).border
                          : null,
                      shape: BoxShape.circle,
                      boxShadow: (canSend || loading)
                          ? [
                              loading && !isEditing
                                  ? _Design(context).shadowError
                                  : _Design(context).shadowPrimary,
                            ]
                          : [],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(21),
                        onTap: loading ? _stop : (canSend ? _send : null),
                        child: Icon(
                          isEditing
                              ? Icons.check_rounded
                              : loading
                              ? Icons.stop_rounded
                              : Icons.arrow_upward_rounded,
                          color: (canSend || loading)
                              ? Colors.white
                              : _Design(context).textTertiary,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _relTime(String iso) {
    try {
      final d = DateTime.parse(iso);
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
      if (diff.inHours < 24) return '${diff.inHours}j lalu';
      if (diff.inDays < 7) return '${diff.inDays}h lalu';
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return '';
    }
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final active = item['id'] == _currentConversationId;
    final title = item['title'] as String;
    final time = _relTime(item['updatedAt'] as String);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: _Design.radiusMd,
          onTap: () => _switchConv(item['id'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: active
                  ? _Design(context).primary.withOpacity(0.07)
                  : Colors.transparent,
              borderRadius: _Design.radiusMd,
              border: active
                  ? Border.all(color: _Design(context).primary.withOpacity(0.2))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: active
                        ? _Design(context).primary
                        : _Design(context).inputBg,
                    borderRadius: _Design.radiusSm,
                  ),
                  child: Icon(
                    active ? Icons.chat_bubble : Icons.chat_bubble_outline,
                    color: active
                        ? Colors.white
                        : _Design(context).textSecondary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: active
                              ? _Design(context).primary
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 11,
                          color: _Design(context).textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                _iconBtn(
                  Icons.edit_outlined,
                  Colors.blue,
                  () => _renameConv(item['id'] as String, title),
                ),
                const SizedBox(width: 4),
                _iconBtn(
                  Icons.delete_outline_rounded,
                  Colors.red,
                  () => _deleteConv(item['id'] as String),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color baseColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: baseColor.withOpacity(0.08),
          borderRadius: _Design.radiusSm,
        ),
        child: Icon(icon, size: 14, color: baseColor.withOpacity(0.6)),
      ),
    );
  }

  // ═══════════════════════════════════════
  // MODEL PICKER
  // ═══════════════════════════════════════
  void _showModelPicker() {
    final grouped = <String, List<Map<String, String>>>{};
    for (final m in _models) {
      grouped.putIfAbsent(m['note'] ?? 'Lainnya', () => []).add(m);
    }
    const order = [
      '⭐ Recommended',
      '💬 Chat Umum',
      '💻 Coding',
      '🧠 Reasoning',
      '🔧 Ringan',
      '🧪 Eksperimental',
    ];
    final sorted = [
      ...order
          .where((c) => grouped.containsKey(c))
          .map((c) => MapEntry(c, grouped[c]!)),
      ...grouped.entries.where((e) => !order.contains(e.key)),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.78,
        decoration: BoxDecoration(
          color: _Design(context).surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _Design(context).border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: _Design(context).primaryGradient,
                      borderRadius: _Design.radiusSm,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilih Model AI',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _Design(context).textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Semua model gratis dari OpenRouter',
                          style: TextStyle(
                            fontSize: 12,
                            color: _Design(context).textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: _Design(context).textTertiary,
                      size: 22,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _Design(context).primary.withOpacity(0.05),
                borderRadius: _Design.radiusMd,
                border: Border.all(
                  color: _Design(context).primary.withOpacity(0.12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: _Design(context).primary,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Aktif: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: _Design(context).textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _shortModel,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _Design(context).primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 20, indent: 20, endIndent: 20),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: sorted.length,
                itemBuilder: (_, ci) {
                  final cat = sorted[ci];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                        child: Text(
                          cat.key,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _Design(context).textTertiary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      ...cat.value.map((model) {
                        final sel = model['name'] == _selectedModel;
                        final name = model['name']!.split('/').last;
                        final prov = model['name']!.split('/').first;
                        final isR = cat.key.contains('Reasoning');
                        final caps = model['capabilities'] ?? 'text';
                        final hasImage = caps.contains('image');
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1.5,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: _Design.radiusMd,
                              onTap: () {
                                if (mounted)
                                  setState(
                                    () => _selectedModel = model['name']!,
                                  );
                                _saveModelPref();
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text('Model: $name'),
                                      ],
                                    ),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: _Design(context).primary,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? _Design(
                                          context,
                                        ).primary.withOpacity(0.06)
                                      : Colors.transparent,
                                  borderRadius: _Design.radiusMd,
                                  border: Border.all(
                                    color: sel
                                        ? _Design(context).primary
                                        : _Design(context).border,
                                    width: sel ? 1.2 : 0.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: sel
                                            ? _Design(context).primary
                                            : _Design(context).inputBg,
                                        borderRadius: _Design.radiusSm,
                                      ),
                                      child: Icon(
                                        sel
                                            ? Icons.check
                                            : Icons.smart_toy_outlined,
                                        color: sel
                                            ? Colors.white
                                            : _Design(context).textTertiary,
                                        size: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              fontWeight: sel
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                              fontSize: 13,
                                              color: sel
                                                  ? _Design(context).primary
                                                  : _Design(
                                                      context,
                                                    ).textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Text(
                                                prov,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: _Design(
                                                    context,
                                                  ).textTertiary,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 1,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue[50],
                                                  borderRadius:
                                                      BorderRadius.circular(3),
                                                  border: Border.all(
                                                    color: Colors.blue[200]!,
                                                    width: 0.5,
                                                  ),
                                                ),
                                                child: const Text(
                                                  '📄 TXT',
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              if (hasImage) ...[
                                                const SizedBox(width: 3),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                        vertical: 1,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green[50],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          3,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.green[200]!,
                                                      width: 0.5,
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    '🖼️ IMG',
                                                    style: TextStyle(
                                                      fontSize: 8,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isR)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange[50],
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: Colors.orange[200]!,
                                            ),
                                          ),
                                          child: const Text(
                                            '🧠',
                                            style: TextStyle(fontSize: 11),
                                          ),
                                        ),
                                      ),
                                    if (sel)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _Design(context).primary,
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
                                          ),
                                          child: const Text(
                                            'AKTIF',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      if (ci < sorted.length - 1) const SizedBox(height: 6),
                    ],
                  );
                },
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _showModelPicker,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'BowAI',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                      0.12 + _pulseController.value * 0.06,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 100),
                        child: Text(
                          _shortModel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.unfold_more,
                        size: 14,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              widget.themeService?.themeMode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
              color: Colors.white,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () {
              widget.themeService?.toggleTheme();
            },
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: _Design(context).primaryGradient),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      drawer: Drawer(
        backgroundColor: _Design(context).surface,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
                decoration: BoxDecoration(
                  gradient: _Design(context).drawerGradient,
                  boxShadow: [
                    BoxShadow(
                      color: _Design(context).primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text(
                          'Let me be your AI Assistant!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(left: 6.0),
                          child: Icon(
                            Icons.smart_toy_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'BowAI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: _Design.radiusSm,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _shortModel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ═══════════════════════════════════════════════════
              // NEW CHAT BUTTON - FIXED: Call _newChat first, then pop
              // ═══════════════════════════════════════════════════
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: _Design.radiusLg,
                    onTap: () {
                      // FIX: Close drawer AFTER new chat is initialized
                      _newChat();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        gradient: _Design(context).primaryGradient,
                        borderRadius: _Design.radiusLg,
                        boxShadow: [_Design(context).shadowPrimary],
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.add_comment_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'New Chat',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Divider(height: 1, color: _Design(context).border),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    const Text(
                      'Chat History',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: _Design(context).primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_chatHistoryList.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _Design(context).primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _chatHistoryList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 42,
                              color: _Design(context).border,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Belum ada history',
                              style: TextStyle(
                                color: _Design(context).textTertiary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 2, bottom: 8),
                        itemCount: _chatHistoryList.length,
                        itemBuilder: (_, i) =>
                            _buildHistoryItem(_chatHistoryList[i]),
                      ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Divider(height: 1, color: _Design(context).border),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: _Design.radiusLg,
                    onTap: () {
                      Navigator.pop(context);
                      _showModelPicker();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: _Design(context).inputBg,
                        borderRadius: _Design.radiusLg,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: _Design(context).primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Pilih Model',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: _Design(context).textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _Design(context).primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Gratis',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _Design(context).primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.chevron_right,
                            color: _Design(context).textTertiary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _Design(context).inputBg,
                    borderRadius: _Design.radiusMd,
                    border: Border.all(color: _Design(context).border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 15,
                        color: _Design(context).textTertiary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tap ✏️ rename, 🗑️ hapus. Tap chip model di AppBar untuk ganti cepat.',
                          style: TextStyle(
                            fontSize: 11,
                            color: _Design(context).textTertiary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(gradient: _Design(context).bgGradient),
          ),
          ClipRect(
            child: Column(
              children: [
                Expanded(
                  child: _messages.isEmpty && !_isLoading
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length + (_isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length && _isLoading)
                              return _buildThinkingBubble();
                            final msg = _messages[index];
                            final isStoppedUser =
                                msg.role == 'user' &&
                                msg.content == _stoppedUserContent;
                            return ChatMessageWidget(
                              message: msg,
                              onCopyPrompt: () => _handleCopy(msg.content),
                              onDelete: () => _handleDelete(index),
                              onRetry:
                                  (msg.role == 'assistant' || isStoppedUser)
                                  ? () => _handleRetry(index)
                                  : null,
                              onEditPrompt: msg.role == 'user'
                                  ? () => _handleEdit(index)
                                  : null,
                              onShare: () => _handleShare(msg.content),
                            );
                          },
                        ),
                ),
                _buildInputArea(),
              ],
            ),
          ),
          if (_showScrollFab)
            Positioned(
              bottom: 80,
              right: 18,
              child: AnimatedSlide(
                offset: _showScrollFab ? Offset.zero : const Offset(0, 1.2),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _showScrollFab ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: GestureDetector(
                    onTap: _scrollToBottom,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _Design(context).surface,
                        shape: BoxShape.circle,
                        boxShadow: [_Design.shadowMd],
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _Design(context).primary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) => Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: _Design(context).primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _Design(context).primary.withOpacity(
                        0.2 + _pulseController.value * 0.15,
                      ),
                      blurRadius: 24 + _pulseController.value * 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Halo! Saya BowAI 👋',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _Design(context).textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ketik pertanyaan, upload file, atau gunakan\nvoice input untuk memulai percakapan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _Design(context).textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _chip('💡 Jelaskan konsep'),
                _chip('💻 Bantu coding'),
                _chip('✍️ Tulis email'),
                _chip('🧠 Brainstorm ide'),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: _Design.radiusMd,
        onTap: () {
          _controller.text = text.replaceAll(RegExp(r'^.\s'), '');
          if (mounted) setState(() {});
          _focusNode.requestFocus();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: _Design(context).surface,
            borderRadius: _Design.radiusMd,
            border: Border.all(color: _Design(context).border),
            boxShadow: [_Design.shadowSm],
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: _Design(context).textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
