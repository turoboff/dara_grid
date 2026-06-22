import 'package:data_grid/data_grid.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const DataGridExampleApp());
}

class DataGridExampleApp extends StatelessWidget {
  const DataGridExampleApp({super.key});

  ThemeData _buildTheme(Brightness brightness) {
    final ThemeData baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0A84FF),
        brightness: brightness,
      ),
      useMaterial3: true,
    );
    final DataGridThemeData gridTheme =
        DataGridThemeData.fallback(baseTheme, brightness: brightness).copyWith(
          headerCellHorizontalPadding: 14,
          cellHorizontalPadding: 14,
          surfaceRadius: 24,
          footerRadius: 24,
          selectionIndicator: const Color(0xFF0A84FF),
          supplementaryRowHeight: 46,
          summaryRowHeight: 50,
        );
    return baseTheme.copyWith(extensions: <ThemeExtension<dynamic>>[gridTheme]);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Data Grid Example',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const DataGridShowcaseScreen(),
    );
  }
}
