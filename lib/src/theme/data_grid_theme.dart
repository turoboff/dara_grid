import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/grid_types.dart';

/// Public theme data for styling the data grid.
@immutable
class DataGridThemeData extends ThemeExtension<DataGridThemeData> {
  const DataGridThemeData({
    required this.brightness,
    required this.surface,
    required this.surfaceMuted,
    required this.header,
    required this.row,
    required this.rowAlt,
    required this.selectedRow,
    required this.hoverRow,
    required this.summaryRow,
    required this.border,
    required this.headerText,
    required this.footerText,
    required this.muted,
    required this.accent,
    required this.badgeBorder,
    required this.sortHighlight,
    required this.editorText,
    required this.editorHint,
    required this.error,
    required this.selectionIndicator,
    required this.checkboxCheckColor,
    required this.filledControlForeground,
    required this.compactHeaderHeight,
    required this.standardHeaderHeight,
    required this.comfortableHeaderHeight,
    required this.compactRowHeight,
    required this.standardRowHeight,
    required this.comfortableRowHeight,
    required this.selectionColumnWidth,
    required this.supplementaryRowHeight,
    required this.summaryRowHeight,
    required this.surfaceRadius,
    required this.checkboxHeaderRadius,
    required this.footerRadius,
    required this.badgeRadius,
    required this.pageIndicatorRadius,
    required this.pagerButtonRadius,
    required this.editorCellRadius,
    required this.editorCursorRadius,
    required this.loadingBarRadius,
    required this.cellHorizontalPadding,
    required this.headerCellHorizontalPadding,
    required this.footerHorizontalPadding,
    required this.footerVerticalPadding,
    required this.footerSpacing,
    required this.footerRunSpacing,
    required this.loadingBarInset,
    required this.loadingBarHeight,
    required this.resizeHandleWidth,
    required this.clearButtonSize,
    required this.clearButtonIconSize,
    required this.editorClearSpacing,
    required this.editableTrailingSpace,
    required this.trailingActionInset,
    required this.pageSizeDropdownWidth,
    required this.pageSizeFieldHorizontalPadding,
    required this.pageSizeFieldVerticalPadding,
    required this.pageLoadingIndicatorSize,
    required this.pagerButtonSize,
    required this.pagerIconSize,
    required this.showSortOrderMinWidth,
  });

  factory DataGridThemeData.fallback(
    ThemeData baseTheme, {
    required Brightness brightness,
  }) {
    final ColorScheme baseScheme = baseTheme.colorScheme;
    final ColorScheme scheme = baseScheme.brightness == brightness
        ? baseScheme
        : ColorScheme.fromSeed(
            seedColor: baseScheme.primary,
            brightness: brightness,
          );
    final Color surface = scheme.surface;
    final Color surfaceMuted = Color.alphaBlend(
      scheme.onSurface.withValues(
        alpha: brightness == Brightness.dark ? 0.06 : 0.03,
      ),
      surface,
    );
    final Color selectedRow = Color.alphaBlend(
      scheme.primary.withValues(
        alpha: brightness == Brightness.dark ? 0.26 : 0.12,
      ),
      surface,
    );
    final Color hoverRow = Color.alphaBlend(
      scheme.primary.withValues(
        alpha: brightness == Brightness.dark ? 0.14 : 0.05,
      ),
      surface,
    );
    final Color summaryRow = Color.alphaBlend(
      scheme.secondary.withValues(
        alpha: brightness == Brightness.dark ? 0.16 : 0.08,
      ),
      surface,
    );
    final Color sortHighlight = Color.alphaBlend(
      scheme.primary.withValues(
        alpha: brightness == Brightness.dark ? 0.18 : 0.08,
      ),
      surface,
    );
    return DataGridThemeData(
      brightness: brightness,
      surface: surface,
      surfaceMuted: surfaceMuted,
      header: surfaceMuted,
      row: surface,
      rowAlt: Color.alphaBlend(
        scheme.primary.withValues(
          alpha: brightness == Brightness.dark ? 0.05 : 0.015,
        ),
        surface,
      ),
      selectedRow: selectedRow,
      hoverRow: hoverRow,
      summaryRow: summaryRow,
      border: scheme.outlineVariant,
      headerText: scheme.onSurfaceVariant,
      footerText: scheme.onSurfaceVariant,
      muted: scheme.outline,
      accent: scheme.primary,
      badgeBorder: Color.alphaBlend(
        scheme.primary.withValues(
          alpha: brightness == Brightness.dark ? 0.28 : 0.18,
        ),
        surface,
      ),
      sortHighlight: sortHighlight,
      editorText: scheme.onSurface,
      editorHint: scheme.onSurfaceVariant.withValues(alpha: 0.85),
      error: scheme.error,
      selectionIndicator: scheme.primary,
      checkboxCheckColor: scheme.onPrimary,
      filledControlForeground: scheme.onPrimary,
      compactHeaderHeight: 36,
      standardHeaderHeight: 42,
      comfortableHeaderHeight: 56,
      compactRowHeight: 40,
      standardRowHeight: 46,
      comfortableRowHeight: 60,
      selectionColumnWidth: 56,
      supplementaryRowHeight: 44,
      summaryRowHeight: 48,
      surfaceRadius: 22,
      checkboxHeaderRadius: 18,
      footerRadius: 22,
      badgeRadius: 999,
      pageIndicatorRadius: 12,
      pagerButtonRadius: 10,
      editorCellRadius: 4,
      editorCursorRadius: 2,
      loadingBarRadius: 999,
      cellHorizontalPadding: 10,
      headerCellHorizontalPadding: 10,
      footerHorizontalPadding: 12,
      footerVerticalPadding: 10,
      footerSpacing: 12,
      footerRunSpacing: 8,
      loadingBarInset: 12,
      loadingBarHeight: 6,
      resizeHandleWidth: 12,
      clearButtonSize: 20,
      clearButtonIconSize: 18,
      editorClearSpacing: 6,
      editableTrailingSpace: 28,
      trailingActionInset: 4,
      pageSizeDropdownWidth: 94,
      pageSizeFieldHorizontalPadding: 8,
      pageSizeFieldVerticalPadding: 6,
      pageLoadingIndicatorSize: 18,
      pagerButtonSize: 30,
      pagerIconSize: 16,
      showSortOrderMinWidth: 96,
    );
  }

  final Brightness brightness;
  final Color surface;
  final Color surfaceMuted;
  final Color header;
  final Color row;
  final Color rowAlt;
  final Color selectedRow;
  final Color hoverRow;
  final Color summaryRow;
  final Color border;
  final Color headerText;
  final Color footerText;
  final Color muted;
  final Color accent;
  final Color badgeBorder;
  final Color sortHighlight;
  final Color editorText;
  final Color editorHint;
  final Color error;
  final Color selectionIndicator;
  final Color checkboxCheckColor;
  final Color filledControlForeground;
  final double compactHeaderHeight;
  final double standardHeaderHeight;
  final double comfortableHeaderHeight;
  final double compactRowHeight;
  final double standardRowHeight;
  final double comfortableRowHeight;
  final double selectionColumnWidth;
  final double supplementaryRowHeight;
  final double summaryRowHeight;
  final double surfaceRadius;
  final double checkboxHeaderRadius;
  final double footerRadius;
  final double badgeRadius;
  final double pageIndicatorRadius;
  final double pagerButtonRadius;
  final double editorCellRadius;
  final double editorCursorRadius;
  final double loadingBarRadius;
  final double cellHorizontalPadding;
  final double headerCellHorizontalPadding;
  final double footerHorizontalPadding;
  final double footerVerticalPadding;
  final double footerSpacing;
  final double footerRunSpacing;
  final double loadingBarInset;
  final double loadingBarHeight;
  final double resizeHandleWidth;
  final double clearButtonSize;
  final double clearButtonIconSize;
  final double editorClearSpacing;
  final double editableTrailingSpace;
  final double trailingActionInset;
  final double pageSizeDropdownWidth;
  final double pageSizeFieldHorizontalPadding;
  final double pageSizeFieldVerticalPadding;
  final double pageLoadingIndicatorSize;
  final double pagerButtonSize;
  final double pagerIconSize;
  final double showSortOrderMinWidth;

  double headerHeight(DataGridDensity density) => switch (density) {
    DataGridDensity.compact => compactHeaderHeight,
    DataGridDensity.standard => standardHeaderHeight,
    DataGridDensity.comfortable => comfortableHeaderHeight,
  };

  double rowHeight(DataGridDensity density) => switch (density) {
    DataGridDensity.compact => compactRowHeight,
    DataGridDensity.standard => standardRowHeight,
    DataGridDensity.comfortable => comfortableRowHeight,
  };

  @override
  DataGridThemeData copyWith({
    Brightness? brightness,
    Color? surface,
    Color? surfaceMuted,
    Color? header,
    Color? row,
    Color? rowAlt,
    Color? selectedRow,
    Color? hoverRow,
    Color? summaryRow,
    Color? border,
    Color? headerText,
    Color? footerText,
    Color? muted,
    Color? accent,
    Color? badgeBorder,
    Color? sortHighlight,
    Color? editorText,
    Color? editorHint,
    Color? error,
    Color? selectionIndicator,
    Color? checkboxCheckColor,
    Color? filledControlForeground,
    double? compactHeaderHeight,
    double? standardHeaderHeight,
    double? comfortableHeaderHeight,
    double? compactRowHeight,
    double? standardRowHeight,
    double? comfortableRowHeight,
    double? selectionColumnWidth,
    double? supplementaryRowHeight,
    double? summaryRowHeight,
    double? surfaceRadius,
    double? checkboxHeaderRadius,
    double? footerRadius,
    double? badgeRadius,
    double? pageIndicatorRadius,
    double? pagerButtonRadius,
    double? editorCellRadius,
    double? editorCursorRadius,
    double? loadingBarRadius,
    double? cellHorizontalPadding,
    double? headerCellHorizontalPadding,
    double? footerHorizontalPadding,
    double? footerVerticalPadding,
    double? footerSpacing,
    double? footerRunSpacing,
    double? loadingBarInset,
    double? loadingBarHeight,
    double? resizeHandleWidth,
    double? clearButtonSize,
    double? clearButtonIconSize,
    double? editorClearSpacing,
    double? editableTrailingSpace,
    double? trailingActionInset,
    double? pageSizeDropdownWidth,
    double? pageSizeFieldHorizontalPadding,
    double? pageSizeFieldVerticalPadding,
    double? pageLoadingIndicatorSize,
    double? pagerButtonSize,
    double? pagerIconSize,
    double? showSortOrderMinWidth,
  }) {
    return DataGridThemeData(
      brightness: brightness ?? this.brightness,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      header: header ?? this.header,
      row: row ?? this.row,
      rowAlt: rowAlt ?? this.rowAlt,
      selectedRow: selectedRow ?? this.selectedRow,
      hoverRow: hoverRow ?? this.hoverRow,
      summaryRow: summaryRow ?? this.summaryRow,
      border: border ?? this.border,
      headerText: headerText ?? this.headerText,
      footerText: footerText ?? this.footerText,
      muted: muted ?? this.muted,
      accent: accent ?? this.accent,
      badgeBorder: badgeBorder ?? this.badgeBorder,
      sortHighlight: sortHighlight ?? this.sortHighlight,
      editorText: editorText ?? this.editorText,
      editorHint: editorHint ?? this.editorHint,
      error: error ?? this.error,
      selectionIndicator: selectionIndicator ?? this.selectionIndicator,
      checkboxCheckColor: checkboxCheckColor ?? this.checkboxCheckColor,
      filledControlForeground:
          filledControlForeground ?? this.filledControlForeground,
      compactHeaderHeight: compactHeaderHeight ?? this.compactHeaderHeight,
      standardHeaderHeight: standardHeaderHeight ?? this.standardHeaderHeight,
      comfortableHeaderHeight:
          comfortableHeaderHeight ?? this.comfortableHeaderHeight,
      compactRowHeight: compactRowHeight ?? this.compactRowHeight,
      standardRowHeight: standardRowHeight ?? this.standardRowHeight,
      comfortableRowHeight: comfortableRowHeight ?? this.comfortableRowHeight,
      selectionColumnWidth: selectionColumnWidth ?? this.selectionColumnWidth,
      supplementaryRowHeight:
          supplementaryRowHeight ?? this.supplementaryRowHeight,
      summaryRowHeight: summaryRowHeight ?? this.summaryRowHeight,
      surfaceRadius: surfaceRadius ?? this.surfaceRadius,
      checkboxHeaderRadius: checkboxHeaderRadius ?? this.checkboxHeaderRadius,
      footerRadius: footerRadius ?? this.footerRadius,
      badgeRadius: badgeRadius ?? this.badgeRadius,
      pageIndicatorRadius: pageIndicatorRadius ?? this.pageIndicatorRadius,
      pagerButtonRadius: pagerButtonRadius ?? this.pagerButtonRadius,
      editorCellRadius: editorCellRadius ?? this.editorCellRadius,
      editorCursorRadius: editorCursorRadius ?? this.editorCursorRadius,
      loadingBarRadius: loadingBarRadius ?? this.loadingBarRadius,
      cellHorizontalPadding:
          cellHorizontalPadding ?? this.cellHorizontalPadding,
      headerCellHorizontalPadding:
          headerCellHorizontalPadding ?? this.headerCellHorizontalPadding,
      footerHorizontalPadding:
          footerHorizontalPadding ?? this.footerHorizontalPadding,
      footerVerticalPadding:
          footerVerticalPadding ?? this.footerVerticalPadding,
      footerSpacing: footerSpacing ?? this.footerSpacing,
      footerRunSpacing: footerRunSpacing ?? this.footerRunSpacing,
      loadingBarInset: loadingBarInset ?? this.loadingBarInset,
      loadingBarHeight: loadingBarHeight ?? this.loadingBarHeight,
      resizeHandleWidth: resizeHandleWidth ?? this.resizeHandleWidth,
      clearButtonSize: clearButtonSize ?? this.clearButtonSize,
      clearButtonIconSize: clearButtonIconSize ?? this.clearButtonIconSize,
      editorClearSpacing: editorClearSpacing ?? this.editorClearSpacing,
      editableTrailingSpace:
          editableTrailingSpace ?? this.editableTrailingSpace,
      trailingActionInset: trailingActionInset ?? this.trailingActionInset,
      pageSizeDropdownWidth:
          pageSizeDropdownWidth ?? this.pageSizeDropdownWidth,
      pageSizeFieldHorizontalPadding:
          pageSizeFieldHorizontalPadding ?? this.pageSizeFieldHorizontalPadding,
      pageSizeFieldVerticalPadding:
          pageSizeFieldVerticalPadding ?? this.pageSizeFieldVerticalPadding,
      pageLoadingIndicatorSize:
          pageLoadingIndicatorSize ?? this.pageLoadingIndicatorSize,
      pagerButtonSize: pagerButtonSize ?? this.pagerButtonSize,
      pagerIconSize: pagerIconSize ?? this.pagerIconSize,
      showSortOrderMinWidth:
          showSortOrderMinWidth ?? this.showSortOrderMinWidth,
    );
  }

  @override
  DataGridThemeData lerp(
    covariant ThemeExtension<DataGridThemeData>? other,
    double t,
  ) {
    if (other is! DataGridThemeData) {
      return this;
    }
    return DataGridThemeData(
      brightness: t < 0.5 ? brightness : other.brightness,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      header: Color.lerp(header, other.header, t)!,
      row: Color.lerp(row, other.row, t)!,
      rowAlt: Color.lerp(rowAlt, other.rowAlt, t)!,
      selectedRow: Color.lerp(selectedRow, other.selectedRow, t)!,
      hoverRow: Color.lerp(hoverRow, other.hoverRow, t)!,
      summaryRow: Color.lerp(summaryRow, other.summaryRow, t)!,
      border: Color.lerp(border, other.border, t)!,
      headerText: Color.lerp(headerText, other.headerText, t)!,
      footerText: Color.lerp(footerText, other.footerText, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      badgeBorder: Color.lerp(badgeBorder, other.badgeBorder, t)!,
      sortHighlight: Color.lerp(sortHighlight, other.sortHighlight, t)!,
      editorText: Color.lerp(editorText, other.editorText, t)!,
      editorHint: Color.lerp(editorHint, other.editorHint, t)!,
      error: Color.lerp(error, other.error, t)!,
      selectionIndicator: Color.lerp(
        selectionIndicator,
        other.selectionIndicator,
        t,
      )!,
      checkboxCheckColor: Color.lerp(
        checkboxCheckColor,
        other.checkboxCheckColor,
        t,
      )!,
      filledControlForeground: Color.lerp(
        filledControlForeground,
        other.filledControlForeground,
        t,
      )!,
      compactHeaderHeight: lerpDouble(
        compactHeaderHeight,
        other.compactHeaderHeight,
        t,
      )!,
      standardHeaderHeight: lerpDouble(
        standardHeaderHeight,
        other.standardHeaderHeight,
        t,
      )!,
      comfortableHeaderHeight: lerpDouble(
        comfortableHeaderHeight,
        other.comfortableHeaderHeight,
        t,
      )!,
      compactRowHeight: lerpDouble(
        compactRowHeight,
        other.compactRowHeight,
        t,
      )!,
      standardRowHeight: lerpDouble(
        standardRowHeight,
        other.standardRowHeight,
        t,
      )!,
      comfortableRowHeight: lerpDouble(
        comfortableRowHeight,
        other.comfortableRowHeight,
        t,
      )!,
      selectionColumnWidth: lerpDouble(
        selectionColumnWidth,
        other.selectionColumnWidth,
        t,
      )!,
      supplementaryRowHeight: lerpDouble(
        supplementaryRowHeight,
        other.supplementaryRowHeight,
        t,
      )!,
      summaryRowHeight: lerpDouble(
        summaryRowHeight,
        other.summaryRowHeight,
        t,
      )!,
      surfaceRadius: lerpDouble(surfaceRadius, other.surfaceRadius, t)!,
      checkboxHeaderRadius: lerpDouble(
        checkboxHeaderRadius,
        other.checkboxHeaderRadius,
        t,
      )!,
      footerRadius: lerpDouble(footerRadius, other.footerRadius, t)!,
      badgeRadius: lerpDouble(badgeRadius, other.badgeRadius, t)!,
      pageIndicatorRadius: lerpDouble(
        pageIndicatorRadius,
        other.pageIndicatorRadius,
        t,
      )!,
      pagerButtonRadius: lerpDouble(
        pagerButtonRadius,
        other.pagerButtonRadius,
        t,
      )!,
      editorCellRadius: lerpDouble(
        editorCellRadius,
        other.editorCellRadius,
        t,
      )!,
      editorCursorRadius: lerpDouble(
        editorCursorRadius,
        other.editorCursorRadius,
        t,
      )!,
      loadingBarRadius: lerpDouble(
        loadingBarRadius,
        other.loadingBarRadius,
        t,
      )!,
      cellHorizontalPadding: lerpDouble(
        cellHorizontalPadding,
        other.cellHorizontalPadding,
        t,
      )!,
      headerCellHorizontalPadding: lerpDouble(
        headerCellHorizontalPadding,
        other.headerCellHorizontalPadding,
        t,
      )!,
      footerHorizontalPadding: lerpDouble(
        footerHorizontalPadding,
        other.footerHorizontalPadding,
        t,
      )!,
      footerVerticalPadding: lerpDouble(
        footerVerticalPadding,
        other.footerVerticalPadding,
        t,
      )!,
      footerSpacing: lerpDouble(footerSpacing, other.footerSpacing, t)!,
      footerRunSpacing: lerpDouble(
        footerRunSpacing,
        other.footerRunSpacing,
        t,
      )!,
      loadingBarInset: lerpDouble(loadingBarInset, other.loadingBarInset, t)!,
      loadingBarHeight: lerpDouble(
        loadingBarHeight,
        other.loadingBarHeight,
        t,
      )!,
      resizeHandleWidth: lerpDouble(
        resizeHandleWidth,
        other.resizeHandleWidth,
        t,
      )!,
      clearButtonSize: lerpDouble(clearButtonSize, other.clearButtonSize, t)!,
      clearButtonIconSize: lerpDouble(
        clearButtonIconSize,
        other.clearButtonIconSize,
        t,
      )!,
      editorClearSpacing: lerpDouble(
        editorClearSpacing,
        other.editorClearSpacing,
        t,
      )!,
      editableTrailingSpace: lerpDouble(
        editableTrailingSpace,
        other.editableTrailingSpace,
        t,
      )!,
      trailingActionInset: lerpDouble(
        trailingActionInset,
        other.trailingActionInset,
        t,
      )!,
      pageSizeDropdownWidth: lerpDouble(
        pageSizeDropdownWidth,
        other.pageSizeDropdownWidth,
        t,
      )!,
      pageSizeFieldHorizontalPadding: lerpDouble(
        pageSizeFieldHorizontalPadding,
        other.pageSizeFieldHorizontalPadding,
        t,
      )!,
      pageSizeFieldVerticalPadding: lerpDouble(
        pageSizeFieldVerticalPadding,
        other.pageSizeFieldVerticalPadding,
        t,
      )!,
      pageLoadingIndicatorSize: lerpDouble(
        pageLoadingIndicatorSize,
        other.pageLoadingIndicatorSize,
        t,
      )!,
      pagerButtonSize: lerpDouble(pagerButtonSize, other.pagerButtonSize, t)!,
      pagerIconSize: lerpDouble(pagerIconSize, other.pagerIconSize, t)!,
      showSortOrderMinWidth: lerpDouble(
        showSortOrderMinWidth,
        other.showSortOrderMinWidth,
        t,
      )!,
    );
  }
}

/// Helper for resolving the active grid theme from the widget tree.
abstract final class DataGridTheme {
  static DataGridThemeData of(
    BuildContext context, {
    DataGridThemeMode themeMode = DataGridThemeMode.system,
    DataGridThemeData? override,
  }) {
    if (override != null) {
      return override;
    }
    final ThemeData materialTheme = Theme.of(context);
    final Brightness brightness = switch (themeMode) {
      DataGridThemeMode.system => materialTheme.brightness,
      DataGridThemeMode.light => Brightness.light,
      DataGridThemeMode.dark => Brightness.dark,
    };
    final DataGridThemeData? extension = materialTheme
        .extension<DataGridThemeData>();
    if (extension != null &&
        (themeMode == DataGridThemeMode.system ||
            extension.brightness == brightness)) {
      return extension;
    }
    return DataGridThemeData.fallback(materialTheme, brightness: brightness);
  }
}
