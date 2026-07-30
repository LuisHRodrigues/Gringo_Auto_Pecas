import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Wrapper simples sobre o SharedPreferences que imita a API do localStorage
/// usada no projeto web (getString/setString com JSON).
class LocalStore {
  LocalStore._(this._prefs);
  final SharedPreferences _prefs;

  static LocalStore? _instance;
  static Future<LocalStore> instance() async {
    _instance ??= LocalStore._(await SharedPreferences.getInstance());
    return _instance!;
  }

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
  Future<void> remove(String key) => _prefs.remove(key);

  List<dynamic> getJsonList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    return jsonDecode(raw) as List<dynamic>;
  }

  Future<void> setJsonList(String key, List<Map<String, dynamic>> value) =>
      _prefs.setString(key, jsonEncode(value));

  Map<String, dynamic>? getJsonMap(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> setJsonMap(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));
}
