import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jagad_ai/models/chat_message.dart';
import 'package:jagad_ai/widgets/chat_message_widget.dart';

/// Regression tests for the blockquote ("`>` lines") visibility bug.
///
/// flutter_markdown styles blockquote text as
/// `blockquoteStyle.merge(paragraphStyle)`, and `TextStyle.merge` lets the
/// paragraph's non-null fields (including `color`) override the blockquote's.
/// The blockquote background must therefore contrast with the *paragraph*
/// text color; previously, light-mode AI messages used grey.shade900 for both,
/// making quoted lines invisible.
void main() {
  Widget wrap(Widget child, {Brightness brightness = Brightness.light}) {
    return MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: child),
    );
  }

  ChatMessageWidget aiMessage(String content) {
    return ChatMessageWidget(
      message: ChatMessage(
        content: content,
        role: 'assistant',
        modelName: 'openrouter/deepseek/deepseek-chat',
      ),
    );
  }

  TextSpan? findSpan(InlineSpan span, String needle) {
    if (span is TextSpan) {
      if ((span.text ?? '').contains(needle)) return span;
      for (final child in span.children ?? const <InlineSpan>[]) {
        final found = findSpan(child, needle);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// Walks the text spans of every RichText in the tree and returns the
  /// explicit style color of the first span containing [needle].
  Color? spanColorOf(WidgetTester tester, String needle) {
    for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
      final span = findSpan(richText.text, needle);
      if (span != null && span.style?.color != null) {
        return span.style!.color;
      }
    }
    return null;
  }

  /// Finds the background color of the blockquote box (identified by its
  /// 3px left border).
  Color? blockquoteBackground(WidgetTester tester) {
    for (final db in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox))) {
      final dec = db.decoration;
      if (dec is BoxDecoration && dec.border is Border) {
        final border = dec.border! as Border;
        if (border.left.width == 3) return dec.color;
      }
    }
    return null;
  }

  testWidgets('light mode: AI blockquote text color differs from background',
      (tester) async {
    await tester.pumpWidget(
      wrap(aiMessage('> this is a quoted line\n\nnormal line')),
    );

    final textColor = spanColorOf(tester, 'this is a quoted line');
    final bgColor = blockquoteBackground(tester);

    expect(textColor, isNotNull, reason: 'blockquote text span must be found');
    expect(bgColor, isNotNull, reason: 'blockquote box must be found');
    expect(textColor, isNot(equals(bgColor)),
        reason: 'quoted text must not share its background color');
  });

  testWidgets('dark mode: AI blockquote text color differs from background',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        aiMessage('> quoted text in dark mode'),
        brightness: Brightness.dark,
      ),
    );

    final textColor = spanColorOf(tester, 'quoted text in dark mode');
    final bgColor = blockquoteBackground(tester);

    expect(textColor, isNotNull);
    expect(bgColor, isNotNull);
    expect(textColor, isNot(equals(bgColor)));
  });

  testWidgets('light mode: user blockquote text color differs from background',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        ChatMessageWidget(
          message: ChatMessage(content: '> user quoted line', role: 'user'),
        ),
      ),
    );

    final textColor = spanColorOf(tester, 'user quoted line');
    final bgColor = blockquoteBackground(tester);

    expect(textColor, isNotNull);
    expect(bgColor, isNotNull);
    expect(textColor, isNot(equals(bgColor)));
  });

}

