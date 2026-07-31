/// Public login-screen marketing block, from `GET /api/v1/marketing`.
class MarketingContent {
  final bool enabled;
  final String type; // 'text' | 'image' | 'embed'
  final String title;
  final String content;

  const MarketingContent({
    required this.enabled,
    this.type = 'text',
    this.title = '',
    this.content = '',
  });

  static const empty = MarketingContent(enabled: false);

  /// Something worth rendering (a heading and/or body/URL).
  bool get hasContent =>
      title.trim().isNotEmpty || content.trim().isNotEmpty;

  factory MarketingContent.fromJson(Map<String, dynamic> j) => MarketingContent(
        enabled: (j['enabled'] as bool?) ?? false,
        type: (j['type'] as String?) ?? 'text',
        title: (j['title'] as String?) ?? '',
        content: (j['content'] as String?) ?? '',
      );
}
