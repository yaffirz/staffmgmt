import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the employee list is rendered.
enum EmployeeListView { table, cards }

/// Per-device view preferences (persisted via shared_preferences).
class ViewPrefsProvider extends ChangeNotifier {
  static const _employeeViewKey = 'employee_list_view';

  EmployeeListView _employeeView = EmployeeListView.table;
  EmployeeListView get employeeView => _employeeView;

  ViewPrefsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _employeeView = prefs.getString(_employeeViewKey) == 'cards'
        ? EmployeeListView.cards
        : EmployeeListView.table;
    notifyListeners();
  }

  Future<void> setEmployeeView(EmployeeListView view) async {
    _employeeView = view;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _employeeViewKey, view == EmployeeListView.cards ? 'cards' : 'table');
  }
}
