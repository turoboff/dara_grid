import 'dart:math' as math;

import '../models/models.dart';

/// Pure calculations used by the grid state and rendering layers.
final class DataGridCalculations {
  const DataGridCalculations._();

  /// Returns the visible ordered columns after hidden columns are removed.
  static List<DataGridColumn<T>> orderedVisibleColumns<T>({
    required List<DataGridColumn<T>> columns,
    required List<String> orderedColumnIds,
    required Set<String> hiddenColumnIds,
  }) {
    final Map<String, DataGridColumn<T>> byId = <String, DataGridColumn<T>>{
      for (final DataGridColumn<T> column in columns) column.id: column,
    };
    final List<String> ordered = orderedColumnIds.isEmpty
        ? columns.map((DataGridColumn<T> column) => column.id).toList()
        : orderedColumnIds;
    final List<DataGridColumn<T>> result = <DataGridColumn<T>>[];
    for (final String id in ordered) {
      final DataGridColumn<T>? column = byId[id];
      if (column == null || hiddenColumnIds.contains(id)) {
        continue;
      }
      result.add(column);
    }
    for (final DataGridColumn<T> column in columns) {
      if (!result.contains(column) && !hiddenColumnIds.contains(column.id)) {
        result.add(column);
      }
    }
    return result;
  }

  /// Sorts rows locally according to the current sort specification.
  static List<T> sortRows<T>({
    required List<T> rows,
    required List<DataGridColumn<T>> columns,
    required DataGridOptions options,
  }) {
    if (options.paginationMode == DataGridPaginationMode.server) {
      return rows;
    }
    final List<T> sorted = List<T>.of(rows);
    final List<DataGridSortSpec> specs = options.sortSpecs;
    if (specs.isEmpty) {
      return sorted;
    }
    final Map<String, DataGridColumn<T>> columnsById =
        <String, DataGridColumn<T>>{
          for (final DataGridColumn<T> column in columns) column.id: column,
        };
    sorted.sort((T left, T right) {
      for (final DataGridSortSpec spec in specs) {
        final DataGridColumn<T>? column = columnsById[spec.columnId];
        if (column == null) {
          continue;
        }
        final int delta = compareSortValues(
          column.sortValue?.call(left),
          column.sortValue?.call(right),
        );
        if (delta == 0) {
          continue;
        }
        return spec.direction == DataGridSortDirection.asc ? delta : -delta;
      }
      return 0;
    });
    return sorted;
  }

  /// Resolves the visible slice for local pagination mode.
  static List<T> visibleRows<T>({
    required List<T> rows,
    required DataGridOptions options,
    required int totalPages,
  }) {
    if (options.paginationMode == DataGridPaginationMode.server) {
      return rows;
    }
    final int page = options.page.clamp(1, totalPages);
    final int start = (page - 1) * options.pageSize;
    final int end = math.min(start + options.pageSize, rows.length);
    return rows.sublist(start, end);
  }

  /// Returns the total rows represented by the current dataset.
  static int totalRows<T>({
    required List<T> rows,
    required DataGridOptions options,
    required int? totalRowCount,
  }) {
    if (options.paginationMode == DataGridPaginationMode.server) {
      return totalRowCount ?? rows.length;
    }
    return rows.length;
  }

  /// Computes the number of visible pages for the active page size.
  static int totalPages({required int totalRows, required int pageSize}) {
    final int safePageSize = math.max(1, pageSize);
    return math.max(1, (totalRows / safePageSize).ceil());
  }

  /// Formats the active sort stack into a stable cache signature.
  static String sortSignature(List<DataGridSortSpec> specs) {
    return specs
        .map(
          (DataGridSortSpec spec) =>
              '${spec.columnId}:${spec.direction.name}',
        )
        .join('|');
  }

  /// Computes the current one-based start index shown in the footer.
  static int pageStartIndex({
    required int totalRows,
    required int page,
    required int pageSize,
  }) {
    return totalRows == 0 ? 0 : ((page - 1) * pageSize) + 1;
  }

  /// Computes the current one-based end index shown in the footer.
  static int pageEndIndex({
    required int totalRows,
    required int page,
    required int pageSize,
  }) {
    return math.min(page * pageSize, totalRows);
  }

  /// Compares values across common sortable primitive types.
  static int compareSortValues(
    Comparable<dynamic>? left,
    Comparable<dynamic>? right,
  ) {
    if (identical(left, right)) {
      return 0;
    }
    if (left == null) {
      return -1;
    }
    if (right == null) {
      return 1;
    }
    if (left is num && right is num) {
      return left.compareTo(right);
    }
    if (left is DateTime && right is DateTime) {
      return left.compareTo(right);
    }
    if (left is String && right is String) {
      return left.compareTo(right);
    }
    return left.compareTo(right);
  }
}
