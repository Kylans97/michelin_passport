import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// British English, so every date reads day month year, in the date
/// pickers and their typed input too (product owner, 2026-11-22: "de
/// Europese notatie volgt en niet de Amerikaanse"). The copy stays
/// English; only formatting follows the locale.
const appLocale = Locale('en', 'GB');

const appSupportedLocales = [appLocale];

const appLocalizationsDelegates = GlobalMaterialLocalizations.delegates;
