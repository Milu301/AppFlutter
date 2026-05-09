import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import '../api/api_client.dart';
import '../utils/dates.dart';

class LocationController with WidgetsBindingObserver {
  final ApiClient api;
  final String vendorId;

  StreamSubscription<Position>? _sub;
  bool _running = false;

  DateTime? _lastSentUtc;
  Position? _lastSentPos;

  // ✅ Ajusta esto para “tiempo real”
  final Duration minInterval = const Duration(seconds: 5);
  final double minDistanceM = 10; // manda si se movió al menos 10m (aunque no haya pasado el tiempo)

  LocationController({required this.api, required this.vendorId});

  bool get isRunning => _running;
  DateTime? get lastSentUtc => _lastSentUtc;

  Future<bool> _ensurePermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  Future<void> start() async {
    if (_running) return;
    _running = true;
    WidgetsBinding.instance.addObserver(this);

    final ok = await _ensurePermission();
    if (!ok) {
      _running = false;
      WidgetsBinding.instance.removeObserver(this);
      return;
    }

    // manda una vez al arrancar
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
      await _send(pos);
    } catch (_) {}

    _sub?.cancel();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // genera eventos al moverse (m)
    );

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) async {
        await _maybeSend(pos);
      },
      onError: (_) {},
    );
  }

  Future<void> stop() async {
    _running = false;
    await _sub?.cancel();
    _sub = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  Future<void> _maybeSend(Position pos) async {
    final now = DateTime.now().toUtc();

    if (_lastSentUtc != null) {
      final dt = now.difference(_lastSentUtc!);

      double dist = 999999;
      if (_lastSentPos != null) {
        dist = Geolocator.distanceBetween(
          _lastSentPos!.latitude,
          _lastSentPos!.longitude,
          pos.latitude,
          pos.longitude,
        );
      }

      // si no pasó suficiente tiempo y tampoco se movió suficiente, no mandes
      if (dt < minInterval && dist < minDistanceM) return;
    }

    await _send(pos);
  }

  Future<void> _send(Position pos) async {
    try {
      await api.postVendorLocation(vendorId, {
        'lat': pos.latitude,
        'lng': pos.longitude,

        // ✅ nombres como backend (schema.js)
        'accuracy_m': pos.accuracy,
        'speed_mps': pos.speed,
        'heading_deg': pos.heading,
        'altitude_m': pos.altitude,

        'source': 'foreground',
        'recorded_at': Dates.nowIsoUtc(),
      });

      _lastSentUtc = DateTime.now().toUtc();
      _lastSentPos = pos;
    } catch (_) {
      // silencioso para no spamear UI
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_running) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _sub?.cancel();
      _sub = null;
    } else if (state == AppLifecycleState.resumed) {
      // reanudar stream
      start();
    }
  }
}
