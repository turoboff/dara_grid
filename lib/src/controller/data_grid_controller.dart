import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// Mutable controller that coordinates grid options, layout state, focus, and selection.
class DataGridController<T> extends ChangeNotifier {
  /// Creates a controller with optional initial pagination and sorting options.
  DataGridController({DataGridOptions? options})
    : _options = options ?? const DataGridOptions();

  DataGridOptions _options;
  final Set<Object> _selectedRowKeys = <Object>{};
  final Map<String, double> _columnWidths = <String, double>{};
  final Map<Object, double> _rowHeights = <Object, double>{};
  final Set<String> _hiddenColumnIds = <String>{};
  List<String> _orderedColumnIds = <String>[];
  Object? _focusedRowKey;
  String? _focusedColumnId;
  bool _preferEditorOnFocus = false;
  bool _selectEditorTextOnFocus = false;
  Object? _editingRowKey;
  String? _editingColumnId;
  VoidCallback? _ensureFocusedCellVisibleCallback;
  bool Function(int rowDelta, int columnDelta)? _moveFocusCallback;

  /// Current pagination and sorting options.
  DataGridOptions get options => _options;

  /// Immutable view of the selected row keys.
  Set<Object> get selectedRowKeys => Set<Object>.unmodifiable(_selectedRowKeys);

  /// Immutable view of user-resized column widths.
  Map<String, double> get columnWidths =>
      Map<String, double>.unmodifiable(_columnWidths);

  /// Immutable view of user-resized row heights.
  Map<Object, double> get rowHeights =>
      Map<Object, double>.unmodifiable(_rowHeights);

  /// Immutable set of currently hidden column ids.
  Set<String> get hiddenColumnIds => Set<String>.unmodifiable(_hiddenColumnIds);

  /// Immutable list describing the current column order.
  List<String> get orderedColumnIds =>
      List<String>.unmodifiable(_orderedColumnIds);

  /// Currently focused row key, if any.
  Object? get focusedRowKey => _focusedRowKey;

  /// Currently focused column id, if any.
  String? get focusedColumnId => _focusedColumnId;

  /// Whether focus should prefer opening the inline editor.
  bool get preferEditorOnFocus => _preferEditorOnFocus;

  /// Whether editor text should be selected when focus is restored.
  bool get selectEditorTextOnFocus => _selectEditorTextOnFocus;

  /// Currently editing row key, if any.
  Object? get editingRowKey => _editingRowKey;

  /// Currently editing column id, if any.
  String? get editingColumnId => _editingColumnId;

  /// Seeds controller-managed column state from the current column list.
  void initializeColumns(List<DataGridColumn<T>> columns) {
    for (final DataGridColumn<T> column in columns) {
      _columnWidths.putIfAbsent(column.id, () => column.width);
      if (column.hidden) {
        _hiddenColumnIds.add(column.id);
      }
    }
    if (_orderedColumnIds.isEmpty) {
      _orderedColumnIds = columns
          .map((DataGridColumn<T> column) => column.id)
          .toList();
    }
  }

  /// Restores persisted column and sort state from storage.
  void hydrate(DataGridStoredState state, List<DataGridColumn<T>> columns) {
    final Set<String> allIds = columns
        .map((DataGridColumn<T> column) => column.id)
        .toSet();
    _hiddenColumnIds
      ..clear()
      ..addAll(state.hiddenColumns.where(allIds.contains));
    _orderedColumnIds = <String>[
      ...state.orderedColumns.where(allIds.contains),
      ...columns
          .map((DataGridColumn<T> column) => column.id)
          .where((String id) => !state.orderedColumns.contains(id)),
    ];
    _columnWidths
      ..clear()
      ..addAll(
        state.columnWidths.map(
          (String key, double value) => MapEntry<String, double>(key, value),
        ),
      );
    for (final DataGridColumn<T> column in columns) {
      _columnWidths.putIfAbsent(column.id, () => column.width);
    }
    _options = _options.copyWith(sortSpecs: state.sortSpecs);
    notifyListeners();
  }

  /// Captures the current persisted state snapshot.
  DataGridStoredState snapshot({required bool persistSort}) {
    return DataGridStoredState(
      hiddenColumns: _hiddenColumnIds.toList(),
      orderedColumns: _orderedColumnIds,
      columnWidths: _columnWidths,
      sortSpecs: persistSort ? _options.sortSpecs : const <DataGridSortSpec>[],
    );
  }

  /// Replaces the current pagination and sorting options.
  void updateOptions(DataGridOptions options) {
    _options = options;
    notifyListeners();
  }

  /// Switches between local and server pagination behavior.
  void setPaginationMode(DataGridPaginationMode mode) {
    _options = _options.copyWith(paginationMode: mode);
    notifyListeners();
  }

  /// Navigates to a concrete page number.
  void goToPage(int page) {
    _options = _options.copyWith(page: page);
    notifyListeners();
  }

  /// Updates the page size and resets paging to the first page.
  void setPageSize(int pageSize) {
    _options = _options.copyWith(page: 1, pageSize: pageSize, take: pageSize);
    notifyListeners();
  }

  /// Cycles the sort state for a column.
  void toggleSort(String columnId, {required bool multiSort}) {
    final List<DataGridSortSpec> current = List<DataGridSortSpec>.of(
      _options.sortSpecs,
    );
    final int index = current.indexWhere(
      (DataGridSortSpec spec) => spec.columnId == columnId,
    );
    final DataGridSortDirection? direction = index == -1
        ? null
        : current[index].direction;
    final DataGridSortDirection? next = switch (direction) {
      null => DataGridSortDirection.asc,
      DataGridSortDirection.asc => DataGridSortDirection.desc,
      DataGridSortDirection.desc => null,
    };

    if (!multiSort) {
      _options = _options.copyWith(
        sortSpecs: next == null
            ? const <DataGridSortSpec>[]
            : <DataGridSortSpec>[
                DataGridSortSpec(columnId: columnId, direction: next),
              ],
      );
      notifyListeners();
      return;
    }
    if (next == null) {
      current.removeWhere((DataGridSortSpec spec) => spec.columnId == columnId);
    } else if (index != -1) {
      current[index] = DataGridSortSpec(columnId: columnId, direction: next);
    } else {
      current.add(DataGridSortSpec(columnId: columnId, direction: next));
    }
    _options = _options.copyWith(sortSpecs: current);
    notifyListeners();
  }

  /// Applies a column width delta while respecting min and max bounds.
  void resizeColumn(
    String columnId,
    double delta,
    double minWidth,
    double maxWidth,
  ) {
    final double current = _columnWidths[columnId] ?? minWidth;
    _columnWidths[columnId] = (current + delta).clamp(minWidth, maxWidth);
    notifyListeners();
  }

  /// Applies a row height delta while respecting min and max bounds.
  void resizeRow(
    Object rowKey,
    double delta, {
    double min = 44,
    double max = 132,
    double? baseHeight,
  }) {
    final double current = _rowHeights[rowKey] ?? baseHeight ?? min;
    _rowHeights[rowKey] = (current + delta).clamp(min, max);
    notifyListeners();
  }

  /// Toggles a row selection entry.
  void toggleSelection(Object rowKey, {required bool multiSelect}) {
    if (!multiSelect) {
      if (_selectedRowKeys.length == 1 && _selectedRowKeys.contains(rowKey)) {
        _selectedRowKeys.clear();
      } else {
        _selectedRowKeys
          ..clear()
          ..add(rowKey);
      }
      notifyListeners();
      return;
    }

    if (_selectedRowKeys.contains(rowKey)) {
      _selectedRowKeys.remove(rowKey);
    } else {
      _selectedRowKeys.add(rowKey);
    }
    notifyListeners();
  }

  /// Replaces the entire current selection.
  void replaceSelection(Iterable<Object> rowKeys) {
    _selectedRowKeys
      ..clear()
      ..addAll(rowKeys);
    notifyListeners();
  }

  /// Wires view callbacks that require widget context or scrolling state.
  void attachView({
    VoidCallback? ensureFocusedCellVisible,
    bool Function(int rowDelta, int columnDelta)? moveFocus,
  }) {
    _ensureFocusedCellVisibleCallback = ensureFocusedCellVisible;
    _moveFocusCallback = moveFocus;
  }

  /// Sets the currently focused cell.
  void focusCell({
    required Object rowKey,
    required String columnId,
    bool preferEditor = false,
    bool selectEditorText = false,
  }) {
    _focusedRowKey = rowKey;
    _focusedColumnId = columnId;
    _preferEditorOnFocus = preferEditor;
    _selectEditorTextOnFocus = selectEditorText;
    notifyListeners();
  }

  /// Convenience alias for setting focus with row and column ids.
  void focusCellByRowKey({
    required Object rowKey,
    required String columnId,
    bool preferEditor = false,
    bool selectEditorText = false,
  }) {
    focusCell(
      rowKey: rowKey,
      columnId: columnId,
      preferEditor: preferEditor,
      selectEditorText: selectEditorText,
    );
  }

  /// Requests focus movement through the attached view callback.
  bool moveFocus(int rowDelta, int columnDelta) {
    return _moveFocusCallback?.call(rowDelta, columnDelta) ?? false;
  }

  /// Requests that the attached view scroll the focused cell into view.
  void ensureFocusedCellVisible() {
    _ensureFocusedCellVisibleCallback?.call();
  }

  /// Updates the current focus, or clears it when either value is null.
  void setFocus({Object? rowKey, String? columnId}) {
    if (rowKey == null || columnId == null) {
      _focusedRowKey = rowKey;
      _focusedColumnId = columnId;
      _preferEditorOnFocus = false;
      _selectEditorTextOnFocus = false;
      notifyListeners();
      return;
    }
    focusCell(rowKey: rowKey, columnId: columnId);
  }

  /// Marks a cell as actively editing.
  void beginEdit({required Object rowKey, required String columnId}) {
    _editingRowKey = rowKey;
    _editingColumnId = columnId;
    notifyListeners();
  }

  /// Clears the current editing state.
  void endEdit() {
    _editingRowKey = null;
    _editingColumnId = null;
    notifyListeners();
  }

  /// Applies a new hidden/order configuration from the settings panel.
  void applyColumnSettings({
    required List<String> hiddenColumnIds,
    required List<String> orderedColumnIds,
  }) {
    _hiddenColumnIds
      ..clear()
      ..addAll(hiddenColumnIds);
    _orderedColumnIds = List<String>.of(orderedColumnIds);
    notifyListeners();
  }

  /// Restores column visibility, order, and width back to defaults.
  void resetColumns(List<DataGridColumn<T>> columns) {
    _hiddenColumnIds
      ..clear()
      ..addAll(
        columns
            .where((DataGridColumn<T> column) => column.hidden)
            .map((DataGridColumn<T> column) => column.id),
      );
    _orderedColumnIds = columns
        .map((DataGridColumn<T> column) => column.id)
        .toList();
    _columnWidths
      ..clear()
      ..addEntries(
        columns.map(
          (DataGridColumn<T> column) =>
              MapEntry<String, double>(column.id, column.width),
        ),
      );
    notifyListeners();
  }
}
