import 'package:dio/dio.dart';
import '../../config/app_config.dart';
import '../app_bus.dart';
import '../auth/session_store.dart';
import 'api_error.dart';

class ApiClient {
  final Dio dio;

  ApiClient(this.dio) {
    dio.options = BaseOptions(
      baseUrl: AppConfig.api,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 12),
      headers: {'Content-Type': 'application/json'},
    );

    dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: false,
      responseBody: true,
      error: true,
      logPrint: (o) => print(o),
    ));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final s = SessionStore.session;
          if (s != null && s.token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer ${s.token}';
          }
          handler.next(options);
        },
        onError: (e, handler) {
          final status = e.response?.statusCode;
          final data = e.response?.data;
          final apiErr = ApiError.fromResponse(data, status: status);

          if (status == 401) {
            AppBus.emit(UnauthorizedEvent());
          }

          if (status == 403 &&
              (isSubscriptionExpired(apiErr) || isDeviceMismatch(apiErr))) {
            AppBus.emit(
                BlockingAuthEvent(code: apiErr.code, message: apiErr.message));
          }

          handler.next(e);
        },
      ),
    );

    print('✅ ApiClient baseUrl = ${dio.options.baseUrl}');
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  ApiError? extractError(Map<String, dynamic> body, {int? status}) {
    final ok = body['ok'];
    if (ok == true) return null;
    return ApiError.fromResponse(body, status: status);
  }

  List<dynamic> _extractItems(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is List) return data;
    if (data is Map) {
      final m = data.cast<String, dynamic>();
      final items = m['items'];
      if (items is List) return items;
    }
    final items = body['items'];
    if (items is List) return items;
    return const [];
  }

  // =====================================================
  // ✅ Helpers (NUEVO) para fallback/caja
  // =====================================================
  bool _is404(DioException e) => e.response?.statusCode == 404;
  bool _is405(DioException e) => e.response?.statusCode == 405;
  bool _is500(DioException e) => e.response?.statusCode == 500;

  Map<String, dynamic> _normalizeCashPayload(Map<String, dynamic> payload) {
    final rawType = (payload['movement_type'] ??
            payload['type'] ??
            payload['direction'] ??
            '')
        .toString();

    String movementType;
    if (rawType == 'in' || rawType == 'income' || rawType == 'ingreso') {
      movementType = 'income';
    } else if (rawType == 'out' ||
        rawType == 'expense' ||
        rawType == 'egreso') {
      movementType = 'expense';
    } else {
      movementType = 'income';
    }

    final amount = payload['amount'];

    final note = payload['note'] ??
        payload['description'] ??
        payload['desc'] ??
        payload['concept'] ??
        null;

    return <String, dynamic>{
      'movement_type': movementType,
      'amount': amount,
      'note': note,
      if (payload.containsKey('category')) 'category': payload['category'],
      if (payload.containsKey('occurred_at'))
        'occurred_at': payload['occurred_at'],
      if (payload.containsKey('reference_type'))
        'reference_type': payload['reference_type'],
      if (payload.containsKey('reference_id'))
        'reference_id': payload['reference_id'],
    };
  }

  // -------------------------------------------------
  // 🩺 Health
  // -------------------------------------------------
  Future<Map<String, dynamic>> health() async {
    final r = await dio.get('/health');
    return _asMap(r.data);
  }

  // -------------------------------------------------
  // 🔐 AUTH
  // -------------------------------------------------
  Future<Map<String, dynamic>> loginAdmin({
    required String email,
    required String password,
  }) async {
    final r = await dio.post('/auth/admin/login', data: {
      'email': email,
      'password': password,
    });
    return _asMap(r.data);
  }

  Future<Map<String, dynamic>> loginVendor({
    required String email,
    required String password,
    required String deviceId,
  }) async {
    final r = await dio.post('/auth/vendor/login', data: {
      'email': email,
      'password': password,
      'deviceId': deviceId,
    });
    return _asMap(r.data);
  }

  // -------------------------------------------------
  // 👤 ADMIN: VENDORS
  // -------------------------------------------------
  Future<List<dynamic>> getAdminVendors(
    String adminId, {
    String? q,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    final qp = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (q != null && q.trim().isNotEmpty) qp['q'] = q.trim();
    if (status != null && status.isNotEmpty) qp['status'] = status;

    final r = await dio.get('/admins/$adminId/vendors', queryParameters: qp);
    return _extractItems(_asMap(r.data));
  }

  Future<Map<String, dynamic>> createVendor(
      String adminId, Map<String, dynamic> payload) async {
    final r = await dio.post('/admins/$adminId/vendors', data: payload);
    return _asMap(r.data);
  }

  Future<Map<String, dynamic>> updateVendor(
      String vendorId, Map<String, dynamic> payload) async {
    final r = await dio.put('/vendors/$vendorId', data: payload);
    return _asMap(r.data);
  }

  Future<Map<String, dynamic>> deleteVendor(String vendorId) async {
    final r = await dio.delete('/vendors/$vendorId');
    return _asMap(r.data);
  }

  Future<void> resetVendorDevice(String vendorId) async {
    await dio.post('/vendors/$vendorId/reset-device');
  }

  Future<void> forceLogoutVendor(String vendorId) async {
    await dio.post('/vendors/$vendorId/force-logout');
  }

  // -------------------------------------------------
  // 👥 ADMIN: CLIENTS
  // -------------------------------------------------
  Future<List<dynamic>> getAdminClients(
    String adminId, {
    String? q,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    final qp = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (q != null && q.trim().isNotEmpty) qp['q'] = q.trim();
    if (status != null && status.isNotEmpty) qp['status'] = status;

    final r = await dio.get('/admins/$adminId/clients', queryParameters: qp);
    return _extractItems(_asMap(r.data));
  }

  Future<Map<String, dynamic>> createAdminClient(
      String adminId, Map<String, dynamic> payload) async {
    final r = await dio.post('/admins/$adminId/clients', data: payload);
    return _asMap(r.data);
  }

  Future<Map<String, dynamic>> createVendorClient(
      String vendorId, Map<String, dynamic> payload) async {
    final r = await dio.post('/vendors/$vendorId/clients', data: payload);
    return _asMap(r.data);
  }

  Future<Map<String, dynamic>> updateClient(
      String clientId, Map<String, dynamic> payload) async {
    final r = await dio.put('/clients/$clientId', data: payload);
    return _asMap(r.data);
  }

  Future<Map<String, dynamic>> deleteClient(String clientId) async {
    final r = await dio.delete('/clients/$clientId');
    return _asMap(r.data);
  }

  Future<Map<String, dynamic>> getClient(String clientId) async {
    final r = await dio.get('/clients/$clientId');
    return _asMap(r.data);
  }

  // -------------------------------------------------
  // 🚗 ADMIN: ROUTES
  // -------------------------------------------------
  Future<List<dynamic>> getAdminRoutes(
    String adminId, {
    String? q,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    final qp = <String, dynamic>{'limit': limit, 'offset': offset};
    if (q != null && q.trim().isNotEmpty) qp['q'] = q.trim();
    if (status != null && status.isNotEmpty) qp['status'] = status;

    final r = await dio.get('/admins/$adminId/routes', queryParameters: qp);
    return _extractItems(_asMap(r.data));
  }

  Future<Map<String, dynamic>> createRoute(
      String adminId, Map<String, dynamic> payload) async {
    final r = await dio.post('/admins/$adminId/routes', data: payload);
    return _asMap(r.data);
  }

  Future<Map<String, dynamic>> updateRoute(
      String routeId, Map<String, dynamic> payload) async {
    final r = await dio.put('/routes/$routeId', data: payload);
    return _asMap(r.data);
  }

  Future<Map<String, dynamic>> deleteRoute(String routeId) async {
    final r = await dio.delete('/routes/$routeId');
    return _asMap(r.data);
  }

  Future<List<dynamic>> getRouteClients(String routeId) async {
    final r = await dio.get('/routes/$routeId/clients');
    return _extractItems(_asMap(r.data));
  }

  Future<Map<String, dynamic>> setRouteClients(
      String routeId, List<Map<String, dynamic>> clients) async {
    final r =
        await dio.post('/routes/$routeId/clients', data: {'clients': clients});
    return _asMap(r.data);
  }

  Future<Map<String, dynamic>> reorderRouteClients(
      String routeId, List<Map<String, dynamic>> items) async {
    final r = await dio
        .put('/routes/$routeId/clients/reorder', data: {'items': items});
    return _asMap(r.data);
  }

  Future<Map<String, dynamic>> assignRoute(
      String routeId, Map<String, dynamic> payload) async {
    final r = await dio.post('/routes/$routeId/assign', data: payload);
    return _asMap(r.data);
  }

  // -------------------------------------------------
  // 📅 VENDOR: RouteDay y Cash
  // -------------------------------------------------
  Future<Map<String, dynamic>> getVendorRouteDay(
      String vendorId, String dateYYYYMMDD) async {
    final r = await dio.get('/vendors/$vendorId/route-day',
        queryParameters: {'date': dateYYYYMMDD});
    return _asMap(r.data);
  }

  Future<Map<String, dynamic>> createRouteVisit(
      Map<String, dynamic> payload) async {
    final r = await dio.post('/route-visits', data: payload);
    return _asMap(r.data);
  }

  Future<Map<String, dynamic>> closeRouteDay(
      String vendorId, String dateYYYYMMDD) async {
    final r = await dio.post(
      '/vendors/$vendorId/route-day/close',
      data: {'date': dateYYYYMMDD},
    );
    return _asMap(r.data);
  }

  Future<List<dynamic>> getVendorClientsLegacy(String vendorId,
      {int limit = 100}) async {
    final r = await dio.get('/vendors/$vendorId/clients', queryParameters: {
      'limit': limit,
      'offset': 0,
    });
    return _extractItems(_asMap(r.data));
  }

  Future<List<dynamic>> getVendorCash(String vendorId, String day,
      {int limit = 100, int offset = 0}) async {
    final r = await dio.get('/vendors/$vendorId/cash', queryParameters: {
      'date': day,
      'limit': limit,
      'offset': offset,
    });
    return _extractItems(_asMap(r.data));
  }

  Future<Map<String, dynamic>> getVendorCashSummary(
      String vendorId, String dateYYYYMMDD) async {
    DioException? lastErr;

    // 1) Endpoint legacy (si existe)
    try {
      final r = await dio.get(
        '/vendors/$vendorId/cash/summary',
        queryParameters: {'date': dateYYYYMMDD},
      );
      return _asMap(r.data);
    } on DioException catch (e) {
      lastErr = e;
    }

    // 2) Endpoint nuevo (sin vendorId)
    try {
      final r = await dio.get(
        '/cash/summary',
        queryParameters: {'date': dateYYYYMMDD},
      );
      return _asMap(r.data);
    } on DioException catch (e) {
      lastErr = e;
    }

    // 3) Fallback: calcular desde /vendors/:vendorId/cash
    double income = 0;
    double expense = 0;

    const limit = 100;
    int offset = 0;

    for (int guard = 0; guard < 50; guard++) {
      final r = await dio.get('/vendors/$vendorId/cash', queryParameters: {
        'date': dateYYYYMMDD,
        'limit': limit,
        'offset': offset,
      });

      final body = _asMap(r.data);
      final items = _extractItems(body);

      for (final it in items) {
        final m = (it as Map).cast<String, dynamic>();
        final mt = (m['movement_type'] ?? m['type'] ?? m['direction'] ?? '')
            .toString();
        final amtRaw = m['amount'];
        final amt = (amtRaw is num)
            ? amtRaw.toDouble()
            : double.tryParse(amtRaw?.toString() ?? '0') ?? 0;

        if (mt == 'expense' || mt == 'out') {
          expense += amt;
        } else {
          income += amt;
        }
      }

      if (items.length < limit) break;
      offset += limit;
    }

    return {
      'ok': true,
      'data': {
        'income': income,
        'expense': expense,
        'net': income - expense,
        'date': dateYYYYMMDD,
        'source': 'computed_from_list',
        if (lastErr != null)
          'fallback_error': lastErr.response?.data ?? lastErr.message,
      }
    };
  }

  Future<void> postVendorLocation(
      String vendorId, Map<String, dynamic> payload) async {
    await dio.post('/vendors/$vendorId/location', data: payload);
  }

  // -------------------------------------------------
  // 📊 STATS
  // -------------------------------------------------
  Future<Map<String, dynamic>> getVendorStats(String vendorId) async {
    try {
      final r = await dio.get('/vendors/$vendorId/stats');
      return _asMap(r.data);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<Map<String, dynamic>> getAdminStats(String adminId) async {
    try {
      final r = await dio.get('/admins/$adminId/stats');
      return _asMap(r.data);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  // -------------------------------------------------
  // 💰 VENDOR: Cash Movements
  // -------------------------------------------------
  Future<Map<String, dynamic>> createVendorCashMovement(
      String vendorId, Map<String, dynamic> payload) async {
    final r =
        await dio.post('/vendors/$vendorId/cash/movements', data: payload);
    return _asMap(r.data);
  }

  // -------------------------------------------------
  // 💳 CLIENTES: Créditos y Pagos
  // -------------------------------------------------
  Future<Map<String, dynamic>> createCredit(
      String clientId, Map<String, dynamic> payload) async {
    final r = await dio.post('/clients/$clientId/credits', data: payload);
    return _asMap(r.data);
  }

  Future<Map<String, dynamic>> createPayment(
      String creditId, Map<String, dynamic> payload) async {
    final r = await dio.post('/credits/$creditId/payments', data: payload);
    return _asMap(r.data);
  }

  // -------------------------------------------------
  // 📍 LOCALIZACIÓN VENDEDOR
  // -------------------------------------------------
  Future<Map<String, dynamic>> getVendorLocationLatest(
      String adminId, String vendorId) async {
    final r =
        await dio.get('/admins/$adminId/vendors/$vendorId/location/latest');
    return _asMap(r.data);
  }

  Future<List<dynamic>> getVendorLocationHistoryLegacy(
      String adminId, String vendorId) async {
    final r =
        await dio.get('/admins/$adminId/vendors/$vendorId/location/history');
    return _extractItems(_asMap(r.data));
  }

  // =====================================================
  // ADMIN · CASH  ✅ FIX
  // - Intenta 2 endpoints (nuevo y legacy)
  // - Si ambos fallan, calcula el summary desde la lista /admins/:adminId/cash
  // =====================================================
  Future<Map<String, dynamic>> getAdminCashSummary(
      String adminId, String dateYYYYMMDD) async {
    DioException? lastErr;

    // ✅ 1) Endpoint NUEVO (recomendado): no necesita adminId en la URL
    try {
      final r = await dio.get(
        '/cash/summary',
        queryParameters: {'date': dateYYYYMMDD},
      );
      return _asMap(r.data);
    } on DioException catch (e) {
      lastErr = e;
      // seguimos al legacy
    }

    // ✅ 2) Endpoint LEGACY (por compat)
    try {
      final r = await dio.get(
        '/admins/$adminId/cash/summary',
        queryParameters: {'date': dateYYYYMMDD},
      );
      return _asMap(r.data);
    } on DioException catch (e) {
      lastErr = e;
      // seguimos al compute
    }

    // ✅ 3) ÚLTIMO FALLBACK: calcular summary desde la lista
    double income = 0;
    double expense = 0;

    // ✅ BACKEND VALIDA max 100
    const limit = 100;
    int offset = 0;

    for (int guard = 0; guard < 50; guard++) {
      final r = await dio.get(
        '/admins/$adminId/cash',
        queryParameters: {
          'date': dateYYYYMMDD,
          'limit': limit,
          'offset': offset,
        },
      );

      final body = _asMap(r.data);
      final items = _extractItems(body);

      for (final it in items) {
        final m = (it as Map).cast<String, dynamic>();
        final mt = (m['movement_type'] ?? m['type'] ?? m['direction'] ?? '')
            .toString();
        final amtRaw = m['amount'];
        final amt = (amtRaw is num)
            ? amtRaw.toDouble()
            : double.tryParse(amtRaw?.toString() ?? '0') ?? 0;

        if (mt == 'expense' || mt == 'out') {
          expense += amt;
        } else {
          income += amt;
        }
      }

      if (items.length < limit) break;
      offset += limit;
    }

    return {
      'ok': true,
      'data': {
        'income': income,
        'expense': expense,
        'net': income - expense,
        'date': dateYYYYMMDD,
        'source': 'computed_from_list',
        if (lastErr != null)
          'fallback_error': lastErr.response?.data ?? lastErr.message,
      }
    };
  }

  Future<List<dynamic>> getAdminCash(
    String adminId,
    String dateYYYYMMDD, {
    int limit = 100,
    int offset = 0,
  }) async {
    final r = await dio.get(
      '/admins/$adminId/cash',
      queryParameters: {
        'date': dateYYYYMMDD,
        'limit': limit,
        'offset': offset,
      },
    );

    final items = _extractItems(_asMap(r.data));

    // ✅ compat: backend devuelve movement_type/note, UI lee type/description
    return items.map((e) {
      final m = (e as Map).cast<String, dynamic>();

      final mt = (m['movement_type'] ?? '').toString();
      if (!m.containsKey('type') && mt.isNotEmpty) {
        m['type'] = (mt == 'expense') ? 'out' : 'in';
      }

      if (!m.containsKey('description') && m['note'] != null) {
        m['description'] = m['note'];
      }

      return m;
    }).toList();
  }

  Future<Map<String, dynamic>> createAdminCashMovement(
    String adminId,
    Map<String, dynamic> payload,
  ) async {
    final data = _normalizeCashPayload(payload);

    try {
      final r = await dio.post('/admins/$adminId/cash/movements', data: data);
      return _asMap(r.data);
    } on DioException catch (e) {
      if (_is404(e) || _is405(e)) {
        final r2 = await dio.post('/admins/$adminId/cash', data: data);
        return _asMap(r2.data);
      }
      rethrow;
    }
  }

  // =====================================================
  // ADMIN · REPORTS
  // =====================================================
  Future<Map<String, dynamic>> getCollectionsReport(
      String adminId, String dateYYYYMMDD) async {
    final r = await dio.get(
      '/admins/$adminId/reports/collections',
      queryParameters: {'date': dateYYYYMMDD},
    );
    return _asMap(r.data);
  }

  Future<Map<String, dynamic>> getLateClientsReport(
      String adminId, String dateYYYYMMDD) async {
    final r = await dio.get(
      '/admins/$adminId/reports/late-clients',
      queryParameters: {'date': dateYYYYMMDD},
    );
    return _asMap(r.data);
  }

  Future<Map<String, dynamic>> getVendorPerformanceReport(
      String adminId, String dateYYYYMMDD) async {
    final r = await dio.get(
      '/admins/$adminId/reports/vendor-performance',
      queryParameters: {'date': dateYYYYMMDD},
    );
    return _asMap(r.data);
  }

  Future<String> getCollectionsCsv(String adminId, String dateYYYYMMDD) async {
    final r = await dio.get(
      '/admins/$adminId/reports/collections/csv',
      queryParameters: {'date': dateYYYYMMDD},
      options: Options(responseType: ResponseType.plain),
    );
    return r.data.toString();
  }

  // =====================================================
  // ADMIN · VENDORS
  // =====================================================
  Future<Map<String, dynamic>> getVendor(String vendorId) async {
    final r = await dio.get('/vendors/$vendorId');
    return _asMap(r.data);
  }

  // =====================================================
  // VENDOR · CLIENTS (con q)
  // =====================================================
  Future<List<dynamic>> getVendorClients(
    String vendorId, {
    String? q,
    int limit = 100,
    int offset = 0,
  }) async {
    final qp = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (q != null && q.isNotEmpty) qp['q'] = q;

    final r = await dio.get('/vendors/$vendorId/clients', queryParameters: qp);
    return _extractItems(_asMap(r.data));
  }

  // =====================================================
  // VENDOR · PAYMENTS (con q)
  // =====================================================
  Future<List<dynamic>> getVendorPayments(
    String vendorId, {
    String? q,
    int limit = 100,
    int offset = 0,
  }) async {
    final qp = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (q != null && q.isNotEmpty) qp['q'] = q;

    final r = await dio.get('/vendors/$vendorId/payments', queryParameters: qp);
    return _extractItems(_asMap(r.data));
  }

  // =====================================================
  // ✅ FIX DEFINITIVO: LOCATION HISTORY SIEMPRE MANDA date
  // =====================================================
  Future<List<dynamic>> getVendorLocationHistory(
    String adminId,
    String vendorId, {
    String? date,
    String? from,
    String? to,
    int limit = 500,
    int offset = 0,
  }) async {
    String? d = date ?? from ?? to;

    if (d == null || d.trim().isEmpty) {
      d = DateTime.now().toIso8601String().substring(0, 10);
    }

    final qp = <String, dynamic>{
      'date': d,
      'limit': limit,
      'offset': offset,
    };

    final r = await dio.get(
      '/admins/$adminId/vendors/$vendorId/location/history',
      queryParameters: qp,
    );
    return _extractItems(_asMap(r.data));
  }
}
