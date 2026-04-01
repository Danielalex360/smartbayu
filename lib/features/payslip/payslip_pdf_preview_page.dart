// lib/features/payslip/payslip_pdf_preview_page.dart
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'payslip_pdf_helper.dart';

class PayslipPdfPreviewPage extends StatelessWidget {
  const PayslipPdfPreviewPage({
    super.key,
    required this.staff,
    required this.payslip,
  });

  final Map<String, dynamic> staff;
  final Map<String, dynamic> payslip;

  @override
  Widget build(BuildContext context) {
    final periodLabel = (payslip['monthLabel'] ?? payslip['month_label'] ?? '-').toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Payslip – $periodLabel',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: PdfPreview(
        build: (format) => generatePayslipPdf(
          staff: staff,
          payslip: payslip,
        ),
        pdfFileName: 'payslip_$periodLabel.pdf',
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
      ),
    );
  }
}
