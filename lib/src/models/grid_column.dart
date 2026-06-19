import 'package:flutter/material.dart';

import 'grid_types.dart';

/// Describes one visible data column in the grid.
class DataGridColumn<T> {
  /// Creates a column definition.
  const DataGridColumn({
    required this.id,
    required this.label,
    required this.width,
    required this.cellBuilder,
    this.sortValue,
    this.editorText,
    this.editorTextStyle,
    this.headerBuilder,
    this.summaryBuilder,
    this.extraCellBuilder,
    this.alignment = Alignment.centerLeft,
    this.sortable = true,
    this.resizable = true,
    this.hidden = false,
    this.hideable = true,
    this.reorderable = true,
    this.editable,
    this.readonly,
    this.required = false,
    this.requiredMessage,
    this.pin = DataGridColumnPin.none,
    this.minWidth = 80,
    this.maxWidth = 360,
    this.wrapLines = 1,
    this.editType = DataGridEditType.text,
    this.saveTrigger = DataGridSaveTrigger.enter,
  });

  /// Stable identifier used for sorting, focus, persistence, and keys.
  final String id;

  /// Header text shown for the column.
  final String label;

  /// Default width before user resizing is applied.
  final double width;

  /// Smallest allowed width during manual resize.
  final double minWidth;

  /// Largest allowed width during manual resize.
  final double maxWidth;

  /// Alignment used by header, display, and summary content.
  final Alignment alignment;

  /// Enables sorting for this column when true.
  final bool sortable;

  /// Enables drag-based resizing when true.
  final bool resizable;

  /// Hides the column by default.
  final bool hidden;

  /// Allows the user to hide/show the column in settings.
  final bool hideable;

  /// Allows the user to reorder the column in settings.
  final bool reorderable;

  /// Optional pin placement metadata for custom consumers.
  final DataGridColumnPin pin;

  /// Maximum display lines used by wrapped content.
  final int wrapLines;

  /// Selects the inline editor behavior.
  final DataGridEditType editType;

  /// Controls when inline edits for this column are committed.
  final DataGridSaveTrigger saveTrigger;

  /// Optional extractor used by the sorting engine.
  final DataGridSortValue<T>? sortValue;

  /// Builds the display cell for this column.
  final DataGridCellBuilder<T> cellBuilder;

  /// Resolves the starting editor value for inline editing.
  final DataGridCellTextValue<T>? editorText;

  /// Customizes the inline editor text style.
  final DataGridCellTextStyle<T>? editorTextStyle;

  /// Optional custom header widget builder.
  final Widget Function(BuildContext context, DataGridColumn<T> column)?
  headerBuilder;

  /// Optional builder for summary row cells.
  final Widget Function(BuildContext context, Object? value)? summaryBuilder;

  /// Optional builder for supplementary top/bottom rows.
  final Widget Function(BuildContext context, Object? value)? extraCellBuilder;

  /// Optional predicate that marks a row as editable for this column.
  final bool Function(T row)? editable;

  /// Optional predicate that forces a row to stay read-only for this column.
  final bool Function(T row)? readonly;

  /// Marks the editor value as required.
  final bool required;

  /// Optional override for the required validation message.
  final String? requiredMessage;

  /// Returns true when this row may be edited in the column.
  bool isEditableFor(T row) => editable?.call(row) ?? false;

  /// Returns true when this row must be treated as read-only in the column.
  bool isReadonlyFor(T row) => readonly?.call(row) ?? false;
}
