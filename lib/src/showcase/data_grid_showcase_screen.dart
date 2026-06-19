import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:data_grid/data_grid.dart';
import 'package:flutter/material.dart';

class DataGridShowcaseScreen extends StatefulWidget {
  const DataGridShowcaseScreen({super.key, this.onBack, this.onOpenPosDemo});

  final VoidCallback? onBack;
  final VoidCallback? onOpenPosDemo;

  @override
  State<DataGridShowcaseScreen> createState() => _DataGridShowcaseScreenState();
}

class _DataGridShowcaseScreenState extends State<DataGridShowcaseScreen> {
  static const List<int> _pageSizeOptions = <int>[20, 25, 50, 100, 250];
  static const List<int> _rowCountOptions = <int>[140, 300, 1200, 3000];
  static const String _readonlyStorageKey = 'demo-readonly-grid';
  static const String _editableStorageKey = 'demo-editable-grid';
  static const double _defaultGridHeight = 520;

  final DataGridController<CustomerRecord> _gridController =
      DataGridController<CustomerRecord>(
        options: const DataGridOptions(
          page: 1,
          pageSize: 20,
          paginationMode: DataGridPaginationMode.local,
        ),
      );
  final DataGridPersistenceAdapter _persistenceAdapter =
      const SharedPreferencesDataGridPersistenceAdapter();
  List<CustomerRecord> _rows = List<CustomerRecord>.generate(
    140,
    CustomerRecord.sample,
  );

  bool _loading = false;
  bool _pageTransitionLoading = false;
  bool _editableMode = false;
  bool _multiSort = true;
  bool _keyboardNavigation = true;
  bool _showTotals = true;
  bool _pagingEnabled = true;
  bool _showExtraRows = false;
  bool _showSelectedCount = true;
  bool _showRowStyle = true;
  bool _persistenceEnabled = true;
  int _pagedPageSize = 20;
  int _rowCount = 140;
  int _checkboxSelectionMin = 0;
  int _checkboxSelectionMax = 0;
  String _searchQuery = '';
  DataGridThemeMode _themeMode = DataGridThemeMode.light;
  DataGridDensity _density = DataGridDensity.compact;
  Timer? _pageTransitionLoadingTimer;
  int _lastObservedPage = 1;

  String get _activeSearchQuery => _searchQuery.trim();

  List<DataGridColumn<CustomerRecord>> get _columns =>
      <DataGridColumn<CustomerRecord>>[
        DataGridColumn<CustomerRecord>(
          id: 'id',
          label: 'ID',
          width: 84,
          hideable: false,
          sortValue: (CustomerRecord record) => record.id,
          cellBuilder: (BuildContext context, CustomerRecord record) => Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '#${record.id}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
            ),
          ),
        ),
        DataGridColumn<CustomerRecord>(
          id: 'customer',
          label: 'Customer',
          width: 172,
          hideable: false,
          sortValue: (CustomerRecord record) => record.customer,
          editorText: (CustomerRecord record) => record.customer,
          editorTextStyle: (BuildContext context, CustomerRecord record) =>
              Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
          editable: (_) => true,
          required: true,
          requiredMessage: 'Customer is required',
          cellBuilder: (_, CustomerRecord record) => _PrimaryCell(
            title: record.customer,
            subtitle: record.company,
            highlightQuery: _activeSearchQuery,
          ),
        ),
        DataGridColumn<CustomerRecord>(
          id: 'company',
          label: 'Company',
          width: 188,
          sortValue: (CustomerRecord record) => record.company,
          editorText: (CustomerRecord record) => record.company,
          editorTextStyle: (BuildContext context, CustomerRecord record) =>
              Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF0F172A)),
          editable: (_) => true,
          required: true,
          cellBuilder: (_, CustomerRecord record) => _PlainTextCell(
            record.company,
            highlightQuery: _activeSearchQuery,
          ),
        ),
        DataGridColumn<CustomerRecord>(
          id: 'email',
          label: 'Email',
          width: 226,
          sortValue: (CustomerRecord record) => record.email,
          editorText: (CustomerRecord record) => record.email,
          editorTextStyle: (BuildContext context, CustomerRecord record) =>
              Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
          editable: (_) => true,
          required: true,
          cellBuilder: (_, CustomerRecord record) => _PlainTextCell(
            record.email,
            muted: true,
            highlightQuery: _activeSearchQuery,
          ),
        ),
        DataGridColumn<CustomerRecord>(
          id: 'phone',
          label: 'Phone',
          width: 146,
          sortValue: (CustomerRecord record) => record.phone,
          cellBuilder: (_, CustomerRecord record) =>
              _PlainTextCell(record.phone, highlightQuery: _activeSearchQuery),
        ),
        DataGridColumn<CustomerRecord>(
          id: 'region',
          label: 'Region',
          width: 132,
          sortValue: (CustomerRecord record) => record.region,
          cellBuilder: (_, CustomerRecord record) =>
              _PlainTextCell(record.region, highlightQuery: _activeSearchQuery),
        ),
        DataGridColumn<CustomerRecord>(
          id: 'status',
          label: 'Status',
          width: 124,
          sortValue: (CustomerRecord record) => record.status.label,
          cellBuilder: (_, CustomerRecord record) => _TagChipCell(
            record.status.label,
            color: _statusColor(record.status),
            textColor: _statusTextColor(record.status),
            highlightQuery: _activeSearchQuery,
          ),
        ),
        DataGridColumn<CustomerRecord>(
          id: 'balance',
          label: 'Balance',
          width: 132,
          alignment: Alignment.centerRight,
          sortValue: (CustomerRecord record) => record.balance,
          editorText: (CustomerRecord record) =>
              record.balance.toStringAsFixed(2),
          editorTextStyle: (BuildContext context, CustomerRecord record) =>
              Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
          editable: (_) => true,
          required: true,
          editType: DataGridEditType.number,
          cellBuilder: (_, CustomerRecord record) => _MetricCell(
            _formatCurrency(record.balance),
            align: TextAlign.right,
            emphasis: true,
          ),
          summaryBuilder: (BuildContext context, Object? value) => _MetricCell(
            value?.toString() ?? '',
            align: TextAlign.right,
            emphasis: true,
          ),
        ),
        DataGridColumn<CustomerRecord>(
          id: 'lastOrder',
          label: 'Last Order',
          width: 124,
          sortValue: (CustomerRecord record) => record.lastOrder,
          cellBuilder: (_, CustomerRecord record) =>
              _PlainTextCell(_formatDate(record.lastOrder)),
        ),
        DataGridColumn<CustomerRecord>(
          id: 'progress',
          label: 'Progress',
          width: 184,
          sortValue: (CustomerRecord record) => record.progress,
          cellBuilder: (_, CustomerRecord record) =>
              _ProgressCell(record.progress),
          summaryBuilder: (BuildContext context, Object? value) => Text(
            value?.toString() ?? '',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        DataGridColumn<CustomerRecord>(
          id: 'owner',
          label: 'Owner',
          width: 132,
          sortValue: (CustomerRecord record) => record.owner,
          editorText: (CustomerRecord record) => record.owner,
          editorTextStyle: (BuildContext context, CustomerRecord record) =>
              Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF0F172A)),
          editable: (_) => true,
          required: true,
          cellBuilder: (_, CustomerRecord record) =>
              _OwnerCell(record.owner, highlightQuery: _activeSearchQuery),
        ),
        DataGridColumn<CustomerRecord>(
          id: 'createdAt',
          label: 'Created At',
          width: 126,
          sortValue: (CustomerRecord record) => record.createdAt,
          cellBuilder: (_, CustomerRecord record) =>
              _PlainTextCell(_formatDate(record.createdAt)),
        ),
        DataGridColumn<CustomerRecord>(
          id: 'updatedAt',
          label: 'Updated At',
          width: 126,
          sortValue: (CustomerRecord record) => record.updatedAt,
          cellBuilder: (_, CustomerRecord record) =>
              _PlainTextCell(_formatDate(record.updatedAt)),
        ),
        DataGridColumn<CustomerRecord>(
          id: 'notes',
          label: 'Notes',
          width: 260,
          wrapLines: 3,
          sortValue: (CustomerRecord record) => record.notes,
          editorText: (CustomerRecord record) => record.notes,
          editorTextStyle: (BuildContext context, CustomerRecord record) =>
              Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF0F172A)),
          editable: (_) => true,
          saveTrigger: DataGridSaveTrigger.both,
          cellBuilder: (_, CustomerRecord record) => _PlainTextCell(
            record.notes,
            maxLines: 2,
            highlightQuery: _activeSearchQuery,
          ),
        ),
        DataGridColumn<CustomerRecord>(
          id: 'actions',
          label: 'Actions',
          width: 260,
          sortable: false,
          resizable: false,
          hideable: false,
          cellBuilder: (_, CustomerRecord record) => _ActionCell(
            recordId: record.id,
            onAction: (String action) => _handleAction(record, action),
          ),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _gridController.addListener(_refresh);
    _lastObservedPage = _gridController.options.page;
  }

  @override
  void dispose() {
    _pageTransitionLoadingTimer?.cancel();
    _gridController.removeListener(_refresh);
    _gridController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  List<CustomerRecord> get _filteredRows {
    final String query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return _rows;
    }
    return _rows.where((CustomerRecord record) {
      final String haystack = <String>[
        record.customer,
        record.company,
        record.email,
        record.phone,
        record.region,
        record.status.label,
        record.owner,
        record.notes,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  List<CustomerRecord> get _gridRows => _filteredRows;

  String? get _storageKey => _persistenceEnabled
      ? (_editableMode ? _editableStorageKey : _readonlyStorageKey)
      : null;

  DataGridSelectionConfig<CustomerRecord> get _selectionConfig =>
      DataGridSelectionConfig<CustomerRecord>(
        enableCheckboxSelection: true,
        multiSelect: true,
        minSelected: _checkboxSelectionMin,
        maxSelected: _checkboxSelectionMax <= 0 ? null : _checkboxSelectionMax,
      );

  Future<void> _handleAction(CustomerRecord record, String action) async {
    switch (action) {
      case 'View':
        await _openViewModal(record);
      case 'Edit':
        await _openEditModal(record);
      case 'Delete':
        _showTransientAction(record, action);
    }
  }

  Future<void> _openViewModal(CustomerRecord record) async {
    final _ModalAction? nextAction = await _showCenteredModal<_ModalAction>(
      context,
      child: _CustomerViewDialog(record: record),
    );

    if (!mounted || nextAction != _ModalAction.edit) {
      return;
    }

    final CustomerRecord? latestRecord = _recordById(record.id);
    if (latestRecord != null) {
      await _openEditModal(latestRecord);
    }
  }

  Future<void> _openEditModal(CustomerRecord record) async {
    final CustomerRecord? updatedRecord =
        await _showCenteredModal<CustomerRecord>(
          context,
          child: _CustomerEditDialog(record: record),
        );

    if (!mounted || updatedRecord == null) {
      return;
    }

    setState(() {
      final int rowIndex = _rows.indexWhere(
        (CustomerRecord item) => item.id == updatedRecord.id,
      );
      if (rowIndex != -1) {
        _rows[rowIndex] = updatedRecord;
      }
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Saved changes for ${updatedRecord.customer}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _showTransientAction(CustomerRecord record, String action) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$action clicked for ${record.customer}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  CustomerRecord? _recordById(int id) {
    for (final CustomerRecord record in _rows) {
      if (record.id == id) {
        return record;
      }
    }
    return null;
  }

  Future<bool> _handleInlineEditCommit(
    DataGridEditCommit<CustomerRecord> commit,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final int rowIndex = _rows.indexWhere(
      (CustomerRecord row) => row.id == commit.row.id,
    );
    if (rowIndex == -1) {
      return false;
    }
    final CustomerRecord row = _rows[rowIndex];
    CustomerRecord nextRow = row;
    switch (commit.column.id) {
      case 'customer':
        nextRow = row.copyWith(customer: commit.nextValue.trim());
        break;
      case 'company':
        nextRow = row.copyWith(company: commit.nextValue.trim());
        break;
      case 'email':
        nextRow = row.copyWith(email: commit.nextValue.trim());
        break;
      case 'owner':
        nextRow = row.copyWith(owner: commit.nextValue.trim());
        break;
      case 'notes':
        nextRow = row.copyWith(notes: commit.nextValue.trim());
        break;
      case 'balance':
        final double? parsed = double.tryParse(commit.nextValue.trim());
        if (parsed == null || parsed < 0) {
          return false;
        }
        nextRow = row.copyWith(balance: parsed);
        break;
      default:
        return true;
    }
    setState(() {
      _rows[rowIndex] = nextRow.copyWith(updatedAt: DateTime.now());
    });
    return true;
  }

  Color _baseRowColor(int index, CustomerRecord record) {
    switch (record.visualState) {
      case RowVisualState.warning:
        return const Color(0xFFFFFBF2);
      case RowVisualState.success:
        return const Color(0xFFF5FCF7);
      case RowVisualState.inactive:
        return const Color(0xFFF8FAFC);
      case RowVisualState.normal:
        return index.isEven ? Colors.white : const Color(0xFFFCFDFE);
    }
  }

  Map<String, Object?>? get _summaryValues {
    if (!_showTotals) {
      return null;
    }
    final List<CustomerRecord> rows = _pagingEnabled
        ? _filteredRows.take(_gridController.options.pageSize).toList()
        : _filteredRows;
    final double balanceTotal = rows.fold<double>(
      0,
      (double total, CustomerRecord row) => total + row.balance,
    );
    final int averageProgress = rows.isEmpty
        ? 0
        : (rows.fold<int>(
                    0,
                    (int total, CustomerRecord row) => total + row.progress,
                  ) /
                  rows.length)
              .round();
    return <String, Object?>{
      'customer': _pagingEnabled ? 'Page summary' : 'Grid summary',
      'balance': _formatCurrency(balanceTotal),
      'progress': 'Avg $averageProgress%',
    };
  }

  Map<String, Object?>? get _extraTopValues => _showExtraRows
      ? <String, Object?>{
          'customer': 'Extra top row',
          'notes': 'Configuration stays in the demo app shell.',
        }
      : null;

  Map<String, Object?>? get _extraBottomValues => _showExtraRows
      ? <String, Object?>{
          'customer': 'Extra bottom row',
          'owner': 'Grid module is reusable across apps.',
        }
      : null;

  void _regenerateRows() {
    setState(() {
      _rows = List<CustomerRecord>.generate(_rowCount, CustomerRecord.sample);
    });
    if (!_pagingEnabled) {
      _syncPagingState();
    }
  }

  void _syncPagingState() {
    final int targetPageSize = _pagingEnabled
        ? _pagedPageSize
        : math.max(1, _filteredRows.length);
    _gridController.updateOptions(
      _gridController.options.copyWith(
        page: 1,
        pageSize: targetPageSize,
        take: targetPageSize,
      ),
    );
  }

  Future<void> _simulateLoading() async {
    if (_loading) {
      return;
    }
    setState(() {
      _loading = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
    });
  }

  void _showPageTransitionLoading() {
    _pageTransitionLoadingTimer?.cancel();
    if (!_pageTransitionLoading && mounted) {
      setState(() {
        _pageTransitionLoading = true;
      });
    }
    _pageTransitionLoadingTimer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _pageTransitionLoading = false;
      });
    });
  }

  void _handleGridOptionsChanged(DataGridOptions options) {
    final bool pageChanged = options.page != _lastObservedPage;
    _lastObservedPage = options.page;
    if (_pagingEnabled) {
      _pagedPageSize = options.pageSize;
    }
    if (_pagingEnabled && pageChanged) {
      _showPageTransitionLoading();
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _resetDemoState() async {
    await _persistenceAdapter.reset(_readonlyStorageKey);
    await _persistenceAdapter.reset(_editableStorageKey);
    _gridController
      ..replaceSelection(const <Object>[])
      ..setFocus()
      ..resetColumns(_columns)
      ..updateOptions(
        const DataGridOptions(
          page: 1,
          pageSize: 20,
          paginationMode: DataGridPaginationMode.local,
        ),
      );
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _pageTransitionLoading = false;
      _editableMode = false;
      _multiSort = true;
      _keyboardNavigation = true;
      _showTotals = true;
      _pagingEnabled = true;
      _showExtraRows = false;
      _showSelectedCount = true;
      _showRowStyle = true;
      _persistenceEnabled = true;
      _pagedPageSize = 20;
      _rowCount = 140;
      _checkboxSelectionMin = 0;
      _checkboxSelectionMax = 0;
      _searchQuery = '';
      _themeMode = DataGridThemeMode.light;
      _density = DataGridDensity.compact;
      _rows = List<CustomerRecord>.generate(_rowCount, CustomerRecord.sample);
    });
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFEAF4FF),
              Color(0xFFF9FBFF),
              Color(0xFFF7F7FA),
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            const Positioned(
              left: -60,
              top: -40,
              child: _AmbientGlow(size: 220, color: Color(0x660A84FF)),
            ),
            const Positioned(
              right: -30,
              top: 120,
              child: _AmbientGlow(size: 180, color: Color(0x55B8E6FF)),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double gridHeight = math.max(
                    280,
                    constraints.maxHeight - 360,
                  );
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Flutter Custom Table Demo — Web / Windows / macOS',
                                    style: textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: <Widget>[
                                FilledButton.tonalIcon(
                                  key: const Key('back-home-button'),
                                  onPressed: widget.onBack,
                                  icon: const Icon(Icons.home_rounded),
                                  label: const Text('Home'),
                                ),
                                FilledButton.tonalIcon(
                                  key: const Key('open-pos-demo-button'),
                                  onPressed: widget.onOpenPosDemo,
                                  icon: const Icon(Icons.point_of_sale_rounded),
                                  label: const Text('Open POS Demo'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _DemoControlPanel(
                          searchQuery: _searchQuery,
                          rowCount: _rowCount,
                          rowCountOptions: _rowCountOptions,
                          editableMode: _editableMode,
                          multiSort: _multiSort,
                          keyboardNavigation: _keyboardNavigation,
                          loading: _loading,
                          showTotals: _showTotals,
                          pagingEnabled: _pagingEnabled,
                          showExtraRows: _showExtraRows,
                          showSelectedCount: _showSelectedCount,
                          showRowStyle: _showRowStyle,
                          persistenceEnabled: _persistenceEnabled,
                          checkboxSelectionMin: _checkboxSelectionMin,
                          checkboxSelectionMax: _checkboxSelectionMax,
                          themeMode: _themeMode,
                          density: _density,
                          onSearchChanged: (String value) {
                            setState(() {
                              _searchQuery = value;
                            });
                            if (!_pagingEnabled) {
                              _syncPagingState();
                            }
                          },
                          onRowCountChanged: (int? value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _rowCount = value;
                              _rows = List<CustomerRecord>.generate(
                                _rowCount,
                                CustomerRecord.sample,
                              );
                            });
                            if (!_pagingEnabled) {
                              _syncPagingState();
                            }
                          },
                          onEditableModeChanged: (bool value) {
                            setState(() {
                              _editableMode = value;
                            });
                          },
                          onMultiSortChanged: (bool value) {
                            setState(() {
                              _multiSort = value;
                            });
                          },
                          onKeyboardNavigationChanged: (bool value) {
                            setState(() {
                              _keyboardNavigation = value;
                            });
                          },
                          onLoadingChanged: (bool value) {
                            setState(() {
                              _loading = value;
                            });
                          },
                          onShowTotalsChanged: (bool value) {
                            setState(() {
                              _showTotals = value;
                            });
                          },
                          onPagingEnabledChanged: (bool value) {
                            setState(() {
                              if (!value) {
                                _pagedPageSize =
                                    _gridController.options.pageSize;
                              }
                              _pagingEnabled = value;
                            });
                            _syncPagingState();
                          },
                          onShowExtraRowsChanged: (bool value) {
                            setState(() {
                              _showExtraRows = value;
                            });
                          },
                          onShowSelectedCountChanged: (bool value) {
                            setState(() {
                              _showSelectedCount = value;
                            });
                          },
                          onShowRowStyleChanged: (bool value) {
                            setState(() {
                              _showRowStyle = value;
                            });
                          },
                          onPersistenceEnabledChanged: (bool value) {
                            setState(() {
                              _persistenceEnabled = value;
                            });
                          },
                          onCheckboxSelectionMinChanged: (int value) {
                            setState(() {
                              _checkboxSelectionMin = math.max(0, value);
                            });
                          },
                          onCheckboxSelectionMaxChanged: (int value) {
                            setState(() {
                              _checkboxSelectionMax = math.max(0, value);
                            });
                          },
                          onThemeModeChanged: (DataGridThemeMode? value) {
                            if (value != null) {
                              setState(() {
                                _themeMode = value;
                              });
                            }
                          },
                          onDensityChanged: (DataGridDensity? value) {
                            if (value != null) {
                              setState(() {
                                _density = value;
                              });
                            }
                          },
                          onRegeneratePressed: _regenerateRows,
                          onSimulateLoadingPressed: _simulateLoading,
                          onResetPressed: _resetDemoState,
                        ),
                        const SizedBox(height: 18),
                        Expanded(
                          child: _GlassSurface(
                            borderRadius: 24,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                10,
                              ),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: SizedBox(
                                  key: const Key('customer-grid-host'),
                                  width: double.infinity,
                                  child: DataGrid<CustomerRecord>(
                                    key: const Key('customer-grid'),
                                    columns: _columns,
                                    rows: _gridRows,
                                    rowKey: (CustomerRecord row) => row.id,
                                    controller: _gridController,
                                    persistenceAdapter: _persistenceAdapter,
                                    storageKey: _storageKey,
                                    mode: _editableMode
                                        ? DataGridMode.editable
                                        : DataGridMode.readonly,
                                    navigationConfig: DataGridNavigationConfig(
                                      autoFocus: true,
                                      keyboardNavigation: _keyboardNavigation,
                                      rowSelectFocusColumnId: 'customer',
                                    ),
                                    pageSizeOptions: _pageSizeOptions,
                                    selectionConfig: _selectionConfig,
                                    totalRowCount: _filteredRows.length,
                                    loading: _loading || _pageTransitionLoading,
                                    height: gridHeight,
                                    density: _density,
                                    themeMode: _themeMode,
                                    multiSort: _multiSort,
                                    persistSort: true,
                                    showFooter: _pagingEnabled,
                                    showSelectedCount: _showSelectedCount,
                                    summaryValues: _summaryValues,
                                    extraTopValues: _extraTopValues,
                                    extraBottomValues: _extraBottomValues,
                                    rowColorBuilder: _showRowStyle
                                        ? (
                                            CustomerRecord row,
                                            int rowIndex,
                                            bool isSelected,
                                            bool isHovered,
                                          ) => _baseRowColor(rowIndex, row)
                                        : null,
                                    onOptionsChanged: _handleGridOptionsChanged,
                                    onEditCommit: _handleInlineEditCommit,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoControlPanel extends StatelessWidget {
  const _DemoControlPanel({
    required this.searchQuery,
    required this.rowCount,
    required this.rowCountOptions,
    required this.editableMode,
    required this.multiSort,
    required this.keyboardNavigation,
    required this.loading,
    required this.showTotals,
    required this.pagingEnabled,
    required this.showExtraRows,
    required this.showSelectedCount,
    required this.showRowStyle,
    required this.persistenceEnabled,
    required this.checkboxSelectionMin,
    required this.checkboxSelectionMax,
    required this.themeMode,
    required this.density,
    required this.onSearchChanged,
    required this.onRowCountChanged,
    required this.onEditableModeChanged,
    required this.onMultiSortChanged,
    required this.onKeyboardNavigationChanged,
    required this.onLoadingChanged,
    required this.onShowTotalsChanged,
    required this.onPagingEnabledChanged,
    required this.onShowExtraRowsChanged,
    required this.onShowSelectedCountChanged,
    required this.onShowRowStyleChanged,
    required this.onPersistenceEnabledChanged,
    required this.onCheckboxSelectionMinChanged,
    required this.onCheckboxSelectionMaxChanged,
    required this.onThemeModeChanged,
    required this.onDensityChanged,
    required this.onRegeneratePressed,
    required this.onSimulateLoadingPressed,
    required this.onResetPressed,
  });

  final String searchQuery;
  final int rowCount;
  final List<int> rowCountOptions;
  final bool editableMode;
  final bool multiSort;
  final bool keyboardNavigation;
  final bool loading;
  final bool showTotals;
  final bool pagingEnabled;
  final bool showExtraRows;
  final bool showSelectedCount;
  final bool showRowStyle;
  final bool persistenceEnabled;
  final int checkboxSelectionMin;
  final int checkboxSelectionMax;
  final DataGridThemeMode themeMode;
  final DataGridDensity density;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int?> onRowCountChanged;
  final ValueChanged<bool> onEditableModeChanged;
  final ValueChanged<bool> onMultiSortChanged;
  final ValueChanged<bool> onKeyboardNavigationChanged;
  final ValueChanged<bool> onLoadingChanged;
  final ValueChanged<bool> onShowTotalsChanged;
  final ValueChanged<bool> onPagingEnabledChanged;
  final ValueChanged<bool> onShowExtraRowsChanged;
  final ValueChanged<bool> onShowSelectedCountChanged;
  final ValueChanged<bool> onShowRowStyleChanged;
  final ValueChanged<bool> onPersistenceEnabledChanged;
  final ValueChanged<int> onCheckboxSelectionMinChanged;
  final ValueChanged<int> onCheckboxSelectionMaxChanged;
  final ValueChanged<DataGridThemeMode?> onThemeModeChanged;
  final ValueChanged<DataGridDensity?> onDensityChanged;
  final VoidCallback onRegeneratePressed;
  final VoidCallback onSimulateLoadingPressed;
  final Future<void> Function() onResetPressed;

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      borderRadius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 16,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: <Widget>[
              _ControlField(
                label: 'Search',
                child: SizedBox(
                  width: 250,
                  child: _BufferedTextField(
                    value: searchQuery,
                    onChanged: onSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'Customer, company, owner, note',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              _ControlField(
                label: 'Rows',
                child: _DropdownField<int>(
                  value: rowCount,
                  items: rowCountOptions,
                  itemLabel: (int value) => '$value',
                  onChanged: onRowCountChanged,
                ),
              ),
              _ControlField(
                label: 'Theme',
                child: _DropdownField<DataGridThemeMode>(
                  value: themeMode,
                  items: DataGridThemeMode.values,
                  itemLabel: (DataGridThemeMode value) => value.name,
                  onChanged: onThemeModeChanged,
                ),
              ),
              _ControlField(
                label: 'Density',
                child: _DropdownField<DataGridDensity>(
                  value: density,
                  items: DataGridDensity.values,
                  itemLabel: (DataGridDensity value) => value.name,
                  onChanged: onDensityChanged,
                ),
              ),
              _ControlField(
                label: 'Checkbox min',
                child: SizedBox(
                  width: 120,
                  child: _BufferedTextField(
                    value: '$checkboxSelectionMin',
                    keyboardType: TextInputType.number,
                    onChanged: (String value) => onCheckboxSelectionMinChanged(
                      int.tryParse(value.trim()) ?? 0,
                    ),
                    decoration: const InputDecoration(isDense: true),
                  ),
                ),
              ),
              _ControlField(
                label: 'Checkbox max',
                child: SizedBox(
                  width: 120,
                  child: _BufferedTextField(
                    value: '$checkboxSelectionMax',
                    keyboardType: TextInputType.number,
                    onChanged: (String value) => onCheckboxSelectionMaxChanged(
                      int.tryParse(value.trim()) ?? 0,
                    ),
                    decoration: const InputDecoration(
                      hintText: '0 = no limit',
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _ToggleChip(
                label: 'Editable mode',
                value: editableMode,
                onChanged: onEditableModeChanged,
              ),
              _ToggleChip(
                label: 'Multi sort',
                value: multiSort,
                onChanged: onMultiSortChanged,
              ),
              _ToggleChip(
                label: 'Keyboard nav',
                value: keyboardNavigation,
                onChanged: onKeyboardNavigationChanged,
              ),
              _ToggleChip(
                label: 'Loading overlay',
                value: loading,
                onChanged: onLoadingChanged,
              ),
              _ToggleChip(
                label: 'Totals',
                value: showTotals,
                onChanged: onShowTotalsChanged,
              ),
              _ToggleChip(
                label: 'Paging',
                value: pagingEnabled,
                onChanged: onPagingEnabledChanged,
              ),
              _ToggleChip(
                label: 'Selected count',
                value: showSelectedCount,
                onChanged: onShowSelectedCountChanged,
              ),
              _ToggleChip(
                label: 'Row style',
                value: showRowStyle,
                onChanged: onShowRowStyleChanged,
              ),
              _ToggleChip(
                label: 'Extra rows',
                value: showExtraRows,
                onChanged: onShowExtraRowsChanged,
              ),
              _ToggleChip(
                label: 'Persistence',
                value: persistenceEnabled,
                onChanged: onPersistenceEnabledChanged,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              FilledButton.icon(
                onPressed: onRegeneratePressed,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Regenerate'),
              ),
              FilledButton.tonalIcon(
                onPressed: onSimulateLoadingPressed,
                icon: const Icon(Icons.hourglass_top_rounded),
                label: const Text('Simulate loading'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  onResetPressed();
                },
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reset state'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlField extends StatelessWidget {
  const _ControlField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final T value;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD7E2EE)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            onChanged: onChanged,
            borderRadius: BorderRadius.circular(14),
            items: items
                .map(
                  (T item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(itemLabel(item)),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _BufferedTextField extends StatefulWidget {
  const _BufferedTextField({
    required this.value,
    required this.onChanged,
    this.decoration,
    this.keyboardType,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;

  @override
  State<_BufferedTextField> createState() => _BufferedTextFieldState();
}

class _BufferedTextFieldState extends State<_BufferedTextField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _BufferedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == _controller.text || _focusNode.hasFocus) {
      return;
    }
    _controller.value = TextEditingValue(
      text: widget.value,
      selection: TextSelection.collapsed(offset: widget.value.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      decoration: widget.decoration,
      keyboardType: widget.keyboardType,
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    const Color activeAccent = Color(0xFF0F766E);
    const Color activeBackground = Color(0xFFE6FFFB);
    const Color activeForeground = Color(0xFF115E59);
    const Color inactiveBackground = Color(0xFFF8FAFC);
    const Color inactiveForeground = Color(0xFF475569);

    return FilterChip(
      avatar: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: value ? activeAccent : const Color(0xFFD7E2EE),
          shape: BoxShape.circle,
        ),
      ),
      label: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 160),
        style:
            Theme.of(context).textTheme.labelLarge?.copyWith(
              color: value ? activeForeground : inactiveForeground,
              fontWeight: FontWeight.w700,
            ) ??
            const TextStyle(),
        child: Text(label),
      ),
      selected: value,
      onSelected: onChanged,
      backgroundColor: inactiveBackground,
      selectedColor: activeBackground,
      showCheckmark: false,
      side: BorderSide(
        color: value
            ? activeAccent.withValues(alpha: 0.38)
            : const Color(0xFFD7E2EE),
      ),
      elevation: 0,
      pressElevation: 0,
      shadowColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }
}

enum _ModalAction { edit }

class _CustomerViewDialog extends StatelessWidget {
  const _CustomerViewDialog({required this.record});

  final CustomerRecord record;

  @override
  Widget build(BuildContext context) {
    return _ModalShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Account Overview',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF5B6472),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      record.customer,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: const Color(0xFF0F172A),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${record.company}  •  ${record.region}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF516076),
                      ),
                    ),
                  ],
                ),
              ),
              _ModalCloseButton(onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _Badge(
                label: record.status.label,
                background: const Color(0xFFE0F2FE),
                foreground: const Color(0xFF0C4A6E),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: <Widget>[
              _MetricSummaryCard(
                label: 'Outstanding Balance',
                value: _formatCurrency(record.balance),
              ),
              _MetricSummaryCard(
                label: 'Progress',
                value: '${record.progress}%',
              ),
              _MetricSummaryCard(
                label: 'Last Order',
                value: _formatDate(record.lastOrder),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _DetailBlock(
            title: 'Contact',
            items: <MapEntry<String, String>>[
              MapEntry<String, String>('Email', record.email),
              MapEntry<String, String>('Phone', record.phone),
              MapEntry<String, String>('Owner', record.owner),
            ],
          ),
          const SizedBox(height: 14),
          _DetailBlock(
            title: 'Account',
            items: <MapEntry<String, String>>[
              MapEntry<String, String>('Customer ID', '#${record.id}'),
              MapEntry<String, String>('Status', record.status.label),
            ],
          ),
          const SizedBox(height: 14),
          _DetailBlock(
            title: 'Service Notes',
            items: <MapEntry<String, String>>[
              MapEntry<String, String>('Notes', record.notes),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                key: const Key('view-modal-edit-button'),
                onPressed: () => Navigator.of(context).pop(_ModalAction.edit),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomerEditDialog extends StatefulWidget {
  const _CustomerEditDialog({required this.record});

  final CustomerRecord record;

  @override
  State<_CustomerEditDialog> createState() => _CustomerEditDialogState();
}

class _CustomerEditDialogState extends State<_CustomerEditDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _customerController;
  late final TextEditingController _companyController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _balanceController;
  late final TextEditingController _ownerController;
  late final TextEditingController _notesController;

  late String _region;
  late RecordStatus _status;
  late double _progress;

  @override
  void initState() {
    super.initState();
    final CustomerRecord record = widget.record;
    _customerController = TextEditingController(text: record.customer);
    _companyController = TextEditingController(text: record.company);
    _emailController = TextEditingController(text: record.email);
    _phoneController = TextEditingController(text: record.phone);
    _balanceController = TextEditingController(
      text: record.balance.toStringAsFixed(2),
    );
    _ownerController = TextEditingController(text: record.owner);
    _notesController = TextEditingController(text: record.notes);
    _region = record.region;
    _status = record.status;
    _progress = record.progress.toDouble();
  }

  @override
  void dispose() {
    _customerController.dispose();
    _companyController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _balanceController.dispose();
    _ownerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final double balance = double.parse(_balanceController.text.trim());
    final CustomerRecord updated = widget.record.copyWith(
      customer: _customerController.text.trim(),
      company: _companyController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      region: _region,
      status: _status,
      balance: balance,
      progress: _progress.round(),
      owner: _ownerController.text.trim(),
      notes: _notesController.text.trim(),
      updatedAt: DateTime.now(),
      visualState: _visualStateForStatus(_status),
    );

    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final CustomerRecord record = widget.record;

    return _ModalShell(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Edit Customer',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: const Color(0xFF0F172A),
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Update business fields and save changes directly back into the table.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                _ModalCloseButton(onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: <Widget>[
                _ReadOnlyFieldCard(
                  label: 'Customer ID',
                  value: '#${record.id}',
                ),
                _ReadOnlyFieldCard(
                  label: 'Created At',
                  value: _formatDate(record.createdAt),
                ),
                _ReadOnlyFieldCard(
                  label: 'Updated At',
                  value: _formatDate(record.updatedAt),
                ),
                _ReadOnlyFieldCard(
                  label: 'Last Order',
                  value: _formatDate(record.lastOrder),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: <Widget>[
                _SizedInput(
                  width: 300,
                  child: TextFormField(
                    key: const Key('edit-customer-field'),
                    controller: _customerController,
                    decoration: const InputDecoration(labelText: 'Customer'),
                    validator: _requiredValidator,
                  ),
                ),
                _SizedInput(
                  width: 300,
                  child: TextFormField(
                    key: const Key('edit-company-field'),
                    controller: _companyController,
                    decoration: const InputDecoration(labelText: 'Company'),
                    validator: _requiredValidator,
                  ),
                ),
                _SizedInput(
                  width: 300,
                  child: TextFormField(
                    key: const Key('edit-email-field'),
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      if (!value.contains('@')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                ),
                _SizedInput(
                  width: 300,
                  child: TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    validator: _requiredValidator,
                  ),
                ),
                _SizedInput(
                  width: 260,
                  child: _FormDropdown<String>(
                    label: 'Region',
                    value: _region,
                    items: _regions
                        .map(
                          (String region) => DropdownMenuItem<String>(
                            value: region,
                            child: Text(region),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() {
                          _region = value;
                        });
                      }
                    },
                  ),
                ),
                _SizedInput(
                  width: 250,
                  child: _FormDropdown<RecordStatus>(
                    label: 'Status',
                    value: _status,
                    items: RecordStatus.values
                        .map(
                          (RecordStatus status) =>
                              DropdownMenuItem<RecordStatus>(
                                value: status,
                                child: Text(status.label),
                              ),
                        )
                        .toList(),
                    onChanged: (RecordStatus? value) {
                      if (value != null) {
                        setState(() {
                          _status = value;
                        });
                      }
                    },
                  ),
                ),
                _SizedInput(
                  width: 220,
                  child: TextFormField(
                    key: const Key('edit-balance-field'),
                    controller: _balanceController,
                    decoration: const InputDecoration(labelText: 'Balance'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (String? value) {
                      final String raw = value?.trim() ?? '';
                      final double? parsed = double.tryParse(raw);
                      if (raw.isEmpty) {
                        return 'Required';
                      }
                      if (parsed == null || parsed < 0) {
                        return 'Enter a valid amount';
                      }
                      return null;
                    },
                  ),
                ),
                _SizedInput(
                  width: 300,
                  child: TextFormField(
                    controller: _ownerController,
                    decoration: const InputDecoration(labelText: 'Owner'),
                    validator: _requiredValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Progress',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF475569),
                fontWeight: FontWeight.w700,
              ),
            ),
            Slider(
              value: _progress,
              min: 0,
              max: 100,
              divisions: 100,
              label: '${_progress.round()}%',
              onChanged: (double value) {
                setState(() {
                  _progress = value;
                });
              },
            ),
            TextFormField(
              controller: _notesController,
              minLines: 4,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Notes',
                alignLabelWithHint: true,
              ),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  key: const Key('edit-save-button'),
                  onPressed: _save,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Save Changes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: <Color>[color, Colors.transparent]),
        ),
      ),
    );
  }
}

class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    required this.child,
    this.borderRadius = 20,
    this.padding,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 26,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
  }
}

class _ActionCell extends StatelessWidget {
  const _ActionCell({required this.recordId, required this.onAction});

  final int recordId;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _ActionButton(
          key: Key('row-$recordId-action-view'),
          label: 'View',
          icon: Icons.visibility_outlined,
          onPressed: () => onAction('View'),
        ),
        _ActionButton(
          key: Key('row-$recordId-action-edit'),
          label: 'Edit',
          icon: Icons.edit_outlined,
          onPressed: () => onAction('Edit'),
        ),
        _ActionButton(
          key: Key('row-$recordId-action-delete'),
          label: 'Delete',
          icon: Icons.delete_outline_rounded,
          onPressed: () => onAction('Delete'),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }
}

class _PlainTextCell extends StatelessWidget {
  const _PlainTextCell(
    this.text, {
    this.muted = false,
    this.maxLines = 1,
    this.highlightQuery,
  });

  final String text;
  final bool muted;
  final int maxLines;
  final String? highlightQuery;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: muted ? const Color(0xFF64748B) : const Color(0xFF0F172A),
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: _SelectableCellText(
        text,
        maxLines: maxLines,
        style: style,
        highlightQuery: highlightQuery,
      ),
    );
  }
}

class _PrimaryCell extends StatelessWidget {
  const _PrimaryCell({
    required this.title,
    required this.subtitle,
    this.highlightQuery,
  });

  final String title;
  final String subtitle;
  final String? highlightQuery;

  @override
  Widget build(BuildContext context) {
    final TextStyle? titleStyle = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: const Color(0xFF0F172A), fontWeight: FontWeight.w700);
    final TextStyle? subtitleStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B));
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SelectableCellText(
          title,
          style: titleStyle,
          maxLines: 1,
          highlightQuery: highlightQuery,
        ),
        const SizedBox(height: 2),
        _SelectableCellText(
          subtitle,
          style: subtitleStyle,
          maxLines: 1,
          highlightQuery: highlightQuery,
        ),
      ],
    );
  }
}

class _TagChipCell extends StatelessWidget {
  const _TagChipCell(
    this.label, {
    required this.color,
    required this.textColor,
    this.highlightQuery,
  });

  final String label;
  final Color color;
  final Color textColor;
  final String? highlightQuery;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
        child: _SelectableCellText(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
          highlightQuery: highlightQuery,
          highlightStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w800,
            backgroundColor: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell(
    this.value, {
    this.emphasis = false,
    this.align = TextAlign.left,
  });

  final String value;
  final bool emphasis;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: emphasis ? const Color(0xFF0F172A) : const Color(0xFF334155),
      fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
    );
    return _SelectableCellText(
      value,
      textAlign: align,
      maxLines: 1,
      style: style,
    );
  }
}

class _SelectableCellText extends StatelessWidget {
  const _SelectableCellText(
    this.text, {
    this.style,
    this.maxLines = 1,
    this.textAlign = TextAlign.left,
    this.highlightQuery,
    this.highlightStyle,
  });

  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextAlign textAlign;
  final String? highlightQuery;
  final TextStyle? highlightStyle;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: _buildHighlightedTextSpans(
          text: text,
          baseStyle: style,
          query: highlightQuery,
          highlightStyle:
              highlightStyle ??
              style?.copyWith(
                fontWeight: FontWeight.w800,
                backgroundColor: const Color(0xFFFFF3B0),
              ) ??
              const TextStyle(
                fontWeight: FontWeight.w800,
                backgroundColor: Color(0xFFFFF3B0),
              ),
        ),
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: style,
    );
  }
}

class _ProgressCell extends StatelessWidget {
  const _ProgressCell(this.progress);

  final int progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress / 100,
            minHeight: 8,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 70
                  ? const Color(0xFF16A34A)
                  : progress >= 45
                  ? const Color(0xFF0EA5E9)
                  : const Color(0xFFF59E0B),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$progress%',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF475569),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _OwnerCell extends StatelessWidget {
  const _OwnerCell(this.owner, {this.highlightQuery});

  final String owner;
  final String? highlightQuery;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        CircleAvatar(
          radius: 14,
          backgroundColor: const Color(0xFFDBEAFE),
          child: Text(
            owner.characters.first,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF1D4ED8),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _PlainTextCell(owner, highlightQuery: highlightQuery)),
      ],
    );
  }
}

List<InlineSpan> _buildHighlightedTextSpans({
  required String text,
  required TextStyle? baseStyle,
  required String? query,
  required TextStyle highlightStyle,
}) {
  final String trimmedQuery = query?.trim() ?? '';
  if (trimmedQuery.isEmpty || text.isEmpty) {
    return <InlineSpan>[TextSpan(text: text, style: baseStyle)];
  }

  final String lowerText = text.toLowerCase();
  final String lowerQuery = trimmedQuery.toLowerCase();
  final List<InlineSpan> spans = <InlineSpan>[];
  int start = 0;

  while (start < text.length) {
    final int matchIndex = lowerText.indexOf(lowerQuery, start);
    if (matchIndex == -1) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
      break;
    }

    if (matchIndex > start) {
      spans.add(
        TextSpan(text: text.substring(start, matchIndex), style: baseStyle),
      );
    }

    final int matchEnd = matchIndex + trimmedQuery.length;
    spans.add(
      TextSpan(
        text: text.substring(matchIndex, matchEnd),
        style: highlightStyle,
      ),
    );
    start = matchEnd;
  }

  return spans;
}

class _ModalShell extends StatelessWidget {
  const _ModalShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
          child: SingleChildScrollView(
            child: _GlassSurface(
              borderRadius: 24,
              padding: const EdgeInsets.all(24),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _ModalCloseButton extends StatelessWidget {
  const _ModalCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.close_rounded),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetricSummaryCard extends StatelessWidget {
  const _MetricSummaryCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.title, required this.items});

  final String title;
  final List<MapEntry<String, String>> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (MapEntry<String, String> item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 120,
                    child: Text(
                      item.key,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyFieldCard extends StatelessWidget {
  const _ReadOnlyFieldCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SizedInput extends StatelessWidget {
  const _SizedInput({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, child: child);
  }
}

class _FormDropdown<T> extends StatelessWidget {
  const _FormDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

Future<T?> _showCenteredModal<T>(
  BuildContext context, {
  required Widget child,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: const Color(0xAA0F172A),
    builder: (BuildContext context) => child,
  );
}

String? _requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Required';
  }
  return null;
}

class CustomerRecord {
  CustomerRecord({
    required this.id,
    required this.customer,
    required this.company,
    required this.email,
    required this.phone,
    required this.region,
    required this.status,
    required this.balance,
    required this.lastOrder,
    required this.progress,
    required this.owner,
    required this.createdAt,
    required this.updatedAt,
    required this.notes,
    required this.visualState,
  });

  final int id;
  final String customer;
  final String company;
  final String email;
  final String phone;
  final String region;
  final RecordStatus status;
  final double balance;
  final DateTime lastOrder;
  final int progress;
  final String owner;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String notes;
  final RowVisualState visualState;

  CustomerRecord copyWith({
    String? customer,
    String? company,
    String? email,
    String? phone,
    String? region,
    RecordStatus? status,
    double? balance,
    DateTime? lastOrder,
    int? progress,
    String? owner,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
    RowVisualState? visualState,
  }) {
    return CustomerRecord(
      id: id,
      customer: customer ?? this.customer,
      company: company ?? this.company,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      region: region ?? this.region,
      status: status ?? this.status,
      balance: balance ?? this.balance,
      lastOrder: lastOrder ?? this.lastOrder,
      progress: progress ?? this.progress,
      owner: owner ?? this.owner,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      visualState: visualState ?? this.visualState,
    );
  }

  factory CustomerRecord.sample(int index) {
    const List<String> firstNames = <String>[
      'Amelia',
      'Noah',
      'Layla',
      'Ethan',
      'Mia',
      'Oliver',
      'Sofia',
      'Leo',
      'Zara',
      'Lucas',
    ];
    const List<String> lastNames = <String>[
      'Hart',
      'Kim',
      'Carter',
      'Patel',
      'Rossi',
      'Garcia',
      'Nguyen',
      'Lee',
      'Brown',
      'Davis',
    ];
    const List<String> companies = <String>[
      'Northwind Retail',
      'BluePeak Labs',
      'Atlas Commerce',
      'Summit Health',
      'BrightPath Logistics',
      'Aster Finance',
      'Golden State Foods',
      'Cloudline Systems',
    ];
    const List<String> owners = <String>[
      'Ava Stone',
      'Mason Lee',
      'Nora Kim',
      'Liam Carter',
      'Zoe Adams',
      'Owen Brooks',
    ];
    const List<String> noteTemplates = <String>[
      'Renewal discussion scheduled with finance and procurement teams.',
      'Customer asked for a cleaner invoice history and usage summary.',
      'Migration is stable, but the success team is monitoring training adoption.',
      'Requires follow-up on overdue balance before quarter-end expansion.',
      'Strong engagement from regional managers after the last rollout review.',
      'Disabled integrations pending internal security approval.',
    ];

    final int rowId = index + 1;
    final String firstName = firstNames[index % firstNames.length];
    final String lastName = lastNames[(index * 3) % lastNames.length];
    final String customer = '$firstName $lastName';
    final String company = companies[index % companies.length];
    final RecordStatus status =
        RecordStatus.values[index % RecordStatus.values.length];
    final DateTime createdAt = DateTime(
      2025,
      (index % 12) + 1,
      (index % 27) + 1,
    );
    final DateTime updatedAt = createdAt.add(Duration(days: (index % 18) + 6));

    return CustomerRecord(
      id: rowId,
      customer: customer,
      company: company,
      email:
          '${firstName.toLowerCase()}.${lastName.toLowerCase()}@${company.toLowerCase().replaceAll(' ', '')}.com',
      phone: '+1 (555) ${100 + index}-${1200 + index}',
      region: _regions[index % _regions.length],
      status: status,
      balance: 380 + (index * 117.35) % 24000,
      lastOrder: DateTime(2026, ((index + 2) % 12) + 1, ((index * 2) % 28) + 1),
      progress: 28 + ((index * 7) % 73),
      owner: owners[index % owners.length],
      createdAt: createdAt,
      updatedAt: updatedAt,
      notes: noteTemplates[index % noteTemplates.length],
      visualState: _sampleVisualStateForRow(rowId, status),
    );
  }
}

enum RecordStatus {
  active('Active'),
  review('Review'),
  paused('Paused'),
  inactive('Inactive');

  const RecordStatus(this.label);

  final String label;
}

enum RowVisualState { normal, warning, success, inactive }

const List<String> _regions = <String>[
  'North America',
  'Europe',
  'Middle East',
  'Central Asia',
  'APAC',
  'LATAM',
];

RowVisualState _visualStateForStatus(RecordStatus status) {
  switch (status) {
    case RecordStatus.active:
      return RowVisualState.success;
    case RecordStatus.review:
      return RowVisualState.warning;
    case RecordStatus.paused:
      return RowVisualState.normal;
    case RecordStatus.inactive:
      return RowVisualState.inactive;
  }
}

RowVisualState _sampleVisualStateForRow(int rowId, RecordStatus status) {
  if (rowId == 1) {
    return RowVisualState.success;
  }
  if (rowId == 2) {
    return RowVisualState.warning;
  }
  if (status == RecordStatus.inactive) {
    return RowVisualState.inactive;
  }
  return RowVisualState.normal;
}

String _formatDate(DateTime date) {
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _formatCurrency(double value) {
  final String fixed = value.toStringAsFixed(2);
  final List<String> parts = fixed.split('.');
  final String whole = parts.first;
  final String decimal = parts.last;
  final String formattedWhole = whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (Match match) => ',',
  );
  return '\$$formattedWhole.$decimal';
}

Color _statusColor(RecordStatus status) {
  switch (status) {
    case RecordStatus.active:
      return const Color(0xFFD1FAE5);
    case RecordStatus.review:
      return const Color(0xFFFEF3C7);
    case RecordStatus.paused:
      return const Color(0xFFE0E7FF);
    case RecordStatus.inactive:
      return const Color(0xFFE2E8F0);
  }
}

Color _statusTextColor(RecordStatus status) {
  switch (status) {
    case RecordStatus.active:
      return const Color(0xFF166534);
    case RecordStatus.review:
      return const Color(0xFF92400E);
    case RecordStatus.paused:
      return const Color(0xFF4338CA);
    case RecordStatus.inactive:
      return const Color(0xFF475569);
  }
}
