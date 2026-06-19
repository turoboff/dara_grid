import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/grid_state.dart';

/// Persists and restores user-customizable grid state.
abstract class DataGridPersistenceAdapter {
  /// Creates a persistence adapter.
  const DataGridPersistenceAdapter();

  /// Loads the saved state for a storage key.
  Future<DataGridStoredState?> load(String storageKey);

  /// Saves the current state for a storage key.
  Future<void> save(String storageKey, DataGridStoredState state);

  /// Deletes any saved state for a storage key.
  Future<void> reset(String storageKey);
}

/// Shared preferences backed adapter for local grid persistence.
class SharedPreferencesDataGridPersistenceAdapter
    extends DataGridPersistenceAdapter {
  /// Creates the shared preferences adapter.
  const SharedPreferencesDataGridPersistenceAdapter();

  @override
  Future<DataGridStoredState?> load(String storageKey) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? raw = preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return DataGridStoredState.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(String storageKey, DataGridStoredState state) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(storageKey, jsonEncode(state.toJson()));
  }

  @override
  Future<void> reset(String storageKey) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.remove(storageKey);
  }
}
