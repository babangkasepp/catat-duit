/// Hasil parse struk: nominal total, merchant (toko), tanggal, raw text.
class ReceiptParse {
  final double? amount;
  final String? merchant;
  final DateTime? date;
  final String rawText;
  final double confidence; // 0..1

  const ReceiptParse({
    required this.amount,
    required this.merchant,
    required this.date,
    required this.rawText,
    required this.confidence,
  });

  bool get hasAnything => amount != null || merchant != null || date != null;
}

class ReceiptParser {
  // Keywords yang menandakan baris itu = total bayar (urutan = priority)
  static const _totalKeywords = [
    'grand total',
    'total bayar',
    'total tagihan',
    'total belanja',
    'total pembelian',
    'jumlah bayar',
    'yang dibayar',
    'total akhir',
    'total harga',
    'jumlah',
    'total',
    'bayar',
    'tunai',
    'cash',
    'amount',
  ];

  // Skip lines yang BUKAN total (subtotal, kembalian, pajak, diskon, dll)
  static const _skipKeywords = [
    'subtotal',
    'sub total',
    'sub-total',
    'kembali',
    'kembalian',
    'change',
    'pajak',
    'ppn',
    'tax',
    'service',
    'diskon',
    'discount',
    'dpp',
    'cashback',
    'voucher',
    'point',
    'poin',
    'hemat',
    'ongkir',
    'biaya ongkir',
    'shipping',
    'tagihan', // sering muncul sebagai label "LUNAS", bukan amount
  ];

  static ReceiptParse parse(String raw) {
    final cleaned = raw.replaceAll('\r', '');
    final lines = cleaned
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final amount = _extractTotal(lines);
    final merchant = _extractMerchant(lines);
    final date = _extractDate(cleaned);

    var confidence = 0.0;
    if (amount != null) confidence += 0.6;
    if (merchant != null) confidence += 0.25;
    if (date != null) confidence += 0.15;

    return ReceiptParse(
      amount: amount,
      merchant: merchant,
      date: date,
      rawText: raw,
      confidence: confidence,
    );
  }

  // ---------- AMOUNT ----------
  static double? _extractTotal(List<String> lines) {
    // Pass 1 — cari baris yang mengandung total keyword (bukan skip keyword)
    final candidates = <(int idx, String keyword, double value)>[];
    for (var i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase();
      final isSkip = _skipKeywords.any((k) => lower.contains(k));

      // Find best (earliest = most specific) total keyword match
      String? matchedKw;
      for (final kw in _totalKeywords) {
        if (lower.contains(kw)) {
          matchedKw = kw;
          break;
        }
      }
      if (matchedKw == null) continue;

      // Multi-word total keyword wins over skip (e.g. "total tagihan" beats "tagihan").
      // Single-word total keyword (just "total", "bayar", "jumlah") loses to skip
      // (so "subtotal", "total bayar" line wouldn't both fire).
      final isMultiWord = matchedKw.contains(' ');
      if (isSkip && !isMultiWord) continue;

      final amount = _extractMaxNumber(lines[i]) ??
          (i + 1 < lines.length ? _extractMaxNumber(lines[i + 1]) : null);
      if (amount != null && amount >= 1000) {
        candidates.add((i, matchedKw, amount));
      }
    }

    if (candidates.isNotEmpty) {
      // Priority: keyword paling spesifik (urutan _totalKeywords) → kalau sama, ambil terbesar
      candidates.sort((a, b) {
        final ka = _totalKeywords.indexOf(a.$2);
        final kb = _totalKeywords.indexOf(b.$2);
        if (ka != kb) return ka.compareTo(kb);
        return b.$3.compareTo(a.$3);
      });
      return candidates.first.$3;
    }

    // Pass 2 — fallback: angka terbesar di seluruh struk (skip baris dengan skip keyword)
    double? maxN;
    for (final l in lines) {
      final lower = l.toLowerCase();
      if (_skipKeywords.any((k) => lower.contains(k))) continue;
      final n = _extractMaxNumber(l);
      if (n != null && n >= 1000 && (maxN == null || n > maxN)) {
        maxN = n;
      }
    }
    return maxN;
  }

  /// Cari angka format Indonesia dari sebuah baris dan return yang terbesar.
  /// Format yang di-handle:
  ///   12.500          → 12500
  ///   12,500          → 12500
  ///   12.500,00       → 12500
  ///   Rp 12.500       → 12500
  ///   1.234.567       → 1234567
  static double? _extractMaxNumber(String line) {
    // Match angka dengan separator titik/koma, optional decimal
    final regex = RegExp(r'(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d{4,})');
    final matches = regex.allMatches(line);
    double? best;
    for (final m in matches) {
      final raw = m.group(0)!;
      final n = _parseIdNumber(raw);
      if (n != null && (best == null || n > best)) best = n;
    }
    return best;
  }

  static double? _parseIdNumber(String s) {
    // Hilangkan separator. Format Indonesia: titik = ribuan, koma = desimal.
    // Tapi banyak struk pakai koma sebagai ribuan juga.
    // Strategy: kalau ada KEDUA titik & koma, anggap koma = desimal.
    //          kalau cuma satu separator, kalau diikuti tepat 3 digit → ribuan, drop.
    String clean = s.trim();
    final hasDot = clean.contains('.');
    final hasComma = clean.contains(',');

    if (hasDot && hasComma) {
      // 12.500,00 → 12500
      clean = clean.replaceAll('.', '');
      clean = clean.replaceAll(',', '.');
    } else if (hasDot) {
      // 12.500 → cek: kalau group terakhir 3 digit → ribuan
      final parts = clean.split('.');
      if (parts.last.length == 3) {
        clean = clean.replaceAll('.', '');
      } // else: 12.5 → biarkan sebagai desimal
    } else if (hasComma) {
      final parts = clean.split(',');
      if (parts.last.length == 3) {
        clean = clean.replaceAll(',', '');
      } else {
        clean = clean.replaceAll(',', '.');
      }
    }

    return double.tryParse(clean);
  }

  // ---------- MERCHANT ----------
  static String? _extractMerchant(List<String> lines) {
    // Heuristik: dari 5 baris pertama, ambil baris yang:
    //   - panjangnya 3-40 char
    //   - tidak mengandung angka berderet (NPWP/no struk)
    //   - bukan baris alamat (jl., jln, jalan)
    final addressKw = ['jl.', 'jln', 'jalan ', 'no.', 'rt ', 'rw ', 'kec.', 'kel.'];
    for (var i = 0; i < lines.length && i < 6; i++) {
      final l = lines[i];
      if (l.length < 3 || l.length > 40) continue;

      final lower = l.toLowerCase();
      if (addressKw.any((k) => lower.contains(k))) continue;
      if (lower.startsWith('jl ') || lower.startsWith('jln ')) continue;

      // skip kalau >40% digit (kemungkinan NPWP/nomor)
      final digits = RegExp(r'\d').allMatches(l).length;
      if (digits / l.length > 0.4) continue;

      // skip kalau cuma garis/separator
      if (RegExp(r'^[-=*_\s.]+$').hasMatch(l)) continue;

      // skip kata generic
      final genericStart = ['no struk', 'kasir', 'tanggal', 'date', 'time', 'jam'];
      if (genericStart.any((g) => lower.startsWith(g))) continue;

      return _titleCase(l);
    }
    return null;
  }

  static String _titleCase(String s) {
    return s
        .split(RegExp(r'\s+'))
        .map((w) {
          if (w.isEmpty) return w;
          // Preserve short all-caps acronyms (SCH, KFC, JCO, etc.)
          if (w.length <= 4 && w == w.toUpperCase() && RegExp(r'^[A-Z]+$').hasMatch(w)) {
            return w;
          }
          if (w.length == 1) return w.toUpperCase();
          return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  // ---------- DATE ----------
  static DateTime? _extractDate(String text) {
    // Format umum di struk Indonesia:
    //   2026-05-21          (ISO — cek dulu biar gak ke-match parsial sebagai dd-mm-yyyy)
    //   21/05/2026, 21-05-2026, 21.05.2026
    //   21 Mei 2026
    final regexes = <RegExp>[
      RegExp(r'(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})'), // yyyy-mm-dd FIRST
      RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})'), // dd/mm/yyyy
    ];

    for (final r in regexes) {
      final m = r.firstMatch(text);
      if (m != null) {
        try {
          int a = int.parse(m.group(1)!);
          int b = int.parse(m.group(2)!);
          int c = int.parse(m.group(3)!);
          int day, month, year;
          if (a > 31) {
            // yyyy-mm-dd
            year = a;
            month = b;
            day = c;
          } else {
            // dd-mm-yyyy
            day = a;
            month = b;
            year = c < 100 ? 2000 + c : c;
          }
          if (month < 1 || month > 12) continue;
          if (day < 1 || day > 31) continue;
          if (year < 2000 || year > 2100) continue;
          return DateTime(year, month, day);
        } catch (_) {
          continue;
        }
      }
    }

    // Format text: "21 Mei 2026"
    final monthNames = {
      'jan': 1, 'januari': 1,
      'feb': 2, 'februari': 2,
      'mar': 3, 'maret': 3,
      'apr': 4, 'april': 4,
      'mei': 5, 'may': 5,
      'jun': 6, 'juni': 6,
      'jul': 7, 'juli': 7,
      'agu': 8, 'agt': 8, 'agustus': 8, 'aug': 8,
      'sep': 9, 'september': 9,
      'okt': 10, 'oktober': 10, 'oct': 10,
      'nov': 11, 'november': 11,
      'des': 12, 'desember': 12, 'dec': 12,
    };
    final textRegex = RegExp(
      r'(\d{1,2})\s+([a-zA-Z]{3,})\s+(\d{4})',
    );
    final m = textRegex.firstMatch(text);
    if (m != null) {
      final day = int.tryParse(m.group(1)!);
      final mon = monthNames[m.group(2)!.toLowerCase()];
      final year = int.tryParse(m.group(3)!);
      if (day != null && mon != null && year != null) {
        return DateTime(year, mon, day);
      }
    }

    return null;
  }
}


