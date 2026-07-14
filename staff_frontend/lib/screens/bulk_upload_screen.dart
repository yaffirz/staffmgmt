import 'dart:convert';
// Web-only file download/upload via the browser. This screen targets Flutter
// web; on a future native build these would be swapped for an OS file picker.
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/bulk_result.dart';
import '../services/api_client.dart';
import '../services/staff_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

enum BulkKind { brands, stores, positions, employees }

class BulkUploadScreen extends StatefulWidget {
  final BulkKind kind;
  const BulkUploadScreen({super.key, required this.kind});

  @override
  State<BulkUploadScreen> createState() => _BulkUploadScreenState();
}

class _BulkUploadScreenState extends State<BulkUploadScreen> {
  late final TextEditingController _csvCtrl;
  bool _processing = false;
  String? _error;
  String? _loadedFileName;
  BulkResult? _result;

  @override
  void initState() {
    super.initState();
    _csvCtrl = TextEditingController(text: _template);
  }

  @override
  void dispose() {
    _csvCtrl.dispose();
    super.dispose();
  }

  String get _title => switch (widget.kind) {
        BulkKind.brands => 'Bulk add brands',
        BulkKind.stores => 'Bulk add stores',
        BulkKind.positions => 'Bulk add positions',
        BulkKind.employees => 'Bulk add employees',
      };

  String get _fileName => switch (widget.kind) {
        BulkKind.brands => 'brands_template.csv',
        BulkKind.stores => 'stores_template.csv',
        BulkKind.positions => 'positions_template.csv',
        BulkKind.employees => 'employees_template.csv',
      };

  String get _header => switch (widget.kind) {
        BulkKind.brands => 'brand_name',
        BulkKind.stores => 'brand_name,store_name',
        BulkKind.positions => 'brand_name,position_title',
        BulkKind.employees =>
          'payroll_id,employee_name,date_of_birth,brand_name,store_name,'
              'position_title,email,payrate,pay_currency,phone_number,'
              'mag_code,country_name,additional_stores',
      };

  String get _example => switch (widget.kind) {
        BulkKind.brands => 'Burger Boys\nSushi Co\nTaco Town',
        BulkKind.stores =>
          'Pizza Boys,Arima\nPizza Boys,Tunapuna\nSushi Co,MovieTowne',
        BulkKind.positions =>
          'Pizza Boys,Driver\nPizza Boys,Cook\nPizza Boys,Cleaner',
        BulkKind.employees =>
          'E1001,Jane Doe,03/15/1998,Pizza Boys,Port of Spain,Cashier,'
              'jane@example.com,20.50,TTD,868-555-0101,,Trinidad,'
              'San Fernando;Chaguanas\n'
              'E1002,Marcus Khan,07/22/1995,Pizza Boys,San Fernando,'
              'Crew Member,marcus@example.com,18.00,TTD,,,Trinidad,\n'
              'E1003,Aaliyah Mohammed,11/30/2000,Pizza Boys,Chaguanas,'
              'Shift Supervisor,aaliyah@example.com,25.00,TTD,868-555-0143,,'
              'Trinidad,Port of Spain',
      };

  String get _template => '$_header\n$_example';

  List<String> get _helpPoints => switch (widget.kind) {
        BulkKind.brands => const [
            'One column: brand_name.',
            'Brands that already exist are skipped.',
          ],
        BulkKind.stores => const [
            'Two columns: brand_name, store_name.',
            'The brand must already exist.',
            'Stores that already exist under that brand are skipped.',
          ],
        BulkKind.positions => const [
            'Two columns: brand_name, position_title.',
            'The brand must already exist.',
            'Positions that already exist under that brand are skipped.',
          ],
        BulkKind.employees => const [
            'Dates use MM/DD/YYYY.',
            'Brand, store and position must already exist — the store and '
                'position must belong to that brand.',
            'additional_stores is a semicolon-separated list, '
                'e.g. San Fernando;Chaguanas.',
            'Leave mag_code blank to auto-assign the next MAG number.',
            'Required fields follow your Form Settings.',
            'Duplicate payroll IDs are skipped.',
          ],
      };

  void _downloadTemplate() {
    final bytes = utf8.encode(_template);
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', _fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _pickFile() async {
    final input = html.FileUploadInputElement()..accept = '.csv,text/csv';
    input.click();
    await input.onChange.first;
    final files = input.files;
    if (files == null || files.isEmpty) return;
    final file = files.first;
    final reader = html.FileReader();
    reader.readAsText(file);
    await reader.onLoad.first;
    final text = (reader.result as String?) ?? '';
    if (!mounted) return;
    setState(() {
      _csvCtrl.text = text.trim();
      _loadedFileName = file.name;
      _error = null;
      _result = null;
    });
  }

  Future<void> _process() async {
    final csv = _csvCtrl.text.trim();
    if (csv.isEmpty) {
      setState(() => _error = 'Paste some CSV rows or upload a file first.');
      return;
    }
    setState(() {
      _processing = true;
      _error = null;
      _result = null;
    });
    try {
      final svc = context.read<StaffService>();
      final result = switch (widget.kind) {
        BulkKind.brands => await svc.bulkBrands(csv),
        BulkKind.stores => await svc.bulkStores(csv),
        BulkKind.positions => await svc.bulkPositions(csv),
        BulkKind.employees => await svc.bulkEmployees(csv),
      };
      if (!mounted) return;
      setState(() {
        _result = result;
        _processing = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _processing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not reach the server. Please try again.';
        _processing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppScaffold(
      appBar: AppBar(title: Text(_title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Paste rows below or upload a .csv file. '
                  'Always include the header line.',
                  style: TextStyle(fontSize: 13.5, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                // Bulleted rules
                ..._helpPoints.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1, right: 8),
                          child: Text('•',
                              style: TextStyle(
                                  fontSize: 14, color: cs.onSurfaceVariant)),
                        ),
                        Expanded(
                          child: Text(
                            p,
                            style: TextStyle(
                                fontSize: 13.5,
                                height: 1.35,
                                color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Template box with copy + download
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Template',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      SelectableText(
                        _template,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _downloadTemplate,
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('Download template'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: _template));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Template copied')),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 18),
                            label: const Text('Copy'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Upload row
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.attach_file, size: 18),
                      label: const Text('Choose .csv file'),
                    ),
                    const SizedBox(width: 12),
                    if (_loadedFileName != null)
                      Expanded(
                        child: Text(
                          'Loaded: $_loadedFileName',
                          style: TextStyle(
                              fontSize: 13, color: cs.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _csvCtrl,
                  minLines: 6,
                  maxLines: 14,
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'CSV rows',
                    alignLabelWithHint: true,
                    helperText: 'Edit here after uploading if needed.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: TextStyle(color: cs.error)),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _processing ? null : _process,
                    icon: _processing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: Colors.white),
                          )
                        : const Icon(Icons.upload),
                    label: const Text('Process upload'),
                  ),
                ),
                if (_result != null) ...[
                  const SizedBox(height: 20),
                  _ResultReport(result: _result!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultReport extends StatelessWidget {
  final BulkResult result;
  const _ResultReport({required this.result});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? cs.outlineVariant : AppColors.line),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF2E7D43)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${result.created} created  •  ${result.skipped} skipped'
                  '  •  ${result.errors.length} error(s)',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (result.errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Errors',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant)),
            const SizedBox(height: 6),
            ...result.errors.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('Row ${e.row}: ${e.message}',
                    style: TextStyle(fontSize: 13, color: cs.error)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
