/// Immutable data model for one card and its senses.
///
/// One [FlashcardItem] is the whole card (word + IPA + all senses); each
/// [WordSense] is one tab of the sense switcher, so the UI only ever renders
/// the *active* sense — synonyms/antonyms/examples never leak across senses.
library;

import 'package:flutter/foundation.dart';

@immutable
class WordSense {
  /// Part of speech shown as a badge, e.g. "verb", "phrasal verb".
  final String partOfSpeech;

  /// Grammar/status tags rendered in a dedicated row, e.g.
  /// ["Transitive", "Separable"]. Replaces cryptic inline tags ("PUT",
  /// "FULL", "TD") with structured, human-readable data.
  final List<String> grammarTags;

  /// English definition (plain text, no inline markup).
  final String definition;

  /// English example sentence. Shown LTR, italic, with its own TTS button.
  final String example;

  /// Persian translation of [example]; hidden behind the "ترجمه مثال"
  /// expandable toggle until tapped.
  final String? exampleTranslation;

  /// Persian meaning of the sense (the `p` field in pack JSON).
  final String? meaningFa;

  /// Synonyms **specific to this sense**, same part of speech as the headword
  /// (e.g. for verb "load" (goods): pack, fill, load up — never nouns).
  final List<String> synonyms;

  /// Antonyms **specific to this sense**, same part of speech as the headword.
  final List<String> antonyms;

  /// Prepositional pattern if any, e.g. "load sth into sth".
  final String? pattern;

  const WordSense({
    required this.partOfSpeech,
    required this.grammarTags,
    required this.definition,
    required this.example,
    this.exampleTranslation,
    this.meaningFa,
    this.synonyms = const [],
    this.antonyms = const [],
    this.pattern,
  });

  /// Copy helper (kept immutable: returns a new instance).
  WordSense copyWith({
    String? partOfSpeech,
    List<String>? grammarTags,
    String? definition,
    String? example,
    String? exampleTranslation,
    String? meaningFa,
    List<String>? synonyms,
    List<String>? antonyms,
    String? pattern,
  }) {
    return WordSense(
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      grammarTags: grammarTags ?? this.grammarTags,
      definition: definition ?? this.definition,
      example: example ?? this.example,
      exampleTranslation: exampleTranslation ?? this.exampleTranslation,
      meaningFa: meaningFa ?? this.meaningFa,
      synonyms: synonyms ?? this.synonyms,
      antonyms: antonyms ?? this.antonyms,
      pattern: pattern ?? this.pattern,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WordSense &&
          other.partOfSpeech == partOfSpeech &&
          other.grammarTags.equals(grammarTags) &&
          other.definition == definition &&
          other.example == example &&
          other.exampleTranslation == exampleTranslation &&
          other.meaningFa == meaningFa &&
          other.synonyms.equals(synonyms) &&
          other.antonyms.equals(antonyms) &&
          other.pattern == pattern;

  @override
  int get hashCode => Object.hash(
        partOfSpeech,
        Object.hashAll(grammarTags),
        definition,
        example,
        exampleTranslation,
        meaningFa,
        Object.hashAll(synonyms),
        Object.hashAll(antonyms),
        pattern,
      );
}

@immutable
class FlashcardItem {
  /// The headword, e.g. "load".
  final String word;

  /// IPA transcription, e.g. "/ləʊd/".
  final String ipa;

  /// All senses of the word; index 0 is the sense shown first.
  final List<WordSense> senses;

  const FlashcardItem({
    required this.word,
    required this.ipa,
    required this.senses,
  });

  FlashcardItem copyWith({String? word, String? ipa, List<WordSense>? senses}) {
    return FlashcardItem(
      word: word ?? this.word,
      ipa: ipa ?? this.ipa,
      senses: senses ?? this.senses,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlashcardItem &&
          other.word == word &&
          other.ipa == ipa &&
          other.senses.equals(senses);

  @override
  int get hashCode =>
      Object.hash(word, ipa, Object.hashAll(senses));
}

/// Sample card for the verb "load", matching the pack schema shape:
/// sense 1 = goods/containers, sense 2 = software/data.
const FlashcardItem sampleLoadCard = FlashcardItem(
  word: 'load',
  ipa: '/ləʊd/',
  senses: [
    WordSense(
      partOfSpeech: 'verb',
      grammarTags: ['Transitive', 'Separable'],
      definition:
          'to put goods or a large amount of something into a vehicle, '
          'container, or place',
      example: 'The workers were loading up the truck with heavy boxes.',
      exampleTranslation:
          'کارگران داشتند جعبه‌های سنگین را بار کامیون می‌کردند.',
      meaningFa: 'بار کردن (کالا)؛ پر کردن (ظرف/وسیله نقلیه)',
      synonyms: ['pack', 'fill', 'load up'],
      antonyms: ['unload', 'empty'],
      pattern: 'load sth into/onto sth',
    ),
    WordSense(
      partOfSpeech: 'verb',
      grammarTags: ['Transitive', 'Intransitive'],
      definition:
          'to put a program or piece of data into a computer\'s memory '
          'so it can be used',
      example: 'The software loads automatically when you switch on the device.',
      exampleTranslation:
          'نرم‌افزار به‌محض روشن کردن دستگاه به‌طور خودکار بارگذاری می‌شود.',
      meaningFa: 'بارگذاری کردن (نرم‌افزار/داده)',
      synonyms: ['install', 'insert', 'upload'],
      antonyms: ['remove', 'delete'],
      pattern: 'load sth from sth',
    ),
  ],
);
