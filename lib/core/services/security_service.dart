import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:everything_notes_offline/core/services/settings_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService(ref.watch(settingsServiceProvider));
});

class SecurityService {
  SecurityService(this._settings);

  final SettingsService _settings;
  final LocalAuthentication _auth = LocalAuthentication();

  Future<void> setPin(String pin) async {
    await _settings.putString('pinHash', _hash(pin));
  }

  Future<bool> verifyPin(String pin) async {
    final stored = _settings.getString('pinHash');
    if (stored == null || stored.isEmpty) {
      return true;
    }
    return stored == _hash(pin);
  }

  Future<bool> authenticateWithBiometrics() async {
    final canAuthenticate =
        await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    if (!canAuthenticate) {
      return false;
    }
    return _auth.authenticate(
      localizedReason: 'Unlock Everything Notes Offline',
      biometricOnly: false,
    );
  }

  String _hash(String pin) {
    final bytes = utf8.encode('everything-notes-offline:$pin');
    return sha256.convert(bytes).toString();
  }
}
