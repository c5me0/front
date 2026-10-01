import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Typed, synchronous catalogs keep locale changes on Flutter's normal
/// inherited-widget path, without replacing the navigator or account state.
class ContentLocaleDelegate<T> extends LocalizationsDelegate<T> {
  const ContentLocaleDelegate({required this.ko, required this.en});

  final T ko;
  final T en;

  @override
  bool isSupported(Locale locale) =>
      const ['ko', 'en'].contains(locale.languageCode);

  @override
  Future<T> load(Locale locale) =>
      SynchronousFuture(locale.languageCode == 'ko' ? ko : en);

  @override
  bool shouldReload(ContentLocaleDelegate<T> old) => false;
}
