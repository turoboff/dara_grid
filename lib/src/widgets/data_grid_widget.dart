import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show ItemExtentBuilder, SliverLayoutDimensions;
import 'package:flutter/services.dart';

import '../controller/data_grid_controller.dart';
import '../internal/grid_calculations.dart';
import '../internal/grid_selection_utils.dart';
import '../models/models.dart';
import '../persistence/data_grid_persistence.dart';

/// Reusable data grid widget with sorting, paging, selection, and inline editing.
class DataGrid<T> extends StatefulWidget {
  /// Creates a configurable grid for a row model.
  const DataGrid({
    super.key,
    required this.columns,
    required this.rows,
    required this.rowKey,
    required this.controller,
    this.persistenceAdapter,
    this.storageKey,
    this.pageSizeOptions = const <int>[10, 20, 30, 50],
    this.selectionConfig,
    this.mode = DataGridMode.readonly,
    this.navigationConfig = const DataGridNavigationConfig(),
    this.density = DataGridDensity.standard,
    this.themeMode = DataGridThemeMode.system,
    this.multiSort = true,
    this.persistSort = false,
    this.showFooter = true,
    this.showSelectedCount = false,
    this.loading = false,
    this.totalRowCount,
    this.height,
    this.summaryValues,
    this.extraTopValues,
    this.extraBottomValues,
    this.rowColorBuilder,
    this.onOptionsChanged,
    this.onSelectionChanged,
    this.onRowTap,
    this.onRowDoubleTap,
    this.onFocusChanged,
    this.onHotkey,
    this.onEditStart,
    this.onEditCommit,
    this.onEditCancel,
    this.onEditClear,
  });

  /// Ordered column definitions rendered by the grid.
  final List<DataGridColumn<T>> columns;

  /// Rows available to the grid for the current load.
  final List<T> rows;

  /// Stable row key resolver used by focus, editing, and selection.
  final Object Function(T row) rowKey;

  /// External controller that owns mutable grid state.
  final DataGridController<T> controller;

  /// Optional persistence adapter for saving column preferences.
  final DataGridPersistenceAdapter? persistenceAdapter;

  /// Storage key passed to the persistence adapter.
  final String? storageKey;

  /// Available page sizes displayed in the footer selector.
  final List<int> pageSizeOptions;

  /// Optional checkbox selection configuration.
  final DataGridSelectionConfig<T>? selectionConfig;

  /// Selects read-only or editable behavior.
  final DataGridMode mode;

  /// Configures keyboard and focus traversal behavior.
  final DataGridNavigationConfig navigationConfig;

  /// Controls row and header spacing density.
  final DataGridDensity density;

  /// Controls the grid brightness palette.
  final DataGridThemeMode themeMode;

  /// Allows multiple active sort entries when true.
  final bool multiSort;

  /// Persists sort state together with layout preferences when true.
  final bool persistSort;

  /// Shows the footer with pagination and settings controls.
  final bool showFooter;

  /// Shows the selected row count inside the footer.
  final bool showSelectedCount;

  /// Displays loading affordances and temporarily disables footer paging.
  final bool loading;

  /// Total rows represented by the current server page.
  final int? totalRowCount;

  /// Optional fixed height for the grid surface.
  final double? height;

  /// Optional summary row values keyed by column id.
  final Map<String, Object?>? summaryValues;

  /// Optional supplementary row rendered above the body.
  final Map<String, Object?>? extraTopValues;

  /// Optional supplementary row rendered below the body.
  final Map<String, Object?>? extraBottomValues;

  /// Optional row color resolver for custom business-state styling.
  final DataGridRowColorBuilder<T>? rowColorBuilder;

  /// Notifies listeners when pagination or sorting options change.
  final ValueChanged<DataGridOptions>? onOptionsChanged;

  /// Notifies listeners when the selected row key set changes.
  final ValueChanged<Set<Object>>? onSelectionChanged;

  /// Called when a row is tapped.
  final ValueChanged<T>? onRowTap;

  /// Called when a row is double tapped.
  final ValueChanged<T>? onRowDoubleTap;

  /// Called when logical focus moves to a new target.
  final ValueChanged<DataGridFocusTarget>? onFocusChanged;

  /// Allows consumers to intercept hotkeys before default handling.
  final bool Function(DataGridHotkeyPayload<T> payload)? onHotkey;

  /// Called when inline editing begins.
  final ValueChanged<DataGridEditStart<T>>? onEditStart;

  /// Called before an inline edit is committed into row state.
  final FutureOr<bool> Function(DataGridEditCommit<T> commit)? onEditCommit;

  /// Called when the current inline edit is canceled.
  final VoidCallback? onEditCancel;

  /// Called when the current inline editor requests a clear action.
  final VoidCallback? onEditClear;

  @override
  State<DataGrid<T>> createState() => _DataGridState<T>();
}

class _DataGridState<T> extends State<DataGrid<T>> {
  static const double _checkboxColumnWidth = 56;

  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  final ScrollController _fixedVerticalController = ScrollController();
  final FocusNode _gridFocusNode = FocusNode(debugLabel: 'data-grid');
  bool _syncingFixedScroll = false;
  bool _hydrated = false;
  Object? _hoveredRowKey;
  String _lastSortSignature = '';
  int _lastPageSize = 20;
  double _lastViewportWidth = 0;
  bool _hadGridFocusWithin = false;
  Object? _editingRowKey;
  String? _editingColumnId;
  Object? _lastCheckedRowKey;
  Object? _lastUncheckedRowKey;
  TextEditingController? _editingTextController;
  FocusNode? _editingFocusNode;
  String? _editingErrorText;
  bool _isCommittingEdit = false;
  List<T>? _cachedSortedRows;
  List<T>? _cachedVisibleRows;
  int? _cachedTotalRows;

  DataGridSelectionConfig<T> get _selectionConfig =>
      widget.selectionConfig ??
      const DataGridSelectionConfig<dynamic>() as DataGridSelectionConfig<T>;

  @override
  void initState() {
    super.initState();
    widget.controller.initializeColumns(widget.columns);
    widget.controller.attachView(
      ensureFocusedCellVisible: _ensureFocusedCellVisible,
      moveFocus: _moveFocusByDeltas,
    );
    _lastSortSignature = _sortSignature(widget.controller.options.sortSpecs);
    _lastPageSize = widget.controller.options.pageSize;
    widget.controller.addListener(_onControllerChanged);
    _verticalController.addListener(_syncFixedColumnScroll);
    _gridFocusNode.addListener(_handleGridFocusChange);
    unawaited(_hydratePersistence());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureFocusableCellSelected();
      if (widget.navigationConfig.autoFocus) {
        _focusInitialCell();
      }
    });
  }

  @override
  void didUpdateWidget(covariant DataGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.initializeColumns(widget.columns);
      widget.controller.addListener(_onControllerChanged);
      widget.controller.attachView(
        ensureFocusedCellVisible: _ensureFocusedCellVisible,
        moveFocus: _moveFocusByDeltas,
      );
    }
    if (oldWidget.columns != widget.columns) {
      widget.controller.initializeColumns(widget.columns);
    }
    if (oldWidget.rows != widget.rows ||
        oldWidget.columns != widget.columns ||
        oldWidget.rowKey != widget.rowKey) {
      _invalidateRowCaches();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _verticalController.removeListener(_syncFixedColumnScroll);
    _gridFocusNode.removeListener(_handleGridFocusChange);
    _horizontalController.dispose();
    _verticalController.dispose();
    _fixedVerticalController.dispose();
    _gridFocusNode.dispose();
    _disposeEditingState();
    super.dispose();
  }

  Future<void> _hydratePersistence() async {
    final String? storageKey = widget.storageKey;
    final DataGridPersistenceAdapter? adapter = widget.persistenceAdapter;
    if (_hydrated ||
        storageKey == null ||
        storageKey.isEmpty ||
        adapter == null) {
      _hydrated = true;
      return;
    }
    final DataGridStoredState? stored = await adapter.load(storageKey);
    if (!mounted) {
      return;
    }
    if (stored != null) {
      widget.controller.hydrate(stored, widget.columns);
    }
    _hydrated = true;
  }

  Future<void> _persistState() async {
    final String? storageKey = widget.storageKey;
    final DataGridPersistenceAdapter? adapter = widget.persistenceAdapter;
    if (!_hydrated ||
        storageKey == null ||
        storageKey.isEmpty ||
        adapter == null) {
      return;
    }
    await adapter.save(
      storageKey,
      widget.controller.snapshot(persistSort: widget.persistSort),
    );
  }

  void _onControllerChanged() {
    _invalidateRowCaches();
    final String sortSignature = _sortSignature(
      widget.controller.options.sortSpecs,
    );
    final bool sortChanged = sortSignature != _lastSortSignature;
    final bool pageSizeChanged =
        widget.controller.options.pageSize != _lastPageSize;
    _lastSortSignature = sortSignature;
    _lastPageSize = widget.controller.options.pageSize;
    if (sortChanged || pageSizeChanged) {
      _restoreFocusAfterTableChange();
    }
    widget.onOptionsChanged?.call(widget.controller.options);
    widget.onSelectionChanged?.call(widget.controller.selectedRowKeys);
    unawaited(_persistState());
    if (mounted) {
      setState(() {});
    }
  }

  void _invalidateRowCaches() {
    _cachedSortedRows = null;
    _cachedVisibleRows = null;
    _cachedTotalRows = null;
  }

  _GridPalette get _palette {
    final Brightness brightness = switch (widget.themeMode) {
      DataGridThemeMode.system => Theme.of(context).brightness,
      DataGridThemeMode.light => Brightness.light,
      DataGridThemeMode.dark => Brightness.dark,
    };
    return brightness == Brightness.dark
        ? const _GridPalette.dark()
        : const _GridPalette.light();
  }

  double get _headerHeight => switch (widget.density) {
    DataGridDensity.compact => 40,
    DataGridDensity.standard => 48,
    DataGridDensity.comfortable => 56,
  };

  double get _defaultRowHeight => switch (widget.density) {
    DataGridDensity.compact => 44,
    DataGridDensity.standard => 52,
    DataGridDensity.comfortable => 60,
  };

  List<DataGridColumn<T>> get _orderedVisibleColumns {
    return DataGridCalculations.orderedVisibleColumns<T>(
      columns: widget.columns,
      orderedColumnIds: widget.controller.orderedColumnIds,
      hiddenColumnIds: widget.controller.hiddenColumnIds,
    );
  }

  List<T> get _sortedRows {
    final List<T>? cached = _cachedSortedRows;
    if (cached != null) {
      return cached;
    }
    if (widget.controller.options.paginationMode ==
        DataGridPaginationMode.server) {
      return _cachedSortedRows = widget.rows;
    }
    return _cachedSortedRows = DataGridCalculations.sortRows<T>(
      rows: widget.rows,
      columns: widget.columns,
      options: widget.controller.options,
    );
  }

  List<T> get _visibleRows {
    final List<T>? cached = _cachedVisibleRows;
    if (cached != null) {
      return cached;
    }
    if (widget.controller.options.paginationMode ==
        DataGridPaginationMode.server) {
      return _cachedVisibleRows = widget.rows;
    }
    return _cachedVisibleRows = DataGridCalculations.visibleRows<T>(
      rows: _sortedRows,
      options: widget.controller.options,
      totalPages: _totalPages,
    );
  }

  int get _totalRows {
    final int? cached = _cachedTotalRows;
    if (cached != null) {
      return cached;
    }
    if (widget.controller.options.paginationMode ==
        DataGridPaginationMode.server) {
      return _cachedTotalRows = widget.totalRowCount ?? widget.rows.length;
    }
    return _cachedTotalRows = DataGridCalculations.totalRows<T>(
      rows: _sortedRows,
      options: widget.controller.options,
      totalRowCount: widget.totalRowCount,
    );
  }

  int get _totalPages {
    return DataGridCalculations.totalPages(
      totalRows: _totalRows,
      pageSize: widget.controller.options.pageSize,
    );
  }

  double get _tableWidth => _orderedVisibleColumns.fold<double>(
    0,
    (double total, DataGridColumn<T> column) =>
        total + (widget.controller.columnWidths[column.id] ?? column.width),
  );

  String _sortSignature(List<DataGridSortSpec> specs) =>
      DataGridCalculations.sortSignature(specs);

  int get _pageStartIndex => DataGridCalculations.pageStartIndex(
    totalRows: _totalRows,
    page: widget.controller.options.page,
    pageSize: widget.controller.options.pageSize,
  );

  int get _pageEndIndex => DataGridCalculations.pageEndIndex(
    totalRows: _totalRows,
    page: widget.controller.options.page,
    pageSize: widget.controller.options.pageSize,
  );

  int get _defaultFocusableColumnIndex {
    final int index = _orderedVisibleColumns.indexWhere(
      (DataGridColumn<T> column) => column.sortable,
    );
    return index >= 0 ? index : 0;
  }

  bool get _isEditableMode => widget.mode == DataGridMode.editable;

  void _requestGridFocus() {
    if (!_gridFocusNode.hasFocus) {
      _gridFocusNode.requestFocus();
    }
  }

  void _handleGridFocusChange() {
    final bool hasFocus = _gridFocusNode.hasFocus;
    if (_hadGridFocusWithin == hasFocus) {
      return;
    }
    _hadGridFocusWithin = hasFocus;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _clearGridFocus() async {
    if (_editingRowKey != null || _editingColumnId != null) {
      final bool committed = await _commitEditing();
      if (!committed) {
        return;
      }
    }
    widget.controller.setFocus();
    _gridFocusNode.unfocus();
  }

  void _disposeEditingState() {
    _editingFocusNode?.dispose();
    _editingTextController?.dispose();
    _editingFocusNode = null;
    _editingTextController = null;
    _editingRowKey = null;
    _editingColumnId = null;
    _editingErrorText = null;
  }

  int _findVisibleRowIndexByKey(Object rowKey) {
    return _visibleRows.indexWhere((T row) => widget.rowKey(row) == rowKey);
  }

  int _findColumnIndexById(String columnId) {
    return _orderedVisibleColumns.indexWhere(
      (DataGridColumn<T> column) => column.id == columnId,
    );
  }

  T? _findVisibleRowByKey(Object rowKey) {
    final int index = _findVisibleRowIndexByKey(rowKey);
    if (index == -1) {
      return null;
    }
    return _visibleRows[index];
  }

  bool _isEditableCellAt(int visibleRowIndex, int columnIndex) {
    if (!_isEditableMode ||
        visibleRowIndex < 0 ||
        visibleRowIndex >= _visibleRows.length ||
        columnIndex < 0 ||
        columnIndex >= _orderedVisibleColumns.length) {
      return false;
    }
    final T row = _visibleRows[visibleRowIndex];
    final DataGridColumn<T> column = _orderedVisibleColumns[columnIndex];
    return column.isEditableFor(row) && !column.isReadonlyFor(row);
  }

  int? _resolvePreferredEditableColumnIndex(T row) {
    final String? preferredColumnId =
        widget.navigationConfig.rowSelectFocusColumnId;
    if (preferredColumnId != null) {
      final int preferredIndex = _orderedVisibleColumns.indexWhere(
        (DataGridColumn<T> column) =>
            column.id == preferredColumnId &&
            column.isEditableFor(row) &&
            !column.isReadonlyFor(row),
      );
      if (preferredIndex >= 0) {
        return preferredIndex;
      }
    }
    for (int index = 0; index < _orderedVisibleColumns.length; index += 1) {
      final DataGridColumn<T> column = _orderedVisibleColumns[index];
      if (column.isEditableFor(row) && !column.isReadonlyFor(row)) {
        return index;
      }
    }
    return null;
  }

  DataGridFocusTarget? _editableFocusTargetForRow(T row) {
    final int? columnIndex = _resolvePreferredEditableColumnIndex(row);
    if (columnIndex == null) {
      return null;
    }
    return DataGridFocusTarget(
      rowKey: widget.rowKey(row),
      columnId: _orderedVisibleColumns[columnIndex].id,
      preferEditor: true,
      selectEditorText: widget.navigationConfig.autoSelectInputOnFocus,
    );
  }

  String _resolveEditorText(T row, DataGridColumn<T> column) {
    return column.editorText?.call(row) ?? '';
  }

  void _notifyFocusChanged(DataGridFocusTarget target) {
    widget.onFocusChanged?.call(target);
  }

  void _focusInitialCell() {
    if (_visibleRows.isEmpty || _orderedVisibleColumns.isEmpty) {
      return;
    }
    final T row = _visibleRows.first;
    if (_isEditableMode) {
      final DataGridFocusTarget? editableTarget = _editableFocusTargetForRow(
        row,
      );
      if (editableTarget != null) {
        _activateFocusTarget(editableTarget);
        return;
      }
    }
    _activateFocusTarget(
      DataGridFocusTarget(
        rowKey: widget.rowKey(row),
        columnId: _orderedVisibleColumns[_defaultFocusableColumnIndex].id,
      ),
    );
  }

  void _ensureFocusableCellSelected() {
    if (_visibleRows.isEmpty || _orderedVisibleColumns.isEmpty) {
      widget.controller.setFocus();
      return;
    }
    if (widget.controller.focusedRowKey == null ||
        widget.controller.focusedColumnId == null) {
      final T row = _visibleRows.first;
      widget.controller.focusCell(
        rowKey: widget.rowKey(row),
        columnId: _orderedVisibleColumns[_defaultFocusableColumnIndex].id,
      );
    }
  }

  int? _focusedVisibleRowIndex() {
    final Object? key = widget.controller.focusedRowKey;
    if (key == null) {
      return null;
    }
    final int index = _visibleRows.indexWhere(
      (T row) => widget.rowKey(row) == key,
    );
    return index == -1 ? null : index;
  }

  int? _focusedColumnIndex() {
    final String? columnId = widget.controller.focusedColumnId;
    if (columnId == null) {
      return null;
    }
    final int index = _orderedVisibleColumns.indexWhere(
      (DataGridColumn<T> column) => column.id == columnId,
    );
    return index == -1 ? null : index;
  }

  void _setFocusedCell(int visibleRowIndex, int columnIndex) {
    if (_visibleRows.isEmpty || _orderedVisibleColumns.isEmpty) {
      return;
    }
    final int safeRow = visibleRowIndex.clamp(0, _visibleRows.length - 1);
    final int safeColumn = columnIndex.clamp(
      0,
      _orderedVisibleColumns.length - 1,
    );
    final T row = _visibleRows[safeRow];
    final DataGridFocusTarget target = DataGridFocusTarget(
      rowKey: widget.rowKey(row),
      columnId: _orderedVisibleColumns[safeColumn].id,
    );
    widget.controller.focusCell(
      rowKey: target.rowKey,
      columnId: target.columnId,
    );
    _notifyFocusChanged(target);
    _requestGridFocus();
  }

  void _focusCellAt(int visibleRowIndex, int columnIndex) {
    if (_visibleRows.isEmpty || _orderedVisibleColumns.isEmpty) {
      return;
    }
    final int safeRow = visibleRowIndex.clamp(0, _visibleRows.length - 1);
    final int safeColumn = columnIndex.clamp(
      0,
      _orderedVisibleColumns.length - 1,
    );
    if (_isEditableMode && _isEditableCellAt(safeRow, safeColumn)) {
      final T row = _visibleRows[safeRow];
      _activateFocusTarget(
        DataGridFocusTarget(
          rowKey: widget.rowKey(row),
          columnId: _orderedVisibleColumns[safeColumn].id,
          preferEditor: true,
          selectEditorText: widget.navigationConfig.autoSelectInputOnFocus,
        ),
      );
      return;
    }
    _setFocusedCell(safeRow, safeColumn);
  }

  void _ensureTableAnchorFocus({String? preferredColumnId}) {
    if (_visibleRows.isEmpty || _orderedVisibleColumns.isEmpty) {
      return;
    }
    if (widget.controller.focusedRowKey != null &&
        widget.controller.focusedColumnId != null) {
      return;
    }
    final String fallbackColumnId =
        _orderedVisibleColumns[_defaultFocusableColumnIndex].id;
    widget.controller.focusCell(
      rowKey: widget.rowKey(_visibleRows.first),
      columnId: preferredColumnId ?? fallbackColumnId,
    );
  }

  void _restoreFocusAfterTableChange() {
    if (widget.controller.options.paginationMode ==
        DataGridPaginationMode.server) {
      return;
    }
    final Object? focusedRowKey = widget.controller.focusedRowKey;
    if (focusedRowKey == null) {
      return;
    }
    final int sortedIndex = _sortedRows.indexWhere(
      (T row) => widget.rowKey(row) == focusedRowKey,
    );
    if (sortedIndex == -1) {
      return;
    }
    final int nextPage =
        (sortedIndex ~/ widget.controller.options.pageSize) + 1;
    final int rowIndexOnPage = sortedIndex % widget.controller.options.pageSize;
    if (nextPage != widget.controller.options.page) {
      widget.controller.updateOptions(
        widget.controller.options.copyWith(page: nextPage),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _jumpTableToRowOffset(rowIndexOnPage);
        _requestGridFocus();
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _jumpTableToRowOffset(rowIndexOnPage);
      _requestGridFocus();
    });
  }

  void _ensureCellVisible(
    int visibleRowIndex,
    int columnIndex, {
    int? verticalNavigationDelta,
  }) {
    if (_verticalController.hasClients) {
      final ({double top, double bottom})? bounds = _rowBoundsForIndex(
        visibleRowIndex,
      );
      if (bounds == null) {
        return;
      }
      final double rowTop = bounds.top;
      final double rowBottom = bounds.bottom;
      final double rowHeight = rowBottom - rowTop;
      final double currentOffset = _verticalController.offset;
      final double viewportDimension =
          _verticalController.position.viewportDimension;
      final double viewportEnd = currentOffset + viewportDimension;
      double targetOffset = currentOffset;
      final bool shouldCenterOnVerticalNavigation =
          verticalNavigationDelta != null &&
          ((verticalNavigationDelta > 0 &&
                  rowBottom >= viewportEnd - (rowHeight / 2)) ||
              (verticalNavigationDelta < 0 &&
                  rowTop <= currentOffset + (rowHeight / 2)));
      if (shouldCenterOnVerticalNavigation) {
        targetOffset = rowTop - ((viewportDimension - rowHeight) / 2);
      } else if (rowTop < currentOffset) {
        targetOffset = rowTop;
      } else if (rowBottom > viewportEnd) {
        targetOffset = rowBottom - viewportDimension;
      }
      targetOffset = targetOffset.clamp(
        _verticalController.position.minScrollExtent,
        _verticalController.position.maxScrollExtent,
      );
      if ((targetOffset - currentOffset).abs() > 0.5) {
        _verticalController.jumpTo(targetOffset);
      }
    }
    if (_fixedVerticalController.hasClients) {
      final double target = _verticalController.hasClients
          ? _verticalController.offset.clamp(
              _fixedVerticalController.position.minScrollExtent,
              _fixedVerticalController.position.maxScrollExtent,
            )
          : _fixedVerticalController.offset;
      if ((target - _fixedVerticalController.offset).abs() > 0.5) {
        _fixedVerticalController.jumpTo(target);
      }
    }
    if (!_horizontalController.hasClients || _lastViewportWidth <= 0) {
      return;
    }
    double leading = 0;
    for (int index = 0; index < columnIndex; index += 1) {
      final DataGridColumn<T> column = _orderedVisibleColumns[index];
      leading += widget.controller.columnWidths[column.id] ?? column.width;
    }
    final DataGridColumn<T> targetColumn = _orderedVisibleColumns[columnIndex];
    final double width =
        widget.controller.columnWidths[targetColumn.id] ?? targetColumn.width;
    final double trailing = leading + width;
    final double currentOffset = _horizontalController.offset;
    final double viewportEnd = currentOffset + _lastViewportWidth;
    double targetOffset = currentOffset;
    if (leading < currentOffset) {
      targetOffset = leading;
    } else if (trailing > viewportEnd) {
      targetOffset = trailing - _lastViewportWidth;
    }
    targetOffset = targetOffset.clamp(
      _horizontalController.position.minScrollExtent,
      _horizontalController.position.maxScrollExtent,
    );
    if ((targetOffset - currentOffset).abs() > 0.5) {
      _horizontalController.jumpTo(targetOffset);
    }
  }

  ({double top, double bottom})? _rowBoundsForIndex(int visibleRowIndex) {
    if (visibleRowIndex < 0 || visibleRowIndex >= _visibleRows.length) {
      return null;
    }
    double rowTop = 0;
    for (int index = 0; index < visibleRowIndex; index += 1) {
      final T row = _visibleRows[index];
      rowTop +=
          widget.controller.rowHeights[widget.rowKey(row)] ?? _defaultRowHeight;
    }
    final T row = _visibleRows[visibleRowIndex];
    final double rowHeight =
        widget.controller.rowHeights[widget.rowKey(row)] ?? _defaultRowHeight;
    return (top: rowTop, bottom: rowTop + rowHeight);
  }

  bool _isRowFullyVisible(int visibleRowIndex) {
    if (!_verticalController.hasClients) {
      return true;
    }
    final ({double top, double bottom})? bounds = _rowBoundsForIndex(
      visibleRowIndex,
    );
    if (bounds == null) {
      return false;
    }
    final double currentOffset = _verticalController.offset;
    final double viewportEnd =
        currentOffset + _verticalController.position.viewportDimension;
    return bounds.top >= currentOffset && bounds.bottom <= viewportEnd;
  }

  void _restoreScrollOffsets({
    required double verticalOffset,
    required double horizontalOffset,
  }) {
    if (_verticalController.hasClients) {
      final double clamped = verticalOffset.clamp(
        _verticalController.position.minScrollExtent,
        _verticalController.position.maxScrollExtent,
      );
      if ((_verticalController.offset - clamped).abs() > 0.5) {
        _verticalController.jumpTo(clamped);
      }
    }
    if (_fixedVerticalController.hasClients) {
      final double clamped = verticalOffset.clamp(
        _fixedVerticalController.position.minScrollExtent,
        _fixedVerticalController.position.maxScrollExtent,
      );
      if ((_fixedVerticalController.offset - clamped).abs() > 0.5) {
        _fixedVerticalController.jumpTo(clamped);
      }
    }
    if (_horizontalController.hasClients) {
      final double clamped = horizontalOffset.clamp(
        _horizontalController.position.minScrollExtent,
        _horizontalController.position.maxScrollExtent,
      );
      if ((_horizontalController.offset - clamped).abs() > 0.5) {
        _horizontalController.jumpTo(clamped);
      }
    }
  }

  void _ensureFocusedCellVisible({int? verticalNavigationDelta}) {
    final int? rowIndex = _focusedVisibleRowIndex();
    final int? columnIndex = _focusedColumnIndex();
    if (rowIndex == null || columnIndex == null) {
      return;
    }
    _ensureCellVisible(
      rowIndex,
      columnIndex,
      verticalNavigationDelta: verticalNavigationDelta,
    );
  }

  void _activateFocusTarget(DataGridFocusTarget target) {
    widget.controller.focusCell(
      rowKey: target.rowKey,
      columnId: target.columnId,
      preferEditor: target.preferEditor,
      selectEditorText: target.selectEditorText,
    );
    _notifyFocusChanged(target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final int rowIndex = _findVisibleRowIndexByKey(target.rowKey);
      final int columnIndex = _findColumnIndexById(target.columnId);
      if (rowIndex == -1 || columnIndex == -1) {
        return;
      }
      _ensureCellVisible(rowIndex, columnIndex);
      if (target.preferEditor && _isEditableCellAt(rowIndex, columnIndex)) {
        _startEditingCell(
          rowIndex,
          columnIndex,
          selectAll: target.selectEditorText,
        );
      } else {
        _requestGridFocus();
      }
    });
  }

  void _moveToPage(
    int page, {
    required int targetRowIndex,
    required int targetColumnIndex,
  }) {
    final int clampedPage = page.clamp(1, _totalPages);
    final int safeColumn = targetColumnIndex.clamp(
      0,
      _orderedVisibleColumns.length - 1,
    );
    Object? nextRowKey;
    if (widget.controller.options.paginationMode ==
        DataGridPaginationMode.local) {
      final int nextStart =
          (clampedPage - 1) * widget.controller.options.pageSize;
      final int nextLength = math.min(
        widget.controller.options.pageSize,
        _sortedRows.length - nextStart,
      );
      if (nextLength > 0) {
        final int safeRow = targetRowIndex.clamp(0, nextLength - 1);
        nextRowKey = widget.rowKey(_sortedRows[nextStart + safeRow]);
      }
    }
    final int pageLength =
        widget.controller.options.paginationMode ==
            DataGridPaginationMode.server
        ? _visibleRows.length
        : math.min(
            widget.controller.options.pageSize,
            math.max(
              0,
              _sortedRows.length -
                  ((clampedPage - 1) * widget.controller.options.pageSize),
            ),
          );
    final int safeRowIndex = pageLength <= 0
        ? 0
        : targetRowIndex.clamp(0, pageLength - 1);
    widget.controller.goToPage(clampedPage);
    if (nextRowKey != null) {
      final String nextColumnId = _orderedVisibleColumns[safeColumn].id;
      widget.controller.setFocus(rowKey: nextRowKey, columnId: nextColumnId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        widget.controller.setFocus(rowKey: nextRowKey, columnId: nextColumnId);
        _jumpTableToRowOffset(safeRowIndex);
        _requestGridFocus();
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _jumpTableToRowOffset(safeRowIndex);
    });
  }

  void _startEditingCell(
    int visibleRowIndex,
    int columnIndex, {
    bool selectAll = false,
  }) {
    if (!_isEditableCellAt(visibleRowIndex, columnIndex)) {
      return;
    }
    final T row = _visibleRows[visibleRowIndex];
    final DataGridColumn<T> column = _orderedVisibleColumns[columnIndex];
    final Object rowKey = widget.rowKey(row);
    final bool preserveViewport = _isRowFullyVisible(visibleRowIndex);
    final double verticalOffset = _verticalController.hasClients
        ? _verticalController.offset
        : 0;
    final double horizontalOffset = _horizontalController.hasClients
        ? _horizontalController.offset
        : 0;
    final bool sameCell =
        _editingRowKey == rowKey && _editingColumnId == column.id;
    if (!sameCell) {
      _disposeEditingState();
      _editingRowKey = rowKey;
      _editingColumnId = column.id;
      _editingTextController = TextEditingController(
        text: _resolveEditorText(row, column),
      );
      _editingFocusNode = FocusNode(
        debugLabel: 'grid-editor-$rowKey-${column.id}',
      );
      _editingErrorText = null;
      widget.controller.beginEdit(rowKey: rowKey, columnId: column.id);
      widget.onEditStart?.call(
        DataGridEditStart<T>(
          row: row,
          rowIndex: visibleRowIndex,
          column: column,
        ),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _editingFocusNode == null ||
          _editingTextController == null) {
        return;
      }
      _editingFocusNode!.requestFocus();
      if (selectAll) {
        _editingTextController!.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _editingTextController!.text.length,
        );
      } else {
        _editingTextController!.selection = TextSelection.collapsed(
          offset: _editingTextController!.text.length,
        );
      }
      if (preserveViewport) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _restoreScrollOffsets(
            verticalOffset: verticalOffset,
            horizontalOffset: horizontalOffset,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            _restoreScrollOffsets(
              verticalOffset: verticalOffset,
              horizontalOffset: horizontalOffset,
            );
          });
        });
      }
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _clearCellAndFocusEditor(int visibleRowIndex, int columnIndex) {
    _startEditingCell(visibleRowIndex, columnIndex, selectAll: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _editingTextController == null ||
          _editingFocusNode == null) {
        return;
      }
      _editingTextController!
        ..clear()
        ..selection = const TextSelection.collapsed(offset: 0);
      _editingErrorText = null;
      _editingFocusNode!.requestFocus();
      widget.onEditClear?.call();
      setState(() {});
    });
  }

  void _cancelEditing() {
    if (_editingRowKey == null || _editingColumnId == null) {
      return;
    }
    widget.controller.endEdit();
    _disposeEditingState();
    widget.onEditCancel?.call();
    _requestGridFocus();
    if (mounted) {
      setState(() {});
    }
  }

  Future<bool> _commitEditing({
    DataGridFocusTarget? nextFocusTarget,
    bool restoreCurrentEditor = false,
  }) async {
    if (_isCommittingEdit ||
        _editingRowKey == null ||
        _editingColumnId == null ||
        _editingTextController == null) {
      return true;
    }
    final T? row = _findVisibleRowByKey(_editingRowKey!);
    final int rowIndex = _findVisibleRowIndexByKey(_editingRowKey!);
    final int columnIndex = _findColumnIndexById(_editingColumnId!);
    if (row == null || rowIndex == -1 || columnIndex == -1) {
      _cancelEditing();
      return true;
    }
    final DataGridColumn<T> column = _orderedVisibleColumns[columnIndex];
    final String previousValue = _resolveEditorText(row, column);
    final String nextValue = _editingTextController!.text;
    if (column.required && nextValue.trim().isEmpty) {
      setState(() {
        _editingErrorText = column.requiredMessage ?? 'Required field';
      });
      _editingFocusNode?.requestFocus();
      return false;
    }
    _isCommittingEdit = true;
    bool success = true;
    if (widget.onEditCommit != null) {
      success = await widget.onEditCommit!(
        DataGridEditCommit<T>(
          row: row,
          rowIndex: rowIndex,
          column: column,
          previousValue: previousValue,
          nextValue: nextValue,
        ),
      );
    }
    _isCommittingEdit = false;
    if (!success) {
      setState(() {
        _editingErrorText = 'Unable to save changes';
      });
      _editingFocusNode?.requestFocus();
      return false;
    }
    widget.controller.endEdit();
    _disposeEditingState();
    if (mounted) {
      setState(() {});
    }
    if (nextFocusTarget != null) {
      _activateFocusTarget(nextFocusTarget);
      return true;
    }
    if (restoreCurrentEditor) {
      _activateFocusTarget(
        DataGridFocusTarget(
          rowKey: widget.rowKey(row),
          columnId: column.id,
          preferEditor: true,
          selectEditorText: widget.navigationConfig.autoSelectInputOnFocus,
        ),
      );
      return true;
    }
    _requestGridFocus();
    return true;
  }

  Future<void> _handleEditorTapOutside() async {
    await _commitEditing();
  }

  Future<void> _moveEditorFocusVertical(int delta) async {
    if (_editingRowKey == null || _editingColumnId == null) {
      return;
    }
    final int currentRowIndex = _findVisibleRowIndexByKey(_editingRowKey!);
    final int currentColumnIndex = _findColumnIndexById(_editingColumnId!);
    if (currentRowIndex == -1 || currentColumnIndex == -1) {
      return;
    }
    final int nextRowIndex = currentRowIndex + delta;
    if (nextRowIndex >= 0 && nextRowIndex < _visibleRows.length) {
      if (_isEditableCellAt(nextRowIndex, currentColumnIndex)) {
        await _commitEditing(
          nextFocusTarget: DataGridFocusTarget(
            rowKey: widget.rowKey(_visibleRows[nextRowIndex]),
            columnId: _orderedVisibleColumns[currentColumnIndex].id,
            preferEditor: true,
            selectEditorText: widget.navigationConfig.autoSelectInputOnFocus,
          ),
        );
        return;
      }
    }
    if (delta > 0 && widget.controller.options.page < _totalPages) {
      final bool committed = await _commitEditing();
      if (!committed) {
        return;
      }
      final String columnId = _orderedVisibleColumns[currentColumnIndex].id;
      final int pageTargetRow = 0;
      _moveToPage(
        widget.controller.options.page + 1,
        targetRowIndex: pageTargetRow,
        targetColumnIndex: currentColumnIndex,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _visibleRows.isEmpty) {
          return;
        }
        final int targetColumnIndex = _findColumnIndexById(
          columnId,
        ).clamp(0, _orderedVisibleColumns.length - 1);
        if (_isEditableCellAt(0, targetColumnIndex)) {
          _startEditingCell(
            0,
            targetColumnIndex,
            selectAll: widget.navigationConfig.autoSelectInputOnFocus,
          );
        }
      });
      return;
    }
    if (delta < 0 && widget.controller.options.page > 1) {
      final bool committed = await _commitEditing();
      if (!committed) {
        return;
      }
      final String columnId = _orderedVisibleColumns[currentColumnIndex].id;
      final int targetRowIndex = widget.controller.options.pageSize - 1;
      _moveToPage(
        widget.controller.options.page - 1,
        targetRowIndex: targetRowIndex,
        targetColumnIndex: currentColumnIndex,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _visibleRows.isEmpty) {
          return;
        }
        final int targetColumnIndex = _findColumnIndexById(
          columnId,
        ).clamp(0, _orderedVisibleColumns.length - 1);
        final int rowIndex = _visibleRows.length - 1;
        if (_isEditableCellAt(rowIndex, targetColumnIndex)) {
          _startEditingCell(
            rowIndex,
            targetColumnIndex,
            selectAll: widget.navigationConfig.autoSelectInputOnFocus,
          );
        }
      });
    }
  }

  DataGridFocusTarget? _nextEditableTarget({required bool forward}) {
    if (_editingRowKey == null || _editingColumnId == null) {
      return null;
    }
    final int currentRowIndex = _findVisibleRowIndexByKey(_editingRowKey!);
    final int currentColumnIndex = _findColumnIndexById(_editingColumnId!);
    if (currentRowIndex == -1 || currentColumnIndex == -1) {
      return null;
    }
    if (forward) {
      for (
        int rowIndex = currentRowIndex;
        rowIndex < _visibleRows.length;
        rowIndex += 1
      ) {
        final int startColumn = rowIndex == currentRowIndex
            ? currentColumnIndex + 1
            : 0;
        for (
          int columnIndex = startColumn;
          columnIndex < _orderedVisibleColumns.length;
          columnIndex += 1
        ) {
          if (_isEditableCellAt(rowIndex, columnIndex)) {
            return DataGridFocusTarget(
              rowKey: widget.rowKey(_visibleRows[rowIndex]),
              columnId: _orderedVisibleColumns[columnIndex].id,
              preferEditor: true,
              selectEditorText: widget.navigationConfig.autoSelectInputOnFocus,
            );
          }
        }
      }
      return null;
    }
    for (int rowIndex = currentRowIndex; rowIndex >= 0; rowIndex -= 1) {
      final int startColumn = rowIndex == currentRowIndex
          ? currentColumnIndex - 1
          : _orderedVisibleColumns.length - 1;
      for (int columnIndex = startColumn; columnIndex >= 0; columnIndex -= 1) {
        if (_isEditableCellAt(rowIndex, columnIndex)) {
          return DataGridFocusTarget(
            rowKey: widget.rowKey(_visibleRows[rowIndex]),
            columnId: _orderedVisibleColumns[columnIndex].id,
            preferEditor: true,
            selectEditorText: widget.navigationConfig.autoSelectInputOnFocus,
          );
        }
      }
    }
    return null;
  }

  Future<void> _moveEditorFocusTab({required bool forward}) async {
    final DataGridFocusTarget? target = _nextEditableTarget(forward: forward);
    await _commitEditing(
      nextFocusTarget: target,
      restoreCurrentEditor: target == null,
    );
  }

  void _moveFocusByRowDelta(int delta) {
    if (_visibleRows.isEmpty) {
      return;
    }
    _ensureFocusableCellSelected();
    final int currentRow = _focusedVisibleRowIndex() ?? 0;
    final int currentColumn =
        _focusedColumnIndex() ?? _defaultFocusableColumnIndex;
    final int nextRow = currentRow + delta;
    if (nextRow >= 0 && nextRow < _visibleRows.length) {
      _focusCellAt(nextRow, currentColumn);
      _ensureFocusedCellVisible(verticalNavigationDelta: delta);
      return;
    }
    if (delta > 0 && widget.controller.options.page < _totalPages) {
      _moveToPage(
        widget.controller.options.page + 1,
        targetRowIndex: 0,
        targetColumnIndex: currentColumn,
      );
      return;
    }
    if (delta < 0 && widget.controller.options.page > 1) {
      _moveToPage(
        widget.controller.options.page - 1,
        targetRowIndex: widget.controller.options.pageSize - 1,
        targetColumnIndex: currentColumn,
      );
    }
  }

  void _moveFocusByColumnDelta(int delta) {
    if (_visibleRows.isEmpty || _orderedVisibleColumns.isEmpty) {
      return;
    }
    _ensureFocusableCellSelected();
    final int currentRow = _focusedVisibleRowIndex() ?? 0;
    final int currentColumn =
        _focusedColumnIndex() ?? _defaultFocusableColumnIndex;
    final int nextColumn = (currentColumn + delta).clamp(
      0,
      _orderedVisibleColumns.length - 1,
    );
    _focusCellAt(currentRow, nextColumn);
    _ensureFocusedCellVisible();
  }

  bool _moveFocusByDeltas(int rowDelta, int columnDelta) {
    final int? currentRow = _focusedVisibleRowIndex();
    final int? currentColumn = _focusedColumnIndex();
    if (currentRow == null || currentColumn == null) {
      return false;
    }
    if (rowDelta != 0) {
      _moveFocusByRowDelta(rowDelta);
      return true;
    }
    if (columnDelta != 0) {
      _moveFocusByColumnDelta(columnDelta);
      return true;
    }
    return false;
  }

  void _movePageBy(int delta) {
    if (_visibleRows.isEmpty) {
      return;
    }
    final int page = (widget.controller.options.page + delta).clamp(
      1,
      _totalPages,
    );
    if (page == widget.controller.options.page) {
      return;
    }
    _moveToPage(
      page,
      targetRowIndex: _focusedVisibleRowIndex() ?? 0,
      targetColumnIndex: _focusedColumnIndex() ?? _defaultFocusableColumnIndex,
    );
  }

  Future<void> _handleEditableCellActivation(
    int visibleRowIndex,
    int columnIndex,
  ) async {
    if (!_isEditableMode) {
      _setFocusedCell(visibleRowIndex, columnIndex);
      _ensureFocusedCellVisible();
      return;
    }
    final T row = _visibleRows[visibleRowIndex];
    if (_isEditableCellAt(visibleRowIndex, columnIndex)) {
      final Object rowKey = widget.rowKey(row);
      final String columnId = _orderedVisibleColumns[columnIndex].id;
      final DataGridFocusTarget target = DataGridFocusTarget(
        rowKey: rowKey,
        columnId: columnId,
        preferEditor: true,
        selectEditorText: widget.navigationConfig.autoSelectInputOnFocus,
      );
      if (_editingRowKey != null &&
          (_editingRowKey != target.rowKey ||
              _editingColumnId != target.columnId)) {
        await _commitEditing(nextFocusTarget: target);
      } else {
        _activateFocusTarget(target);
      }
      return;
    }
    final DataGridFocusTarget? preferredTarget = _editableFocusTargetForRow(
      row,
    );
    if (preferredTarget != null) {
      if (_editingRowKey != null &&
          (_editingRowKey != preferredTarget.rowKey ||
              _editingColumnId != preferredTarget.columnId)) {
        await _commitEditing(nextFocusTarget: preferredTarget);
      } else {
        _activateFocusTarget(preferredTarget);
      }
      return;
    }
    _activateFocusTarget(
      DataGridFocusTarget(
        rowKey: widget.rowKey(row),
        columnId: _orderedVisibleColumns[columnIndex].id,
      ),
    );
  }

  void _toggleSelectAll(bool? value) {
    final List<Object> selectableKeys = <Object>[];
    for (int index = 0; index < _visibleRows.length; index += 1) {
      final T row = _visibleRows[index];
      if (_canSelectRow(row, index)) {
        selectableKeys.add(widget.rowKey(row));
      }
    }
    final Set<Object> next = widget.controller.selectedRowKeys.toSet();
    if (value == true) {
      final int additional = _countAddedKeys(next, selectableKeys);
      if (_selectionConfig.maxSelected != null &&
          next.length + additional > _selectionConfig.maxSelected!) {
        return;
      }
      next.addAll(selectableKeys);
    } else {
      final int removed = _countRemovedKeys(next, selectableKeys);
      if (next.length - removed < _selectionConfig.minSelected) {
        return;
      }
      next.removeAll(selectableKeys);
    }
    widget.controller.replaceSelection(next);
  }

  bool _canSelectRow(T row, int rowIndex) {
    return _selectionConfig.isSelectable?.call(row, rowIndex) ?? true;
  }

  bool get _isShiftPressed =>
      HardwareKeyboard.instance.logicalKeysPressed.contains(
        LogicalKeyboardKey.shiftLeft,
      ) ||
      HardwareKeyboard.instance.logicalKeysPressed.contains(
        LogicalKeyboardKey.shiftRight,
      );

  int _countAddedKeys(Set<Object> current, Iterable<Object> candidates) {
    return DataGridSelectionUtils.countAddedKeys(current, candidates);
  }

  int _countRemovedKeys(Set<Object> current, Iterable<Object> candidates) {
    return DataGridSelectionUtils.countRemovedKeys(current, candidates);
  }

  bool _applyRangeSelection(int rowIndex, {required bool nextSelected}) {
    final Object? anchorKey = nextSelected
        ? _lastCheckedRowKey
        : _lastUncheckedRowKey;
    if (!_selectionConfig.multiSelect || anchorKey == null) {
      return false;
    }
    final int anchorIndex = _findVisibleRowIndexByKey(anchorKey);
    if (anchorIndex < 0) {
      return false;
    }

    final int start = math.min(anchorIndex, rowIndex);
    final int end = math.max(anchorIndex, rowIndex);
    final List<Object> rangeKeys = <Object>[];
    for (int index = start; index <= end; index += 1) {
      final T candidate = _visibleRows[index];
      if (_canSelectRow(candidate, index)) {
        rangeKeys.add(widget.rowKey(candidate));
      }
    }
    if (rangeKeys.isEmpty) {
      return false;
    }

    final Set<Object> next = widget.controller.selectedRowKeys.toSet();
    if (nextSelected) {
      final int additional = _countAddedKeys(next, rangeKeys);
      if (_selectionConfig.maxSelected != null &&
          next.length + additional > _selectionConfig.maxSelected!) {
        return true;
      }
      next.addAll(rangeKeys);
      _lastCheckedRowKey = widget.rowKey(_visibleRows[rowIndex]);
    } else {
      final int removed = _countRemovedKeys(next, rangeKeys);
      if (next.length - removed < _selectionConfig.minSelected) {
        return true;
      }
      next.removeAll(rangeKeys);
      _lastUncheckedRowKey = widget.rowKey(_visibleRows[rowIndex]);
    }
    widget.controller.replaceSelection(next);
    return true;
  }

  void _toggleRowSelection(T row, int rowIndex) {
    if (!_canSelectRow(row, rowIndex)) {
      return;
    }
    final Object rowKey = widget.rowKey(row);
    final Set<Object> current = widget.controller.selectedRowKeys.toSet();
    final bool isSelected = current.contains(rowKey);
    if (_isShiftPressed &&
        _applyRangeSelection(rowIndex, nextSelected: !isSelected)) {
      return;
    }
    final int nextCount = isSelected ? current.length - 1 : current.length + 1;
    if (isSelected && nextCount < _selectionConfig.minSelected) {
      return;
    }
    if (!isSelected &&
        _selectionConfig.maxSelected != null &&
        nextCount > _selectionConfig.maxSelected!) {
      return;
    }
    widget.controller.toggleSelection(
      rowKey,
      multiSelect: _selectionConfig.multiSelect,
    );
    if (isSelected) {
      _lastUncheckedRowKey = rowKey;
    } else {
      _lastCheckedRowKey = rowKey;
    }
  }

  void _syncFixedColumnScroll() {
    if (_syncingFixedScroll || !_fixedVerticalController.hasClients) {
      return;
    }
    _syncingFixedScroll = true;
    final double target = _verticalController.offset.clamp(
      _fixedVerticalController.position.minScrollExtent,
      _fixedVerticalController.position.maxScrollExtent,
    );
    if ((_fixedVerticalController.offset - target).abs() > 0.5) {
      _fixedVerticalController.jumpTo(target);
    }
    _syncingFixedScroll = false;
  }

  void _jumpTableToTop() {
    if (_verticalController.hasClients) {
      _verticalController.jumpTo(0);
    }
    if (_fixedVerticalController.hasClients) {
      _fixedVerticalController.jumpTo(0);
    }
  }

  void _jumpTableToRowOffset(int rowIndex) {
    if (rowIndex <= 0) {
      _jumpTableToTop();
      return;
    }
    final double targetOffset = rowIndex * _defaultRowHeight;
    if (_verticalController.hasClients) {
      final double clamped = targetOffset.clamp(
        _verticalController.position.minScrollExtent,
        _verticalController.position.maxScrollExtent,
      );
      _verticalController.jumpTo(clamped);
    }
    if (_fixedVerticalController.hasClients) {
      final double clamped = targetOffset.clamp(
        _fixedVerticalController.position.minScrollExtent,
        _fixedVerticalController.position.maxScrollExtent,
      );
      _fixedVerticalController.jumpTo(clamped);
    }
  }

  Color _resolveRowColor(int index, T row) {
    final Object key = widget.rowKey(row);
    final bool isFocusedRow = widget.controller.focusedRowKey == key;
    final bool isSelected = widget.controller.selectedRowKeys.contains(key);
    final bool isHovered = _hoveredRowKey == key;
    final Color base =
        widget.rowColorBuilder?.call(row, index, isSelected, isHovered) ??
        (index.isEven ? _palette.row : _palette.rowAlt);
    if (isFocusedRow || isSelected) {
      return _palette.selectedRow;
    }
    if (isHovered) {
      return _palette.hoverRow;
    }
    return base;
  }

  Widget _buildPinnedSelectionRows() {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: _AnimatedRowsList<T>(
        controller: _fixedVerticalController,
        items: _visibleRows,
        areItemsEqual: (T left, T right) =>
            widget.rowKey(left) == widget.rowKey(right),
        itemExtentBuilder: (int index, SliverLayoutDimensions dimensions) {
          final T row = _visibleRows[index];
          return widget.controller.rowHeights[widget.rowKey(row)] ??
              _defaultRowHeight;
        },
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (BuildContext context, T row, int index) {
          final Object rowKey = widget.rowKey(row);
          return _PinnedCheckboxRow(
            rowKey: rowKey,
            rowHeight:
                widget.controller.rowHeights[rowKey] ?? _defaultRowHeight,
            backgroundColor: _resolveRowColor(index, row),
            borderColor: _palette.border,
            isSelected: widget.controller.selectedRowKeys.contains(rowKey),
            enabled: _canSelectRow(row, index),
            onResize: (double delta) => widget.controller.resizeRow(
              rowKey,
              delta,
              baseHeight: _defaultRowHeight,
            ),
            onChanged: (_) => _toggleRowSelection(row, index),
          );
        },
      ),
    );
  }

  Widget _buildTableRows(List<DataGridColumn<T>> columns) {
    return _AnimatedRowsList<T>(
      controller: _verticalController,
      items: _visibleRows,
      areItemsEqual: (T left, T right) =>
          widget.rowKey(left) == widget.rowKey(right),
      itemExtentBuilder: (int index, SliverLayoutDimensions dimensions) {
        final T row = _visibleRows[index];
        return widget.controller.rowHeights[widget.rowKey(row)] ??
            _defaultRowHeight;
      },
      itemBuilder: (BuildContext context, T row, int index) {
        final Object rowKey = widget.rowKey(row);
        return _TableRowWidget<T>(
          row: row,
          rowKey: rowKey,
          visibleRowIndex: index,
          rowHeight: widget.controller.rowHeights[rowKey] ?? _defaultRowHeight,
          columns: columns,
          columnWidths: widget.controller.columnWidths,
          backgroundColor: _resolveRowColor(index, row),
          borderColor: _palette.border,
          focusedRowKey: widget.controller.focusedRowKey,
          focusedColumnId: widget.controller.focusedColumnId,
          editingRowKey: _editingRowKey,
          editingColumnId: _editingColumnId,
          editingController: _editingTextController,
          editingFocusNode: _editingFocusNode,
          editingErrorText: _editingErrorText,
          isEditableMode: _isEditableMode,
          onTap: () {
            widget.onRowTap?.call(row);
          },
          onCellTap: (int columnIndex) {
            unawaited(_handleEditableCellActivation(index, columnIndex));
          },
          onDisplayClearTap: (int columnIndex) {
            _clearCellAndFocusEditor(index, columnIndex);
          },
          onEditorSubmitted: () async {
            await _moveEditorFocusVertical(1);
          },
          onEditorTapOutside: _handleEditorTapOutside,
          onEditorClear: () {
            _editingTextController?.clear();
            widget.onEditClear?.call();
          },
          onEditorKeyEvent: (KeyEvent keyEvent) {
            if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
              return KeyEventResult.ignored;
            }
            if (keyEvent.logicalKey == LogicalKeyboardKey.escape) {
              _cancelEditing();
              return KeyEventResult.handled;
            }
            if (keyEvent.logicalKey == LogicalKeyboardKey.enter) {
              unawaited(_moveEditorFocusVertical(1));
              return KeyEventResult.handled;
            }
            if (keyEvent.logicalKey == LogicalKeyboardKey.tab) {
              final bool reverse =
                  HardwareKeyboard.instance.logicalKeysPressed.contains(
                    LogicalKeyboardKey.shiftLeft,
                  ) ||
                  HardwareKeyboard.instance.logicalKeysPressed.contains(
                    LogicalKeyboardKey.shiftRight,
                  );
              unawaited(_moveEditorFocusTab(forward: !reverse));
              return KeyEventResult.handled;
            }
            if (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp) {
              unawaited(_moveEditorFocusVertical(-1));
              return KeyEventResult.handled;
            }
            if (keyEvent.logicalKey == LogicalKeyboardKey.arrowDown) {
              unawaited(_moveEditorFocusVertical(1));
              return KeyEventResult.handled;
            }
            if (keyEvent.logicalKey == LogicalKeyboardKey.arrowLeft) {
              final TextSelection selection =
                  _editingTextController?.selection ??
                  const TextSelection.collapsed(offset: -1);
              if (selection.isCollapsed && selection.start <= 0) {
                unawaited(_moveEditorFocusTab(forward: false));
                return KeyEventResult.handled;
              }
            }
            if (keyEvent.logicalKey == LogicalKeyboardKey.arrowRight) {
              final TextSelection selection =
                  _editingTextController?.selection ??
                  const TextSelection.collapsed(offset: -1);
              final int textLength = _editingTextController?.text.length ?? 0;
              if (selection.isCollapsed && selection.end >= textLength) {
                unawaited(_moveEditorFocusTab(forward: true));
                return KeyEventResult.handled;
              }
            }
            if (keyEvent.logicalKey == LogicalKeyboardKey.pageUp) {
              unawaited(_commitEditing(restoreCurrentEditor: true));
              _movePageBy(-1);
              return KeyEventResult.handled;
            }
            if (keyEvent.logicalKey == LogicalKeyboardKey.pageDown) {
              unawaited(_commitEditing(restoreCurrentEditor: true));
              _movePageBy(1);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          onHoverChanged: (bool hovered) {
            setState(() {
              _hoveredRowKey = hovered ? rowKey : null;
            });
          },
          onResize: (double delta) => widget.controller.resizeRow(
            rowKey,
            delta,
            baseHeight: _defaultRowHeight,
          ),
          onResizeColumn: (DataGridColumn<T> column, double delta) {
            widget.controller.resizeColumn(
              column.id,
              delta,
              column.minWidth,
              column.maxWidth,
            );
          },
        );
      },
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }
    final bool shiftPressed =
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.shiftLeft,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.shiftRight,
        );

    if (shiftPressed && _horizontalController.hasClients) {
      final double nextOffset =
          (_horizontalController.offset +
                  event.scrollDelta.dy +
                  event.scrollDelta.dx)
              .clamp(
                _horizontalController.position.minScrollExtent,
                _horizontalController.position.maxScrollExtent,
              );
      _horizontalController.jumpTo(nextOffset);
      return;
    }

    if (event.scrollDelta.dx != 0 && _horizontalController.hasClients) {
      final double nextOffset =
          (_horizontalController.offset + event.scrollDelta.dx).clamp(
            _horizontalController.position.minScrollExtent,
            _horizontalController.position.maxScrollExtent,
          );
      _horizontalController.jumpTo(nextOffset);
    }
  }

  KeyEventResult _handleGridKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!widget.navigationConfig.keyboardNavigation) {
      return KeyEventResult.ignored;
    }
    final int? rowIndex = _focusedVisibleRowIndex();
    final int? columnIndex = _focusedColumnIndex();
    final T? row = rowIndex == null ? null : _visibleRows[rowIndex];
    final DataGridColumn<T>? column = columnIndex == null
        ? null
        : _orderedVisibleColumns[columnIndex];
    final bool handledByUser =
        widget.onHotkey?.call(
          DataGridHotkeyPayload<T>(
            event: event,
            row: row,
            rowIndex: rowIndex,
            column: column,
            columnIndex: columnIndex,
          ),
        ) ??
        false;
    if (handledByUser) {
      return KeyEventResult.handled;
    }
    if (_visibleRows.isEmpty) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _moveFocusByColumnDelta(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _moveFocusByColumnDelta(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _moveFocusByRowDelta(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _moveFocusByRowDelta(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.tab:
        if (!widget.navigationConfig.captureTabNavigation) {
          return KeyEventResult.ignored;
        }
        final bool reverse =
            HardwareKeyboard.instance.logicalKeysPressed.contains(
              LogicalKeyboardKey.shiftLeft,
            ) ||
            HardwareKeyboard.instance.logicalKeysPressed.contains(
              LogicalKeyboardKey.shiftRight,
            );
        _moveFocusByColumnDelta(reverse ? -1 : 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.pageDown:
        _movePageBy(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.pageUp:
        _movePageBy(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        _focusCellAt(_focusedVisibleRowIndex() ?? 0, 0);
        _ensureFocusedCellVisible();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        _focusCellAt(
          _focusedVisibleRowIndex() ?? 0,
          _orderedVisibleColumns.length - 1,
        );
        _ensureFocusedCellVisible();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  Future<void> _openColumnSettings() async {
    final List<DataGridColumn<T>> columns = widget.columns;
    final List<String>? result = await showDialog<List<String>>(
      context: context,
      builder: (BuildContext context) {
        final Set<String> hidden = widget.controller.hiddenColumnIds.toSet();
        final List<String> ordered = widget.controller.orderedColumnIds.isEmpty
            ? columns.map((DataGridColumn<T> column) => column.id).toList()
            : widget.controller.orderedColumnIds.toList();
        return StatefulBuilder(
          builder:
              (BuildContext context, void Function(void Function()) setState) {
                return AlertDialog(
                  title: const Text('Column settings'),
                  content: SizedBox(
                    width: 420,
                    height: 420,
                    child: ReorderableListView.builder(
                      itemCount: ordered.length,
                      itemBuilder: (BuildContext context, int index) {
                        final DataGridColumn<T> column = columns.firstWhere(
                          (DataGridColumn<T> item) => item.id == ordered[index],
                        );
                        return CheckboxListTile(
                          key: ValueKey<String>(column.id),
                          value:
                              !hidden.contains(column.id) || !column.hideable,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(column.label),
                          secondary: column.reorderable
                              ? const Icon(Icons.drag_indicator_rounded)
                              : const Icon(Icons.lock_outline_rounded),
                          onChanged: column.hideable
                              ? (bool? value) {
                                  setState(() {
                                    if (value ?? false) {
                                      hidden.remove(column.id);
                                    } else {
                                      hidden.add(column.id);
                                    }
                                  });
                                }
                              : null,
                        );
                      },
                      onReorder: (int oldIndex, int newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }
                          final String item = ordered.removeAt(oldIndex);
                          ordered.insert(newIndex, item);
                        });
                      },
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () {
                        widget.controller.resetColumns(widget.columns);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Reset'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(<String>[
                        ...ordered,
                        '::hidden::${hidden.join(",")}',
                      ]),
                      child: const Text('Apply'),
                    ),
                  ],
                );
              },
        );
      },
    );

    if (result == null || result.isEmpty) {
      return;
    }
    final String hiddenMarker = result.firstWhere(
      (String item) => item.startsWith('::hidden::'),
    );
    final List<String> ordered = result
        .where((String item) => !item.startsWith('::hidden::'))
        .toList();
    final String hiddenRaw = hiddenMarker.replaceFirst('::hidden::', '');
    final List<String> hidden = hiddenRaw.isEmpty
        ? <String>[]
        : hiddenRaw.split(',');
    widget.controller.applyColumnSettings(
      hiddenColumnIds: hidden,
      orderedColumnIds: ordered,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<DataGridColumn<T>> columns = _orderedVisibleColumns;
    final double gridHeight = widget.height ?? 560;
    final int currentPage = widget.controller.options.page.clamp(
      1,
      _totalPages,
    );
    return TapRegion(
      onTapOutside: (PointerDownEvent event) {
        unawaited(_clearGridFocus());
      },
      child: Focus(
        focusNode: _gridFocusNode,
        onKeyEvent: _handleGridKeyEvent,
        child: Listener(
          onPointerSignal: _handlePointerSignal,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _requestGridFocus,
            child: Stack(
              children: <Widget>[
                Container(
                  decoration: BoxDecoration(
                    color: _palette.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _palette.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(
                        height: gridHeight,
                        child: LayoutBuilder(
                          builder:
                              (
                                BuildContext context,
                                BoxConstraints constraints,
                              ) {
                                _lastViewportWidth = constraints.maxWidth;
                                final double tableWidth = math.max(
                                  _tableWidth,
                                  constraints.maxWidth - 4,
                                );
                                return Row(
                                  children: <Widget>[
                                    if (_selectionConfig
                                        .enableCheckboxSelection)
                                      SizedBox(
                                        width: _checkboxColumnWidth,
                                        child: Column(
                                          children: <Widget>[
                                            _PinnedCheckboxHeader(
                                              width: _checkboxColumnWidth,
                                              height: _headerHeight,
                                              palette: _palette,
                                              isAllSelected:
                                                  _visibleRows.isNotEmpty &&
                                                  _visibleRows.every(
                                                    (T row) => widget
                                                        .controller
                                                        .selectedRowKeys
                                                        .contains(
                                                          widget.rowKey(row),
                                                        ),
                                                  ),
                                              isPartiallySelected:
                                                  _visibleRows.any(
                                                    (T row) => widget
                                                        .controller
                                                        .selectedRowKeys
                                                        .contains(
                                                          widget.rowKey(row),
                                                        ),
                                                  ) &&
                                                  !_visibleRows.every(
                                                    (T row) => widget
                                                        .controller
                                                        .selectedRowKeys
                                                        .contains(
                                                          widget.rowKey(row),
                                                        ),
                                                  ),
                                              onChanged: _toggleSelectAll,
                                            ),
                                            if (widget.extraTopValues != null)
                                              _PinnedCheckboxSpacerRow(
                                                height: 44,
                                                color: _palette.surfaceMuted,
                                                borderColor: _palette.border,
                                              ),
                                            Expanded(
                                              child:
                                                  _buildPinnedSelectionRows(),
                                            ),
                                            if (widget.extraBottomValues !=
                                                null)
                                              _PinnedCheckboxSpacerRow(
                                                height: 44,
                                                color: _palette.surfaceMuted,
                                                borderColor: _palette.border,
                                              ),
                                            if (widget.summaryValues != null &&
                                                widget
                                                    .summaryValues!
                                                    .isNotEmpty)
                                              _PinnedCheckboxSpacerRow(
                                                height: 48,
                                                color: _palette.summaryRow,
                                                borderColor: _palette.border,
                                                topBorder: true,
                                              ),
                                          ],
                                        ),
                                      ),
                                    Expanded(
                                      child: Scrollbar(
                                        controller: _verticalController,
                                        thumbVisibility: true,
                                        trackVisibility: true,
                                        notificationPredicate:
                                            (ScrollNotification notification) =>
                                                notification.metrics.axis ==
                                                Axis.vertical,
                                        child: Scrollbar(
                                          controller: _horizontalController,
                                          thumbVisibility: true,
                                          trackVisibility: true,
                                          notificationPredicate:
                                              (
                                                ScrollNotification notification,
                                              ) =>
                                                  notification.metrics.axis ==
                                                  Axis.horizontal,
                                          child: SingleChildScrollView(
                                            controller: _horizontalController,
                                            scrollDirection: Axis.horizontal,
                                            child: SizedBox(
                                              width: tableWidth,
                                              child: Column(
                                                children: <Widget>[
                                                  _TableHeader<T>(
                                                    columns: columns,
                                                    palette: _palette,
                                                    height: _headerHeight,
                                                    columnWidths: widget
                                                        .controller
                                                        .columnWidths,
                                                    sortSpecs: widget
                                                        .controller
                                                        .options
                                                        .sortSpecs,
                                                    onResizeColumn:
                                                        (
                                                          DataGridColumn<T>
                                                          column,
                                                          double delta,
                                                        ) {
                                                          widget.controller
                                                              .resizeColumn(
                                                                column.id,
                                                                delta,
                                                                column.minWidth,
                                                                column.maxWidth,
                                                              );
                                                        },
                                                    onSortColumn:
                                                        (
                                                          DataGridColumn<T>
                                                          column,
                                                        ) {
                                                          _ensureTableAnchorFocus(
                                                            preferredColumnId:
                                                                column.id,
                                                          );
                                                          widget.controller
                                                              .toggleSort(
                                                                column.id,
                                                                multiSort: widget
                                                                    .multiSort,
                                                              );
                                                        },
                                                  ),
                                                  if (widget.extraTopValues !=
                                                      null)
                                                    _SupplementaryRow<T>(
                                                      values: widget
                                                          .extraTopValues!,
                                                      columns: columns,
                                                      palette: _palette,
                                                      columnWidths: widget
                                                          .controller
                                                          .columnWidths,
                                                      height: 44,
                                                    ),
                                                  Expanded(
                                                    child: _buildTableRows(
                                                      columns,
                                                    ),
                                                  ),
                                                  if (widget
                                                          .extraBottomValues !=
                                                      null)
                                                    _SupplementaryRow<T>(
                                                      values: widget
                                                          .extraBottomValues!,
                                                      columns: columns,
                                                      palette: _palette,
                                                      columnWidths: widget
                                                          .controller
                                                          .columnWidths,
                                                      height: 44,
                                                    ),
                                                  if (widget.summaryValues !=
                                                          null &&
                                                      widget
                                                          .summaryValues!
                                                          .isNotEmpty)
                                                    _SummaryRow<T>(
                                                      values:
                                                          widget.summaryValues!,
                                                      columns: columns,
                                                      palette: _palette,
                                                      columnWidths: widget
                                                          .controller
                                                          .columnWidths,
                                                      height: 48,
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                        ),
                      ),
                      if (widget.showFooter)
                        _DataGridFooter(
                          palette: _palette,
                          loading: widget.loading,
                          pageStartIndex: _pageStartIndex,
                          pageEndIndex: _pageEndIndex,
                          totalRows: _totalRows,
                          currentPage: currentPage,
                          totalPages: _totalPages,
                          pageSize: widget.controller.options.pageSize,
                          pageSizeOptions: widget.pageSizeOptions,
                          selectedCount:
                              widget.controller.selectedRowKeys.length,
                          showSelectedCount: widget.showSelectedCount,
                          onOpenSettings: _openColumnSettings,
                          onPrevious: currentPage > 1
                              ? () => _moveToPage(
                                  currentPage - 1,
                                  targetRowIndex:
                                      _focusedVisibleRowIndex() ?? 0,
                                  targetColumnIndex:
                                      _focusedColumnIndex() ??
                                      _defaultFocusableColumnIndex,
                                )
                              : null,
                          onNext: currentPage < _totalPages
                              ? () => _moveToPage(
                                  currentPage + 1,
                                  targetRowIndex:
                                      _focusedVisibleRowIndex() ?? 0,
                                  targetColumnIndex:
                                      _focusedColumnIndex() ??
                                      _defaultFocusableColumnIndex,
                                )
                              : null,
                          onPageSizeChanged: (int? value) {
                            if (value == null) {
                              return;
                            }
                            widget.controller.setPageSize(value);
                          },
                        ),
                    ],
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      opacity: widget.loading ? 1 : 0,
                      child: TickerMode(
                        enabled: widget.loading,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: const SizedBox(
                            key: Key('table-loading-bar'),
                            height: 6,
                            child: LinearProgressIndicator(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedRowsList<T> extends StatelessWidget {
  const _AnimatedRowsList({
    required this.items,
    required this.areItemsEqual,
    required this.itemBuilder,
    this.itemExtentBuilder,
    this.controller,
    this.physics,
  });

  final List<T> items;
  final bool Function(T left, T right) areItemsEqual;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final ItemExtentBuilder? itemExtentBuilder;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      physics: physics,
      itemExtentBuilder: itemExtentBuilder,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      addSemanticIndexes: false,
      cacheExtent: 720,
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        final T item = items[index];
        return itemBuilder(context, item, index);
      },
    );
  }
}

class _TableHeader<T> extends StatelessWidget {
  const _TableHeader({
    required this.columns,
    required this.palette,
    required this.height,
    required this.columnWidths,
    required this.sortSpecs,
    required this.onResizeColumn,
    required this.onSortColumn,
  });

  final List<DataGridColumn<T>> columns;
  final _GridPalette palette;
  final double height;
  final Map<String, double> columnWidths;
  final List<DataGridSortSpec> sortSpecs;
  final void Function(DataGridColumn<T> column, double delta) onResizeColumn;
  final ValueChanged<DataGridColumn<T>> onSortColumn;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: palette.header,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: columns.map((DataGridColumn<T> column) {
          final int sortIndex = sortSpecs.indexWhere(
            (DataGridSortSpec spec) => spec.columnId == column.id,
          );
          final DataGridSortDirection? direction = sortIndex == -1
              ? null
              : sortSpecs[sortIndex].direction;
          final double width = columnWidths[column.id] ?? column.width;
          return _HeaderCell<T>(
            key: Key('table-header-${column.id}'),
            column: column,
            palette: palette,
            width: width,
            height: height,
            sortDirection: direction,
            sortOrder: sortIndex == -1 ? null : sortIndex + 1,
            onResize: (double delta) => onResizeColumn(column, delta),
            onSort: () => onSortColumn(column),
          );
        }).toList(),
      ),
    );
  }
}

class _HeaderCell<T> extends StatelessWidget {
  const _HeaderCell({
    super.key,
    required this.column,
    required this.palette,
    required this.width,
    required this.height,
    required this.sortDirection,
    required this.sortOrder,
    required this.onResize,
    required this.onSort,
  });

  final DataGridColumn<T> column;
  final _GridPalette palette;
  final double width;
  final double height;
  final DataGridSortDirection? sortDirection;
  final int? sortOrder;
  final ValueChanged<double> onResize;
  final VoidCallback onSort;

  @override
  Widget build(BuildContext context) {
    final bool showSortOrder = sortOrder != null && width >= 96;
    return Stack(
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: column.sortable ? onSort : null,
            child: Container(
              width: width,
              height: height,
              alignment: column.alignment,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: sortDirection == null ? null : palette.sortHighlight,
                border: Border(right: BorderSide(color: palette.border)),
              ),
              child:
                  column.headerBuilder?.call(context, column) ??
                  Row(
                    mainAxisAlignment: column.alignment == Alignment.centerRight
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          column.label,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: sortDirection == null
                                    ? palette.headerText
                                    : palette.accent,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      if (showSortOrder) ...<Widget>[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: palette.badgeBorder),
                          ),
                          child: Text(
                            '$sortOrder',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: palette.accent,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                      if (column.sortable) ...<Widget>[
                        const SizedBox(width: 4),
                        Icon(
                          switch (sortDirection) {
                            DataGridSortDirection.asc =>
                              Icons.arrow_upward_rounded,
                            DataGridSortDirection.desc =>
                              Icons.arrow_downward_rounded,
                            null => Icons.unfold_more_rounded,
                          },
                          size: 14,
                          color: sortDirection == null
                              ? palette.muted
                              : palette.accent,
                        ),
                      ],
                    ],
                  ),
            ),
          ),
        ),
        if (column.resizable)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (DragUpdateDetails details) =>
                    onResize(details.delta.dx),
                child: const SizedBox(width: 12),
              ),
            ),
          ),
      ],
    );
  }
}

class _TableRowWidget<T> extends StatelessWidget {
  const _TableRowWidget({
    required this.row,
    required this.rowKey,
    required this.visibleRowIndex,
    required this.rowHeight,
    required this.columns,
    required this.columnWidths,
    required this.backgroundColor,
    required this.borderColor,
    required this.focusedRowKey,
    required this.focusedColumnId,
    required this.editingRowKey,
    required this.editingColumnId,
    required this.editingController,
    required this.editingFocusNode,
    required this.editingErrorText,
    required this.isEditableMode,
    required this.onTap,
    required this.onCellTap,
    required this.onDisplayClearTap,
    required this.onEditorSubmitted,
    required this.onEditorTapOutside,
    required this.onEditorClear,
    required this.onEditorKeyEvent,
    required this.onHoverChanged,
    required this.onResize,
    required this.onResizeColumn,
  });

  final T row;
  final Object rowKey;
  final int visibleRowIndex;
  final double rowHeight;
  final List<DataGridColumn<T>> columns;
  final Map<String, double> columnWidths;
  final Color backgroundColor;
  final Color borderColor;
  final Object? focusedRowKey;
  final String? focusedColumnId;
  final Object? editingRowKey;
  final String? editingColumnId;
  final TextEditingController? editingController;
  final FocusNode? editingFocusNode;
  final String? editingErrorText;
  final bool isEditableMode;
  final VoidCallback onTap;
  final ValueChanged<int> onCellTap;
  final ValueChanged<int> onDisplayClearTap;
  final Future<void> Function() onEditorSubmitted;
  final Future<void> Function() onEditorTapOutside;
  final VoidCallback onEditorClear;
  final KeyEventResult Function(KeyEvent event) onEditorKeyEvent;
  final ValueChanged<bool> onHoverChanged;
  final ValueChanged<double> onResize;
  final void Function(DataGridColumn<T> column, double delta) onResizeColumn;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: Stack(
        children: <Widget>[
          SizedBox(
            height: rowHeight,
            child: Row(
              children: List<Widget>.generate(columns.length, (int index) {
                final DataGridColumn<T> column = columns[index];
                final bool isFocused =
                    focusedRowKey == rowKey && focusedColumnId == column.id;
                final bool isEditing =
                    editingRowKey == rowKey && editingColumnId == column.id;
                final bool isEditableCell =
                    isEditableMode &&
                    column.isEditableFor(row) &&
                    !column.isReadonlyFor(row);
                final double cellWidth =
                    columnWidths[column.id] ?? column.width;
                final TextStyle? editorStyle =
                    column.editorTextStyle?.call(context, row) ??
                    Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF0F172A),
                    );
                final Color cellFill = isEditing || isFocused
                    ? const Color(0xFFDCEAFE)
                    : backgroundColor;
                return Stack(
                  children: <Widget>[
                    Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (PointerDownEvent event) {
                        final bool tappedClearZone =
                            (isEditing || isEditableCell) &&
                            event.localPosition.dx >= cellWidth - 28;
                        if (tappedClearZone) {
                          return;
                        }
                        onCellTap(index);
                        onTap();
                      },
                      child: Container(
                        key: Key('table-cell-$rowKey-${column.id}'),
                        width: cellWidth,
                        height: rowHeight,
                        alignment: column.alignment,
                        padding: EdgeInsets.symmetric(
                          horizontal: isEditing ? 0 : 10,
                        ),
                        decoration: BoxDecoration(
                          color: cellFill,
                          borderRadius: isEditing
                              ? BorderRadius.circular(4)
                              : null,
                          border: Border(
                            right: BorderSide(color: borderColor),
                            bottom: BorderSide(color: borderColor),
                          ),
                        ),
                        child:
                            isEditing &&
                                editingController != null &&
                                editingFocusNode != null
                            ? Focus(
                                onKeyEvent: (FocusNode node, KeyEvent event) =>
                                    onEditorKeyEvent(event),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Transform.translate(
                                        offset: const Offset(0, -1),
                                        child: Center(
                                          child: TextField(
                                            key: Key(
                                              'table-editor-$rowKey-${column.id}',
                                            ),
                                            controller: editingController,
                                            focusNode: editingFocusNode,
                                            scrollPadding: EdgeInsets.symmetric(
                                              horizontal: 10,
                                            ),
                                            cursorColor: const Color(
                                              0xFF2563EB,
                                            ),
                                            cursorRadius: const Radius.circular(
                                              2,
                                            ),
                                            maxLines: 1,
                                            selectAllOnFocus: false,
                                            textAlignVertical:
                                                TextAlignVertical.center,
                                            strutStyle: editorStyle != null
                                                ? StrutStyle.fromTextStyle(
                                                    editorStyle,
                                                    height: 1,
                                                    forceStrutHeight: true,
                                                  )
                                                : const StrutStyle(
                                                    height: 1,
                                                    forceStrutHeight: true,
                                                  ),
                                            style: editorStyle?.copyWith(
                                              height: 1,
                                            ),
                                            decoration: InputDecoration(
                                              isDense: true,
                                              border: InputBorder.none,
                                              focusColor: Colors.transparent,
                                              fillColor: Colors.transparent,
                                              hoverColor: Colors.transparent,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              disabledBorder: InputBorder.none,
                                              errorBorder: InputBorder.none,
                                              focusedErrorBorder:
                                                  InputBorder.none,
                                              hintText: column.label,
                                              hintStyle: editorStyle?.copyWith(
                                                color: const Color(0xFF94A3B8),
                                                height: 1,
                                              ),
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            onSubmitted: (_) {
                                              unawaited(onEditorSubmitted());
                                            },
                                            onTapOutside: (_) {
                                              unawaited(onEditorTapOutside());
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: Tooltip(
                                        message:
                                            editingErrorText
                                                    ?.trim()
                                                    .isNotEmpty ==
                                                true
                                            ? editingErrorText!
                                            : 'Clear value',
                                        child: GestureDetector(
                                          key: Key(
                                            'table-editor-clear-$rowKey-${column.id}',
                                          ),
                                          onTap: onEditorClear,
                                          behavior: HitTestBehavior.translucent,
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: Center(
                                              child: Icon(
                                                editingErrorText != null
                                                    ? Icons
                                                          .error_outline_rounded
                                                    : Icons.close_rounded,
                                                size: 18,
                                                color: editingErrorText != null
                                                    ? const Color(0xFFDC2626)
                                                    : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Stack(
                                children: <Widget>[
                                  Positioned.fill(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        right: isEditableCell ? 28 : 0,
                                      ),
                                      child: Align(
                                        alignment: column.alignment,
                                        child: SelectionArea(
                                          child: column.cellBuilder(
                                            context,
                                            row,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (isEditableCell)
                                    Positioned(
                                      right: 4,
                                      top: 0,
                                      bottom: 0,
                                      child: Center(
                                        child: MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: GestureDetector(
                                            key: Key(
                                              'table-display-clear-$rowKey-${column.id}',
                                            ),
                                            onTap: () {
                                              onDisplayClearTap(index);
                                            },
                                            behavior:
                                                HitTestBehavior.translucent,
                                            child: const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: Icon(
                                                Icons.close_rounded,
                                                size: 18,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ),
                    if (column.resizable)
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeColumn,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onHorizontalDragUpdate:
                                (DragUpdateDetails details) =>
                                    onResizeColumn(column, details.delta.dx),
                            child: const SizedBox(width: 12),
                          ),
                        ),
                      ),
                  ],
                );
              }),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeRow,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: (DragUpdateDetails details) =>
                    onResize(details.delta.dy),
                child: const SizedBox(height: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedCheckboxHeader extends StatelessWidget {
  const _PinnedCheckboxHeader({
    required this.width,
    required this.height,
    required this.palette,
    required this.isAllSelected,
    required this.isPartiallySelected,
    required this.onChanged,
  });

  final double width;
  final double height;
  final _GridPalette palette;
  final bool isAllSelected;
  final bool isPartiallySelected;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.header,
        border: Border(
          right: BorderSide(color: palette.border),
          bottom: BorderSide(color: palette.border),
        ),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(18)),
      ),
      child: CupertinoCheckbox(
        key: const Key('table-checkbox-header'),
        value: isAllSelected ? true : (isPartiallySelected ? null : false),
        tristate: true,
        onChanged: onChanged,
        activeColor: palette.accent,
        checkColor: Colors.white,
      ),
    );
  }
}

class _PinnedCheckboxRow extends StatelessWidget {
  const _PinnedCheckboxRow({
    required this.rowKey,
    required this.rowHeight,
    required this.backgroundColor,
    required this.borderColor,
    required this.isSelected,
    required this.enabled,
    required this.onResize,
    required this.onChanged,
  });

  final Object rowKey;
  final double rowHeight;
  final Color backgroundColor;
  final Color borderColor;
  final bool isSelected;
  final bool enabled;
  final ValueChanged<double> onResize;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Container(
          height: rowHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(
              right: BorderSide(color: borderColor),
              bottom: BorderSide(color: borderColor),
            ),
          ),
          child: CupertinoCheckbox(
            key: Key('table-checkbox-$rowKey'),
            value: isSelected,
            onChanged: enabled ? onChanged : null,
            activeColor: const Color(0xFF1D4ED8),
            checkColor: Colors.white,
          ),
        ),
        if (isSelected)
          const Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: ColoredBox(
              color: Color(0xFF1D4ED8),
              child: SizedBox(width: 3),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeRow,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: (DragUpdateDetails details) =>
                  onResize(details.delta.dy),
              child: const SizedBox(height: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _PinnedCheckboxSpacerRow extends StatelessWidget {
  const _PinnedCheckboxSpacerRow({
    required this.height,
    required this.color,
    required this.borderColor,
    this.topBorder = false,
  });

  final double height;
  final Color color;
  final Color borderColor;
  final bool topBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        border: Border(
          right: BorderSide(color: borderColor),
          top: topBorder ? BorderSide(color: borderColor) : BorderSide.none,
          bottom: topBorder ? BorderSide.none : BorderSide(color: borderColor),
        ),
      ),
    );
  }
}

class _SupplementaryRow<T> extends StatelessWidget {
  const _SupplementaryRow({
    required this.values,
    required this.columns,
    required this.palette,
    required this.columnWidths,
    required this.height,
  });

  final Map<String, Object?> values;
  final List<DataGridColumn<T>> columns;
  final _GridPalette palette;
  final Map<String, double> columnWidths;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: palette.surfaceMuted,
      child: Row(
        children: columns.map((DataGridColumn<T> column) {
          final Object? value = values[column.id];
          return Container(
            width: columnWidths[column.id] ?? column.width,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: column.alignment,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: palette.border),
                bottom: BorderSide(color: palette.border),
              ),
            ),
            child:
                column.extraCellBuilder?.call(context, value) ??
                Text(
                  value?.toString() ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          );
        }).toList(),
      ),
    );
  }
}

class _SummaryRow<T> extends StatelessWidget {
  const _SummaryRow({
    required this.values,
    required this.columns,
    required this.palette,
    required this.columnWidths,
    required this.height,
  });

  final Map<String, Object?> values;
  final List<DataGridColumn<T>> columns;
  final _GridPalette palette;
  final Map<String, double> columnWidths;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: palette.summaryRow,
      child: Row(
        children: columns.map((DataGridColumn<T> column) {
          final Object? value = values[column.id];
          return Container(
            width: columnWidths[column.id] ?? column.width,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: column.alignment,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: palette.border),
                top: BorderSide(color: palette.border),
              ),
            ),
            child:
                column.summaryBuilder?.call(context, value) ??
                Text(
                  value?.toString() ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.headerText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
          );
        }).toList(),
      ),
    );
  }
}

class _DataGridFooter extends StatelessWidget {
  const _DataGridFooter({
    required this.palette,
    required this.loading,
    required this.pageStartIndex,
    required this.pageEndIndex,
    required this.totalRows,
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.pageSizeOptions,
    required this.selectedCount,
    required this.showSelectedCount,
    required this.onOpenSettings,
    required this.onPrevious,
    required this.onNext,
    required this.onPageSizeChanged,
  });

  final _GridPalette palette;
  final bool loading;
  final int pageStartIndex;
  final int pageEndIndex;
  final int totalRows;
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final List<int> pageSizeOptions;
  final int selectedCount;
  final bool showSelectedCount;
  final VoidCallback onOpenSettings;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int?> onPageSizeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Showing $pageStartIndex-$pageEndIndex of $totalRows rows',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.footerText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (showSelectedCount) ...<Widget>[
                const SizedBox(width: 12),
                Text(
                  'Selected: $selectedCount',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Column settings',
              ),
              Text(
                'Rows',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 94,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: pageSize,
                      isDense: true,
                      isExpanded: true,
                      items: pageSizeOptions
                          .map(
                            (int size) => DropdownMenuItem<int>(
                              value: size,
                              child: Text('$size'),
                            ),
                          )
                          .toList(),
                      onChanged: onPageSizeChanged,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$currentPage / $totalPages',
                  key: const Key('table-page-indicator'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.headerText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _PagerButton(
                buttonKey: const Key('table-page-previous'),
                onPressed: loading ? null : onPrevious,
                icon: Icons.chevron_left,
                palette: palette,
              ),
              const SizedBox(width: 4),
              _PagerButton(
                buttonKey: const Key('table-page-next'),
                onPressed: loading ? null : onNext,
                icon: Icons.chevron_right,
                filled: true,
                palette: palette,
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 18,
                height: 18,
                child: loading
                    ? CircularProgressIndicator(
                        key: const Key('table-page-loading-indicator'),
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          palette.accent,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
    this.buttonKey,
    required this.onPressed,
    required this.icon,
    required this.palette,
    this.filled = false,
  });

  final Key? buttonKey;
  final VoidCallback? onPressed;
  final IconData icon;
  final _GridPalette palette;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: buttonKey,
      width: 30,
      height: 30,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: filled ? palette.accent : palette.surface,
          foregroundColor: filled ? Colors.white : palette.footerText,
          disabledBackgroundColor: palette.surfaceMuted,
          disabledForegroundColor: palette.muted,
          side: filled ? null : BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: Icon(icon, size: 16),
      ),
    );
  }
}

class _GridPalette {
  const _GridPalette.light()
    : surface = const Color(0xFFFFFFFF),
      surfaceMuted = const Color(0xFFF8FAFC),
      header = const Color(0xFFF8FAFC),
      row = const Color(0xFFFFFFFF),
      rowAlt = const Color(0xFFFCFDFE),
      selectedRow = const Color(0xFFEFF5FF),
      hoverRow = const Color(0xFFF8FBFF),
      summaryRow = const Color(0xFFF4F7FB),
      border = const Color(0xFFD7DFEA),
      headerText = const Color(0xFF475569),
      footerText = const Color(0xFF475569),
      muted = const Color(0xFF94A3B8),
      accent = const Color(0xFF1D4ED8),
      badgeBorder = const Color(0xFFBFDBFE),
      sortHighlight = const Color(0xFFEFF6FF),
      overlay = const Color(0xAAFFFFFF);

  const _GridPalette.dark()
    : surface = const Color(0xFF0F172A),
      surfaceMuted = const Color(0xFF111C31),
      header = const Color(0xFF111C31),
      row = const Color(0xFF0F172A),
      rowAlt = const Color(0xFF122035),
      selectedRow = const Color(0xFF1D3557),
      hoverRow = const Color(0xFF16243C),
      summaryRow = const Color(0xFF14243C),
      border = const Color(0xFF2A3B55),
      headerText = const Color(0xFFE2E8F0),
      footerText = const Color(0xFFCBD5E1),
      muted = const Color(0xFF94A3B8),
      accent = const Color(0xFF60A5FA),
      badgeBorder = const Color(0xFF315E91),
      sortHighlight = const Color(0xFF19304D),
      overlay = const Color(0xAA0F172A);

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
  final Color overlay;
}
