# 0090 — Readable tab labels on the teal AppBar (light + dark)

**Date:** 2026-11-02

## What

Tab labels (e.g. the **Clusters** screen's "Area Managers" / "Ops Managers",
and the **Non-Oracle Employees** screen's tabs) were hard to read — faint and
poorly aligned — against the dark-teal brand AppBar.

## Why

The `TabBar` sits inside the AppBar, which is `AppColors.ink` (dark teal) in
**both** light and dark themes. Material 3's default tints tab labels with
`onSurface`, which is near-invisible on that dark bar.

## Fix

Added a global **`TabBarThemeData`** to both `AppTheme.light()` and
`AppTheme.dark()` (`theme/app_theme.dart`): white selected label, `white70`
unselected, a white full-width indicator (`TabBarIndicatorSize.tab`), bold
selected weight. This fixes every tabbed screen at once, so individual screens
no longer need their own tab colours — the redundant per-screen override in
`clusters_screen.dart` was removed.

## Verified

`flutter analyze` + `flutter build web` clean; confirmed in-browser on the
Clusters screen that both tabs are crisp and aligned in **light and dark** mode.
