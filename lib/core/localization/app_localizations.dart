import 'package:flutter/material.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('en'),
    Locale('ar'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const _strings = {
    'en': {
      'appName': 'Everything Notes Offline',
      'tagline':
          'A powerful offline document editor and note-taking application.',
      'home': 'Home',
      'search': 'Search',
      'folders': 'Folders',
      'backup': 'Backup',
      'settings': 'Settings',
      'newNote': 'New note',
      'unlockTitle': 'Everything Notes Offline is locked',
      'unlock': 'Unlock',
      'useBiometrics': 'Use biometrics',
      'incorrectPin': 'Incorrect PIN.',
    },
    'ar': {
      'appName': 'كل الملاحظات دون اتصال',
      'tagline': 'محرر مستندات وتطبيق ملاحظات قوي يعمل دون اتصال.',
      'home': 'الرئيسية',
      'search': 'بحث',
      'folders': 'المجلدات',
      'backup': 'نسخ احتياطي',
      'settings': 'الإعدادات',
      'newNote': 'ملاحظة جديدة',
      'unlockTitle': 'التطبيق مقفل',
      'unlock': 'فتح',
      'useBiometrics': 'استخدام البصمة',
      'incorrectPin': 'رمز PIN غير صحيح.',
    },
    'es': {
      'appName': 'Everything Notes Offline',
      'tagline': 'Editor de documentos y notas sin conexión.',
      'home': 'Inicio',
      'search': 'Buscar',
      'folders': 'Carpetas',
      'backup': 'Copia',
      'settings': 'Ajustes',
      'newNote': 'Nueva nota',
      'unlockTitle': 'Everything Notes Offline está bloqueado',
      'unlock': 'Desbloquear',
      'useBiometrics': 'Usar biometría',
      'incorrectPin': 'PIN incorrecto.',
    },
    'fr': {
      'appName': 'Everything Notes Offline',
      'tagline': 'Editeur de documents et notes hors ligne.',
      'home': 'Accueil',
      'search': 'Recherche',
      'folders': 'Dossiers',
      'backup': 'Sauvegarde',
      'settings': 'Parametres',
      'newNote': 'Nouvelle note',
      'unlockTitle': 'Everything Notes Offline est verrouille',
      'unlock': 'Deverrouiller',
      'useBiometrics': 'Utiliser la biometrie',
      'incorrectPin': 'PIN incorrect.',
    },
    'hi': {
      'appName': 'Everything Notes Offline',
      'tagline': 'ऑफलाइन दस्तावेज़ संपादक और नोट ऐप।',
      'home': 'होम',
      'search': 'खोज',
      'folders': 'फोल्डर',
      'backup': 'बैकअप',
      'settings': 'सेटिंग्स',
      'newNote': 'नया नोट',
      'unlockTitle': 'Everything Notes Offline लॉक है',
      'unlock': 'अनलॉक',
      'useBiometrics': 'बायोमेट्रिक्स उपयोग करें',
      'incorrectPin': 'गलत PIN.',
    },
  };

  String text(String key) {
    return _strings[locale.languageCode]?[key] ?? _strings['en']![key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
