class AmountParser {
  /// Parses Indonesian amount notation: "50rb" -> 50000, "1.2jt" -> 1200000, "350.000" -> 350000
  static double? parse(String input) {
    if (input.isEmpty) return null;
    // NOTE: jangan strip spasi — bikin word boundary `\b` di regex suffix
    // gagal kalau token berikutnya kebetulan diawali huruf (mis. "50k kopi").
    final s = input.toLowerCase();

    // Pattern 1: number + suffix (rb, ribu, k, jt, juta, m).
    // Spasi opsional antara angka & suffix ("50 rb" juga valid).
    final suffixPattern = RegExp(r'(\d+(?:[.,]\d+)?)\s*(rb|ribu|k|jt|juta|m)\b');
    final m = suffixPattern.firstMatch(s);
    if (m != null) {
      final num = double.tryParse(m.group(1)!.replaceAll(',', '.'));
      final suffix = m.group(2)!;
      if (num == null) return null;
      switch (suffix) {
        case 'rb':
        case 'ribu':
        case 'k':
          return num * 1000;
        case 'jt':
        case 'juta':
        case 'm':
          return num * 1000000;
      }
    }

    // Pattern 2: number with thousands separator (350.000 / 350,000)
    final cleanPattern = RegExp(r'(\d{1,3}(?:[.,]\d{3})+)');
    final m2 = cleanPattern.firstMatch(s);
    if (m2 != null) {
      final raw = m2.group(1)!.replaceAll(RegExp(r'[.,]'), '');
      return double.tryParse(raw);
    }

    // Pattern 3: plain number
    final small = RegExp(r'(\d+)');
    final m3 = small.firstMatch(s);
    if (m3 != null) {
      return double.tryParse(m3.group(1)!);
    }

    return null;
  }

  /// Returns input with the matched amount portion stripped out.
  static String stripAmount(String input) {
    var s = input.toLowerCase();
    s = s.replaceAll(RegExp(r'\d+(?:[.,]\d+)?\s*(rb|ribu|k|jt|juta|m)\b'), ' ');
    s = s.replaceAll(RegExp(r'\d{1,3}(?:[.,]\d{3})+'), ' ');
    s = s.replaceAll(RegExp(r'\b\d{4,}\b'), ' ');
    s = s.replaceAll(RegExp(r'\b\d+\b'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }
}
