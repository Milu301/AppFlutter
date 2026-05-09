import 'dart:convert';
import 'dart:math';

import 'package:android_id/android_id.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceId {
  static const _storage = FlutterSecureStorage();
  static const _key = 'stable_device_id_v1';

  static String _sha256(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  static Future<String> _getWebStableId() async {
    try {
      final existing = await _storage.read(key: _key);
      if (existing != null && existing.trim().isNotEmpty) return existing.trim();

      final rnd = Random();
      final raw = 'web|${DateTime.now().microsecondsSinceEpoch}|${rnd.nextInt(1 << 32)}|${rnd.nextInt(1 << 32)}';
      final id = _sha256(raw);

      await _storage.write(key: _key, value: id);
      return id;
    } catch (_) {
      // último fallback en web
      final rnd = Random();
      return _sha256('web_fallback|${DateTime.now().microsecondsSinceEpoch}|${rnd.nextInt(1 << 32)}');
    }
  }

  static Future<String> getStableId() async {
    if (kIsWeb) return _getWebStableId();

    try {
      final info = DeviceInfoPlugin();

      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          const androidIdPlugin = AndroidId();
          final androidId = await androidIdPlugin.getId();
          if (androidId != null && androidId.trim().isNotEmpty) return androidId.trim();
        } catch (_) {}

        final a = await info.androidInfo;
        final raw = [
          a.fingerprint,
          a.manufacturer,
          a.model,
          a.hardware,
          a.brand,
          a.device,
        ].whereType<String>().join('|');

        return _sha256(raw.isEmpty ? 'unknown_android' : raw);
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final i = await info.iosInfo;
        final id = i.identifierForVendor;
        if (id != null && id.trim().isNotEmpty) return id.trim();
        return 'unknown_ios';
      }

      return 'unknown_device';
    } catch (_) {
      // fallback general
      final rnd = Random();
      return _sha256('fallback|${DateTime.now().microsecondsSinceEpoch}|${rnd.nextInt(1 << 32)}');
    }
  }
}
