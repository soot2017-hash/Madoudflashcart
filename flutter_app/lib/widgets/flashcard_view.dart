import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/flashcard_models.dart';
import 'grammar_tag_row.dart';
import 'sense_body.dart';
import 'synonym_antonym_section.dart';

/// The multi-layered flashcard: header → grammar tags → sense body →
/// sense-specific synonyms/antonyms.
///
/// Only the *active* sense (kept in [activeSense]) is rendered, so the card
/// stays compact even for words with many senses. Switching senses also
/// stops any ongoing TTS playback so audio never describes the wrong sense.
class FlashcardView extends StatefulWidget {
  final FlashcardItem card;

  /// Fired by the word-selection area with the cleaned-up word and, when
  /// known, the sentence it was picked from.
  final void Function(String selectedWord, {String? sourceSentence})
      onCreateCardFromWord;

  const FlashcardView({
    super.key,
    required this.card,
    required this.onCreateCardFromWord,
  });

  @override
  State<FlashcardView> createState() => _FlashcardViewState();
}

class _FlashcardViewState extends State<FlashcardView> {
  /// Index of the currently displayed sense ("1 / 2" switcher).
  int _activeSense = 0;

  /// Single shared TTS engine for word + example playback.
  final FlutterTts _tts = FlutterTts();

  /// Shared speaking-state notifier: the header button and the example
  /// button both listen to it, avoiding duplicated/conflicting TTS handlers.
  final ValueNotifier<bool> _speaking = ValueNotifier(false);

  bool get _isSpeaking => _speaking.value;

  @override
  void initState() {
    super.initState();
    _configureTts();
  }

  /// Configures the TTS engine once: US English, slightly slower rate,
  /// and completion callbacks that update the shared speaking notifier.
  Future<void> _configureTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setStartHandler(() => _speaking.value = true);
    // Both completion and cancellation must clear the speaking flag.
    await _tts.setCompletionHandler(() => _speaking.value = false);
    await _tts.setCancelHandler(() => _speaking.value = false);
    await _tts.setErrorHandler((_) => _speaking.value = false);
  }

  /// Speaks [text], first stopping anything already in flight.
  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  /// Stops playback — called on widget disposal and whenever the sense
  /// switches (so audio never outlives its sense).
  Future<void> _stopTts() async {
    await _tts.stop();
    _speaking.value = false;
  }

  @override
  void dispose() {
    _tts.stop();
    _tts.dispose();
    _speaking.dispose();
    super.dispose();
  }

  WordSense get _sense => widget.card.senses[_activeSense];

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool hasMultipleSenses = widget.card.senses.length > 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, scheme, hasMultipleSenses),
            const SizedBox(height: 14),
            GrammarTagRow(tags: _sense.grammarTags),
            const SizedBox(height: 14),
            // AnimatedSwitcher gives a soft cross-fade between senses.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Column(
                key: ValueKey<int>(_activeSense),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SenseBody(
                    sense: _sense,
                    speaking: _speaking,
                    onTogglePlayback: () =>
                        _isSpeaking ? _stopTts() : _speak(_sense.example),
                    onCreateCardFromWord: widget.onCreateCardFromWord,
                  ),
                  const SizedBox(height: 16),
                  SynonymAntonymSection(sense: _sense),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card header: word + IPA, TTS button (with speaking state), POS badge
  /// and the compact sense switcher — only the active sense is shown.
  Widget _buildHeader(
    BuildContext context,
    ColorScheme scheme,
    bool hasMultipleSenses,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Text(
                widget.card.word,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
              ),
              Text(
                widget.card.ipa,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              // TTS button: pulses while speaking, tap again to stop.
              _TtsButton(
                speaking: _speaking,
                onTap: () =>
                    _isSpeaking ? _stopTts() : _speak(widget.card.word),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Primary part-of-speech badge of the active sense.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _sense.partOfSpeech,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ),
            if (hasMultipleSenses) ...[
              const SizedBox(height: 8),
              // Compact sense switcher: "1 / 2".
              SegmentedButton<int>(
                segments: [
                  for (int i = 0; i < widget.card.senses.length; i++)
                    ButtonSegment(value: i, label: Text('${i + 1}')),
                ],
                selected: {_activeSense},
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onSelectionChanged: (selection) {
                  final int next = selection.first;
                  if (next != _activeSense) {
                    // Stop audio tied to the previous sense, then switch.
                    _stopTts().whenComplete(() {
                      if (mounted) setState(() => _activeSense = next);
                    });
                  }
                },
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Small circular TTS button with speaking-state feedback, driven by the
/// shared [ValueListenable] so it stays in sync with all other buttons.
class _TtsButton extends StatelessWidget {
  final ValueListenable<bool> speaking;
  final VoidCallback onTap;

  const _TtsButton({required this.speaking, required this.onTap});

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
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSpeaking ? scheme.primary : scheme.surfaceContainerHighest,
          ),
          child: Icon(
            isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
            size: 19,
            color: isSpeaking ? scheme.onPrimary : scheme.primary,
          ),
        ),
      ),
    );
  }
}
