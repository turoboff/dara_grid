/// Configures how keyboard focus moves through the grid.
class DataGridNavigationConfig {
  /// Creates keyboard and focus behavior for the grid.
  const DataGridNavigationConfig({
    this.keyboardNavigation = true,
    this.autoFocus = false,
    this.autoSelectInputOnFocus = false,
    this.rowSelectFocusColumnId,
    this.captureTabNavigation = true,
  });

  /// Enables arrow/page/tab navigation inside the grid.
  final bool keyboardNavigation;

  /// Requests focus for the grid after the first layout pass.
  final bool autoFocus;

  /// Selects all editor text when focus moves into an input.
  final bool autoSelectInputOnFocus;

  /// Preferred column to focus after row-based actions such as row clicks.
  final String? rowSelectFocusColumnId;

  /// When true, tab and shift-tab remain inside the grid editing model.
  final bool captureTabNavigation;
}

/// Identifies a logical row/column target that should receive focus.
class DataGridFocusTarget {
  /// Creates a target for display or editor focus.
  const DataGridFocusTarget({
    required this.rowKey,
    required this.columnId,
    this.preferEditor = false,
    this.selectEditorText = false,
  });

  /// Stable row identifier provided by the consumer.
  final Object rowKey;

  /// Column identifier to focus.
  final String columnId;

  /// When true, the grid should open the inline editor if possible.
  final bool preferEditor;

  /// When true, the inline editor should select all text on focus.
  final bool selectEditorText;
}
