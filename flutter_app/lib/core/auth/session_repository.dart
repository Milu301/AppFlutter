import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'session.dart';

class SessionRepository {
  static const _kSessionKey = 'cobrosapp.session.v1';
  final FlutterSecureStorage _storage;

  SessionRepository(this._storage);

  Future<Session?> read() async {
    final raw = await _storage.read(key: _kSessionKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final s = Session.fromJson(map);
      if (s.token.isEmpty || s.adminId.isEmpty || s.role.isEmpty) return null;
      return s;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Session session) async {
    await _storage.write(key: _kSessionKey, value: jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    await _storage.delete(key: _kSessionKey);
  }
}
