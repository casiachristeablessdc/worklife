import 'package:flutter_test/flutter_test.dart';
import 'package:worklife/main.dart';

void main() {
  testWidgets('WorkLife app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const WorkLifeApp());

    expect(find.text('WorkLife foundation ready!'), findsOneWidget);
  });
}