import 'package:flutter/services.dart';

import 'grid_column.dart';

/// Payload passed to custom hotkey handlers.
class DataGridHotkeyPayload<T> {
  /// Creates a keyboard payload for the currently focused cell.
  const DataGridHotkeyPayload({
    required this.event,
    required this.row,
    required this.rowIndex,
    required this.column,
    required this.columnIndex,
  });

  /// Raw key event dispatched by Flutter.
  final KeyEvent event;

  /// Focused row, if any.
  final T? row;

  /// Visible row index, if any.
  final int? rowIndex;

  /// Focused column, if any.
  final DataGridColumn<T>? column;

  /// Visible column index, if any.
  final int? columnIndex;
}

/// Describes a completed inline edit before it is persisted by the consumer.
class DataGridEditCommit<T> {
  /// Creates an edit commit payload.
  const DataGridEditCommit({
    required this.row,
    required this.rowIndex,
    required this.column,
    required this.previousValue,
    required this.nextValue,
  });

  /// Row being edited.
  final T row;

  /// Visible row index for the edit.
  final int rowIndex;

  /// Column being edited.
  final DataGridColumn<T> column;

  /// Previous editor value.
  final String previousValue;

  /// New editor value entered by the user.
  final String nextValue;
}

/// Describes the start of an inline edit session.
class DataGridEditStart<T> {
  /// Creates a start payload for an inline edit.
  const DataGridEditStart({
    required this.row,
    required this.rowIndex,
    required this.column,
  });

  /// Row entering edit mode.
  final T row;

  /// Visible row index entering edit mode.
  final int rowIndex;

  /// Column entering edit mode.
  final DataGridColumn<T> column;
}
