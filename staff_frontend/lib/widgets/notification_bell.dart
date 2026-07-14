import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../screens/store_drilldown_screen.dart';
import '../services/staff_service.dart';

/// Topbar bell with an unread badge that opens a dropdown inbox. Polls the
/// unread count every 60s (and after any read action) to keep the badge fresh.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final MenuController _menu = MenuController();
  Timer? _timer;
  // Held in a ValueNotifier so count updates repaint ONLY the badge — never the
  // MenuAnchor. A setState here would rebuild the anchor and dismiss an open menu.
  final ValueNotifier<int> _unread = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _refreshCount();
    _timer =
        Timer.periodic(const Duration(seconds: 60), (_) => _refreshCount());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _unread.dispose();
    super.dispose();
  }

  Future<void> _refreshCount() async {
    try {
      final c = await context.read<StaffService>().unreadNotificationCount();
      if (mounted) _unread.value = c;
    } catch (_) {
      // Ignore transient errors (e.g. expired token mid-poll); keep last count.
    }
  }

  /// Close the menu and, if the notification points at a store, deep-link into
  /// its drilldown (highlighting the relevant employee).
  void _handleSelect(AppNotification n) {
    _menu.close();
    final storeId = n.targetStoreId;
    if (storeId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoreDrilldownScreen(
          storeId: storeId,
          storeName: n.targetStoreName,
          highlightEmployeeId: n.targetEmployeeId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _menu,
      alignmentOffset: const Offset(-308, 8),
      menuChildren: [
        _NotificationPanel(onChanged: _refreshCount, onSelect: _handleSelect),
      ],
      builder: (context, controller, child) {
        final iconButton = IconButton(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_none),
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        );
        // Count lives in a ValueNotifier so updates repaint ONLY this subtree,
        // never the MenuAnchor (which would close an open menu). When count is 0
        // we render the bare button — a hidden Badge (isLabelVisible:false) leaves
        // its label render box unlaid-out yet hit-tested, which throws every frame.
        return ValueListenableBuilder<int>(
          valueListenable: _unread,
          builder: (context, count, _) => count == 0
              ? iconButton
              : Badge(
                  label: Text(count > 99 ? '99+' : '$count'),
                  offset: const Offset(-4, 4),
                  child: iconButton,
                ),
        );
      },
    );
  }
}

class _NotificationPanel extends StatefulWidget {
  final Future<void> Function() onChanged;
  final void Function(AppNotification) onSelect;
  const _NotificationPanel({required this.onChanged, required this.onSelect});

  @override
  State<_NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<_NotificationPanel> {
  late Future<List<AppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AppNotification>> _load() =>
      context.read<StaffService>().notifications();

  void _reload() => setState(() => _future = _load());

  Future<void> _markAll() async {
    await context.read<StaffService>().markAllNotificationsRead();
    await widget.onChanged();
    if (mounted) _reload();
  }

  /// Click a notification: mark it read (updating the badge), then hand off to
  /// the bell to close the menu and navigate to its target.
  Future<void> _openNotification(AppNotification n) async {
    if (!n.isRead) {
      await context.read<StaffService>().markNotificationRead(n.id);
      await widget.onChanged();
    }
    if (mounted) widget.onSelect(n);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Text('Notifications',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _reload,
                ),
                TextButton(
                  onPressed: _markAll,
                  child: const Text('Mark all read'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // NOTE: a scrollable (ListView) here breaks — MenuAnchor sizes its
          // menu to content by measuring intrinsic height, which scrollables
          // don't support ("Cannot hit test a render box that has never been
          // laid out"). So the list is a capped, non-scrolling Column instead.
          FutureBuilder<List<AppNotification>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Could not load notifications.',
                          style: TextStyle(color: cs.error)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _reload,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              final items = snap.data ?? const <AppNotification>[];
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('You’re all caught up.')),
                );
              }
              const maxShown = 6;
              final shown = items.take(maxShown).toList();
              final rows = <Widget>[];
              for (var i = 0; i < shown.length; i++) {
                if (i > 0) rows.add(const Divider(height: 1));
                rows.add(_tile(shown[i], cs));
              }
              if (items.length > maxShown) {
                rows.add(const Divider(height: 1));
                rows.add(Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text('+ ${items.length - maxShown} more',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                ));
              }
              return Column(mainAxisSize: MainAxisSize.min, children: rows);
            },
          ),
        ],
      ),
    );
  }

  Widget _tile(AppNotification n, ColorScheme cs) {
    return InkWell(
      onTap: () => _openNotification(n),
      child: Container(
        color: n.isRead ? null : cs.primary.withOpacity(0.06),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 10),
              child: Icon(
                n.isRead ? Icons.circle_outlined : Icons.circle,
                size: 10,
                color: n.isRead ? cs.outline : cs.primary,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(n.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Text(n.ageDisplay,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(n.body,
                      style:
                          TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
