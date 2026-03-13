import 'package:flutter_test/flutter_test.dart';
import 'package:optima_healthcare_mobile/app/app.dart';

void main() {
  testWidgets('Login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const OptimaHealthcareApp());

    expect(find.text('Padam Heart Care Centre Login'), findsOneWidget);
  });
}
