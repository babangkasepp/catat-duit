import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../transactions/models/category.dart';
import '../transactions/models/transaction.dart';
import '../transactions/repository/transaction_repository.dart';
import '../transactions/repository/category_repository.dart';
import '../../core/utils/formatters.dart';

class PdfExportService {
  static final _currFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// Generate & share monthly PDF report.
  static Future<File> generateMonthlyReport({
    required int year,
    required int month,
  }) async {
    final txRepo = TransactionRepository();
    final catRepo = CategoryRepository();

    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    final monthName = DateRange.monthName(month);

    final transactions = await txRepo.range(start, end);
    final totals = await txRepo.totals(start, end);
    final byCat = await txRepo.sumByCategory(start, end, 'expense');
    final allCats = await catRepo.all();
    final catMap = {for (final c in allCats) c.id: c};

    final balance = totals.income - totals.expense;

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(monthName, year),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // Summary cards
          _buildSummarySection(totals.income, totals.expense, balance),
          pw.SizedBox(height: 20),

          // Category breakdown
          _buildCategorySection(byCat, catMap, totals.expense),
          pw.SizedBox(height: 20),

          // Transaction list
          _buildTransactionTable(transactions, catMap),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'CatatDuit_${year}_${month.toString().padLeft(2, '0')}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  /// Share the generated PDF file.
  static Future<void> shareReport(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Laporan Keuangan CatatDuit',
      text: 'Laporan keuangan bulanan dari CatatDuit 💸',
    );
  }

  static pw.Widget _buildHeader(String monthName, int year) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Laporan Keuangan',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey800,
                ),
              ),
              pw.Text(
                '$monthName $year',
                style: const pw.TextStyle(
                  fontSize: 14,
                  color: PdfColors.blueGrey600,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'CatatDuit',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.deepPurple,
                ),
              ),
              pw.Text(
                'Generated: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'Halaman ${context.pageNumber} / ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
      ),
    );
  }

  static pw.Widget _buildSummarySection(
      double income, double expense, double balance) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('Pemasukan', income, PdfColors.green700),
          _summaryItem('Pengeluaran', expense, PdfColors.red700),
          _summaryItem(
            'Saldo',
            balance,
            balance >= 0 ? PdfColors.green800 : PdfColors.red800,
          ),
        ],
      ),
    );
  }

  static pw.Widget _summaryItem(String label, double value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey600),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          _currFmt.format(value),
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildCategorySection(
    Map<String, double> byCat,
    Map<String, Category> catMap,
    double totalExpense,
  ) {
    final entries = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return pw.Text('Tidak ada pengeluaran bulan ini.',
          style: const pw.TextStyle(color: PdfColors.grey));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Pengeluaran per Kategori',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey800,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
              children: [
                _tableHeaderCell('Kategori'),
                _tableHeaderCell('Jumlah'),
                _tableHeaderCell('%'),
              ],
            ),
            for (final e in entries)
              pw.TableRow(children: [
                _tableCell(
                    '${catMap[e.key]?.icon ?? ''} ${catMap[e.key]?.name ?? 'Lainnya'}'),
                _tableCell(_currFmt.format(e.value)),
                _tableCell(totalExpense > 0
                    ? '${(e.value / totalExpense * 100).toStringAsFixed(1)}%'
                    : '0%'),
              ]),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _tableCell('TOTAL',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                _tableCell(_currFmt.format(totalExpense),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                _tableCell('100%',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTransactionTable(
    List<Txn> transactions,
    Map<String, Category> catMap,
  ) {
    if (transactions.isEmpty) {
      return pw.Text('Tidak ada transaksi.',
          style: const pw.TextStyle(color: PdfColors.grey));
    }

    final dateFmt = DateFormat('dd/MM');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Daftar Transaksi',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey800,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(3),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
              children: [
                _tableHeaderCell('Tgl'),
                _tableHeaderCell('Kategori'),
                _tableHeaderCell('Catatan'),
                _tableHeaderCell('Tipe'),
                _tableHeaderCell('Nominal'),
              ],
            ),
            for (final t in transactions)
              pw.TableRow(children: [
                _tableCell(dateFmt.format(t.date), fontSize: 8),
                _tableCell(
                  catMap[t.categoryId]?.name ?? '-',
                  fontSize: 8,
                ),
                _tableCell(t.note ?? '-', fontSize: 8),
                _tableCell(
                  t.type == TxnType.income ? 'Masuk' : 'Keluar',
                  fontSize: 8,
                  style: pw.TextStyle(
                    color: t.type == TxnType.income
                        ? PdfColors.green700
                        : PdfColors.red700,
                  ),
                ),
                _tableCell(
                  _currFmt.format(t.amount),
                  fontSize: 8,
                ),
              ]),
          ],
        ),
      ],
    );
  }

  static pw.Widget _tableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blueGrey800,
        ),
      ),
    );
  }

  static pw.Widget _tableCell(String text,
      {double fontSize = 9, pw.TextStyle? style}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: (style ?? const pw.TextStyle()).copyWith(fontSize: fontSize),
      ),
    );
  }
}
