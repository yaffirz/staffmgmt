class BulkRowError {
  final int row;
  final String message;
  const BulkRowError(this.row, this.message);

  factory BulkRowError.fromJson(Map<String, dynamic> j) =>
      BulkRowError(j['row'] as int, j['message'] as String);
}

class BulkResult {
  final int created;
  final int skipped;
  final List<BulkRowError> errors;
  const BulkResult({
    required this.created,
    required this.skipped,
    required this.errors,
  });

  factory BulkResult.fromJson(Map<String, dynamic> j) => BulkResult(
        created: j['created'] as int? ?? 0,
        skipped: j['skipped'] as int? ?? 0,
        errors: (j['errors'] as List? ?? const [])
            .map((e) => BulkRowError.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
