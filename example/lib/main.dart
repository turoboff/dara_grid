import 'package:data_grid/data_grid.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const DataGridExampleApp());
}

class DataGridExampleApp extends StatelessWidget {
  const DataGridExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Data Grid Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A84FF)),
        useMaterial3: true,
      ),
      home: const DataGridShowcaseScreen(),
    );
  }
}
