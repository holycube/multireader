/// 结构化词典词条，对齐 Sprint 6 `mvp_dict.json` schema。

class DictMeaning {

  const DictMeaning({

    required this.text,

    this.primary = false,

  });



  final String text;

  final bool primary;



  factory DictMeaning.fromJson(dynamic json) {

    if (json is Map) {

      return DictMeaning(

        text: '${json['text'] ?? ''}'.trim(),

        primary: json['primary'] == true,

      );

    }

    return DictMeaning(text: '$json'.trim());

  }



  Map<String, dynamic> toJson() => {

        'text': text,

        if (primary) 'primary': true,

      };



  /// 从纯文本列表构建义项；前 [primaryCount] 条标记为主释义。

  static List<DictMeaning> listFromStrings(

    List<String> texts, {

    int primaryCount = 1,

  }) {

    return [

      for (var i = 0; i < texts.length; i++)

        DictMeaning(text: texts[i], primary: i < primaryCount),

    ];

  }

}



class DictSense {

  const DictSense({

    required this.pos,

    required this.meanings,

  });



  final String pos;

  final List<DictMeaning> meanings;



  List<String> get meaningTexts =>

      meanings.map((m) => m.text).where((t) => t.isNotEmpty).toList();



  factory DictSense.fromJson(Map<String, dynamic> json) {

    final rawMeanings = json['meanings'];

    List<DictMeaning> parsed;

    if (rawMeanings is List && rawMeanings.isNotEmpty) {

      if (rawMeanings.first is String) {

        parsed = DictMeaning.listFromStrings(

          rawMeanings.map((e) => '$e').where((e) => e.isNotEmpty).toList(),

        );

      } else {

        parsed = rawMeanings

            .map(DictMeaning.fromJson)

            .where((m) => m.text.isNotEmpty)

            .toList();

      }

    } else {

      parsed = const [];

    }

    return DictSense(

      pos: '${json['pos'] ?? ''}',

      meanings: parsed,

    );

  }



  Map<String, dynamic> toJson() => {

        'pos': pos,

        'meanings': meanings.map((m) => m.toJson()).toList(),

      };

}



class DictEntry {

  const DictEntry({

    required this.word,

    this.phonetic,

    required this.senses,

    this.examTags = const [],

    this.englishDefinition,

    this.fullTranslation,

    this.exchange,

    this.collins,

    this.oxford3000 = false,

  });



  final String word;

  final String? phonetic;

  final List<DictSense> senses;

  final List<String> examTags;

  final String? englishDefinition;

  final String? fullTranslation;

  final String? exchange;

  final int? collins;

  final bool oxford3000;



  bool get hasContent =>

      senses.isNotEmpty ||

      (fullTranslation?.trim().isNotEmpty ?? false) ||

      (englishDefinition?.trim().isNotEmpty ?? false);



  /// 扁平摘要，供 [vocab_entries.definition] 兼容存储。

  String summaryForVocab() {

    if (senses.isEmpty) {

      final fallback = fullTranslation?.trim();

      if (fallback != null && fallback.isNotEmpty) return fallback;

      return englishDefinition?.trim() ?? '';

    }

    return senses

        .map((sense) {

          final meanings = sense.meaningTexts.join('；');

          if (sense.pos.isEmpty) return meanings;

          return '${sense.pos} $meanings';

        })

        .where((line) => line.isNotEmpty)

        .join('\n');

  }



  factory DictEntry.fromJson(Map<String, dynamic> json) {

    final rawSenses = json['senses'];

    final rawTags = json['examTags'];

    final collinsRaw = json['collins'];



    return DictEntry(

      word: '${json['word'] ?? ''}',

      phonetic: _nullableString(json['phonetic']),

      senses: rawSenses is List

          ? rawSenses

              .whereType<Map>()

              .map((e) => DictSense.fromJson(Map<String, dynamic>.from(e)))

              .where((s) => s.meanings.isNotEmpty)

              .toList()

          : const [],

      examTags: rawTags is List

          ? rawTags.map((e) => '$e').where((e) => e.isNotEmpty).toList()

          : const [],

      englishDefinition: _nullableString(json['englishDefinition']),

      fullTranslation: _nullableString(json['fullTranslation']),

      exchange: _nullableString(json['exchange']),

      collins: collinsRaw is int

          ? collinsRaw

          : int.tryParse('$collinsRaw'),

      oxford3000: json['oxford3000'] == true,

    );

  }



  Map<String, dynamic> toJson() => {

        'word': word,

        if (phonetic != null) 'phonetic': phonetic,

        'senses': senses.map((s) => s.toJson()).toList(),

        if (examTags.isNotEmpty) 'examTags': examTags,

        if (englishDefinition != null) 'englishDefinition': englishDefinition,

        if (fullTranslation != null) 'fullTranslation': fullTranslation,

        if (exchange != null) 'exchange': exchange,

        if (collins != null) 'collins': collins,

        if (oxford3000) 'oxford3000': oxford3000,

      };



  static String? _nullableString(Object? value) {

    if (value == null) return null;

    final text = '$value'.trim();

    return text.isEmpty ? null : text;

  }

}



/// ECDICT `exchange` 字段解析为可读标签。

const exchangeLabels = <String, String>{

  'p': '过去式',

  'd': '过去分词',

  'i': '现在分词',

  '3': '第三人称单数',

  'r': '比较级',

  't': '最高级',

  's': '复数',

  '0': 'Lemma',

  '1': '变换形式',

};



List<String> formatExchange(String? exchange) {

  if (exchange == null || exchange.trim().isEmpty) return const [];

  final items = <String>[];

  for (final part in exchange.split('/')) {

    final trimmed = part.trim();

    if (trimmed.isEmpty) continue;

    final colon = trimmed.indexOf(':');

    if (colon <= 0) continue;

    final key = trimmed.substring(0, colon);

    final value = trimmed.substring(colon + 1).trim();

    if (value.isEmpty) continue;

    final label = exchangeLabels[key] ?? key;

    items.add('$label $value');

  }

  return items;

}



/// 变形 Tab 释义行末尾的语法括号注，如「（be的过去式）」。

String formatVariantGrammarNote(String lemma, String exchangeKey) {

  final label = exchangeLabels[exchangeKey] ?? exchangeKey;

  return '（$lemma的$label）';

}


