import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/entry.dart';
import '../../data/services/pdf_export_service.dart';

class PdfPreviewScreen extends StatelessWidget {
  final String title;
  final Future<Uint8List> Function(PdfPageFormat format) buildPdf;

  const PdfPreviewScreen({
    super.key,
    required this.title,
    required this.buildPdf,
  });

  static Future<void> openLoadingSheet(
    BuildContext context, {
    required Entry entry,
    required String despatcherName,
  }) {
    AppHaptics.light();
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => PdfPreviewScreen(
          title: 'Loading Sheet — ${entry.dayKey}',
          buildPdf: (format) => PdfExportService.generateLoadingSheetPdf(entry, despatcherName),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.backgroundSecondary : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? AppColors.textPrimary : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textPrimary : Colors.black87,
              ),
            ),
            const Text(
              'Interactive PDF Preview & Print',
              style: TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
      body: PdfPreview(
        build: buildPdf,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        maxPageWidth: 700,
        pdfFileName: '$title.pdf',
        previewPageMargin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGlow),
        ),
        onError: (ctx, error) => Center(
          child: Text(
            'Error generating PDF preview:\n$error',
            style: const TextStyle(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
