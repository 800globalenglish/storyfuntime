import 'package:flutter_test/flutter_test.dart';
import 'package:story_fun_time/main.dart';

void main() {
  testWidgets('App loads and shows the home screen buttons', (WidgetTester tester) async {
    await tester.pumpWidget(const StoryFunTimeApp());
    await tester.pump();

    expect(find.text('Go to Stories'), findsOneWidget);
    expect(find.text('Go to Characters'), findsOneWidget);
  });
}
