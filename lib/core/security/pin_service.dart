import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinService {
  static const _keyPinHash = 'vault_pin_hash';
  static const _keyPinSalt = 'vault_pin_salt';
  static const _defaultSalt = 'DownloadsAppSecureSalt_2026';

  static Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyPinHash);
  }

  static Future<bool> setPin(String pin) async {
    if (pin.length < 4 || pin.length > 6) return false;
    final prefs = await SharedPreferences.getInstance();
    final hash = _hashPin(pin, _defaultSalt);
    await prefs.setString(_keyPinHash, hash);
    await prefs.setString(_keyPinSalt, _defaultSalt);
    return true;
  }

  static Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_keyPinHash);
    if (storedHash == null) return false;
    final salt = prefs.getString(_keyPinSalt) ?? _defaultSalt;
    return storedHash == _hashPin(pin, salt);
  }

  static Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPinHash);
    await prefs.remove(_keyPinSalt);
  }

  static String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }
}
