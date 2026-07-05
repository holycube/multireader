import 'dict_entry.dart';

/// ECDICT exchange 别名元数据，对应 `mvp_dict_aliases.json` 单条记录。
class DictAliasMeta {
  const DictAliasMeta({
    required this.lemma,
    required this.exchangeKey,
    this.phonetic,
  });

  final String lemma;
  final String exchangeKey;
  final String? phonetic;

  factory DictAliasMeta.fromJson(Map<String, dynamic> json) {
    return DictAliasMeta(
      lemma: '${json['lemma'] ?? ''}',
      exchangeKey: '${json['exchangeKey'] ?? ''}',
      phonetic: _nullableString(json['phonetic']),
    );
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }
}

/// [DictLoader.resolve] 返回值：表面词形、释义来源与可选别名。
class DictLookupResult {
  const DictLookupResult({
    required this.tappedWord,
    this.entry,
    this.alias,
  });

  final String tappedWord;
  final DictEntry? entry;
  final DictAliasMeta? alias;

  bool get hasVariantTabs =>
      alias != null && alias!.lemma != tappedWord;
}
