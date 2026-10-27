import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/attendance.dart';
import '../services/pdf_open.dart';

/// Build a print-ready PDF of the weekly attendance register (formatted like the
/// paper register) and open it in a new tab for print / save-as-PDF.
Future<void> printAttendanceRegister(
    AttendanceRegister reg, String weekLabel) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      header: (ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('ATTENDANCE REGISTER',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text('${reg.storeName}    ${_ascii(weekLabel)}',
                style: const pw.TextStyle(fontSize: 10)),
            pw.Divider(thickness: 0.8),
          ],
        ),
      ),
      build: (ctx) => [
        pw.Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [for (final e in reg.employees) _employeeTable(e)],
        ),
      ],
    ),
  );
  final bytes = await doc.save();
  final safe = reg.storeName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
  openPdf('attendance_${safe}_${reg.weekStart}.pdf', bytes);
}

/// The standard PDF font (Helvetica) only reliably renders ASCII, so typographic
/// characters (en-dash, bullet, middle-dot) come out as boxes. Fold them to ASCII.
String _ascii(String s) => s
    .replaceAll('–', '-') // –
    .replaceAll('—', '-') // —
    .replaceAll('•', '-') // •
    .replaceAll('·', '-'); // ·

final _border = pw.TableBorder.all(color: PdfColors.grey500, width: 0.5);
const _hdrStyle = pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold);
const _cellStyle = pw.TextStyle(fontSize: 8);

pw.Widget _cell(String text,
    {pw.TextStyle style = _cellStyle, pw.TextAlign align = pw.TextAlign.left}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
    child: pw.Text(_ascii(text),
        style: style, textAlign: align, maxLines: 1, softWrap: false),
  );
}

pw.Widget _employeeTable(AttendanceRow row) {
  return pw.Container(
    width: 262,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(_ascii(row.employeeName),
                  style:
                      pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text('#${_ascii(row.payrollId)}',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
            ],
          ),
        ),
        pw.Table(
          border: _border,
          columnWidths: const {
            0: pw.FixedColumnWidth(60),
            1: pw.FixedColumnWidth(18),
            2: pw.FlexColumnWidth(1),
            3: pw.FixedColumnWidth(46),
            4: pw.FixedColumnWidth(46),
            5: pw.FixedColumnWidth(28),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _cell('Day', style: _hdrStyle),
                _cell('Dt', style: _hdrStyle),
                _cell('Roster', style: _hdrStyle),
                _cell('In', style: _hdrStyle),
                _cell('Out', style: _hdrStyle),
                _cell('Hrs', style: _hdrStyle, align: pw.TextAlign.right),
              ],
            ),
            for (final d in row.days)
              pw.TableRow(children: [
                _cell(d.weekday),
                _cell(d.dayNum, align: pw.TextAlign.center),
                _cell(d.roster ?? ''),
                _cell(d.inTime ?? ''),
                _cell(d.outTime ?? ''),
                _cell(d.hours ?? '', align: pw.TextAlign.right),
              ]),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _cell(''),
                _cell(''),
                _cell(''),
                _cell(''),
                _cell('Total', style: _hdrStyle, align: pw.TextAlign.right),
                _cell(row.totalHours, style: _hdrStyle, align: pw.TextAlign.right),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}
