import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/bulk_result.dart';
import '../services/api_client.dart';
import '../services/staff_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

enum BulkKind { brands, stores, positions }

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
      };

  String get _header => switch (widget.kind) {
        BulkKind.brands => 'brand_name',
        BulkKind.stores => 'brand_name,store_name',
        BulkKind.positions => 'brand_name,position_title',
      };

  String get _example => switch (widget.kind) {
        BulkKind.brands => 'Burger Boys\nSushi Co',
        BulkKind.stores => 'Pizza Boys,Arima\nPizza Boys,Tunapuna',
        BulkKind.positions => 'Pizza Boys,Driver\nPizza Boys,Cook',
      };

  String get _template => '$_header\n$_example';

  String get _columnsHelp => switch (widget.kind) {
        BulkKind.brands =>
          'One column: brand_name. The brand must not already exist.',
        BulkKind.stores =>
          'Two columns: brand_name, store_name. The brand must already exist.',
        BulkKind.positions =>
          'Two columns: brand_name, position_title. The brand must already exist.',
      };

  Future<void> _process() async {
    final csv = _csvCtrl.text.trim();
    if (csv.isEmpty) {
      setState(() => _error = 'Paste some CSV rows first.');
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
                  'Paste comma-separated rows below, including the header line. '
                  '$_columnsHelp Existing entries are skipped.',
                  style: TextStyle(fontSize: 13.5, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                // Template box
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SelectableText(
                          _template,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 13),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy template',
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _template));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Template copied')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _csvCtrl,
                  minLines: 6,
                  maxLines: 14,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'CSV rows',
                    alignLabelWithHint: true,
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
              Text(
                '${result.created} created  •  ${result.skipped} skipped'
                '  •  ${result.errors.length} error(s)',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
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
