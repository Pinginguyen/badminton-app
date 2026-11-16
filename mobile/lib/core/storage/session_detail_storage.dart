import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SessionDetailStorage {
  static const _keyPrefix = 'badminton_squad.session_detail.v1.';

  Future<Map<String, Object?>?> load(String sessionId) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString('$_keyPrefix$sessionId');
    if (encoded == null) return null;
    final decoded = jsonDecode(encoded);
    if (decoded is! Map || decoded.keys.any((key) => key is! String)) {
      throw const FormatException('Saved session detail is not an object.');
    }
    return decoded.cast<String, Object?>();
  }

  Future<void> save(String sessionId, Map<String, Object?> snapshot) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      '$_keyPrefix$sessionId',
      jsonEncode(snapshot),
    );
    if (!saved) throw StateError('The session detail could not be saved.');
  }
}