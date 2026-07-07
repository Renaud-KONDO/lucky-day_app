class PaymentModes {
  // ── Togo ──────────────────────────────────────────
  static const String yasTogo       = 'togocel';        // Togocel/Yas
  static const String moovTogo      = 'moov_tg';       // Moov Africa Togo

  // ── Bénin ─────────────────────────────────────────
  static const String mtnBenin      = 'mtn_open';
  static const String moovBenin     = 'moov';

  // ── Côte d'Ivoire ─────────────────────────────────
  // static const String orangeCi      = 'orange_ci';
  static const String mtnCi         = 'mtn_ci';
  // static const String moovCi        = 'moov_ci';         // Moov Africa CI

  // ── Sénégal ───────────────────────────────────────
  //static const String orangeSn      = 'orange_sn';
  static const String freeSn        = 'free_sn';
  //static const String waveSn        = 'wave_sn';

  // ── Display names ─────────────────────────────────
  static const Map<String, String> displayNames = {
    yasTogo:   'Yas (Togocel)',
    moovTogo:  'Moov Africa Togo',
    mtnBenin:  'MTN Bénin',
    moovBenin: 'Moov Africa Bénin',
    //orangeCi:  "Orange Côte d'Ivoire",
    mtnCi:     "MTN Côte d'Ivoire",
    //moovCi:    "Moov Africa CI",
    //orangeSn:  'Orange Sénégal',
    freeSn:    'Free Sénégal',
    //waveSn:    'Wave Sénégal',
  };
}


class PaymentModeDetector {
  /// Detects the payment mode from a local phone number (8 digits, no country code)
  /// and a country code (TG, BJ, CI, SN).
  /// Returns null if the number/country combination is unrecognized.
  static String? detect({
    required String? localNumber,
    required String countryCode,
  }) {
    // Strip any spaces or dashes just in case
    final n = localNumber?.replaceAll(RegExp(r'[\s\-]'), '') ?? '';
    if (n.length < 2) return null;

    final prefix2 = int.tryParse(n.substring(0, 2));
    if (prefix2 == null) return null;

    switch (countryCode.toUpperCase()) {

      // ── Togo ──────────────────────────────────────
      case 'TG':
        // Yas (Togocel): 91, 92, 93, 71, 72, 73
        if ([91, 92, 93, 70, 71, 72, 73].contains(prefix2)) {
          return PaymentModes.yasTogo;
        }
        // Moov Africa Togo: 99, 98, 97, 96, 79 
        if ([99, 98, 97, 96, 79].contains(prefix2)) {
          return PaymentModes.moovTogo;
        }
        return null;

      // ── Bénin ─────────────────────────────────────
      case 'BJ':
        // MTN Bénin -- ùtn_open: 96, 97, 98, 99, 61, 62, 60
        if ([96, 97, 98, 99, 61, 62, 60].contains(prefix2)) {
          return PaymentModes.mtnBenin;
        }
        // Moov Africa Bénin: 95, 94, 93, 91, 90
        if ([95, 94, 93, 91, 90].contains(prefix2)) {
          return PaymentModes.moovBenin;
        }
        return null;

      // ── Côte d'Ivoire ─────────────────────────────
      case 'CI':
        // Orange CI: 07, 08, 09, 47, 48, 49, 57, 58, 59, 67, 68, 69, 77, 78, 79
        /* if ([07, 08, 09, 47, 48, 49, 57, 58, 59, 67, 68, 69, 77, 78, 79].contains(prefix2)) {
          return PaymentModes.orangeCi;
        } */
        // MTN CI: 05, 25, 45, 65, 85
        if ([05, 25, 45, 65, 85].contains(prefix2)) {
          return PaymentModes.mtnCi;
        }
        // Moov Africa CI: 01, 21, 41, 61, 81
        /* if ([01, 21, 41, 61, 81].contains(prefix2)) {
          return PaymentModes.moovCi;
        } */
        return null;

      // ── Sénégal ───────────────────────────────────
      case 'SN':
        // Orange SN: 76, 77, 78
        /* if ([76, 77, 78].contains(prefix2)) {
          return PaymentModes.orangeSn;
        } */
        // Free SN: 70, 75
        if ([70, 75].contains(prefix2)) {
          return PaymentModes.freeSn;
        }
        // Wave SN: 70 shared with Free — Wave uses its own app, usually 
        // identified at API level. We keep Free for 70, Wave for dedicated flows.
        // Adjust if your API distinguishes them differently.
        return null;

      default:
        return null;
    }
  }

  /// Returns a human-readable provider name, or null if undetected.
  static String? displayName({
    required String localNumber,
    required String countryCode,
  }) {
    final mode = detect(localNumber: localNumber, countryCode: countryCode);
    if (mode == null) return null;
    return PaymentModes.displayNames[mode];
  }
}