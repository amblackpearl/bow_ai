// File: lib/widgets/chat_message_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:google_fonts/google_fonts.dart';

import '../models/chat_message.dart';

class ChatMessageWidget extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onCopyPrompt;
  final VoidCallback? onEditPrompt;
  final VoidCallback? onDelete;
  final VoidCallback? onRetry;
  final VoidCallback? onShare;

  const ChatMessageWidget({
    super.key,
    required this.message,
    this.onCopyPrompt,
    this.onEditPrompt,
    this.onDelete,
    this.onRetry,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      decoration: BoxDecoration(
        border: isUser
            ? null
            : Border(
                top: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1),
                bottom: BorderSide(
                  color: Colors.grey.withOpacity(0.1),
                  width: 1,
                ),
              ),
        color: isUser ? Colors.transparent : Colors.grey.withOpacity(0.02),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          // Message Content Area
          Expanded(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // ╔══════════════════════════════════════════════════════╗
                // ║  FIX #2: Model indicator for AI messages             ║
                // ╚══════════════════════════════════════════════════════╝
                if (!isUser && message.modelName != null)
                  _buildModelIndicator(context),

                // Sender Name
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    isUser ? 'You' : 'Assistant',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isUser
                          ? Theme.of(context).colorScheme.primary
                          : (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade600),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                // ╔══════════════════════════════════════════════════════╗
                // ║  FIX #1: Wrap with SelectionArea for multi-line      ║
                // ║  text selection                                     ║
                // ╚══════════════════════════════════════════════════════╝
                SelectionArea(
                  child: isUser
                      ? _buildUserMessage(context)
                      : _buildAIMessage(context),
                ),

                // Action Buttons
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: isUser
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: isUser
                        ? _buildUserActionButtons()
                        : _buildAIActionButtons(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ╔══════════════════════════════════════════════════════╗
  // ║  FIX #2: Model indicator widget                     ║
  // ╚══════════════════════════════════════════════════════╝
  Widget _buildModelIndicator(BuildContext context) {
    final shortName = message.modelName!.split('/').last.toUpperCase();
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: primaryColor.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 12, color: primaryColor),
          const SizedBox(width: 6),
          Text(
            shortName,
            style: TextStyle(
              fontSize: 11,
              color: primaryColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserMessage(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: MarkdownBody(
        data: message.content.isEmpty ? ' ' : message.content,
        selectable: false,
        styleSheet: _getMarkdownStyle(context, true),
        onTapLink: (text, href, title) => _handleLinkTap(context, href),
        builders: {'code': CodeBlockBuilder(context: context, isUser: true)},
      ),
    );
  }

  Widget _buildAIMessage(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.85,
      ),
      child: MarkdownBody(
        data: message.content,
        selectable: false,
        styleSheet: _getMarkdownStyle(context, false),
        onTapLink: (text, href, title) => _handleLinkTap(context, href),
        builders: {'code': CodeBlockBuilder(context: context, isUser: false)},
      ),
    );
  }

  MarkdownStyleSheet _getMarkdownStyle(BuildContext context, bool isUser) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isUser ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade900);
    final codeBgColor = isUser
        ? const Color.fromARGB(255, 185, 178, 178)
        : (isDark ? const Color(0xFF2D2D2D) : const Color.fromARGB(255, 185, 178, 178));
    final codeTextColor = isUser ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade800);
    final blockquoteColor = isUser ? Colors.white70 : (isDark ? Colors.grey.shade400 : Colors.grey.shade700);
    final blockquoteBgColor = isUser ? Colors.white24 : (isDark ? Colors.grey.shade800 : Colors.grey.shade900);
    
    return MarkdownStyleSheet(
      p: TextStyle(
        color: textColor,
        fontSize: 15,
        height: 1.6,
        letterSpacing: 0.2,
      ),
      code: TextStyle(
        backgroundColor: codeBgColor,
        color: codeTextColor,
        fontSize: 14,
        wordSpacing: 5,
        fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
        fontWeight: FontWeight.w500,
      ),
      codeblockDecoration: BoxDecoration(
        boxShadow: isUser
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      codeblockPadding: const EdgeInsets.all(15),
      codeblockAlign: WrapAlignment.start,
      blockquote: TextStyle(
        color: blockquoteColor,
        fontSize: 14,
        height: 1.5,
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        color: blockquoteBgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isUser ? Colors.white70 : const Color(0xFF6366F1),
            width: 3,
          ),
        ),
      ),
      a: TextStyle(
        color: isUser ? Colors.blue[200] : const Color(0xFF6366F1),
        decoration: TextDecoration.underline,
        decorationColor: isUser ? Colors.blue[200] : const Color(0xFF6366F1),
      ),
      h1: TextStyle(
        color: textColor,
        fontSize: 28,
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
      h2: TextStyle(
        color: textColor,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      h3: TextStyle(
        color: textColor,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      listBullet: TextStyle(
        color: textColor,
        fontSize: 15,
        height: 1.6,
      ),
      tableHead: TextStyle(
        color: textColor,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
      tableBody: TextStyle(
        color: isUser ? Colors.white70 : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
        fontSize: 14,
      ),
    );
  }

  List<Widget> _buildAIActionButtons() {
    return [
      _buildActionButton(
        icon: Icons.copy_rounded,
        tooltip: 'Copy',
        onTap: onCopyPrompt,
      ),
      _buildActionButton(
        icon: Icons.refresh_rounded,
        tooltip: 'Regenerate',
        onTap: onRetry,
      ),
      _buildActionButton(
        icon: Icons.share_rounded,
        tooltip: 'Share',
        onTap: onShare,
      ),
      _buildActionButton(
        icon: Icons.delete_outline_rounded,
        tooltip: 'Delete',
        onTap: onDelete,
      ),
    ];
  }

  List<Widget> _buildUserActionButtons() {
    return [
      _buildActionButton(
        icon: Icons.edit_outlined,
        tooltip: 'Edit',
        onTap: onEditPrompt,
      ),
      _buildActionButton(
        icon: Icons.copy_rounded,
        tooltip: 'Copy',
        onTap: onCopyPrompt,
      ),
      _buildActionButton(
        icon: Icons.delete_outline_rounded,
        tooltip: 'Delete',
        onTap: onDelete,
      ),
    ];
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: Colors.grey.shade600),
        ),
      ),
    );
  }

  void _handleLinkTap(BuildContext context, String? href) async {
    if (href != null) {
      await Clipboard.setData(ClipboardData(text: href));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.link, size: 16, color: Colors.white),
                SizedBox(width: 8),
                Text('Link copied to clipboard'),
              ],
            ),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.grey.shade900,
          ),
        );
      }
    }
  }
}

// Custom CodeBlock Builder for enhanced code block display
class CodeBlockBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  final bool isUser;

  CodeBlockBuilder({required this.context, required this.isUser});

  Color get _backgroundColor => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC);
  Color get _headerColor => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF2D2D2D) : const Color(0xFFF1F5F9);
  Color get _borderColor => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF404040) : const Color(0xFFE2E8F0);
  Color get _textColor => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFFD4D4D4) : const Color(0xFF1E293B);

  Color get commentColor => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF6A9955) : const Color(0xFF008000);
  Color get keywordColor => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF569CD6) : const Color(0xFF0000FF);
  Color get stringColor => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFFCE9178) : const Color(0xFFA31515);
  Color get numberColor => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFFB5CEA8) : const Color(0xFF098658);
  Color get builtInColor => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF4FC1FF) : const Color(0xFF267F99);

  Widget _buildCopyButton(String code, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white70 : Colors.black54;
    final textColor = isDark ? Colors.white : Colors.black87;
    final btnBgColor = isDark ? const Color(0x60606060) : Colors.black.withOpacity(0.05);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: code));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text('Code copied!'),
                  ],
                ),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.black87,
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: btnBgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.copy_rounded, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Text(
                'Copy',
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget visitElement(md.Element element, TextStyle? preferredStyle) {
    final md.Element codeElement =
        element.children?.whereType<md.Element>().firstWhere(
          (e) => e.tag == 'code',
          orElse: () => element,
        ) ??
        element;

    final String codeContent = codeElement.textContent;

    String language = '';
    final languageAttr = codeElement.attributes['class'];
    if (languageAttr != null && languageAttr.startsWith('language-')) {
      language = languageAttr.substring(9).trim();
    }
    final languageDisplay = _getLanguageDisplay(language);

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        margin: const EdgeInsets.symmetric(vertical: 12.0),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header bar with language and copy button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _headerColor,
                border: Border(
                  bottom: BorderSide(color: _borderColor, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (languageDisplay.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getLanguageColor(language).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _getLanguageColor(language).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getLanguageIcon(language),
                            size: 14,
                            color: _getLanguageColor(language),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            languageDisplay,
                            style: TextStyle(
                              color: _getLanguageColor(language),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (codeContent.isNotEmpty)
                    _buildCopyButton(codeContent, context),
                ],
              ),
            ),
            // Code content with horizontal scroll
            _ScrollableCodeView(
              child: SelectableText.rich(
                _buildCodeSpan(codeContent, language),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                  wordSpacing: 5,
                  letterSpacing: 0.5,
                  fontSize: 14,
                  height: 1.5,
                  color: _textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final md.Element codeElement =
        element.children?.whereType<md.Element>().firstWhere(
          (e) => e.tag == 'code',
          orElse: () => element,
        ) ??
        element;

    final String codeContent = codeElement.textContent;

    // final bool isInlineCode = !codeContent.contains('\n');
    final bool isInlineCode =
        !codeContent.contains('\n') && !codeContent.contains('\r');

    if (isInlineCode) {
      // Return a compact, styled widget for single backtick inline code
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
        decoration: BoxDecoration(
          color: isUser
              ? Colors.white.withOpacity(0.2)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(
            color: isUser ? Colors.transparent : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Text(
          codeContent,
          style: TextStyle(
            fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isUser
                ? Colors.white
                : Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    String language = '';
    final classAttr = codeElement.attributes['class'];
    if (classAttr != null && classAttr.startsWith('language-')) {
      language = classAttr.substring(9).trim();
    }

    return _buildCodeWidget(codeContent, language);
  }

  Widget _buildCodeWidget(String codeContent, String language) {
    final languageDisplay = _getLanguageDisplay(language);

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _headerColor,
                border: Border(bottom: BorderSide(color: _borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (languageDisplay.isNotEmpty) Text(languageDisplay),
                  if (codeContent.isNotEmpty)
                    _buildCopyButton(codeContent, context),
                ],
              ),
            ),
            _ScrollableCodeView(
              child: SelectableText.rich(
                _buildCodeSpan(codeContent, language),
                style: TextStyle(
                  fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getLanguageDisplay(String language) {
    switch (language.toLowerCase()) {
      case 'dart':
        return 'Dart';
      case 'python':
        return 'Python';
      case 'javascript':
      case 'js':
        return 'JavaScript';
      case 'typescript':
      case 'ts':
        return 'TypeScript';
      case 'java':
        return 'Java';
      case 'kotlin':
        return 'Kotlin';
      case 'swift':
        return 'Swift';
      case 'go':
        return 'Go';
      case 'rust':
        return 'Rust';
      case 'cpp':
        return 'C++';
      case 'c':
        return 'C';
      case 'csharp':
      case 'cs':
        return 'C#';
      case 'php':
        return 'PHP';
      case 'ruby':
        return 'Ruby';
      case 'html':
        return 'HTML';
      case 'css':
        return 'CSS';
      case 'sql':
        return 'SQL';
      case 'json':
        return 'JSON';
      case 'yaml':
        return 'YAML';
      case 'xml':
        return 'XML';
      case 'bash':
      case 'shell':
        return 'Bash';
      case 'markdown':
        return 'Markdown';
      default:
        return language.isNotEmpty ? language.toUpperCase() : '';
    }
  }

  Color _getLanguageColor(String language) {
    switch (language.toLowerCase()) {
      case 'dart':
        return const Color(0xFF00B4AB);
      case 'python':
        return const Color(0xFF3776AB);
      case 'javascript':
      case 'js':
        return const Color(0xFFF7DF1E);
      case 'typescript':
      case 'ts':
        return const Color(0xFF3178C6);
      case 'java':
        return const Color(0xFF007396);
      case 'kotlin':
        return const Color(0xFF7F52FF);
      case 'swift':
        return const Color(0xFFFA7343);
      case 'go':
        return const Color(0xFF00ADD8);
      case 'rust':
        return const Color(0xFFDEA584);
      case 'cpp':
        return const Color(0xFF00599C);
      case 'html':
        return const Color(0xFFE34F26);
      case 'css':
        return const Color(0xFF1572B6);
      case 'sql':
        return const Color(0xFF4479A1);
      default:
        return const Color(0xFFCCCCCC).withOpacity(0.7);
    }
  }

  IconData _getLanguageIcon(String language) {
    switch (language.toLowerCase()) {
      case 'dart':
        return Icons.code;
      case 'python':
        return Icons.terminal;
      case 'javascript':
      case 'js':
        return Icons.javascript;
      case 'java':
        return Icons.coffee;
      case 'html':
        return Icons.html;
      case 'css':
        return Icons.css;
      case 'sql':
        return Icons.storage;
      default:
        return Icons.code_rounded;
    }
  }

  TextSpan _buildCodeSpan(String code, String language) {
    final List<TextSpan> spans = [];
    final lines = code.split('\n');

    final keywords = [
      'import',
      'from',
      'class',
      'def',
      'func',
      'var',
      'let',
      'const',
      'if',
      'else',
      'for',
      'while',
      'return',
      'true',
      'false',
      'null',
      'nil',
      'void',
      'async',
      'await',
      'new',
      'try',
      'catch',
      'finally',
      'throw',
      'switch',
      'case',
      'default',
      'public',
      'private',
      'static',
      'int',
      'float',
      'double',
      'bool',
      'String',
      'List',
      'Map',
      'Set',
      'dynamic',
      'Future',
      'Stream',
      'late',
      'required',
      'final',
      'abstract',
      'extends',
      'implements',
      'get',
      'set',
      'yield',
      'super',
    ];

    final builtIns = [
      'print',
      'setState',
      'BuildContext',
      'Widget',
      'State',
      'StatelessWidget',
      'StatefulWidget',
      'MyApp',
      'MaterialApp',
      'Scaffold',
      'AppBar',
      'Column',
      'Row',
      'Text',
      'Container',
      'Expanded',
      'Padding',
      'InkWell',
      'GestureDetector',
      'ListView',
      'Icon',
      'Image',
      'Navigator',
      'Route',
      'GlobalKey',
      'SingleChildScrollView',
      'Form',
      'TextFormField',
      'AlertDialog',
      'SnackBar',
      'Iterable',
      'Future',
      'Stream',
      'int',
      'double',
      'num',
      'bool',
      'String',
      'List',
      'Map',
      'Set',
      'Null',
    ];

    for (var i = 0; i < lines.length; i++) {
      if (i > 0) {
        spans.add(const TextSpan(text: '\n'));
      }

      String line = lines[i];
      final List<TextSpan> lineSpans = [];
      String remaining = line;

      if (remaining.trim().startsWith('//') ||
          remaining.trim().startsWith('#')) {
        lineSpans.add(
          TextSpan(
            text: remaining,
            style: TextStyle(color: commentColor),
          ),
        );
        remaining = '';
      } else {
        while (remaining.isNotEmpty) {
          bool matched = false;

          if (remaining.startsWith('"')) {
            final endIndex = _findStringEnd(remaining, '"');
            if (endIndex != -1) {
              lineSpans.add(
                TextSpan(
                  text: remaining.substring(0, endIndex + 1),
                  style: TextStyle(color: stringColor),
                ),
              );
              remaining = remaining.substring(endIndex + 1);
              matched = true;
            }
          } else if (remaining.startsWith("'")) {
            final endIndex = _findStringEnd(remaining, "'");
            if (endIndex != -1) {
              lineSpans.add(
                TextSpan(
                  text: remaining.substring(0, endIndex + 1),
                  style: TextStyle(color: stringColor),
                ),
              );
              remaining = remaining.substring(endIndex + 1);
              matched = true;
            }
          } else {
            for (String keyword in keywords) {
              if (remaining.startsWith(keyword)) {
                final nextCharIndex = keyword.length;
                if (remaining.length == nextCharIndex ||
                    !RegExp(
                      r'[a-zA-Z0-9_]',
                    ).hasMatch(remaining[nextCharIndex])) {
                  lineSpans.add(
                    TextSpan(
                      text: keyword,
                      style: TextStyle(color: keywordColor),
                    ),
                  );
                  remaining = remaining.substring(keyword.length);
                  matched = true;
                  break;
                }
              }
            }
          }

          if (!matched) {
            for (String builtIn in builtIns) {
              if (remaining.startsWith(builtIn)) {
                final nextCharIndex = builtIn.length;
                if (remaining.length == nextCharIndex ||
                    !RegExp(
                      r'[a-zA-Z0-9_]',
                    ).hasMatch(remaining[nextCharIndex])) {
                  lineSpans.add(
                    TextSpan(
                      text: builtIn,
                      style: TextStyle(color: builtInColor),
                    ),
                  );
                  remaining = remaining.substring(builtIn.length);
                  matched = true;
                  break;
                }
              }
            }
          }

          if (!matched) {
            final numberMatch = RegExp(r'^\d+(\.\d+)?').firstMatch(remaining);
            if (numberMatch != null) {
              lineSpans.add(
                TextSpan(
                  text: numberMatch.group(0)!,
                  style: TextStyle(color: numberColor),
                ),
              );
              remaining = remaining.substring(numberMatch.group(0)!.length);
              matched = true;
            }
          }

          if (!matched) {
            lineSpans.add(TextSpan(text: remaining[0]));
            remaining = remaining.substring(1);
          }
        }
      }

      spans.addAll(lineSpans);
    }

    return TextSpan(children: spans);
  }

  int _findStringEnd(String text, String quoteChar) {
    for (int i = 1; i < text.length; i++) {
      if (text[i] == quoteChar) {
        if (i > 0 && text[i - 1] == '\\') {
          continue;
        }
        return i;
      }
    }
    return -1;
  }
}

class _ScrollableCodeView extends StatefulWidget {
  final Widget child;
  const _ScrollableCodeView({required this.child});

  @override
  State<_ScrollableCodeView> createState() => _ScrollableCodeViewState();
}

class _ScrollableCodeViewState extends State<_ScrollableCodeView> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawScrollbar(
      controller: _controller,
      thumbVisibility: true,
      thickness: 6.0,
      radius: const Radius.circular(3),
      thumbColor: Colors.white.withAlpha(51), // 0.2 opacity
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 22),
        child: widget.child,
      ),
    );
  }
}
