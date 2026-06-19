import 'package:flutter/material.dart';

/// Controls the ordering direction for a sorted column.
enum DataGridSortDirection { asc, desc }

/// Defines whether pagination is performed locally or by an external source.
enum DataGridPaginationMode { local, server }

/// Forces the grid to render with a specific brightness mode.
enum DataGridThemeMode { system, light, dark }

/// Adjusts the spacing used by headers and rows.
enum DataGridDensity { compact, standard, comfortable }

/// Describes where a column should be pinned in the grid.
enum DataGridColumnPin { none, left, right }

/// Selects the editor flavor used for inline editing.
enum DataGridEditType { text, number, date }

/// Controls when an inline edit should be committed.
enum DataGridSaveTrigger { enter, blur, both }

/// Selects whether the grid is read-only or allows inline editing.
enum DataGridMode { readonly, editable }

/// Resolves the comparable value used by the sorting engine.
typedef DataGridSortValue<T> = Comparable<dynamic>? Function(T row);

/// Builds the widget shown for a single display cell.
typedef DataGridCellBuilder<T> = Widget Function(BuildContext context, T row);

/// Resolves the text shown in the inline editor for a row.
typedef DataGridCellTextValue<T> = String Function(T row);

/// Builds the text style used by an inline editor.
typedef DataGridCellTextStyle<T> =
    TextStyle? Function(BuildContext context, T row);

/// Computes a row background color based on interaction state.
typedef DataGridRowColorBuilder<T> =
    Color? Function(T row, int rowIndex, bool isSelected, bool isHovered);
