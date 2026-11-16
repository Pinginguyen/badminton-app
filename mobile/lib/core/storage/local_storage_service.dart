import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const _snapshotKey = 'badminton_squad.active_session.v1';

  Future<void> _writeTail = Future<void>.value();

  Future<Map<String, Object?>?> loadSnapshot() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_snapshotKey);
    if (encoded == null) return null;

    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      throw const FormatException('Saved badminton session is not an object.');
    }

    final snapshot = <String, Object?>{};
    for (final entry in decoded.entries) {
      if (entry.key is! String) {
        throw const FormatException('Saved session contains a non-string key.');
      }
      snapshot[entry.key as String] = entry.value;
    }
    return snapshot;
  }

  Future<void> saveSnapshot(Map<String, Object?> snapshot) {
    final encoded = jsonEncode(snapshot);
    final operation = _writeTail.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(_snapshotKey, encoded);
      if (!saved) {
        throw StateError('The session snapshot could not be saved.');
      }
    });

    _writeTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  Future<void> clearSnapshot() {
    final operation = _writeTail.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      final removed = await preferences.remove(_snapshotKey);
      if (!removed) {
        throw StateError('The saved session could not be cleared.');
      }
    });

    _writeTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }
}
