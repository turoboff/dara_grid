import 'package:data_grid/data_grid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DataGridController.toggleSort', () {
    test('cycles asc to desc in single-sort mode', () {
      final DataGridController<void> controller = DataGridController<void>(
        options: const DataGridOptions(
          sortSpecs: <DataGridSortSpec>[
            DataGridSortSpec(
              columnId: 'name',
              direction: DataGridSortDirection.asc,
            ),
          ],
        ),
      );

      controller.toggleSort('name', multiSort: false);

      expect(controller.options.sortSpecs, hasLength(1));
      expect(
        controller.options.sortSpecs.single.direction,
        DataGridSortDirection.desc,
      );
    });

    test('replaces prior column in single-sort mode', () {
      final DataGridController<void> controller = DataGridController<void>(
        options: const DataGridOptions(
          sortSpecs: <DataGridSortSpec>[
            DataGridSortSpec(
              columnId: 'id',
              direction: DataGridSortDirection.asc,
            ),
          ],
        ),
      );

      controller.toggleSort('name', multiSort: false);

      expect(controller.options.sortSpecs, hasLength(1));
      expect(controller.options.sortSpecs.single.columnId, 'name');
      expect(
        controller.options.sortSpecs.single.direction,
        DataGridSortDirection.asc,
      );
    });
  });
}
