import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/directory.dart';
import '../services/api_client.dart';
import '../services/staff_service.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import 'bulk_upload_screen.dart';

class BrandsListScreen extends StatefulWidget {
  const BrandsListScreen({super.key});

  @override
  State<BrandsListScreen> createState() => _BrandsListScreenState();
}

class _BrandsListScreenState extends State<BrandsListScreen> {
  List<Brand> _brands = [];
  bool _loading = true;
  String? _error;
  bool _canEdit = false;

  @override
  void initState() {
    super.initState();
    final role = context.read<AuthProvider>().user?.role;
    _canEdit = role == 'Super Admin' || role == 'Admin';
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await context.read<StaffService>().brands();
      if (!mounted) return;
      setState(() {
        _brands = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load brands.';
        _loading = false;
      });
    }
  }

  Future<void> _addBrand() async {
    final ctrl = TextEditingController();
    String? errorText;
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> submit() async {
            final name = ctrl.text.trim();
            if (name.isEmpty) {
              setLocal(() => errorText = 'Name is required');
              return;
            }
            try {
              await ctx.read<StaffService>().createBrand(name);
              if (ctx.mounted) Navigator.pop(ctx, true);
            } on ApiException catch (e) {
              setLocal(() => errorText = e.message);
            } catch (_) {
              setLocal(() => errorText = 'Could not add brand.');
            }
          }

          return AlertDialog(
            title: const Text('Add brand'),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Brand name',
                errorText: errorText,
              ),
              onSubmitted: (_) => submit(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(onPressed: submit, child: const Text('Add')),
            ],
          );
        },
      ),
    );
    if (created == true) _load();
  }

  Future<void> _editBrand(Brand brand) async {
    final ctrl = TextEditingController(text: brand.name);
    String? errorText;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> submit() async {
            final name = ctrl.text.trim();
            if (name.isEmpty) {
              setLocal(() => errorText = 'Name is required');
              return;
            }
            try {
              await ctx.read<StaffService>().updateBrand(brand.id, name);
              if (ctx.mounted) Navigator.pop(ctx, true);
            } on ApiException catch (e) {
              setLocal(() => errorText = e.message);
            } catch (_) {
              setLocal(() => errorText = 'Could not save brand.');
            }
          }

          return AlertDialog(
            title: const Text('Edit brand'),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Brand name',
                errorText: errorText,
              ),
              onSubmitted: (_) => submit(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(onPressed: submit, child: const Text('Save')),
            ],
          );
        },
      ),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Brands'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
          IconButton(
            tooltip: 'Add brand',
            icon: const Icon(Icons.add),
            onPressed: _addBrand,
          ),
          if (_canEdit)
            IconButton(
              tooltip: 'Bulk add brands',
              icon: const Icon(Icons.upload_file),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const BulkUploadScreen(kind: BulkKind.brands),
                  ),
                );
                _load();
              },
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_brands.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No brands yet.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _addBrand,
              icon: const Icon(Icons.add),
              label: const Text('Add brand'),
            ),
          ],
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _brands.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final b = _brands[i];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Material(
                color: isDark ? cs.surfaceContainerHigh : Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _canEdit ? () => _editBrand(b) : null,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isDark ? cs.outlineVariant : AppColors.line),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16),
                    child: Row(
                      children: [
                        Icon(Icons.storefront_outlined, color: cs.primary),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            b.name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (_canEdit)
                          Icon(Icons.edit, size: 16, color: cs.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
