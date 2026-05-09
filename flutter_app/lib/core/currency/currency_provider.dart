import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─────────────────────────────────────────────
// CurrencyConfig model
// ─────────────────────────────────────────────
class CurrencyConfig {
  final String code;
  final String symbol;
  final String name;
  final int decimals;

  const CurrencyConfig({
    required this.code,
    required this.symbol,
    required this.name,
    required this.decimals,
  });

  static const defaultCurrency = CurrencyConfig(
    code: 'COP',
    symbol: '\$',
    name: 'Peso colombiano',
    decimals: 0,
  );

  /// Full format with thousands separator: $1,234,567
  String fmt(double v) {
    final abs = v.abs();
    final sign = v < 0 ? '-' : '';
    String digits;
    if (decimals == 0) {
      digits = _thousands(abs.round().toString());
    } else {
      final parts = abs.toStringAsFixed(decimals).split('.');
      digits = '${_thousands(parts[0])}.${parts[1]}';
    }
    return '$sign$symbol$digits';
  }

  /// Compact format: $1.2M, $3.4K
  String fmtCompact(double v) {
    final abs = v.abs();
    final sign = v < 0 ? '-' : '';
    if (abs >= 1000000) return '$sign$symbol${(abs / 1000000).toStringAsFixed(1)}M';
    if (abs >= 1000) return '$sign$symbol${(abs / 1000).toStringAsFixed(1)}K';
    return '$sign$symbol${abs.toStringAsFixed(decimals == 0 ? 0 : 2)}';
  }

  static String _thousands(String s) {
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ─────────────────────────────────────────────
// Available currencies
// ─────────────────────────────────────────────
const List<CurrencyConfig> kAvailableCurrencies = [
  // ── Latinoamérica ──────────────────────────────────────────────────────────
  CurrencyConfig(code: 'COP', symbol: '\$', name: 'Peso colombiano', decimals: 0),
  CurrencyConfig(code: 'MXN', symbol: '\$', name: 'Peso mexicano', decimals: 2),
  CurrencyConfig(code: 'ARS', symbol: '\$', name: 'Peso argentino', decimals: 2),
  CurrencyConfig(code: 'CLP', symbol: '\$', name: 'Peso chileno', decimals: 0),
  CurrencyConfig(code: 'PEN', symbol: 'S/', name: 'Sol peruano', decimals: 2),
  CurrencyConfig(code: 'BRL', symbol: 'R\$', name: 'Real brasileño', decimals: 2),
  CurrencyConfig(code: 'BOB', symbol: 'Bs.', name: 'Boliviano', decimals: 2),
  CurrencyConfig(code: 'UYU', symbol: '\$', name: 'Peso uruguayo', decimals: 2),
  CurrencyConfig(code: 'PYG', symbol: '₲', name: 'Guaraní paraguayo', decimals: 0),
  CurrencyConfig(code: 'VES', symbol: 'Bs.', name: 'Bolívar venezolano', decimals: 2),
  CurrencyConfig(code: 'GTQ', symbol: 'Q', name: 'Quetzal guatemalteco', decimals: 2),
  CurrencyConfig(code: 'HNL', symbol: 'L', name: 'Lempira hondureño', decimals: 2),
  CurrencyConfig(code: 'CRC', symbol: '₡', name: 'Colón costarricense', decimals: 0),
  CurrencyConfig(code: 'NIO', symbol: 'C\$', name: 'Córdoba nicaragüense', decimals: 2),
  CurrencyConfig(code: 'DOP', symbol: '\$', name: 'Peso dominicano', decimals: 2),
  CurrencyConfig(code: 'PAB', symbol: 'B/.', name: 'Balboa panameño', decimals: 2),
  CurrencyConfig(code: 'CUP', symbol: '\$', name: 'Peso cubano', decimals: 2),
  CurrencyConfig(code: 'JMD', symbol: 'J\$', name: 'Dólar jamaicano', decimals: 2),
  CurrencyConfig(code: 'TTD', symbol: 'TT\$', name: 'Dólar de Trinidad y Tobago', decimals: 2),
  CurrencyConfig(code: 'HTG', symbol: 'G', name: 'Gourde haitiano', decimals: 2),
  CurrencyConfig(code: 'BSD', symbol: 'B\$', name: 'Dólar bahameño', decimals: 2),
  CurrencyConfig(code: 'BBD', symbol: 'Bds\$', name: 'Dólar de Barbados', decimals: 2),
  CurrencyConfig(code: 'XCD', symbol: 'EC\$', name: 'Dólar del Caribe Oriental', decimals: 2),
  CurrencyConfig(code: 'GYD', symbol: 'G\$', name: 'Dólar guyanés', decimals: 2),
  CurrencyConfig(code: 'SRD', symbol: 'Sr\$', name: 'Dólar surinamés', decimals: 2),
  CurrencyConfig(code: 'BZD', symbol: 'BZ\$', name: 'Dólar de Belice', decimals: 2),
  // ── Norteamérica ──────────────────────────────────────────────────────────
  CurrencyConfig(code: 'USD', symbol: '\$', name: 'Dólar estadounidense', decimals: 2),
  CurrencyConfig(code: 'CAD', symbol: 'CA\$', name: 'Dólar canadiense', decimals: 2),
  // ── Europa ────────────────────────────────────────────────────────────────
  CurrencyConfig(code: 'EUR', symbol: '€', name: 'Euro', decimals: 2),
  CurrencyConfig(code: 'GBP', symbol: '£', name: 'Libra esterlina', decimals: 2),
  CurrencyConfig(code: 'CHF', symbol: 'Fr', name: 'Franco suizo', decimals: 2),
  CurrencyConfig(code: 'NOK', symbol: 'kr', name: 'Corona noruega', decimals: 2),
  CurrencyConfig(code: 'SEK', symbol: 'kr', name: 'Corona sueca', decimals: 2),
  CurrencyConfig(code: 'DKK', symbol: 'kr', name: 'Corona danesa', decimals: 2),
  CurrencyConfig(code: 'PLN', symbol: 'zł', name: 'Esloti polaco', decimals: 2),
  CurrencyConfig(code: 'CZK', symbol: 'Kč', name: 'Corona checa', decimals: 2),
  CurrencyConfig(code: 'HUF', symbol: 'Ft', name: 'Forinto húngaro', decimals: 0),
  CurrencyConfig(code: 'RON', symbol: 'lei', name: 'Leu rumano', decimals: 2),
  CurrencyConfig(code: 'BGN', symbol: 'лв', name: 'Lev búlgaro', decimals: 2),
  CurrencyConfig(code: 'HRK', symbol: 'kn', name: 'Kuna croata', decimals: 2),
  CurrencyConfig(code: 'RSD', symbol: 'din', name: 'Dinar serbio', decimals: 2),
  CurrencyConfig(code: 'BAM', symbol: 'KM', name: 'Marco de Bosnia', decimals: 2),
  CurrencyConfig(code: 'MKD', symbol: 'ден', name: 'Denar macedonio', decimals: 2),
  CurrencyConfig(code: 'ALL', symbol: 'L', name: 'Lek albanés', decimals: 2),
  CurrencyConfig(code: 'ISK', symbol: 'kr', name: 'Corona islandesa', decimals: 0),
  CurrencyConfig(code: 'UAH', symbol: '₴', name: 'Grivna ucraniana', decimals: 2),
  CurrencyConfig(code: 'MDL', symbol: 'lei', name: 'Leu moldavo', decimals: 2),
  CurrencyConfig(code: 'BYN', symbol: 'Br', name: 'Rublo bielorruso', decimals: 2),
  CurrencyConfig(code: 'RUB', symbol: '₽', name: 'Rublo ruso', decimals: 2),
  CurrencyConfig(code: 'TRY', symbol: '₺', name: 'Lira turca', decimals: 2),
  CurrencyConfig(code: 'GEL', symbol: '₾', name: 'Lari georgiano', decimals: 2),
  CurrencyConfig(code: 'AMD', symbol: '֏', name: 'Dram armenio', decimals: 0),
  CurrencyConfig(code: 'AZN', symbol: '₼', name: 'Manat azerbaiyano', decimals: 2),
  // ── Asia ──────────────────────────────────────────────────────────────────
  CurrencyConfig(code: 'JPY', symbol: '¥', name: 'Yen japonés', decimals: 0),
  CurrencyConfig(code: 'CNY', symbol: '¥', name: 'Yuan chino', decimals: 2),
  CurrencyConfig(code: 'HKD', symbol: 'HK\$', name: 'Dólar de Hong Kong', decimals: 2),
  CurrencyConfig(code: 'KRW', symbol: '₩', name: 'Won surcoreano', decimals: 0),
  CurrencyConfig(code: 'TWD', symbol: 'NT\$', name: 'Dólar taiwanés', decimals: 2),
  CurrencyConfig(code: 'SGD', symbol: 'S\$', name: 'Dólar de Singapur', decimals: 2),
  CurrencyConfig(code: 'INR', symbol: '₹', name: 'Rupia india', decimals: 2),
  CurrencyConfig(code: 'PKR', symbol: '₨', name: 'Rupia pakistaní', decimals: 2),
  CurrencyConfig(code: 'BDT', symbol: '৳', name: 'Taka bangladesí', decimals: 2),
  CurrencyConfig(code: 'LKR', symbol: 'Rs', name: 'Rupia de Sri Lanka', decimals: 2),
  CurrencyConfig(code: 'NPR', symbol: 'रु', name: 'Rupia nepalesa', decimals: 2),
  CurrencyConfig(code: 'MVR', symbol: 'Rf', name: 'Rufiyaa de Maldivas', decimals: 2),
  CurrencyConfig(code: 'IDR', symbol: 'Rp', name: 'Rupia indonesia', decimals: 0),
  CurrencyConfig(code: 'MYR', symbol: 'RM', name: 'Ringgit malayo', decimals: 2),
  CurrencyConfig(code: 'THB', symbol: '฿', name: 'Baht tailandés', decimals: 2),
  CurrencyConfig(code: 'VND', symbol: '₫', name: 'Dong vietnamita', decimals: 0),
  CurrencyConfig(code: 'PHP', symbol: '₱', name: 'Peso filipino', decimals: 2),
  CurrencyConfig(code: 'KHR', symbol: '៛', name: 'Riel camboyano', decimals: 0),
  CurrencyConfig(code: 'LAK', symbol: '₭', name: 'Kip laosiano', decimals: 0),
  CurrencyConfig(code: 'MMK', symbol: 'K', name: 'Kyat birmano', decimals: 2),
  CurrencyConfig(code: 'BND', symbol: 'B\$', name: 'Dólar de Brunéi', decimals: 2),
  CurrencyConfig(code: 'KZT', symbol: '₸', name: 'Tenge kazajo', decimals: 2),
  CurrencyConfig(code: 'UZS', symbol: 'soʻm', name: 'Som uzbeko', decimals: 0),
  CurrencyConfig(code: 'TJS', symbol: 'SM', name: 'Somoni tayiko', decimals: 2),
  CurrencyConfig(code: 'KGS', symbol: 'лв', name: 'Som kirguís', decimals: 2),
  CurrencyConfig(code: 'MNT', symbol: '₮', name: 'Tugrik mongol', decimals: 0),
  CurrencyConfig(code: 'AFN', symbol: '؋', name: 'Afgani afgano', decimals: 2),
  CurrencyConfig(code: 'IRR', symbol: '﷼', name: 'Rial iraní', decimals: 0),
  CurrencyConfig(code: 'IQD', symbol: 'ع.د', name: 'Dinar iraquí', decimals: 3),
  CurrencyConfig(code: 'SAR', symbol: '﷼', name: 'Riyal saudí', decimals: 2),
  CurrencyConfig(code: 'AED', symbol: 'د.إ', name: 'Dírham emiratí', decimals: 2),
  CurrencyConfig(code: 'KWD', symbol: 'د.ك', name: 'Dinar kuwaití', decimals: 3),
  CurrencyConfig(code: 'BHD', symbol: '.د.ب', name: 'Dinar bareiní', decimals: 3),
  CurrencyConfig(code: 'QAR', symbol: 'ر.ق', name: 'Riyal catarí', decimals: 2),
  CurrencyConfig(code: 'OMR', symbol: 'ر.ع.', name: 'Rial omaní', decimals: 3),
  CurrencyConfig(code: 'JOD', symbol: 'JD', name: 'Dinar jordano', decimals: 3),
  CurrencyConfig(code: 'LBP', symbol: 'ل.ل', name: 'Libra libanesa', decimals: 2),
  CurrencyConfig(code: 'SYP', symbol: '£', name: 'Libra siria', decimals: 2),
  CurrencyConfig(code: 'ILS', symbol: '₪', name: 'Séquel israelí', decimals: 2),
  CurrencyConfig(code: 'YER', symbol: '﷼', name: 'Rial yemení', decimals: 2),
  // ── África ────────────────────────────────────────────────────────────────
  CurrencyConfig(code: 'ZAR', symbol: 'R', name: 'Rand sudafricano', decimals: 2),
  CurrencyConfig(code: 'NGN', symbol: '₦', name: 'Naira nigeriana', decimals: 2),
  CurrencyConfig(code: 'KES', symbol: 'Ksh', name: 'Chelín keniano', decimals: 2),
  CurrencyConfig(code: 'GHS', symbol: 'GH₵', name: 'Cedi ghanés', decimals: 2),
  CurrencyConfig(code: 'UGX', symbol: 'USh', name: 'Chelín ugandés', decimals: 0),
  CurrencyConfig(code: 'TZS', symbol: 'TSh', name: 'Chelín tanzano', decimals: 0),
  CurrencyConfig(code: 'ETB', symbol: 'Br', name: 'Birr etíope', decimals: 2),
  CurrencyConfig(code: 'EGP', symbol: '£', name: 'Libra egipcia', decimals: 2),
  CurrencyConfig(code: 'MAD', symbol: 'د.م.', name: 'Dírham marroquí', decimals: 2),
  CurrencyConfig(code: 'DZD', symbol: 'دج', name: 'Dinar argelino', decimals: 2),
  CurrencyConfig(code: 'TND', symbol: 'DT', name: 'Dinar tunecino', decimals: 3),
  CurrencyConfig(code: 'LYD', symbol: 'ل.د', name: 'Dinar libio', decimals: 3),
  CurrencyConfig(code: 'SDG', symbol: 'ج.س.', name: 'Libra sudanesa', decimals: 2),
  CurrencyConfig(code: 'XOF', symbol: 'Fr', name: 'Franco CFA Oeste África', decimals: 0),
  CurrencyConfig(code: 'XAF', symbol: 'Fr', name: 'Franco CFA Central África', decimals: 0),
  CurrencyConfig(code: 'MZN', symbol: 'MT', name: 'Metical mozambiqueño', decimals: 2),
  CurrencyConfig(code: 'ZMW', symbol: 'ZK', name: 'Kwacha zambiano', decimals: 2),
  CurrencyConfig(code: 'BWP', symbol: 'P', name: 'Pula botsuanesa', decimals: 2),
  CurrencyConfig(code: 'MWK', symbol: 'MK', name: 'Kwacha malauí', decimals: 2),
  CurrencyConfig(code: 'RWF', symbol: 'Fr', name: 'Franco ruandés', decimals: 0),
  CurrencyConfig(code: 'SOS', symbol: 'Sh', name: 'Chelín somalí', decimals: 2),
  CurrencyConfig(code: 'MUR', symbol: '₨', name: 'Rupia mauriciana', decimals: 2),
  CurrencyConfig(code: 'MGA', symbol: 'Ar', name: 'Ariary malgache', decimals: 2),
  CurrencyConfig(code: 'SCR', symbol: '₨', name: 'Rupia de Seychelles', decimals: 2),
  CurrencyConfig(code: 'LSL', symbol: 'L', name: 'Loti de Lesoto', decimals: 2),
  CurrencyConfig(code: 'NAD', symbol: 'N\$', name: 'Dólar namibio', decimals: 2),
  CurrencyConfig(code: 'AOA', symbol: 'Kz', name: 'Kwanza angoleño', decimals: 2),
  CurrencyConfig(code: 'GNF', symbol: 'Fr', name: 'Franco guineano', decimals: 0),
  CurrencyConfig(code: 'CMF', symbol: 'Fr', name: 'Franco camerunés', decimals: 0),
  // ── Oceanía ───────────────────────────────────────────────────────────────
  CurrencyConfig(code: 'AUD', symbol: 'A\$', name: 'Dólar australiano', decimals: 2),
  CurrencyConfig(code: 'NZD', symbol: 'NZ\$', name: 'Dólar neozelandés', decimals: 2),
  CurrencyConfig(code: 'FJD', symbol: 'FJ\$', name: 'Dólar fiyiano', decimals: 2),
  CurrencyConfig(code: 'PGK', symbol: 'K', name: 'Kina de Papúa Nueva Guinea', decimals: 2),
  CurrencyConfig(code: 'SBD', symbol: 'SI\$', name: 'Dólar de Islas Salomón', decimals: 2),
  CurrencyConfig(code: 'VUV', symbol: 'Vt', name: 'Vatu de Vanuatu', decimals: 0),
  CurrencyConfig(code: 'WST', symbol: 'WS\$', name: 'Tālā samoano', decimals: 2),
  CurrencyConfig(code: 'XPF', symbol: 'Fr', name: 'Franco CFP (Polinesia)', decimals: 0),
  CurrencyConfig(code: 'TOP', symbol: 'T\$', name: 'Paʻanga tongano', decimals: 2),
];

// ─────────────────────────────────────────────
// Notifier + Provider
// ─────────────────────────────────────────────
class CurrencyNotifier extends StateNotifier<CurrencyConfig> {
  final FlutterSecureStorage _storage;
  static const _storageKey = 'preferred_currency_code';

  CurrencyNotifier(this._storage) : super(CurrencyConfig.defaultCurrency) {
    _init();
  }

  Future<void> _init() async {
    final code = await _storage.read(key: _storageKey);
    if (code == null) return;
    final found = kAvailableCurrencies.firstWhere(
      (c) => c.code == code,
      orElse: () => CurrencyConfig.defaultCurrency,
    );
    state = found;
  }

  Future<void> setCurrency(CurrencyConfig config) async {
    state = config;
    await _storage.write(key: _storageKey, value: config.code);
  }
}

