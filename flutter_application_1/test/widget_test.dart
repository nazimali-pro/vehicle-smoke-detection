import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('App loads smoke and plate UI', (WidgetTester tester) async {
    await tester.pumpWidget(const VehicleSmokeApp());
    expect(find.text('Vehicle Smoke & Plate AI'), findsOneWidget);
  });
}
