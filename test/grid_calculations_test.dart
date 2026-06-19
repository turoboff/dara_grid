import 'package:data_grid/src/internal/grid_calculations.dart';
import 'package:data_grid/data_grid.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DataGridCalculations', () {
    final List<DataGridColumn<_Row>> columns = <DataGridColumn<_Row>>[
      DataGridColumn<_Row>(
        id: 'name',
        label: 'Name',
        width: 160,
        sortValue: (_Row row) => row.name,
        cellBuilder: (BuildContext context, _Row row) => Text(row.name),
      ),
      DataGridColumn<_Row>(
        id: 'score',
        label: 'Score',
        width: 100,
        sortValue: (_Row row) => row.score,
        cellBuilder: (BuildContext context, _Row row) => Text('${row.score}'),
      ),
    ];

    test('sorts rows using the active sort stack', () {
      final List<_Row> rows = <_Row>[
        const _Row(name: 'Charlie', score: 3),
        const _Row(name: 'Alice', score: 2),
        const _Row(name: 'Bob', score: 1),
      ];

      final List<_Row> sorted = DataGridCalculations.sortRows<_Row>(
        rows: rows,
        columns: columns,
        options: const DataGridOptions(
          sortSpecs: <DataGridSortSpec>[
            DataGridSortSpec(
              columnId: 'name',
              direction: DataGridSortDirection.asc,
            ),
          ],
        ),
      );

      expect(sorted.map((_Row row) => row.name), <String>[
        'Alice',
        'Bob',
        'Charlie',
      ]);
    });

    test('returns server rows without local slicing', () {
      final List<_Row> rows = List<_Row>.generate(
        3,
        (int index) => _Row(name: 'Row $index', score: index),
      );

      final List<_Row> visible = DataGridCalculations.visibleRows<_Row>(
        rows: rows,
        options: const DataGridOptions(
          paginationMode: DataGridPaginationMode.server,
          page: 3,
          pageSize: 1,
        ),
        totalPages: 3,
      );

      expect(visible, same(rows));
    });

    test('computes local visible rows and footer indices', () {
      final List<_Row> rows = List<_Row>.generate(
        25,
        (int index) => _Row(name: 'Row $index', score: index),
      );
      const DataGridOptions options = DataGridOptions(page: 2, pageSize: 10);

      final List<_Row> visible = DataGridCalculations.visibleRows<_Row>(
        rows: rows,
        options: options,
        totalPages: DataGridCalculations.totalPages(
          totalRows: rows.length,
          pageSize: options.pageSize,
        ),
      );

      expect(visible.length, 10);
      expect(visible.first.score, 10);
      expect(
        DataGridCalculations.pageStartIndex(
          totalRows: rows.length,
          page: options.page,
          pageSize: options.pageSize,
        ),
        11,
      );
      expect(
        DataGridCalculations.pageEndIndex(
          totalRows: rows.length,
          page: options.page,
          pageSize: options.pageSize,
        ),
        20,
      );
    });
  });
}

class _Row {
  const _Row({required this.name, required this.score});

  final String name;
  final int score;
}
