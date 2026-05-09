class Dates {
  static String todayYmd() => ymd(DateTime.now());

  static String ymd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static DateTime? tryParseYmd(String s) {
    try {
      final parts = s.split('-').map(int.parse).toList();
      if (parts.length != 3) return null;
      return DateTime(parts[0], parts[1], parts[2]);
    } catch (_) {
      return null;
    }
  }

  // ✅ RFC3339 UTC con Z
  // Ej: 2026-01-09T12:34:56.789Z
  static String nowIsoUtc() {
    final d = DateTime.now().toUtc();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    final ss = d.second.toString().padLeft(2, '0');
    final ms = d.millisecond.toString().padLeft(3, '0');
    return '$y-$m-$day' 'T' '$hh:$mm:$ss.$ms' 'Z';
  }

  // ✅ RFC3339 con offset + milisegundos (3 dígitos)
  // Ej: 2026-01-09T12:34:56.789-05:00
  static String nowIsoWithOffset() {
    final d = DateTime.now();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm2 = d.minute.toString().padLeft(2, '0');
    final ss = d.second.toString().padLeft(2, '0');
    final ms = d.millisecond.toString().padLeft(3, '0');

    final off = d.timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    final abs = off.abs();
    final oh = abs.inHours.toString().padLeft(2, '0');
    final om = (abs.inMinutes % 60).toString().padLeft(2, '0');

    return '$y-$m-$day' 'T' '$hh:$mm2:$ss.$ms$sign$oh:$om';
  }
}
