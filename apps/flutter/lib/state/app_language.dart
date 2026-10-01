import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  korean('ko', '한국어'),
  english('en', 'English');

  const AppLanguage(this.code, this.label);
  final String code;
  final String label;
  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) => code == 'ko' ? korean : english;
}

class AppLanguageController extends ChangeNotifier {
  AppLanguageController({AppLanguage language = AppLanguage.english})
    : _language = language;

  static const preferenceKey = 'cameo.language';
  static const supportedLocales = [Locale('ko'), Locale('en')];
  AppLanguage _language;
  AppLanguage get language => _language;

  static Future<AppLanguageController> load() async {
    String? stored;
    try {
      stored = (await SharedPreferences.getInstance()).getString(preferenceKey);
    } catch (_) {
      // A failed preference read must not block login or an incoming call.
    }
    return AppLanguageController(language: AppLanguage.fromCode(stored));
  }

  Future<void> select(AppLanguage language) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(preferenceKey, language.code)) {
      throw StateError('Could not persist app language');
    }
    if (language == _language) return;
    _language = language;
    notifyListeners();
  }
}

class AppLanguageScope extends InheritedNotifier<AppLanguageController> {
  const AppLanguageScope({
    super.key,
    required AppLanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLanguageController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLanguageScope>()?.notifier;
}
