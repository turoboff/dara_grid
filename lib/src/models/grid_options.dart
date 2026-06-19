import 'grid_types.dart';

/// Describes one active sort entry in the current sort stack.
class DataGridSortSpec {
  /// Creates a sort entry for a column.
  const DataGridSortSpec({required this.columnId, required this.direction});

  /// Target column identifier.
  final String columnId;

  /// Sort direction applied to the column.
  final DataGridSortDirection direction;

  /// Serializes the sort entry for persistence.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'columnId': columnId,
    'direction': direction.name,
  };

  /// Restores a sort entry from persisted JSON.
  factory DataGridSortSpec.fromJson(Map<String, dynamic> json) {
    return DataGridSortSpec(
      columnId: json['columnId'] as String? ?? '',
      direction: DataGridSortDirection.values.byName(
        json['direction'] as String? ?? DataGridSortDirection.asc.name,
      ),
    );
  }
}

/// Captures the active pagination and sorting options for the grid.
class DataGridOptions {
  /// Creates the current grid options snapshot.
  const DataGridOptions({
    this.page = 1,
    this.pageSize = 20,
    this.skip,
    this.take,
    this.paginationMode = DataGridPaginationMode.local,
    this.sortSpecs = const <DataGridSortSpec>[],
  });

  /// One-based page number.
  final int page;

  /// Number of visible rows per page.
  final int pageSize;

  /// Optional server-side skip offset.
  final int? skip;

  /// Optional server-side take size.
  final int? take;

  /// Selects whether the grid slices data locally or delegates to a server.
  final DataGridPaginationMode paginationMode;

  /// Ordered list of active sort rules.
  final List<DataGridSortSpec> sortSpecs;

  /// Returns a copy with the provided changes applied.
  DataGridOptions copyWith({
    int? page,
    int? pageSize,
    int? skip,
    int? take,
    DataGridPaginationMode? paginationMode,
    List<DataGridSortSpec>? sortSpecs,
  }) {
    return DataGridOptions(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      skip: skip ?? this.skip,
      take: take ?? this.take,
      paginationMode: paginationMode ?? this.paginationMode,
      sortSpecs: sortSpecs ?? this.sortSpecs,
    );
  }
}
