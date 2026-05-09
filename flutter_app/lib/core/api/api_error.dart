class ApiError {
  final String code;
  final String message;
  final int? status;

  const ApiError({
    required this.code,
    required this.message,
    this.status,
  });

  factory ApiError.fromResponse(dynamic data, {int? status}) {
    try {
      if (data is Map<String, dynamic>) {
        final err = data['error'];
        if (err is Map<String, dynamic>) {
          final code = (err['code'] ?? 'INTERNAL_ERROR').toString();
          final msg = (err['message'] ?? 'Error').toString();
          return ApiError(code: code, message: msg, status: status);
        }
      }
    } catch (_) {}
    return ApiError(
      code: 'INTERNAL_ERROR',
      message: 'Error inesperado',
      status: status,
    );
  }

  @override
  String toString() => 'ApiError(code=$code, status=$status, message=$message)';
}

bool isSubscriptionExpired(ApiError e) => e.code == 'SUBSCRIPTION_EXPIRED';
bool isDeviceMismatch(ApiError e) => e.code == 'DEVICE_MISMATCH';
