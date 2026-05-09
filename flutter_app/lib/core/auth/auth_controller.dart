import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_error.dart';
import '../app_bus.dart';
import '../location/location_controller.dart';
import '../utils/device_id.dart';
import 'session.dart';
import 'session_repository.dart';
import 'session_store.dart';

enum AuthStatus {
  unknown,
  unauthenticated,
  admin,
  vendor,
  subscriptionExpired,
  deviceMismatch,
}

class AuthState {
  final AuthStatus status;
  final Session? session;

  /// Mensaje "humano" para pantallas de bloqueo (suscripción expirada / device mismatch)
  final String? message;

  /// Último error de login (o acción) para mostrar en UI.
  final ApiError? lastError;

  const AuthState({
    required this.status,
    this.session,
    this.message,
    this.lastError,
  });

  AuthState copyWith({
    AuthStatus? status,
    Session? session,
    bool clearSession = false,
    String? message,
    ApiError? lastError,
    bool clearMessage = false,
    bool clearLastError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: clearSession ? null : (session ?? this.session),
      message: clearMessage ? null : (message ?? this.message),
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final SessionRepository sessionRepo;
  final ApiClient api;

  StreamSubscription<AppEvent>? _sub;
  LocationController? _location;

  AuthController({required this.sessionRepo, required this.api})
      : super(const AuthState(status: AuthStatus.unknown)) {
    // Eventos globales desde interceptores dio
    _sub = AppBus.stream.listen((event) {
      if (event is UnauthorizedEvent) {
        logout();
      } else if (event is BlockingAuthEvent) {
        _block(event.code, event.message);
      }
    });

    _init();
  }

  // ✅ NUEVO: normaliza respuestas tipo:
  // { ok:true, data:{ token... } }
  // { ok:true, data:{ data:{ token... } } }
  // { ok:true, data:{ data:{ data:{ token... } } } } (por si acaso)
  Map<String, dynamic> _unwrapOkData(Map<String, dynamic> body) {
    Map<String, dynamic> asMap(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return v.cast<String, dynamic>();
      return <String, dynamic>{};
    }

    final d0 = asMap(body['data']);
    final d1 = asMap(d0['data']);
    final d2 = asMap(d1['data']);

    if (d2.isNotEmpty) return d2;
    if (d1.isNotEmpty) return d1;
    return d0;
  }

  ApiError? _extractApiErrorFromException(Object e) {
    if (e is DioException) {
      final data = e.response?.data;

      // Si el backend devolvió JSON tipo {ok:false, error:{...}}
      if (data is Map) {
        final map = data.cast<String, dynamic>();
        final err = api.extractError(map);
        if (err != null) return err;

        // fallback si viene otro formato
        final msg = (map['message'] ?? map['error'] ?? e.message ?? '').toString();
        final status = e.response?.statusCode;
        return ApiError(
          code: status != null ? 'HTTP_$status' : 'NETWORK_ERROR',
          message: msg.isEmpty ? 'Error de servidor' : msg,
        );
      }

      final status = e.response?.statusCode;
      final msg = e.response?.statusMessage ?? e.message ?? 'No se pudo conectar al backend';
      return ApiError(
        code: status != null ? 'HTTP_$status' : 'NETWORK_ERROR',
        message: msg,
      );
    }

    return null;
  }

  Future<void> _init() async {
    try {
      final s = await sessionRepo.read();
      if (s == null) {
        SessionStore.clear();
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }

      SessionStore.set(s);

      if (s.role == 'vendor' && s.vendorId != null && s.vendorId!.isNotEmpty) {
        _location = LocationController(api: api, vendorId: s.vendorId!);
        await _location?.start();
        state = AuthState(status: AuthStatus.vendor, session: s);
        return;
      }

      state = AuthState(status: AuthStatus.admin, session: s);
    } catch (_) {
      SessionStore.clear();
      await sessionRepo.clear();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> logout() async {
    await _location?.stop();
    _location = null;

    SessionStore.clear();
    await sessionRepo.clear();

    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void _block(String code, String message) {
    _location?.stop();
    _location = null;

    SessionStore.clear();
    // ignore: discarded_futures
    sessionRepo.clear();

    if (code == 'SUBSCRIPTION_EXPIRED') {
      state = AuthState(status: AuthStatus.subscriptionExpired, message: message);
    } else if (code == 'DEVICE_MISMATCH') {
      state = AuthState(status: AuthStatus.deviceMismatch, message: message);
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> loginAdmin({
    required String email,
    required String password,
  }) async {
    // limpiar error previo
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      clearLastError: true,
      clearMessage: true,
      clearSession: true,
    );

    try {
      final body = await api
          .loginAdmin(email: email, password: password)
          .timeout(const Duration(seconds: 12));

      final err = api.extractError(body);
      if (err != null) {
        if (err.code == 'SUBSCRIPTION_EXPIRED') {
          _block(err.code, err.message);
        } else {
          state = state.copyWith(status: AuthStatus.unauthenticated, lastError: err);
        }
        return false;
      }

      final payload = _unwrapOkData(body);

      final token = (payload['token'] ?? '').toString();

      // ✅ Soportar backend que manda session (nuevo) o admin (viejo)
      final sessionMap = (payload['session'] as Map?)?.cast<String, dynamic>() ?? {};
      final admin = (payload['admin'] as Map?)?.cast<String, dynamic>() ?? {};

      final adminId = (sessionMap['adminId'] ??
              sessionMap['admin_id'] ??
              admin['id'] ??
              admin['adminId'] ??
              admin['admin_id'] ??
              '')
          .toString();

      final adminEmail = (sessionMap['email'] ?? admin['email'] ?? '').toString();

      DateTime? sub;
      final rawSub = admin['subscription_expires_at'] ?? admin['subscriptionExpiresAt'];
      if (rawSub != null) {
        final s = rawSub.toString();
        if (s.trim().isNotEmpty) {
          try {
            sub = DateTime.parse(s);
          } catch (_) {
            sub = null;
          }
        }
      }

      if (token.isEmpty || adminId.isEmpty) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          lastError: const ApiError(code: 'INTERNAL_ERROR', message: 'Respuesta inválida del servidor'),
        );
        return false;
      }

      final s = Session(
        token: token,
        role: 'admin',
        adminId: adminId,
        adminEmail: adminEmail.isEmpty ? null : adminEmail,
        subscriptionExpiresAt: sub,
      );

      SessionStore.set(s);
      await sessionRepo.save(s);

      state = AuthState(status: AuthStatus.admin, session: s);
      return true;
    } catch (e) {
      final err = _extractApiErrorFromException(e);
      if (err != null) {
        if (err.code == 'SUBSCRIPTION_EXPIRED') {
          _block(err.code, err.message);
        } else {
          state = state.copyWith(status: AuthStatus.unauthenticated, lastError: err);
        }
        return false;
      }

      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        lastError: const ApiError(code: 'INTERNAL_ERROR', message: 'No se pudo conectar al backend'),
      );
      return false;
    }
  }

  Future<bool> loginVendor({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      clearLastError: true,
      clearMessage: true,
      clearSession: true,
    );

    try {
      String deviceId;
      try {
        deviceId = await DeviceId.getStableId();
      } catch (_) {
        deviceId = 'unknown_device';
      }
      if (deviceId.trim().isEmpty) deviceId = 'unknown_device';

      final body = await api
          .loginVendor(email: email, password: password, deviceId: deviceId)
          .timeout(const Duration(seconds: 12));

      final err = api.extractError(body);
      if (err != null) {
        if (err.code == 'SUBSCRIPTION_EXPIRED' || err.code == 'DEVICE_MISMATCH') {
          _block(err.code, err.message);
        } else {
          state = state.copyWith(status: AuthStatus.unauthenticated, lastError: err);
        }
        return false;
      }

      final payload = _unwrapOkData(body);

      final token = (payload['token'] ?? '').toString();

      // ✅ Soportar backend que manda session (nuevo) o vendor (viejo)
      final sessionMap = (payload['session'] as Map?)?.cast<String, dynamic>() ?? {};
      final vendor = (payload['vendor'] as Map?)?.cast<String, dynamic>() ?? {};

      final vendorId = (sessionMap['vendorId'] ??
              sessionMap['vendor_id'] ??
              vendor['id'] ??
              vendor['vendorId'] ??
              vendor['vendor_id'] ??
              '')
          .toString();

      final adminId = (sessionMap['adminId'] ??
              sessionMap['admin_id'] ??
              vendor['admin_id'] ??
              vendor['adminId'] ??
              '')
          .toString();

      final vendorEmail = (sessionMap['email'] ?? vendor['email'] ?? '').toString();
      final vendorName = (vendor['name'] ?? '').toString(); // session normalmente no trae name

      if (token.isEmpty || vendorId.isEmpty || adminId.isEmpty) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          lastError: const ApiError(code: 'INTERNAL_ERROR', message: 'Respuesta inválida del servidor'),
        );
        return false;
      }

      final s = Session(
        token: token,
        role: 'vendor',
        adminId: adminId,
        vendorId: vendorId,
        vendorEmail: vendorEmail.isEmpty ? null : vendorEmail,
        vendorName: vendorName.isEmpty ? null : vendorName,
      );

      SessionStore.set(s);
      await sessionRepo.save(s);

      await _location?.stop();
      _location = LocationController(api: api, vendorId: vendorId);
      await _location?.start();

      state = AuthState(status: AuthStatus.vendor, session: s);
      return true;
    } catch (e) {
      final err = _extractApiErrorFromException(e);
      if (err != null) {
        if (err.code == 'SUBSCRIPTION_EXPIRED' || err.code == 'DEVICE_MISMATCH') {
          _block(err.code, err.message);
        } else {
          state = state.copyWith(status: AuthStatus.unauthenticated, lastError: err);
        }
        return false;
      }

      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        lastError: const ApiError(code: 'INTERNAL_ERROR', message: 'No se pudo conectar al backend'),
      );
      return false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _location?.stop();
    super.dispose();
  }
}
