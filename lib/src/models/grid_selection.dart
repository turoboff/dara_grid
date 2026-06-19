/// Configures checkbox selection behavior for the grid.
class DataGridSelectionConfig<T> {
  /// Creates selection constraints and row eligibility rules.
  const DataGridSelectionConfig({
    this.enableCheckboxSelection = false,
    this.multiSelect = true,
    this.minSelected = 0,
    this.maxSelected,
    this.isSelectable,
  });

  /// Shows the leading checkbox column when true.
  final bool enableCheckboxSelection;

  /// Allows multiple rows to stay selected at the same time.
  final bool multiSelect;

  /// Minimum number of rows that must remain selected.
  final int minSelected;

  /// Maximum number of rows that may be selected.
  final int? maxSelected;

  /// Optional per-row eligibility predicate.
  final bool Function(T row, int rowIndex)? isSelectable;
}
