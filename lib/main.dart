import 'package:flutter/material.dart';
import 'package:jagad_ai/screens/chat_screen.dart';
import 'package:jagad_ai/services/theme_service.dart';
import 'package:jagad_ai/services/api_profile_service.dart';

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
  final ApiProfileService _profileService = ApiProfileService();

  @override
  void initState() {
    super.initState();
    _profileService.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_themeService, _profileService]),
      builder: (context, _) {
        return MaterialApp(
          title: 'JagadAI',
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
          home: ChatScreen(
            themeService: _themeService,
            profileService: _profileService,
          ),
        );
      },
    );
  }
}
