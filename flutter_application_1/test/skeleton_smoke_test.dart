import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/theme.dart';
import 'package:flutter_application_1/ui/widgets/common.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: ListView(padding: const EdgeInsets.all(16), children: [child]),
    ),
  );
}

void main() {
  testWidgets('MetricTile iskeletten değere geçerken yüksekliği korur', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const MetricTile(
          label: 'Kalori',
          value: '0',
          unit: 'kcal',
          loading: true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final loadingHeight = tester.getSize(find.byType(MetricTile)).height;
    expect(find.text('Kalori'), findsOneWidget);
    expect(find.text('0'), findsNothing);

    await tester.pumpWidget(
      _wrap(
        const MetricTile(label: 'Kalori', value: '1234', unit: 'kcal'),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(MetricTile)).height, loadingHeight);
    expect(find.text('1234'), findsOneWidget);
  });

  testWidgets('ContentSwap geçiş sırasında yeni içeriğin boyutunu alır', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ContentSwap(
          loading: true,
          skeleton: Skeleton(height: 40),
          child: SizedBox(height: 120, child: Text('içerik')),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(find.byType(ContentSwap)).height, 40);

    await tester.pumpWidget(
      _wrap(
        const ContentSwap(
          loading: false,
          skeleton: Skeleton(height: 40),
          child: SizedBox(height: 120, child: Text('içerik')),
        ),
      ),
    );
    // Geçişin ortası: eski iskelet hâlâ ekranda ama boyut yeniye göre.
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(find.byType(ContentSwap)).height, 120);
    await tester.pumpAndSettle();
    expect(find.text('içerik'), findsOneWidget);
  });

  testWidgets('AsyncContent iskelet verildiğinde spinner göstermez', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        AsyncContent<String>(
          loading: true,
          error: null,
          data: null,
          onRetry: () {},
          skeleton: const Skeleton(height: 40),
          builder: (value) => Text(value),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(Skeleton), findsOneWidget);
  });
}
