class StaffNote {
  final int noteId;
  final int employeeId;
  final String noteText;
  final int authorUserId;
  final String authorName;
  final DateTime createdAt;
  final List<String> visibilityRoles;
  final List<int> visibilityBrandIds;
  final String visibilityLabel;
  final bool canEdit;
  // Present on the "all notes" feed; null on a single employee's notes.
  final String? employeeName;

  const StaffNote({
    required this.noteId,
    required this.employeeId,
    required this.noteText,
    required this.authorUserId,
    required this.authorName,
    required this.createdAt,
    required this.visibilityRoles,
    required this.visibilityBrandIds,
    required this.visibilityLabel,
    required this.canEdit,
    this.employeeName,
  });

  factory StaffNote.fromJson(Map<String, dynamic> j) => StaffNote(
        noteId: j['note_id'] as int,
        employeeId: j['employee_id'] as int,
        noteText: j['note_text'] as String,
        authorUserId: (j['author_user_id'] as int?) ?? 0,
        authorName: (j['author_name'] as String?) ?? 'Unknown',
        createdAt: DateTime.parse(j['created_at'] as String),
        visibilityRoles: ((j['visibility_roles'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
        visibilityBrandIds: ((j['visibility_brand_ids'] as List?) ?? const [])
            .map((e) => e as int)
            .toList(growable: false),
        visibilityLabel: (j['visibility_label'] as String?) ?? 'Private',
        canEdit: (j['can_edit'] as bool?) ?? false,
        employeeName: j['employee_name'] as String?,
      );

  bool get isPrivate => visibilityRoles.isEmpty && visibilityBrandIds.isEmpty;

  /// MM/DD/YYYY per the app convention.
  String get createdDisplay {
    final d = createdAt.toLocal();
    return '${d.month.toString().padLeft(2, '0')}/'
        '${d.day.toString().padLeft(2, '0')}/${d.year}';
  }
}
