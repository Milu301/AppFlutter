class Session {
  final String token;
  final String role; // 'admin' | 'vendor'
  final String adminId;
  final String? vendorId;

  // Perfil (opcionales) para UI
  final String? adminEmail;
  final DateTime? subscriptionExpiresAt;

  final String? vendorEmail;
  final String? vendorName;

  const Session({
    required this.token,
    required this.role,
    required this.adminId,
    this.vendorId,
    this.adminEmail,
    this.subscriptionExpiresAt,
    this.vendorEmail,
    this.vendorName,
  });

  Map<String, dynamic> toJson() => {
        'token': token,
        'role': role,
        'adminId': adminId,
        'vendorId': vendorId,
        'adminEmail': adminEmail,
        'subscriptionExpiresAt': subscriptionExpiresAt?.toIso8601String(),
        'vendorEmail': vendorEmail,
        'vendorName': vendorName,
      };

  factory Session.fromJson(Map<String, dynamic> json) {
    DateTime? sub;
    final rawSub = json['subscriptionExpiresAt'];
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

    return Session(
      token: (json['token'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      adminId: (json['adminId'] ?? '').toString(),
      vendorId: json['vendorId']?.toString(),
      adminEmail: json['adminEmail']?.toString(),
      subscriptionExpiresAt: sub,
      vendorEmail: json['vendorEmail']?.toString(),
      vendorName: json['vendorName']?.toString(),
    );
  }
}
