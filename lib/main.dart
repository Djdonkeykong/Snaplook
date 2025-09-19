import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'shared/navigation/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: SnaplookApp()));
}

class SnaplookApp extends StatelessWidget {
  const SnaplookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snaplook',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.lightTheme, // Use light theme for both
      themeMode: ThemeMode.light, // Force light theme for clean design
      home: const MainNavigation(),
    );
  }
}