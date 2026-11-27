import 'package:flutter/material.dart';

import 'models/flashcard_models.dart';
import 'theme/app_theme.dart';
import 'widgets/flashcard_screen.dart';

void main() {
  runApp(const MadoudFlashcardsApp());
}

/// Root widget of the Madoud Flash Cards app.
///
/// Applies the custom purple [AppTheme] in both light and dark modes and
/// follows the OS theme setting automatically.
class MadoudFlashcardsApp extends StatelessWidget {
  const MadoudFlashcardsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Madoud Flash Cards',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: FlashcardScreen(
        // The sample "load" card; in the full app this comes from the
        // selected pack instead of being hard-coded.
        card: sampleLoadCard,
      ),
    );
  }
}
