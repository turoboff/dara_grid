import 'package:data_grid/src/internal/grid_selection_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DataGridSelectionUtils', () {
    test('counts added and removed keys accurately', () {
      final Set<Object> current = <Object>{1, 2, 3};

      expect(
        DataGridSelectionUtils.countAddedKeys(current, <Object>[2, 3, 4, 5]),
        2,
      );
      expect(
        DataGridSelectionUtils.countRemovedKeys(
          current,
          <Object>[2, 3, 4, 5],
        ),
        2,
      );
    });

    test('validates selection min and max constraints', () {
      expect(
        DataGridSelectionUtils.canApplySelectionDelta(
          currentSelectedCount: 2,
          delta: -1,
          minSelected: 2,
        ),
        isFalse,
      );
      expect(
        DataGridSelectionUtils.canApplySelectionDelta(
          currentSelectedCount: 2,
          delta: 2,
          minSelected: 0,
          maxSelected: 3,
        ),
        isFalse,
      );
      expect(
        DataGridSelectionUtils.canApplySelectionDelta(
          currentSelectedCount: 2,
          delta: 1,
          minSelected: 0,
          maxSelected: 4,
        ),
        isTrue,
      );
    });
  });
}
