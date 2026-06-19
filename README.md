# data_grid

A reusable Flutter data grid package extracted from the OsonKassa demo app.

## Features

- Local and server-driven pagination
- Single and multi-column sorting
- Keyboard navigation and focus management
- Checkbox selection with min/max selection rules
- Inline editing with validation hooks
- Column resize, hide, and reorder persistence
- Light and dark presentation modes
- A complete showcase screen with realistic customer data

## Public API

Import the package with:

```dart
import 'package:data_grid/data_grid.dart';
```

Primary entry points:

- `DataGrid<T>`
- `DataGridController<T>`
- `DataGridColumn<T>`
- `DataGridOptions`
- `DataGridPersistenceAdapter`
- `DataGridShowcaseScreen`

## Example App

The package includes a runnable Flutter example in [`example/`](example).

```bash
cd example
flutter pub get
flutter run
```

The showcase app demonstrates:

- customer table configuration
- local and server-style paging
- persistence and density controls
- inline editing and action dialogs

The package is designed to be embedded into application-specific screens while keeping the grid behavior reusable.
