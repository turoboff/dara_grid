import 'grid_options.dart';

/// Serializable snapshot of user-customizable grid state.
class DataGridStoredState {
  /// Creates a persisted state snapshot.
  const DataGridStoredState({
    this.hiddenColumns = const <String>[],
    this.orderedColumns = const <String>[],
    this.columnWidths = const <String, double>{},
    this.sortSpecs = const <DataGridSortSpec>[],
  });

  /// Hidden column identifiers.
  final List<String> hiddenColumns;

  /// Column order persisted by the user.
  final List<String> orderedColumns;

  /// Persisted widths by column identifier.
  final Map<String, double> columnWidths;

  /// Persisted sort stack.
  final List<DataGridSortSpec> sortSpecs;

  /// Serializes the state for storage.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'hiddenColumns': hiddenColumns,
    'orderedColumns': orderedColumns,
    'columnWidths': columnWidths,
    'sortSpecs': sortSpecs
        .map((DataGridSortSpec spec) => spec.toJson())
        .toList(),
  };

  /// Restores persisted state from JSON.
  factory DataGridStoredState.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> widthJson =
        (json['columnWidths'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{})
            .map(
              (dynamic key, dynamic value) =>
                  MapEntry<String, dynamic>(key.toString(), value),
            );
    return DataGridStoredState(
      hiddenColumns: (json['hiddenColumns'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(),
      orderedColumns: (json['orderedColumns'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(),
      columnWidths: widthJson.map(
        (String key, dynamic value) =>
            MapEntry<String, double>(key, (value as num?)?.toDouble() ?? 0),
      ),
      sortSpecs: (json['sortSpecs'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> item) => DataGridSortSpec.fromJson(
              item.map(
                (dynamic key, dynamic value) =>
                    MapEntry<String, dynamic>(key.toString(), value),
              ),
            ),
          )
          .toList(),
    );
  }
}
