import 'package:flutter/material.dart';

import '../models/flashcard_models.dart';
import 'word_selection_area.dart';

/// Main sense body: the English definition and example sentence are rendered
/// inside an explicit LTR [Directionality] so English always aligns from the
/// left edge, even inside the RTL Persian app shell.
///
/// Layers, top to bottom:
///  1. English definition (LTR, word-selectable → "Convert to Card").
///  2. Persian meaning (RTL), if present.
///  3. Italic English example with its own TTS button (LTR, word-selectable).
///  4. Expandable "ترجمه مثال" toggle revealing the Persian example (RTL).
class SenseBody extends StatelessWidget {
  /// The active sense to render.
  final WordSense sense;

  /// Shared speaking state owned by [FlashcardView]; both the header button
  /// and the example button stay in sync through this single notifier.
  final ValueListenable<bool> speaking;

  /// Toggles playback of the example sentence (stop if speaking, speak if not).
  final VoidCallback onTogglePlayback;

  /// Fired when the user picks a word and confirms card creation.
  final void Function(String selectedWord, {String? sourceSentence})
      onCreateCardFromWord;

  const SenseBody({
    super.key,
    required this.sense,
    required this.speaking,
    required this.onTogglePlayback,
    required this.onCreateCardFromWord,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- 1. English definition (LTR, selectable) ---
        Directionality(
          textDirection: TextDirection.ltr,
          child: WordSelectionArea(
            text: sense.definition,
            sourceSentence: sense.definition,
            onCreateCardFromWord: onCreateCardFromWord,
            textStyle: TextStyle(
              fontSize: 15.5,
              height: 1.6,
              color: scheme.onSurface,
            ),
          ),
        ),

        // --- 2. Persian meaning (RTL) ---
        if (sense.meaningFa != null) ...[
          const SizedBox(height: 8),
          Text(
            sense.meaningFa!,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 14,
              height: 1.8,
              color: scheme.primary,
            ),
          ),
        ],

        // --- 3. English example (LTR, italic, with TTS + selection) ---
        if (sense.example.isNotEmpty) ...[
          const SizedBox(height: 14),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: WordSelectionArea(
                    text: sense.example,
                    sourceSentence: sense.example,
                    onCreateCardFromWord: onCreateCardFromWord,
                    textStyle: TextStyle(
                      fontSize: 14.5,
                      height: 1.6,
                      fontStyle: FontStyle.italic,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ExampleTtsButton(
                  speaking: speaking,
                  onTap: onTogglePlayback,
                ),
              ],
            ),
          ),
        ],

        // --- 4. Expandable Persian example translation (RTL) ---
        if (sense.exampleTranslation != null) ...[
          const SizedBox(height: 4),
          _ExampleTranslationToggle(translation: sense.exampleTranslation!),
        ],
      ],
    );
  }
}

/// Compact speaker button for the example sentence; mirrors the shared
/// speaking state so only one button appears "active" at a time.
class _ExampleTtsButton extends StatelessWidget {
  final ValueListenable<bool> speaking;
  final VoidCallback onTap;

  const _ExampleTtsButton({required this.speaking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: speaking,
      builder: (context, isSpeaking, _) => InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSpeaking ? scheme.primary : scheme.surfaceContainerHighest,
          ),
          child: Icon(
            isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
            size: 17,
            color: isSpeaking ? scheme.onPrimary : scheme.primary,
          ),
        ),
      ),
    );
  }
}

/// "ترجمه مثال" expander: keeps the Persian example hidden until tapped.
class _ExampleTranslationToggle extends StatefulWidget {
  final String translation;

  const _ExampleTranslationToggle({required this.translation});

  @override
  State<_ExampleTranslationToggle> createState() =>
      _ExampleTranslationToggleState();
}

class _ExampleTranslationToggleState extends State<_ExampleTranslationToggle> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'ترجمه مثال',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  widget.translation,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.8,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              secondChild: const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
