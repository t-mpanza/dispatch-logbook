import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/utils/formatters.dart';
import '../models/entry.dart';

class PdfExportService {
  static Future<Uint8List> generateLoadingSheetPdf(
    Entry entry,
    String despatcherName,
  ) async {
    final pdf = pw.Document();
    final trips = entry.loadingSheetTrips ?? [];

    int totalTyres = 0;
    int totalMinutes = 0;

    for (final t in trips) {
      totalTyres += t.quantityLoaded;
      totalMinutes += t.durationMinutes ?? 0;
    }

    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    final timeFormatted = totalMinutes > 0
        ? (hours > 0 ? '${hours}h ${mins}m (${totalMinutes}m)' : '$totalMinutes mins')
        : '0 mins';

    final hasAnyIbts = trips.any((t) => t.hasIbtDocuments);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DESPATCH LOADING SHEET',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'DAILY COMPLIANCE & LOGISTICS AUDIT',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'DATE: ${entry.dayKey}',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'DESPATCHER: $despatcherName',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(thickness: 1.5, color: PdfColors.blue800),
            pw.SizedBox(height: 10),

            // Summary KPI
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildKpiItem('TOTAL TRUCKS', '${trips.length}'),
                  _buildKpiItem('TOTAL DURATION', timeFormatted),
                  _buildKpiItem('TOTAL TYRES LOADED', '$totalTyres'),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Main Trips Table
            pw.TableHelper.fromTextArray(
              headers: [
                '#',
                'TRIP / IBT',
                'REG',
                'DRIVER',
                'TYRES',
                'START',
                'FINISH',
                'DURATION'
              ],
              data: trips.asMap().entries.map((item) {
                final idx = item.key + 1;
                final t = item.value;
                final ibtTag = t.hasIbtDocuments
                    ? '\n(${t.ibtDocuments!.map((d) => d.documentNo).join(", ")})'
                    : '';
                final tripLabel =
                    (t.tripId.isEmpty ? 'TRIP $idx' : t.tripId) + ibtTag;

                return [
                  '$idx',
                  tripLabel,
                  t.reg.isEmpty ? '-' : t.reg,
                  t.driverName.isEmpty ? '-' : t.driverName,
                  '${t.quantityLoaded}',
                  AppFormatters.formatTimeHHmm(t.startTime).isEmpty
                      ? '-'
                      : AppFormatters.formatTimeHHmm(t.startTime),
                  AppFormatters.formatTimeHHmm(t.finishTime).isEmpty
                      ? '-'
                      : AppFormatters.formatTimeHHmm(t.finishTime),
                  t.durationMinutes != null && t.durationMinutes! > 0
                      ? '${t.durationMinutes}m'
                      : '-',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue800,
              ),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.center,
              columnWidths: {
                0: const pw.FixedColumnWidth(20),
                1: const pw.FlexColumnWidth(2.5),
                2: const pw.FlexColumnWidth(1.8),
                3: const pw.FlexColumnWidth(1.8),
                4: const pw.FixedColumnWidth(36),
                5: const pw.FixedColumnWidth(36),
                6: const pw.FixedColumnWidth(36),
                7: const pw.FixedColumnWidth(40),
              },
            ),

            // Itemized IBT Breakdown Section
            if (hasAnyIbts) ...[
              pw.SizedBox(height: 16),
              pw.Text(
                'ITEMIZED IBT MANIFEST BREAKDOWN',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: [
                  'IBT DOC',
                  'TRIP',
                  'SPECIFICATION / PATTERN',
                  'RCS CODE',
                  'LOADED / TARGET',
                  'STATUS'
                ],
                data: [
                  for (final t in trips)
                    if (t.hasIbtDocuments)
                      for (final doc in t.ibtDocuments!)
                        for (final line in doc.lineItems)
                          [
                            doc.documentNo,
                            t.tripId,
                            line.description,
                            line.rcsCode ?? '-',
                            '${line.loadedQuantity} / ${line.targetTotal}',
                            line.isOverloaded
                                ? '+${line.overCount} OVER'
                                : (line.isShort
                                    ? 'SHORT (${line.remaining})'
                                    : 'COMPLETE'),
                          ]
                ],
                headerStyle: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey800,
                ),
                cellStyle: const pw.TextStyle(fontSize: 7.5),
                cellAlignment: pw.Alignment.center,
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.5),
                  1: const pw.FlexColumnWidth(1.2),
                  2: const pw.FlexColumnWidth(3.0),
                  3: const pw.FlexColumnWidth(1.2),
                  4: const pw.FlexColumnWidth(1.5),
                  5: const pw.FlexColumnWidth(1.5),
                },
              ),
            ],

            pw.SizedBox(height: 20),

            // Signatures
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 150,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(color: PdfColors.black, width: 1),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Despatcher Signature',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 150,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(color: PdfColors.black, width: 1),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Warehouse Manager Signature',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Generated via Dispatch Diary on ${DateTime.now().toLocal()}',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildKpiItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
      ],
    );
  }

  static Future<void> printOrSharePdf(
    Entry entry,
    String despatcherName,
  ) async {
    final bytes = await generateLoadingSheetPdf(entry, despatcherName);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'LoadingSheet_${entry.dayKey}.pdf',
    );
  }
}
