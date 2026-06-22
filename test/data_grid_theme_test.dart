import 'package:data_grid/data_grid.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DataGridTheme', () {
    testWidgets('resolves fallback theme from the current light theme', (
      WidgetTester tester,
    ) async {
      final ThemeData materialTheme = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A84FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      );
      late DataGridThemeData resolvedTheme;

      await tester.pumpWidget(
        MaterialApp(
          theme: materialTheme,
          home: Builder(
            builder: (BuildContext context) {
              resolvedTheme = DataGridTheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolvedTheme.brightness, Brightness.light);
      expect(resolvedTheme.surface, materialTheme.colorScheme.surface);
      expect(resolvedTheme.accent, materialTheme.colorScheme.primary);
      expect(resolvedTheme.headerHeight(DataGridDensity.compact), 36);
    });

    testWidgets('resolves fallback theme from the current dark theme', (
      WidgetTester tester,
    ) async {
      final ThemeData materialTheme = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A84FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      );
      late DataGridThemeData resolvedTheme;

      await tester.pumpWidget(
        MaterialApp(
          theme: materialTheme,
          home: Builder(
            builder: (BuildContext context) {
              resolvedTheme = DataGridTheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolvedTheme.brightness, Brightness.dark);
      expect(resolvedTheme.surface, materialTheme.colorScheme.surface);
      expect(resolvedTheme.accent, materialTheme.colorScheme.primary);
      expect(resolvedTheme.rowHeight(DataGridDensity.comfortable), 60);
    });

    testWidgets('applies custom theme extension colors and size tokens', (
      WidgetTester tester,
    ) async {
      final DataGridController<_Row> controller = DataGridController<_Row>(
        options: const DataGridOptions(pageSize: 10),
      );
      final ThemeData materialTheme = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A84FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      );
      final DataGridThemeData gridTheme =
          DataGridThemeData.fallback(
            materialTheme,
            brightness: Brightness.light,
          ).copyWith(
            accent: const Color(0xFFFF6A3D),
            standardHeaderHeight: 72,
            standardRowHeight: 66,
            loadingBarHeight: 10,
          );

      await tester.pumpWidget(
        MaterialApp(
          theme: materialTheme.copyWith(
            extensions: <ThemeExtension<dynamic>>[gridTheme],
          ),
          home: Scaffold(
            body: DataGrid<_Row>(
              columns: _columns,
              rows: _rows,
              rowKey: (_Row row) => row.id,
              controller: controller,
              density: DataGridDensity.standard,
              loading: true,
              selectionConfig: const DataGridSelectionConfig<_Row>(
                enableCheckboxSelection: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byKey(const Key('table-header-name'))).height,
        closeTo(72, 1),
      );
      expect(
        tester.getSize(find.byKey(const Key('table-cell-1-name'))).height,
        closeTo(66, 1),
      );

      final CupertinoCheckbox headerCheckbox = tester.widget<CupertinoCheckbox>(
        find.byKey(const Key('table-checkbox-header')),
      );
      expect(headerCheckbox.activeColor, const Color(0xFFFF6A3D));
      expect(
        tester.getSize(find.byKey(const Key('table-loading-bar'))).height,
        10,
      );
    });

    testWidgets('keeps checkbox rows aligned during iOS bounce overscroll', (
      WidgetTester tester,
    ) async {
      final DataGridController<_Row> controller = DataGridController<_Row>(
        options: const DataGridOptions(pageSize: 50),
      );
      final List<_Row> rows = List<_Row>.generate(
        30,
        (int index) =>
            _Row(id: index + 1, name: 'Row ${index + 1}', score: index),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            platform: TargetPlatform.iOS,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0A84FF),
            ),
            useMaterial3: true,
          ),
          home: Scaffold(
            body: DataGrid<_Row>(
              columns: _columns,
              rows: rows,
              rowKey: (_Row row) => row.id,
              controller: controller,
              height: 220,
              selectionConfig: const DataGridSelectionConfig<_Row>(
                enableCheckboxSelection: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder scrollable = find
          .descendant(
            of: find.byType(DataGrid<_Row>),
            matching: find.byType(Scrollable),
          )
          .first;

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(scrollable),
      );
      await gesture.moveBy(const Offset(0, 80));
      await tester.pump();

      final double checkboxTop = tester
          .getTopLeft(find.byKey(const Key('table-checkbox-1')))
          .dy;
      final double cellTop = tester
          .getTopLeft(find.byKey(const Key('table-cell-1-name')))
          .dy;

      expect((checkboxTop - cellTop).abs(), lessThan(0.1));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('keeps column settings accessible when footer is hidden', (
      WidgetTester tester,
    ) async {
      final DataGridController<_Row> controller = DataGridController<_Row>(
        options: const DataGridOptions(pageSize: 10),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0A84FF),
            ),
            useMaterial3: true,
          ),
          home: Scaffold(
            body: DataGrid<_Row>(
              columns: _columns,
              rows: _rows,
              rowKey: (_Row row) => row.id,
              controller: controller,
              showFooter: false,
              selectionConfig: const DataGridSelectionConfig<_Row>(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('table-column-settings')), findsOneWidget);
      expect(find.byKey(const Key('table-page-indicator')), findsNothing);
    });
  });
}

const List<DataGridColumn<_Row>> _columns = <DataGridColumn<_Row>>[
  DataGridColumn<_Row>(
    id: 'name',
    label: 'Name',
    width: 160,
    cellBuilder: _buildNameCell,
  ),
  DataGridColumn<_Row>(
    id: 'score',
    label: 'Score',
    width: 100,
    alignment: Alignment.centerRight,
    cellBuilder: _buildScoreCell,
  ),
];

Widget _buildNameCell(BuildContext context, _Row row) => Text(row.name);

Widget _buildScoreCell(BuildContext context, _Row row) => Text('${row.score}');

const List<_Row> _rows = <_Row>[
  _Row(id: 1, name: 'Alice', score: 12),
  _Row(id: 2, name: 'Bob', score: 7),
];

class _Row {
  const _Row({required this.id, required this.name, required this.score});

  final int id;
  final String name;
  final int score;
}
