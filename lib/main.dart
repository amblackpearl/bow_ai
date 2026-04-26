import 'package:flutter/material.dart';
import 'package:bow_ai/screens/chat_screen.dart';
import 'package:bow_ai/services/theme_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeService _themeService = ThemeService();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeService,
      builder: (context, _) {
        return MaterialApp(
          title: 'BowAI',
          themeMode: _themeService.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF4F46E5), // primary color
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF4F46E5), // primary color
              brightness: Brightness.dark,
            ),
          ),
          home: ChatScreen(themeService: _themeService),
        );
      },
    );
  }
}
