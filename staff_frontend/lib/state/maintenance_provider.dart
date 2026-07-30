import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/maintenance_status.dart';
import '../services/staff_service.dart';

/// Polls the public maintenance-status endpoint and exposes the current state.
/// RootGate consults this to decide whether a non-exempt user sees the
/// maintenance page. Failures are swallowed (treated as "not in maintenance")
/// so a transient network blip never locks the whole app behind the page.
class MaintenanceProvider extends ChangeNotifier {
  final StaffService _svc;
  Timer? _timer;
  MaintenanceStatus _status = MaintenanceStatus.inactive;

  MaintenanceProvider(this._svc) {
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => refresh());
  }

  bool get active => _status.active;
  String get message => _status.message;
  DateTime? get until => _status.until;

  Future<void> refresh() async {
    try {
      final s = await _svc.maintenanceStatus();
      // Only notify if something actually changed (avoid needless rebuilds).
      final changed = s.active != _status.active ||
          s.message != _status.message ||
          s.until != _status.until;
      _status = s;
      if (changed) notifyListeners();
    } catch (_) {
      // Ignore — keep the last known state (defaults to inactive).
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
