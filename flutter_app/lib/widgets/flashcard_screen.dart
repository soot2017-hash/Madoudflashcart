import 'package:flutter/material.dart';

import '../models/flashcard_models.dart';
import 'flashcard_view.dart';

/// Screen that hosts the flashcard.
///
/// This is the seam between the card UI and the rest of the app: whenever the
/// user picks a word in an example/definition, [onCreateCardFromWord] fires
/// with the cleaned-up word (and, when available, the sentence it came from).
class FlashcardScreen extends StatelessWidget {
  /// The card currently being studied.
  final FlashcardItem card;

  /// Called with the selected word (punctuation trimmed, casing normalized),
  /// e.g. "loading up," → "loading up". [sourceSentence] carries the English
  /// sentence the word was picked from, when known.
  final void Function(String selectedWord, {String? sourceSentence})?
      onCreateCardFromWord;

  const FlashcardScreen({super.key, required this.card, this.onCreateCardFromWord});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بازیچه کلمات'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            FlashcardView(
              card: card,
              // Default action: confirm card creation with a snackbar.
              onCreateCardFromWord: (word, {sourceSentence}) {
                onCreateCardFromWord?.call(word, sourceSentence: sourceSentence);
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text('کارت «$word» ساخته شد ✓'),
                    ),
                  );
              },
            ),
          ],
        ),
      ),
    );
  }
}
