import 'session.dart';

class SessionStore {
  static Session? _session;

  static Session? get session => _session;

  static void set(Session? s) {
    _session = s;
  }

  static void clear() {
    _session = null;
  }
}
