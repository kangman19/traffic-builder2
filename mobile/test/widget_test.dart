import 'package:flutter_test/flutter_test.dart';
import 'package:traffic_builder/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TrafficBuilderApp());
    expect(find.text('Traffic Builder'), findsOneWidget);
  });
}
