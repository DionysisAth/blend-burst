import 'package:flutter/widgets.dart';

import '../core/models.dart';
import 'gen/app_strings.dart';

export 'gen/app_strings.dart';

/// The game's texts in the current language.
///
/// A global rather than `AppStrings.of(context)`, so models, notifications
/// and screens built without a MaterialApp (in tests) share one source.
/// [LanguageScope] keeps it in step with the app's locale and rebuilds the
/// whole tree when the language changes.
AppStrings get tr => Lang.current;

class Lang {
  /// Languages the game speaks (those with an app_<code>.arb), in the
  /// order Settings lists them.
  static final codes = [
    for (final c in _order)
      if (AppStrings.supportedLocales.any((l) => l.languageCode == c)) c,
  ];

  static const _order = [
    'en',
    'el',
    'es',
    'pt',
    'fr',
    'de',
    'it',
    'nl',
    'pl',
    'tr',
    'ru',
    'id',
    'ja',
    'ko',
    'zh',
  ];

  /// Each language's name in that language.
  static const names = {
    'en': 'English',
    'el': 'Ελληνικά',
    'es': 'Español',
    'pt': 'Português',
    'fr': 'Français',
    'de': 'Deutsch',
    'it': 'Italiano',
    'nl': 'Nederlands',
    'pl': 'Polski',
    'tr': 'Türkçe',
    'ru': 'Русский',
    'id': 'Bahasa Indonesia',
    'ja': '日本語',
    'ko': '한국어',
    'zh': '中文',
  };

  static final english = lookupAppStrings(const Locale('en'));
  static AppStrings current = english;

  /// The language to show: [chosen] (a code from Settings) if set,
  /// otherwise the first of the phone's languages the game speaks,
  /// otherwise English.
  static Locale resolve(String? chosen, [List<Locale>? phone]) {
    if (chosen != null && codes.contains(chosen)) return Locale(chosen);
    for (final l
        in phone ?? WidgetsBinding.instance.platformDispatcher.locales) {
      if (codes.contains(l.languageCode)) return Locale(l.languageCode);
    }
    return const Locale('en');
  }

  static void use(Locale locale) {
    current = lookupAppStrings(
      codes.contains(locale.languageCode) ? locale : const Locale('en'),
    );
  }
}

/// Points [tr] at [locale] and rebuilds everything below when it changes,
/// so texts taken from models (booster names, goals...) update as well.
class LanguageScope extends StatefulWidget {
  final Locale locale;
  final Widget child;
  const LanguageScope({super.key, required this.locale, required this.child});

  @override
  State<LanguageScope> createState() => _LanguageScopeState();
}

class _LanguageScopeState extends State<LanguageScope> {
  @override
  void initState() {
    super.initState();
    Lang.use(widget.locale);
  }

  @override
  void didUpdateWidget(LanguageScope old) {
    super.didUpdateWidget(old);
    if (old.locale == widget.locale) return;
    Lang.use(widget.locale);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      void rebuild(Element e) {
        e.markNeedsBuild();
        e.visitChildren(rebuild);
      }

      (context as Element).visitChildren(rebuild);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

extension TileColorLabel on TileColor {
  /// The color's name in the current language ("Red", "Purple"...).
  String get label => switch (this) {
    TileColor.red => tr.colorRed,
    TileColor.blue => tr.colorBlue,
    TileColor.yellow => tr.colorYellow,
    TileColor.purple => tr.colorPurple,
    TileColor.green => tr.colorGreen,
    TileColor.orange => tr.colorOrange,
    TileColor.brown => tr.colorUmber,
    TileColor.gray => tr.colorCharcoal,
  };
}
