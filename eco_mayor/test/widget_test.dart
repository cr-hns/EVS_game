import 'package:flutter_test/flutter_test.dart';
import 'package:eco_mayor/main.dart';

void main() {
  testWidgets('EcoMayor builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const EcoMayorApp());
    expect(find.text('Environmental City Simulation'), findsOneWidget);
  });
}
