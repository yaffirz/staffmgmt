class FormFieldConfig {
  final String formKey;
  final String fieldKey;
  final String label;
  final bool enabled;
  final bool required;
  final bool locked;
  final int sortOrder;

  const FormFieldConfig({
    required this.formKey,
    required this.fieldKey,
    required this.label,
    required this.enabled,
    required this.required,
    required this.locked,
    required this.sortOrder,
  });

  factory FormFieldConfig.fromJson(Map<String, dynamic> j) => FormFieldConfig(
        formKey: j['form_key'] as String,
        fieldKey: j['field_key'] as String,
        label: j['label'] as String,
        enabled: j['enabled'] as bool? ?? true,
        required: j['required'] as bool? ?? false,
        locked: j['locked'] as bool? ?? false,
        sortOrder: j['sort_order'] as int? ?? 0,
      );

  FormFieldConfig copyWith({bool? enabled, bool? required}) => FormFieldConfig(
        formKey: formKey,
        fieldKey: fieldKey,
        label: label,
        enabled: enabled ?? this.enabled,
        required: required ?? this.required,
        locked: locked,
        sortOrder: sortOrder,
      );
}
