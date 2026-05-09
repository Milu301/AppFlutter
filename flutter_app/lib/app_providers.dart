import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'core/api/api_client.dart';
import 'core/auth/auth_controller.dart';
import 'core/auth/session_repository.dart';
import 'core/currency/currency_provider.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

final sessionRepoProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(ref.read(secureStorageProvider));
});

final dioProvider = Provider<Dio>((ref) => Dio());

final apiProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.read(dioProvider));
});

final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    sessionRepo: ref.read(sessionRepoProvider),
    api: ref.read(apiProvider),
  );
});

// Badge count for overdue credits — updated by vendor dashboard
final overdueCountProvider = StateProvider<int>((ref) => 0);

// User's preferred display currency — persisted across sessions
final currencyProvider =
    StateNotifierProvider<CurrencyNotifier, CurrencyConfig>((ref) {
  return CurrencyNotifier(ref.read(secureStorageProvider));
});
