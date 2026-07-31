import 'package:flutter/foundation.dart';

import '../models/marketing_content.dart';
import '../services/staff_service.dart';

/// Fetches the public login-screen marketing block and exposes it. Failures are
/// swallowed (treated as "nothing to show") so a network blip never breaks the
/// login screen. The login screen also calls [refresh] when it appears, so on
/// native the fetch happens after the server URL is configured.
class MarketingProvider extends ChangeNotifier {
  final StaffService _svc;
  MarketingContent _content = MarketingContent.empty;

  MarketingProvider(this._svc) {
    refresh();
  }

  MarketingContent get content => _content;

  Future<void> refresh() async {
    try {
      final c = await _svc.marketingContent();
      final changed = c.enabled != _content.enabled ||
          c.type != _content.type ||
          c.title != _content.title ||
          c.content != _content.content;
      _content = c;
      if (changed) notifyListeners();
    } catch (_) {
      // Keep the last known content (defaults to empty/disabled).
    }
  }
}
