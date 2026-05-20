import 'package:flutter_test/flutter_test.dart';
import 'package:catat_duit/features/transactions/parser/amount_parser.dart';

void main() {
  group('AmountParser', () {
    test('parses "50rb" as 50000', () {
      expect(AmountParser.parse('50rb'), 50000);
    });

    test('parses "50k" as 50000', () {
      expect(AmountParser.parse('50k kopi'), 50000);
    });

    test('parses "1.2jt" as 1200000', () {
      expect(AmountParser.parse('1.2jt gaji'), 1200000);
    });

    test('parses "350.000" as 350000', () {
      expect(AmountParser.parse('bayar listrik 350.000'), 350000);
    });

    test('parses plain "50000"', () {
      expect(AmountParser.parse('50000 kopi'), 50000);
    });

    test('returns null for empty input', () {
      expect(AmountParser.parse(''), null);
    });

    test('strips amount tokens', () {
      expect(AmountParser.stripAmount('50rb kopi'), 'kopi');
      expect(AmountParser.stripAmount('1.2jt gaji bulanan'), 'gaji bulanan');
      expect(AmountParser.stripAmount('350.000 listrik'), 'listrik');
    });
  });
}
