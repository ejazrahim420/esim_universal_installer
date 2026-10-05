import 'package:flutter_test/flutter_test.dart';
import 'package:esim_universal_installer_example/main.dart';

void main() {
  testWidgets('example app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const EsimInstallerExampleApp());
    await tester.pump();

    expect(find.text('eSIM Universal Installer'), findsOneWidget);
    expect(find.text('Install eSIM'), findsOneWidget);
  });
}
