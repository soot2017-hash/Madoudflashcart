import 'package:flutter/material.dart';

/// A tap-to-select text area: tapping any word highlights it and shows a
/// floating purple "Convert to Card" pill anchored right above the selected
/// word (clamped inside screen bounds), using [OverlayPortal].
///
/// Selection is auto-dismissed when:
///  * the user taps outside the text,
///  * the enclosing scrollable scrolls,
///  * the user taps the same word again (deselect),
///  * a card is created from the word.
class WordSelectionArea extends StatefulWidget {
  /// Full plain text to render (a definition or an example sentence).
  final String text;

  /// Sentence recorded as the card's source when a word is converted.
  final String? sourceSentence;

  /// Fired with the cleaned-up word (punctuation trimmed, casing normalized):
  /// "loading up," → "loading up".
  final void Function(String selectedWord, {String? sourceSentence})
      onCreateCardFromWord;

  /// Style for the rendered text (LTR context is applied by the parent).
  final TextStyle textStyle;

  const WordSelectionArea({
    super.key,
    required this.text,
    required this.onCreateCardFromWord,
    required this.textStyle,
    this.sourceSentence,
  });

  @override
  State<WordSelectionArea> createState() => _WordSelectionAreaState();
}

class _WordSelectionAreaState extends State<WordSelectionArea> {
  /// Index of the currently selected word in [words]; null when nothing is
  /// selected.
  int? _selectedIndex;

  /// Controller backing the floating-pill overlay.
  final OverlayPortalController _pillController = OverlayPortalController();

  /// Screen-space rect of the selected word's [TextSpan] box; recomputed on
  /// every selection so the pill can clamp itself to the screen.
  Rect? _selectedWordRect;

  /// Raw text split into words (kept in sync with [_selectedIndex] ranges).
  late final List<String> _words;

  @override
  void initState() {
    super.initState();
    _words = widget.text.split(RegExp(r'\s+'));
  }

  /// Edge punctuation/junk to trim from a selected word ("loading up," →
  /// "loading up"). Kept as a plain character-class regex so apostrophes in
  /// contractions ("don't") survive.
  static final RegExp _edgeJunk = RegExp(r'^[^\w]+|[^\w]+$');

  /// Trims punctuation and normalizes casing: `loading up,` → `loading up`.
  static String _cleanWord(String raw) {
    return raw.replaceAll(_edgeJunk, '').trim().toLowerCase();
  }

  /// Computes the on-screen rect of the selected word from its TextSpan box.
  Rect? _rectForSelection(TextBox box) {
    final RenderBox? box0 = context.findRenderObject() as RenderBox?;
    if (box0 == null || !box0.attached) return null;
    // TextPainter boxes are in text coordinates; convert to screen space.
    final Matrix4 transform = box0.getTransformTo(null);
    final Offset topLeft = MatrixUtils.transformPoint(transform, box.topLeft);
    final Offset bottomRight =
        MatrixUtils.transformPoint(transform, box.bottomRight);
    final Rect screenRect = Rect.fromPoints(topLeft, bottomRight);
    // Expand slightly and clamp inside the screen so the pill never clips.
    final Size screen = MediaQuery.of(context).size;
    final Rect expanded = screenRect
        .inflate(6)
        .intersect(const Offset(8, 8) & screen);
    return expanded;
  }

  void _onWordTap(int index) {
    if (_selectedIndex == index) {
      // Tapping the same word again deselects and dismisses the pill.
      _dismiss();
      return;
    }
    setState(() {
      _selectedIndex = index;
      _selectedWordRect = null; // recomputed by the pill's first layout
    });
    _pillController.show();
  }

  void _dismiss() {
    if (_pillController.isShowing) _pillController.hide();
    if (mounted) {
      setState(() {
        _selectedIndex = null;
        _selectedWordRect = null;
      });
    }
  }

  void _convertSelectedWord() {
    final int? index = _selectedIndex;
    if (index == null) return;
    final String word = _cleanWord(_words[index]);
    _dismiss();
    if (word.isNotEmpty) {
      widget.onCreateCardFromWord(word, sourceSentence: widget.sourceSentence);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dismiss on any scroll of the enclosing scrollable.
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        if (_selectedIndex != null) _dismiss();
        return false;
      },
      child: OverlayPortal(
        controller: _pillController,
        overlayChildBuilder: (BuildContext overlayContext) =>
            _SelectionPillOverlay(
          anchorRect: _selectedWordRect,
          onTap: _convertSelectedWord,
        ),
        child: GestureDetector(
          // Tap outside any word clears the selection.
          onTap: _dismiss,
          behavior: HitTestBehavior.opaque,
          child: _TappableText(
            words: _words,
            selectedIndex: _selectedIndex,
            textStyle: widget.textStyle,
            highlightColor: Theme.of(context).colorScheme.primary,
            onWordTap: _onWordTap,
            onWordBoxMeasured: (Rect rect) {
              if (mounted) setState(() => _selectedWordRect = rect);
            },
          ),
        ),
      ),
    );
  }
}

/// Renders the sentence word by word so each word is independently tappable
/// and can report its on-screen box (for pill anchoring).
class _TappableText extends StatelessWidget {
  final List<String> words;
  final int? selectedIndex;
  final TextStyle textStyle;
  final Color highlightColor;
  final void Function(int index) onWordTap;
  final void Function(Rect screenRect) onWordBoxMeasured;

  const _TappableText({
    required this.words,
    required this.selectedIndex,
    required this.textStyle,
    required this.highlightColor,
    required this.onWordTap,
    required this.onWordBoxMeasured,
  });

  @override
  Widget build(BuildContext context) {
    final List<InlineSpan> spans = <InlineSpan>[];
    for (int i = 0; i < words.length; i++) {
      final bool selected = selectedIndex == i;
      final TextStyle style = selected
          ? textStyle.copyWith(
              backgroundColor: highlightColor.withValues(alpha: 0.22),
              fontWeight: FontWeight.w600,
            )
          : textStyle;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => onWordTap(i),
            behavior: HitTestBehavior.opaque,
            child: Builder(
              builder: (BuildContext spanContext) {
                // Report the word's screen rect once built, so the overlay
                // pill can anchor and clamp itself.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final RenderBox? box =
                      spanContext.findRenderObject() as RenderBox?;
                  if (box != null && box.attached) {
                    final Matrix4 transform = box.getTransformTo(null);
                    final Offset topLeft =
                        MatrixUtils.transformPoint(transform, Offset.zero);
                    final Offset bottomRight = MatrixUtils.transformPoint(
                        transform, box.size.bottomRight(Offset.zero));
                    onWordBoxMeasured(Rect.fromPoints(topLeft, bottomRight));
                  }
                });
                return Text(words[i], style: style);
              },
            ),
          ),
        ),
      );
      if (i != words.length - 1) spans.add(const TextSpan(text: ' '));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: textStyle,
    );
  }
}

/// The floating purple pill shown above the selection, clamped within the
/// screen so it never clips off-screen.
class _SelectionPillOverlay extends StatelessWidget {
  /// Screen-space rect of the selected word (anchor); may be briefly null on
  /// the first frame — the pill then waits at the top until measured.
  final Rect? anchorRect;
  final VoidCallback onTap;

  const _SelectionPillOverlay({required this.anchorRect, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (anchorRect == null) return const SizedBox.shrink();

    final Size screen = MediaQuery.of(context).size;
    // Sizing the pill first: place it above the anchor, then clamp.
    const Size pillSize = Size(150, 40);
    final EdgeInsets safe = MediaQuery.paddingOf(context) + const EdgeInsets.all(8);

    double left = anchorRect!.center.dx - pillSize.width / 2;
    double top = anchorRect!.top - pillSize.height - 8;

    // Clamp horizontally and vertically within safe screen bounds.
    left = left.clamp(safe.left, screen.width - safe.right - pillSize.width);
    top = top.clamp(safe.top, screen.height - safe.bottom - pillSize.height);

    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.style_rounded,
                    size: 17, color: Theme.of(context).colorScheme.onPrimary),
                const SizedBox(width: 6),
                Text(
                  'کارت شو',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
