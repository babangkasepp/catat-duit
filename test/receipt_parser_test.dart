import 'package:flutter_test/flutter_test.dart';
import 'package:catat_duit/features/ocr/receipt_parser.dart';

void main() {
  group('ReceiptParser - amount extraction', () {
    test('Indomaret format with TOTAL keyword', () {
      const text = '''
INDOMARET
Jl. Sudirman No. 123
Jakarta

INDOMILK UHT 250ML       6.500
ROTI TAWAR               12.000
KOPI KAPAL API SACHET     2.500

SUBTOTAL                 21.000
DISKON                    1.000
TOTAL                    20.000
TUNAI                    50.000
KEMBALI                  30.000

21/05/2026 14:23
''';
      final r = ReceiptParser.parse(text);
      expect(r.amount, 20000);
      expect(r.merchant, 'Indomaret');
      expect(r.date, DateTime(2026, 5, 21));
      expect(r.confidence, greaterThanOrEqualTo(0.9));
    });

    test('Alfamart with comma as thousand separator', () {
      const text = '''
ALFAMART
Jln. Mawar 5

Item A             5,000
Item B             7,500
TOTAL BAYAR       12,500
''';
      final r = ReceiptParser.parse(text);
      expect(r.amount, 12500);
      expect(r.merchant, 'Alfamart');
    });

    test('amount with decimal (mixed dot and comma)', () {
      const text = '''
Toko Maju
TOTAL  Rp 125.000,00
''';
      final r = ReceiptParser.parse(text);
      expect(r.amount, 125000);
    });

    test('skips subtotal/diskon/kembalian', () {
      const text = '''
Warung Bu Tini
Subtotal         50.000
Diskon            5.000
TOTAL            45.000
TUNAI            50.000
KEMBALI           5.000
''';
      final r = ReceiptParser.parse(text);
      expect(r.amount, 45000);
    });

    test('falls back to largest number when no keyword', () {
      const text = '''
Random Receipt
A 1.000
B 2.000
C 15.000
''';
      final r = ReceiptParser.parse(text);
      expect(r.amount, 15000);
    });
  });

  group('ReceiptParser - merchant extraction', () {
    test('takes first non-address line', () {
      const text = '''
KOPI KENANGAN
Jl. Asia Afrika No. 8
Bandung
''';
      final r = ReceiptParser.parse(text);
      expect(r.merchant, 'Kopi Kenangan');
    });

    test('skips lines that are mostly digits', () {
      const text = '''
NPWP: 01.234.567.8-901.000
Toko Sumber Rejeki
Jl. Merdeka 12
''';
      final r = ReceiptParser.parse(text);
      expect(r.merchant, 'Toko Sumber Rejeki');
    });
  });

  group('ReceiptParser - date extraction', () {
    test('dd/mm/yyyy format', () {
      const text = 'Tanggal: 21/05/2026';
      final r = ReceiptParser.parse(text);
      expect(r.date, DateTime(2026, 5, 21));
    });

    test('yyyy-mm-dd format', () {
      const text = 'Date: 2026-05-21 14:23:00';
      final r = ReceiptParser.parse(text);
      expect(r.date, DateTime(2026, 5, 21));
    });

    test('text month "21 Mei 2026"', () {
      const text = 'Tanggal cetak: 21 Mei 2026';
      final r = ReceiptParser.parse(text);
      expect(r.date, DateTime(2026, 5, 21));
    });

    test('returns null for invalid date', () {
      const text = 'No date here';
      final r = ReceiptParser.parse(text);
      expect(r.date, isNull);
    });
  });

  group('ReceiptParser - edge cases', () {
    test('empty input returns nothing', () {
      final r = ReceiptParser.parse('');
      expect(r.hasAnything, isFalse);
      expect(r.confidence, 0);
    });

    test('hasAnything true when only amount', () {
      const text = 'TOTAL 50.000';
      final r = ReceiptParser.parse(text);
      expect(r.hasAnything, isTrue);
      expect(r.amount, 50000);
    });
  });
}
