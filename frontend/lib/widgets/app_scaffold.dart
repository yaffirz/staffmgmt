import 'package:flutter/material.dart';

import 'app_footer.dart';

/// Every screen is built with this instead of a bare [Scaffold], which is how
/// the "Created by Arif Asad Ali" footer stays permanently pinned to the bottom
/// of the page across the whole app. The body fills the remaining space; the
/// footer never scrolls away.
class AppScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;

  const AppScaffold({super.key, required this.body, this.appBar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
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
