import 'package:flutter/material.dart';

import 'app_footer.dart';
import 'global_bar_actions.dart';

/// Every screen is built with this instead of a bare [Scaffold], which is how
/// the "Created by Arif Asad Ali" footer stays permanently pinned to the bottom
/// of the page across the whole app. The body fills the remaining space; the
/// footer never scrolls away.
///
/// When [globalActions] is true (default) and an [AppBar] is supplied, the
/// shared top-bar controls (bell, theme toggle, log out) are appended to that
/// bar's actions — so they appear on every signed-in page, not just the
/// dashboard. Pre-login / self-contained pages (login, register, maintenance)
/// and the dashboard (which builds its own) pass `globalActions: false`.
class AppScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final bool globalActions;

  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.globalActions = true,
  });

  PreferredSizeWidget? _bar() {
    final bar = appBar;
    if (!globalActions || bar is! AppBar) return bar;
    return AppBar(
      key: bar.key,
      title: bar.title,
      leading: bar.leading,
      automaticallyImplyLeading: bar.automaticallyImplyLeading,
      centerTitle: bar.centerTitle,
      backgroundColor: bar.backgroundColor,
      foregroundColor: bar.foregroundColor,
      elevation: bar.elevation,
      bottom: bar.bottom,
      actions: [
        ...?bar.actions,
        const GlobalBarActions(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _bar(),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(child: body),
            const AppFooter(),
          ],
        ),
      ),
    );
  }
}
