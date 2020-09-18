import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

/// Base class to handle localization in the project
class AppLocalizations {
  Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  Map<String, String> _localizedStrings;

  /// loads the locale file from the /lang directory
  Future load() async {
    String jsonString =
        await rootBundle.loadString('lang/${locale.languageCode}.json');

    Map<String, dynamic> jsonMap = json.decode(jsonString);

    _localizedStrings = jsonMap.map((k, v) {
      return MapEntry(k, v.toString());
    });
  }

  /// Translate strings with the [key] used in the .json file.
  String trans(String key) {
    return _localizedStrings[key];
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => [
        "aa",
        "ab",
        "af",
        "ak",
        "sq",
        "am",
        "ar",
        "an",
        "hy",
        "as",
        "av",
        "ae",
        "ay",
        "az",
        "ba",
        "bm",
        "eu",
        "be",
        "bn",
        "bh",
        "bi",
        "bs",
        "br",
        "bg",
        "my",
        "ca",
        "ch",
        "ce",
        "zh",
        "cu",
        "cv",
        "kw",
        "co",
        "cr",
        "cs",
        "da",
        "dv",
        "nl",
        "dz",
        "en",
        "eo",
        "et",
        "ee",
        "fo",
        "fj",
        "fi",
        "fr",
        "fy",
        "ff",
        "ka",
        "de",
        "gd",
        "ga",
        "gl",
        "gv",
        "el",
        "gn",
        "gu",
        "ht",
        "ha",
        "he",
        "hz",
        "hi",
        "ho",
        "hr",
        "hu",
        "ig",
        "is",
        "io",
        "ii",
        "iu",
        "ie",
        "ia",
        "id",
        "ik",
        "it",
        "jv",
        "ja",
        "kl",
        "kn",
        "ks",
        "kr",
        "kk",
        "km",
        "ki",
        "rw",
        "ky",
        "kv",
        "kg",
        "ko",
        "kj",
        "ku",
        "lo",
        "la",
        "lv",
        "li",
        "ln",
        "lt",
        "lb",
        "lu",
        "lg",
        "mk",
        "mh",
        "ml",
        "mi",
        "mr",
        "ms",
        "mg",
        "mt",
        "mn",
        "na",
        "nv",
        "nr",
        "nd",
        "ng",
        "ne",
        "nn",
        "nb",
        "no",
        "ny",
        "oc",
        "oj",
        "or",
        "om",
        "os",
        "pa",
        "fa",
        "pi",
        "pl",
        "pt",
        "ps",
        "qu",
        "rm",
        "ro",
        "rn",
        "ru",
        "sg",
        "sa",
        "si",
        "sk",
        "sl",
        "se",
        "sm",
        "sn",
        "sd",
        "so",
        "st",
        "es",
        "sc",
        "sr",
        "ss",
        "su",
        "sw",
        "sv",
        "ty",
        "ta",
        "tt",
        "te",
        "tg",
        "tl",
        "th",
        "bo",
        "ti",
        "to",
        "tn",
        "ts",
        "tk",
        "tr",
        "tw",
        "ug",
        "uk",
        "ur",
        "uz",
        "ve",
        "vi",
        "vo",
        "cy",
        "wa",
        "wo",
        "xh",
        "yi",
        "yo",
        "za",
        "zu"
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;

  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = new AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }
}

/// Reloads the locale for the [AppLocalizations] class with a locale.
reloadLocale(BuildContext context, Locale locale) async {
  AppLocalizations.of(context).locale = locale;
  await AppLocalizations.of(context).load();
}

/// A locale class used to manage the current locale state.
class AppLocale {
  Locale locale = Locale("en");

  AppLocale._privateConstructor();
  static final AppLocale instance = AppLocale._privateConstructor();

  /// Updates the current locale for the app.
  /// Provide the [locale] you wish to use like Locale("es")
  /// The locale needs to also exist within your /lang directory
  updateLocale(BuildContext context, Locale locale) {
    this.locale = locale;
    reloadLocale(context, locale);
  }
}
