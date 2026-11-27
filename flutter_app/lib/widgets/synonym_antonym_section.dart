import 'package:flutter/material.dart';

import '../models/flashcard_models.dart';

/// Synonyms & antonyms for the **active sense only** — each sense carries its
/// own lists in [WordSense], so the block never repeats stale synonyms across
/// senses and never mixes parts of speech (for verb "load": pack, fill,
/// load up / install, insert — never nouns like "encumbrance").
class SynonymAntonymSection extends StatelessWidget {
  /// The active sense whose word-lists are rendered.
  final WordSense sense;

  const SynonymAntonymSection({super.key, required this.sense});

  @override
  Widget build(BuildContext context) {
    final bool hasSyn = sense.synonyms.isNotEmpty;
    final bool hasAnt = sense.antonyms.isNotEmpty;
    if (!hasSyn && !hasAnt) return const SizedBox.shrink();

    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 24, thickness: 0.8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasSyn)
              Expanded(child: _WordGroup(label: 'مترادف‌ها', words: sense.synonyms, scheme: scheme)),
            if (hasSyn && hasAnt) const SizedBox(width: 16),
            if (hasAnt)
              Expanded(child: _WordGroup(label: 'متضادها', words: sense.antonyms, scheme: scheme)),
          ],
        ),
      ],
    );
  }
}

/// One labelled group of tappable word chips.
class _WordGroup extends StatelessWidget {
  final String label;
  final List<String> words;
  final ColorScheme scheme;

  const _WordGroup({
    required this.label,
    required this.words,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        // English words inside an RTL column: keep the chip row LTR.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final String w in words)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    w,
                    style: TextStyle(fontSize: 12.5, color: scheme.onSurface),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
