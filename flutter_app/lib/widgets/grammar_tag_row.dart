import 'package:flutter/material.dart';

import '../models/flashcard_models.dart';

/// Dedicated row for standardized grammar tags ("Transitive", "Intransitive",
/// "Separable", ...) rendered as a Wrap of chips — kept separate from the
/// definition text so no cryptic inline tags ("PUT", "FULL", "TD") are needed
/// inside sentences anymore.
class GrammarTagRow extends StatelessWidget {
  /// Grammar/status tags for the active sense.
  final List<String> tags;

  const GrammarTagRow({super.key, required this.tags});

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final String tag in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.4)),
            ),
            child: Text(
              tag,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
