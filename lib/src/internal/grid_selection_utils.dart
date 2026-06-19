/// Pure helpers for enforcing grid selection constraints.
final class DataGridSelectionUtils {
  const DataGridSelectionUtils._();

  /// Counts how many candidate keys would be newly added to the selection.
  static int countAddedKeys(
    Set<Object> current,
    Iterable<Object> candidates,
  ) {
    int count = 0;
    for (final Object key in candidates) {
      if (!current.contains(key)) {
        count += 1;
      }
    }
    return count;
  }

  /// Counts how many candidate keys would be removed from the selection.
  static int countRemovedKeys(
    Set<Object> current,
    Iterable<Object> candidates,
  ) {
    int count = 0;
    for (final Object key in candidates) {
      if (current.contains(key)) {
        count += 1;
      }
    }
    return count;
  }

  /// Returns true when a selection change stays within min/max limits.
  static bool canApplySelectionDelta({
    required int currentSelectedCount,
    required int delta,
    required int minSelected,
    int? maxSelected,
  }) {
    final int nextCount = currentSelectedCount + delta;
    if (nextCount < minSelected) {
      return false;
    }
    if (maxSelected != null && nextCount > maxSelected) {
      return false;
    }
    return true;
  }
}
