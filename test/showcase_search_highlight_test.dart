import 'package:data_grid/src/showcase/data_grid_showcase_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'highlights matched text when the search query omits whitespace',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: DataGridShowcaseScreen()),
      );
      await tester.pumpAndSettle();

      final Finder searchField = find.widgetWithIcon(
        TextFormField,
        Icons.search_rounded,
      );
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'northamerica');
      await tester.pumpAndSettle();

      expect(find.text('North America'), findsWidgets);

      final RichText regionText = tester.widget<RichText>(
        find.byWidgetPredicate((Widget widget) {
          if (widget is! RichText) {
            return false;
          }

          final InlineSpan span = widget.text;
          if (span.toPlainText() != 'North America') {
            return false;
          }

          return _containsHighlight(span, const Color(0xFFFFF3B0));
        }).first,
      );

      expect(
        _containsHighlight(regionText.text, const Color(0xFFFFF3B0)),
        isTrue,
      );
    },
  );
}

bool _containsHighlight(InlineSpan span, Color expectedColor) {
  if (span is TextSpan) {
    if (span.style?.backgroundColor == expectedColor &&
        span.text != null &&
        span.text!.isNotEmpty) {
      return true;
    }

    final List<InlineSpan>? children = span.children;
    if (children == null) {
      return false;
    }

    return children.any(
      (InlineSpan child) => _containsHighlight(child, expectedColor),
    );
  }

  return false;
}
